// Small compatibility surface for the macOS-only Metal observer API used by
// the v469e binary. iOS has a single default-device path instead.

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <os/lock.h>
#import <math.h>
#import <stdlib.h>
#import <string.h>

typedef void (^UT99MetalDeviceHandler)(id device, NSString *notificationName);

NSArray *MTLCopyAllDevicesWithObserver(id *observer, UT99MetalDeviceHandler handler) {
    if (observer) *observer = nil;
    id device = MTLCreateSystemDefaultDevice();
    if (device && handler) handler(device, @"added");
    return device ? @[device] : @[];
}

void MTLRemoveDeviceObserver(id observer) {
    (void)observer;
}

typedef struct {
    NSUInteger width;
    NSUInteger height;
} UT99BC1TextureInfo;

static NSMapTable *UT99BC1Textures;
static NSLock *UT99BC1Lock;
static IMP UT99OriginalNewTexture;
static IMP UT99OriginalReplaceRegion;
static IMP UT99OriginalReplaceRegionSlice;
static BOOL UT99BC1Installed;

// FruCoRe owns a separate SDL Metal window, so the host MTKView cannot report
// game FPS. Measure the renderer at the command buffer presentation boundary
// instead. The bounded ring is allocation-free on the render thread and the
// public snapshot function copies it while holding the lock only briefly.
#define UT99_PRESENTATION_SAMPLE_COUNT 2048
static os_unfair_lock UT99PresentationLock = OS_UNFAIR_LOCK_INIT;
static CFTimeInterval UT99PresentationIntervals[UT99_PRESENTATION_SAMPLE_COUNT];
static NSUInteger UT99PresentationSampleIndex;
static NSUInteger UT99PresentationSampleCount;
static CFTimeInterval UT99LastPresentationTime;
static uint64_t UT99PresentedFrameCount;
static uint64_t UT99PresentedDrawableWidth;
static uint64_t UT99PresentedDrawableHeight;
static IMP UT99OriginalPresentDrawable;
static BOOL UT99PresentationHookInstalled;

static int UT99CompareIntervals(const void *left, const void *right) {
    CFTimeInterval a = *(const CFTimeInterval *)left;
    CFTimeInterval b = *(const CFTimeInterval *)right;
    return (a > b) - (a < b);
}

static void UT99PresentDrawable(id commandBuffer, SEL selector, id<CAMetalDrawable> drawable) {
    CFTimeInterval now = CACurrentMediaTime();
    NSUInteger width = drawable.texture.width;
    NSUInteger height = drawable.texture.height;
    os_unfair_lock_lock(&UT99PresentationLock);
    if (UT99LastPresentationTime > 0) {
        CFTimeInterval interval = now - UT99LastPresentationTime;
        // Ignore debugger pauses and clock discontinuities; these are not
        // renderer frame times and would poison the bounded low-percentile.
        if (interval > 0 && interval < 1.0) {
            UT99PresentationIntervals[UT99PresentationSampleIndex] = interval;
            UT99PresentationSampleIndex = (UT99PresentationSampleIndex + 1) % UT99_PRESENTATION_SAMPLE_COUNT;
            UT99PresentationSampleCount = MIN(UT99PresentationSampleCount + 1,
                                              UT99_PRESENTATION_SAMPLE_COUNT);
        }
    }
    UT99LastPresentationTime = now;
    UT99PresentedFrameCount += 1;
    UT99PresentedDrawableWidth = width;
    UT99PresentedDrawableHeight = height;
    os_unfair_lock_unlock(&UT99PresentationLock);
    ((void (*)(id, SEL, id<CAMetalDrawable>))UT99OriginalPresentDrawable)(
        commandBuffer, selector, drawable);
}

void UT99MetalCopyPresentationMetrics(double *averageFPS, double *onePercentLowFPS,
                                      double *averageFrameTimeMS, uint64_t *frameCount,
                                      uint64_t *drawableWidth, uint64_t *drawableHeight) {
    CFTimeInterval samples[UT99_PRESENTATION_SAMPLE_COUNT];
    NSUInteger count;
    os_unfair_lock_lock(&UT99PresentationLock);
    count = UT99PresentationSampleCount;
    if (count > 0) memcpy(samples, UT99PresentationIntervals, count * sizeof(CFTimeInterval));
    uint64_t frames = UT99PresentedFrameCount;
    uint64_t width = UT99PresentedDrawableWidth;
    uint64_t height = UT99PresentedDrawableHeight;
    os_unfair_lock_unlock(&UT99PresentationLock);

    double fps = 0;
    double lowFPS = 0;
    double frameMS = 0;
    if (count > 0) {
        double total = 0;
        for (NSUInteger index = 0; index < count; index++) total += samples[index];
        double average = total / (double)count;
        fps = average > 0 ? 1.0 / average : 0;
        frameMS = average * 1000.0;
        qsort(samples, count, sizeof(CFTimeInterval), UT99CompareIntervals);
        NSUInteger lowCount = MAX((NSUInteger)1, (count + 99) / 100);
        double lowTotal = 0;
        for (NSUInteger index = count - lowCount; index < count; index++) {
            lowTotal += samples[index];
        }
        double lowAverage = lowTotal / (double)lowCount;
        lowFPS = lowAverage > 0 ? 1.0 / lowAverage : 0;
    }
    if (averageFPS) *averageFPS = fps;
    if (onePercentLowFPS) *onePercentLowFPS = lowFPS;
    if (averageFrameTimeMS) *averageFrameTimeMS = frameMS;
    if (frameCount) *frameCount = frames;
    if (drawableWidth) *drawableWidth = width;
    if (drawableHeight) *drawableHeight = height;
}

static void UT99InstallPresentationHook(id<MTLDevice> device) {
    if (UT99PresentationHookInstalled || !device) return;
    id<MTLCommandQueue> queue = [device newCommandQueue];
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    Class commandBufferClass = [commandBuffer class];
    Method presentMethod = class_getInstanceMethod(commandBufferClass, @selector(presentDrawable:));
    if (!presentMethod) {
        NSLog(@"UT99 Metal presentation metrics unavailable: no presentDrawable method");
        return;
    }
    UT99OriginalPresentDrawable = method_getImplementation(presentMethod);
    method_setImplementation(presentMethod, (IMP)UT99PresentDrawable);
    UT99PresentationHookInstalled = YES;
    NSLog(@"UT99 Metal presentation metrics installed commandBuffer=%@",
          NSStringFromClass(commandBufferClass));
}

static BOOL UT99IsBC1(MTLPixelFormat format) {
    NSUInteger value = (NSUInteger)format;
    return value == 129 || value == 130;
}

static uint8_t UT99Expand5(uint16_t value) {
    return (uint8_t)((value << 3) | (value >> 2));
}

static void UT99DecodeBC1Block(const uint8_t *source, uint8_t *destination,
                               NSUInteger destinationRowBytes, NSUInteger blockX,
                               NSUInteger blockY, NSUInteger width, NSUInteger height) {
    uint16_t color0 = (uint16_t)source[0] | ((uint16_t)source[1] << 8);
    uint16_t color1 = (uint16_t)source[2] | ((uint16_t)source[3] << 8);
    uint8_t colors[4][4] = {0};
    colors[0][0] = UT99Expand5((color0 >> 11) & 0x1f);
    colors[0][1] = UT99Expand5((color0 >> 5) & 0x3f);
    colors[0][2] = UT99Expand5(color0 & 0x1f);
    colors[0][3] = 255;
    colors[1][0] = UT99Expand5((color1 >> 11) & 0x1f);
    colors[1][1] = UT99Expand5((color1 >> 5) & 0x3f);
    colors[1][2] = UT99Expand5(color1 & 0x1f);
    colors[1][3] = 255;
    if (color0 > color1) {
        for (NSUInteger channel = 0; channel < 3; channel++) {
            colors[2][channel] = (uint8_t)((2 * colors[0][channel] + colors[1][channel]) / 3);
            colors[3][channel] = (uint8_t)((colors[0][channel] + 2 * colors[1][channel]) / 3);
        }
        colors[2][3] = colors[3][3] = 255;
    } else {
        for (NSUInteger channel = 0; channel < 3; channel++) {
            colors[2][channel] = (uint8_t)((colors[0][channel] + colors[1][channel]) / 2);
        }
        colors[2][3] = 255;
        colors[3][3] = 0;
    }
    uint32_t indices = (uint32_t)source[4] | ((uint32_t)source[5] << 8) |
                       ((uint32_t)source[6] << 16) | ((uint32_t)source[7] << 24);
    for (NSUInteger y = 0; y < 4; y++) {
        NSUInteger outputY = blockY + y;
        if (outputY >= height) continue;
        for (NSUInteger x = 0; x < 4; x++) {
            NSUInteger outputX = blockX + x;
            uint8_t index = (uint8_t)(indices & 3);
            indices >>= 2;
            if (outputX < width) {
                memcpy(destination + outputY * destinationRowBytes + outputX * 4,
                       colors[index], 4);
            }
        }
    }
}

static void UT99ExpandBC1(const void *source, NSUInteger sourceRowBytes,
                           NSUInteger width, NSUInteger height, void *destination,
                           NSUInteger destinationRowBytes) {
    NSUInteger rows = MAX(1, (height + 3) / 4);
    NSUInteger columns = MAX(1, (width + 3) / 4);
    const uint8_t *bytes = source;
    for (NSUInteger y = 0; y < rows; y++) {
        for (NSUInteger x = 0; x < columns; x++) {
            UT99DecodeBC1Block(bytes + y * sourceRowBytes + x * 8,
                               destination, destinationRowBytes, x * 4, y * 4,
                               width, height);
        }
    }
}

static NSValue *UT99TextureKey(id texture) {
    return [NSValue valueWithNonretainedObject:texture];
}

static void UT99RememberBC1Texture(id texture, NSUInteger width, NSUInteger height) {
    if (!texture) return;
    UT99BC1TextureInfo info = { width, height };
    NSValue *value = [NSValue value:&info withObjCType:@encode(UT99BC1TextureInfo)];
    [UT99BC1Lock lock];
    [UT99BC1Textures setObject:value forKey:UT99TextureKey(texture)];
    [UT99BC1Lock unlock];
}

static BOOL UT99LookupBC1Texture(id texture, UT99BC1TextureInfo *info) {
    [UT99BC1Lock lock];
    NSValue *value = [UT99BC1Textures objectForKey:UT99TextureKey(texture)];
    [UT99BC1Lock unlock];
    if (!value) return NO;
    [value getValue:info];
    return YES;
}

static id UT99NewTextureWithDescriptor(id device, SEL selector,
                                       MTLTextureDescriptor *descriptor) {
    MTLPixelFormat originalFormat = descriptor.pixelFormat;
    BOOL expand = UT99IsBC1(originalFormat);
    NSUInteger width = descriptor.width;
    NSUInteger height = descriptor.height;
    if (expand) descriptor.pixelFormat = MTLPixelFormatRGBA8Unorm;
    id texture = ((id (*)(id, SEL, id))UT99OriginalNewTexture)(device, selector, descriptor);
    if (expand) {
        descriptor.pixelFormat = originalFormat;
        UT99RememberBC1Texture(texture, width, height);
    }
    return texture;
}

static void UT99ReplaceRegion(id texture, SEL selector, MTLRegion region,
                              NSUInteger level, const void *bytes, NSUInteger rowBytes) {
    UT99BC1TextureInfo info;
    if (!bytes || !UT99LookupBC1Texture(texture, &info)) {
        ((void (*)(id, SEL, MTLRegion, NSUInteger, const void *, NSUInteger))UT99OriginalReplaceRegion)(
            texture, selector, region, level, bytes, rowBytes);
        return;
    }
    NSUInteger width = region.size.width;
    NSUInteger height = region.size.height;
    NSUInteger outputRowBytes = width * 4;
    void *expanded = calloc(MAX(1, height), MAX(1, outputRowBytes));
    if (!expanded) return;
    UT99ExpandBC1(bytes, rowBytes, width, height, expanded, outputRowBytes);
    ((void (*)(id, SEL, MTLRegion, NSUInteger, const void *, NSUInteger))UT99OriginalReplaceRegion)(
        texture, selector, region, level, expanded, outputRowBytes);
    free(expanded);
}

static void UT99ReplaceRegionSlice(id texture, SEL selector, MTLRegion region,
                                   NSUInteger level, NSUInteger slice, const void *bytes,
                                   NSUInteger rowBytes, NSUInteger imageBytes) {
    UT99BC1TextureInfo info;
    if (!bytes || !UT99LookupBC1Texture(texture, &info)) {
        ((void (*)(id, SEL, MTLRegion, NSUInteger, NSUInteger, const void *, NSUInteger, NSUInteger))UT99OriginalReplaceRegionSlice)(
            texture, selector, region, level, slice, bytes, rowBytes, imageBytes);
        return;
    }
    NSUInteger width = region.size.width;
    NSUInteger height = region.size.height;
    NSUInteger outputRowBytes = width * 4;
    NSUInteger outputImageBytes = outputRowBytes * height;
    void *expanded = calloc(MAX(1, height), MAX(1, outputRowBytes));
    if (!expanded) return;
    UT99ExpandBC1(bytes, rowBytes, width, height, expanded, outputRowBytes);
    ((void (*)(id, SEL, MTLRegion, NSUInteger, NSUInteger, const void *, NSUInteger, NSUInteger))UT99OriginalReplaceRegionSlice)(
        texture, selector, region, level, slice, expanded, outputRowBytes, outputImageBytes);
    free(expanded);
}

void UT99InstallBC1TextureFallback(void) {
    if (UT99BC1Installed) return;
    UT99BC1Installed = YES;
    UT99BC1Textures = [NSMapTable strongToStrongObjectsMapTable];
    UT99BC1Lock = [NSLock new];
    id device = MTLCreateSystemDefaultDevice();
    UT99InstallPresentationHook(device);
    Class deviceClass = [device class];
    Method newTextureMethod = class_getInstanceMethod(deviceClass, @selector(newTextureWithDescriptor:));
    if (!newTextureMethod) {
        NSLog(@"UT99 BC1 fallback unavailable: no Metal descriptor texture factory");
        return;
    }
    UT99OriginalNewTexture = method_getImplementation(newTextureMethod);
    method_setImplementation(newTextureMethod, (IMP)UT99NewTextureWithDescriptor);
    id descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                        width:1 height:1 mipmapped:NO];
    id probeTexture = [device newTextureWithDescriptor:descriptor];
    Class textureClass = [probeTexture class];
    Method replaceMethod = class_getInstanceMethod(textureClass, @selector(replaceRegion:mipmapLevel:withBytes:bytesPerRow:));
    if (replaceMethod) {
        UT99OriginalReplaceRegion = method_getImplementation(replaceMethod);
        method_setImplementation(replaceMethod, (IMP)UT99ReplaceRegion);
    }
    Method sliceMethod = class_getInstanceMethod(textureClass, @selector(replaceRegion:mipmapLevel:slice:withBytes:bytesPerRow:bytesPerImage:));
    if (sliceMethod) {
        UT99OriginalReplaceRegionSlice = method_getImplementation(sliceMethod);
        method_setImplementation(sliceMethod, (IMP)UT99ReplaceRegionSlice);
    }
    NSLog(@"UT99 BC1 fallback installed device=%@ texture=%@ replace=%@ slice=%@",
          NSStringFromClass(deviceClass), NSStringFromClass(textureClass),
          replaceMethod ? @"true" : @"false", sliceMethod ? @"true" : @"false");
}
