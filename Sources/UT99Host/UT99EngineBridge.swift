import Darwin
import Foundation
import UIKit

/// Host boundary for the generated engine image.
///
/// Loading and entry invocation are explicit. This class never patches code or
/// uses JIT, and it does not report success unless dyld actually loads the
/// build-time transformed image.
final class UT99EngineBridge {
    private enum SettingsKey {
        static let lookSensitivity = "ut99.input.lookSensitivity"
        static let invertLookY = "ut99.input.invertLookY"
        static let safeTextures = "ut99.graphics.safeTextures"
        static let verticalSync = "ut99.graphics.vsync"
        static let audioEnabled = "ut99.audio.enabled"
    }
    struct RendererMetrics {
        let averageFPS: Double
        let onePercentLowFPS: Double
        let averageFrameTimeMS: Double
        let frameCount: UInt64
        let drawableWidth: UInt64
        let drawableHeight: UInt64

        var hasPresentedFrames: Bool { frameCount > 0 && drawableWidth > 0 && drawableHeight > 0 }
    }
    enum ProbeResult {
        case notEmbedded
        case loaded
        case started
        case failed(String)

        var statusText: String {
            switch self {
            case .notEmbedded: return "Engine artifact not embedded"
            case .loaded: return "Engine image loaded; entry invocation pending"
            case .started: return "Original engine entry started"
            case let .failed(message): return "Engine load failed: \(message)"
            }
        }
    }

    private var handle: UnsafeMutableRawPointer?
    private var metalShimHandle: UnsafeMutableRawPointer?
    private var movementKeys = Set<Int32>()

    init() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.lookSensitivity: 1.0,
            SettingsKey.invertLookY: false,
            SettingsKey.safeTextures: true,
            SettingsKey.verticalSync: true,
            SettingsKey.audioEnabled: false
        ])
    }

    deinit {
        if let handle {
            dlclose(handle)
        }
        if let metalShimHandle {
            dlclose(metalShimHandle)
        }
    }

    func probeEmbeddedImage() -> ProbeResult {
        guard let imageURL = Bundle.main.bundleURL
            .appendingPathComponent("Frameworks", isDirectory: true)
            .appendingPathComponent("UnrealTournament.dylib") as URL?,
              FileManager.default.fileExists(atPath: imageURL.path) else {
            return .notEmbedded
        }

        guard let handle = dlopen(imageURL.path, RTLD_NOW | RTLD_LOCAL) else {
            let message = dlerror().map { String(cString: $0) } ?? "unknown dyld error"
            return .failed(message)
        }
        self.handle = handle
        return .loaded
    }

    func startOriginalEntry(
        connectURL: String? = nil,
        onExit: ((Int32) -> Void)? = nil
    ) -> ProbeResult {
        if handle == nil {
            let result = probeEmbeddedImage()
            if case .loaded = result {
                // Continue to the resolved handle below.
            } else {
                return result
            }
        }
        guard let handle else { return .failed("engine image is not loaded") }
        guard let symbol = dlsym(handle, "main") else {
            let message = dlerror().map { String(cString: $0) } ?? "main symbol not found"
            return .failed(message)
        }
        typealias EngineMain = @convention(c) (Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32
        let entry = unsafeBitCast(symbol, to: EngineMain.self)
        // We invoke the original main symbol directly instead of going
        // through SDL's platform-specific SDL_main wrapper. SDL otherwise
        // rejects SDL_Init with its "did you include SDL_main.h" error.
        if let readySymbol = dlsym(handle, "SDL_SetMainReady") {
            typealias SetMainReady = @convention(c) () -> Void
            unsafeBitCast(readySymbol, to: SetMainReady.self)()
        } else {
            NSLog("UT99EngineBridge: SDL_SetMainReady was not exported")
        }
        let supportRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Unreal Tournament", isDirectory: true)
        // The original macOS launcher starts in Contents/MacOS and then
        // appChdirSystem() enters Contents/MacOS/System. The iOS host has
        // already staged the equivalent tree in Application Support, so enter
        // at its System directory before invoking the unmodified engine.
        let systemRoot = supportRoot.appendingPathComponent("System", isDirectory: true)
        try? FileManager.default.createDirectory(at: systemRoot, withIntermediateDirectories: true)
        let changedDirectory = FileManager.default.changeCurrentDirectoryPath(systemRoot.path)
        var cwdBuffer = [CChar](repeating: 0, count: 4096)
        let cwd = getcwd(&cwdBuffer, cwdBuffer.count).map { String(cString: $0) } ?? "<unavailable>"
        let iniPath = systemRoot.appendingPathComponent("UnrealTournament.ini").path
        let iniReadable = access(iniPath, R_OK) == 0
        let metalShimPath = Bundle.main.bundleURL
            .appendingPathComponent("Frameworks", isDirectory: true)
            .appendingPathComponent("UT99MetalShim.dylib").path
        if metalShimHandle == nil {
            metalShimHandle = dlopen(metalShimPath, RTLD_NOW | RTLD_LOCAL)
        }
        if let installSymbol = dlsym(metalShimHandle ?? handle, "UT99InstallBC1TextureFallback") {
            typealias InstallBC1Fallback = @convention(c) () -> Void
            unsafeBitCast(installSymbol, to: InstallBC1Fallback.self)()
            NSLog("UT99EngineBridge: Metal shim BC1 fallback installed")
        } else {
            NSLog("UT99EngineBridge: Metal shim BC1 fallback is not loaded")
        }
        applyAppleGraphicsProfile(
            to: URL(fileURLWithPath: iniPath),
            safeTextures: UserDefaults.standard.bool(forKey: SettingsKey.safeTextures),
            verticalSync: UserDefaults.standard.bool(forKey: SettingsKey.verticalSync)
        )
        applyAppleNetworkProfile(to: URL(fileURLWithPath: iniPath))
        if CommandLine.arguments.contains("-UT99AudioEnabled") || UserDefaults.standard.bool(forKey: SettingsKey.audioEnabled) {
            applyAppleAudioProfile(to: URL(fileURLWithPath: iniPath))
        }
        NSLog("UT99EngineBridge engine cwd changed=%@ path=%@ actual=%@ iniReadable=%@", changedDirectory.description, systemRoot.path, cwd, iniReadable ? "true" : "false")
        let stdoutURL = supportRoot.appendingPathComponent("UT99-engine.stdout")
        freopen(stdoutURL.path, "a", stdout)
        freopen(stdoutURL.path, "a", stderr)
        setbuf(stdout, nil)
        setbuf(stderr, nil)
        let readableText = iniReadable ? "true" : "false"
        let runtimeCheck = "UT99EngineBridge cwd=\(cwd) ini=\(iniPath) readable=\(readableText)\\n"
        FileHandle.standardError.write(Data(runtimeCheck.utf8))
        let audioEnabled = CommandLine.arguments.contains("-UT99AudioEnabled") || UserDefaults.standard.bool(forKey: SettingsKey.audioEnabled)
        let requestedMap = commandLineValue(prefix: "-UT99Map=") ?? "DM-Deck16]["
        let requestedGame = commandLineValue(prefix: "-UT99Game=") ?? "Botpack.DeathMatchPlus"
        var arguments: [String]
        if let connectURL, !connectURL.isEmpty {
            // Pass the canonical Unreal URL directly to the original engine;
            // no replacement protocol or native proxy is introduced here.
            arguments = ["UnrealTournament", connectURL, "-log"]
        } else if CommandLine.arguments.contains("-UT99AutoMatch") {
            // Diagnostic stock-match path. This still enters the original
            // engine and Botpack game rules; it only bypasses the intro map.
            arguments = ["UnrealTournament", "\(requestedMap)?game=\(requestedGame)", "-log"]
        } else {
            arguments = ["UnrealTournament", "-log"]
        }
        if !audioEnabled {
            // Simulator and startup diagnostics remain deterministic and
            // explicitly silent unless the caller opts into the configured
            // ALAudio/FMOD path.
            arguments.append("-nosound")
        }
        let argv = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: arguments.count + 1)
        for (index, argument) in arguments.enumerated() {
            argv[index] = strdup(argument)
        }
        argv[arguments.count] = nil
        let invoke = {
            let exitCode = entry(Int32(arguments.count), argv)
            for index in arguments.indices {
                free(argv[index])
            }
            argv.deallocate()
            guard let onExit else { return }
            DispatchQueue.main.async { onExit(exitCode) }
        }
        if CommandLine.arguments.contains("-UT99EngineBackground") {
            // Explicit escape hatch for non-UIKit diagnostics only.
            Thread(block: invoke).start()
        } else {
            // SDL's UIKit video backend creates UIWindow/Metal objects and
            // must run the original entry on the main thread.
            DispatchQueue.main.async(execute: invoke)
        }
        return .started
    }

    private func commandLineValue(prefix: String) -> String? {
        CommandLine.arguments.first(where: { $0.hasPrefix(prefix) })?.dropFirst(prefix.count).description
    }

    private func applyAppleAudioProfile(to iniURL: URL) {
        guard var ini = try? String(contentsOf: iniURL, encoding: .utf8) else { return }
        // Keep the mobile source mix bounded and avoid an unnecessary HRTF
        // negotiation. Buffer allocation itself is fixed in the patched iOS
        // OpenAL Soft build; these remain conservative gameplay defaults.
        ini = ini.replacingOccurrences(of: "UseHRTF=Autodetect", with: "UseHRTF=False")
        // The stock INI contains this setting in several audio sections;
        // normalize every occurrence so an earlier profile cannot leak back
        // in through another subsystem.
        ini = ini.components(separatedBy: "\n").map { line in
            line.hasPrefix("EffectsChannels=") ? "EffectsChannels=16" : line
        }.joined(separator: "\n")
        try? ini.write(to: iniURL, atomically: true, encoding: .utf8)
        NSLog("UT99 applied Apple audio profile: HRTF off, 16 effect channels across audio sections")
    }

    private func applyAppleNetworkProfile(to iniURL: URL) {
        guard var ini = try? String(contentsOf: iniURL, encoding: .utf8) else { return }
        let section = "[UMenu.UMenuNetworkClientWindow]"
        if ini.contains("bShownWindow=False") {
            ini = ini.replacingOccurrences(of: "bShownWindow=False", with: "bShownWindow=True")
        } else if !ini.contains("bShownWindow=True"), ini.contains(section) {
            ini = ini.replacingOccurrences(of: section, with: section + "\nbShownWindow=True")
        }

        // SDL reports UIKit pointer deltas in logical points. WindowConsole's
        // desktop default scales every axis delta by 0.6, which makes an
        // absolute iPad tap drift away from the visible UWindow target. Keep
        // the original engine path but make its menu cursor point-for-point on
        // Apple touch/pointer surfaces.
        let consoleSection = "[UMenu.UnrealConsole]"
        var inConsoleSection = false
        var normalizedLines: [String] = []
        for line in ini.components(separatedBy: "\n") {
            if line == consoleSection {
                inConsoleSection = true
                normalizedLines.append(line)
                normalizedLines.append("MouseScale=1.000000")
                continue
            }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                inConsoleSection = false
            }
            if inConsoleSection && line.hasPrefix("MouseScale=") { continue }
            normalizedLines.append(line)
        }
        ini = normalizedLines.joined(separator: "\n")
        try? ini.write(to: iniURL, atomically: true, encoding: .utf8)
        NSLog("UT99 applied Apple network/input profile: configured-speed prompt acknowledged, UWindow MouseScale=1")
    }

    private func applyAppleGraphicsProfile(to iniURL: URL, safeTextures: Bool, verticalSync: Bool) {
        guard var ini = try? String(contentsOf: iniURL, encoding: .utf8) else { return }
        // The desktop renderer may select S3TC/DXT1 textures. The iOS Metal
        // path must receive decompressed 32-bit textures because BC1 can be
        // unavailable on the simulator and on some Apple GPU families.
        if safeTextures {
            ini = ini.replacingOccurrences(of: "UseS3TC=True", with: "UseS3TC=False")
            ini = ini.replacingOccurrences(of: "UseCompression=True", with: "UseCompression=False")
            ini = ini.replacingOccurrences(of: "TexDXT1ToDXT3=False", with: "TexDXT1ToDXT3=True")
            ini = ini.replacingOccurrences(of: "Use32BitTextures=False", with: "Use32BitTextures=True")
        }

        // EctoPad composes controls over a full-bleed game surface. Publish
        // the active landscape dimensions to Unreal instead of preserving the
        // legacy 512x384 desktop request or carving out a black control bay.
        // Values remain in points; Metal applies the native backing scale.
        let screenSize = UIScreen.main.bounds.size
        let shortEdge = max(1, floor(min(screenSize.width, screenSize.height)))
        let longEdge = max(shortEdge, floor(max(screenSize.width, screenSize.height)))
        let gameHeight = Int(shortEdge)
        let gameWidth = Int(longEdge)
        var section = ""
        let syncValue = verticalSync ? "True" : "False"
        ini = ini.components(separatedBy: "\n").map { line in
            if line.hasPrefix("[") && line.hasSuffix("]") { section = line }
            if section == "[SDLDrv.SDLClient]" {
                if line.hasPrefix("WindowedViewportX=") { return "WindowedViewportX=\(gameWidth)" }
                if line.hasPrefix("WindowedViewportY=") { return "WindowedViewportY=\(gameHeight)" }
                if line.hasPrefix("FullscreenViewportX=") { return "FullscreenViewportX=\(gameWidth)" }
                if line.hasPrefix("FullscreenViewportY=") { return "FullscreenViewportY=\(gameHeight)" }
            }
            if section == "[FruCoRe.FruCoReRenderDevice]" && line.hasPrefix("UseVSync=") {
                return "UseVSync=\(syncValue)"
            }
            return line
        }.joined(separator: "\n")
        let frucoreSection = "[FruCoRe.FruCoReRenderDevice]"
        if ini.contains(frucoreSection), !ini.contains("UseS3TC=False\n") {
            ini = ini.replacingOccurrences(
                of: frucoreSection + "\n",
                with: frucoreSection + "\nUseS3TC=False\nUseCompression=False\nTexDXT1ToDXT3=True\nUse32BitTextures=True\n"
            )
        }
        try? ini.write(to: iniURL, atomically: true, encoding: .utf8)
        NSLog("UT99 applied Apple graphics profile: safeTextures=%@ vsync=%@ SDL full-bleed=%dx%d",
              safeTextures ? "true" : "false", verticalSync ? "true" : "false",
              gameWidth, gameHeight)
    }

    func rendererMetrics() -> RendererMetrics {
        guard let metalShimHandle,
              let symbol = dlsym(metalShimHandle, "UT99MetalCopyPresentationMetrics") else {
            return RendererMetrics(averageFPS: 0, onePercentLowFPS: 0,
                                   averageFrameTimeMS: 0, frameCount: 0,
                                   drawableWidth: 0, drawableHeight: 0)
        }
        typealias CopyMetrics = @convention(c) (
            UnsafeMutablePointer<Double>?, UnsafeMutablePointer<Double>?,
            UnsafeMutablePointer<Double>?, UnsafeMutablePointer<UInt64>?,
            UnsafeMutablePointer<UInt64>?, UnsafeMutablePointer<UInt64>?
        ) -> Void
        let copyMetrics = unsafeBitCast(symbol, to: CopyMetrics.self)
        var averageFPS = 0.0
        var onePercentLowFPS = 0.0
        var averageFrameTimeMS = 0.0
        var frameCount: UInt64 = 0
        var drawableWidth: UInt64 = 0
        var drawableHeight: UInt64 = 0
        copyMetrics(&averageFPS, &onePercentLowFPS, &averageFrameTimeMS,
                    &frameCount, &drawableWidth, &drawableHeight)
        return RendererMetrics(averageFPS: averageFPS,
                               onePercentLowFPS: onePercentLowFPS,
                               averageFrameTimeMS: averageFrameTimeMS,
                               frameCount: frameCount,
                               drawableWidth: drawableWidth,
                               drawableHeight: drawableHeight)
    }

    func runPerformanceSmokeTest() {
        let supportRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Unreal Tournament", isDirectory: true)
        let outputURL = supportRoot.appendingPathComponent("UT99-performance.log")
        try? Data().write(to: outputURL, options: .atomic)
        for seconds in [3, 6, 10] {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .seconds(seconds)) { [weak self] in
                guard let self else { return }
                let metrics = self.rendererMetrics()
                let line = String(
                    format: "t=%ds frames=%llu avgFPS=%.2f onePercentLowFPS=%.2f frameMS=%.3f drawable=%llux%llu\n",
                    seconds, metrics.frameCount, metrics.averageFPS,
                    metrics.onePercentLowFPS, metrics.averageFrameTimeMS,
                    metrics.drawableWidth, metrics.drawableHeight
                )
                if let data = line.data(using: .utf8),
                   let file = try? FileHandle(forWritingTo: outputURL) {
                    _ = try? file.seekToEnd()
                    try? file.write(contentsOf: data)
                    try? file.close()
                }
                NSLog("UT99 performance %@", line.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }

    /// Translate host touch semantics into SDL2 events understood by the
    /// original UT input path. This is deliberately an SDL boundary: the
    /// engine remains unmodified and the host does not invent a second input
    /// protocol.
    func publishTouchAction(_ action: GoldenPadTouchOverlay.Action, pressed: Bool) {
        NSLog("UT99TouchBridge action=%@ pressed=%@", action.rawValue, pressed ? "true" : "false")
        switch action {
        case .primaryFire: pushMouseButton(button: 1, pressed: pressed) // LeftMouse=Fire
        case .alternateFire: pushMouseButton(button: 3, pressed: pressed) // RightMouse=AltFire
        case .jump: pushKey(key: 32, pressed: pressed) // Space=Jump
        case .use: pushKey(key: 13, pressed: pressed) // Enter=InventoryActivate
        case .crouch: pushKey(key: 99, pressed: pressed) // C=Duck
        case .nextWeapon: if pressed { pushMouseWheel(y: -1) } // MouseWheelDown
        case .previousWeapon: if pressed { pushMouseWheel(y: 1) } // MouseWheelUp
        case .scoreboard: pushKey(key: 1 << 30 | 58, pressed: pressed) // F1=ShowScores
        case .pause: pushKey(key: 27, pressed: pressed) // Escape opens/closes Unreal's original game menu
        }
    }

    func publishTouchMove(_ value: CGPoint, active: Bool) {
        // UT99's default movement bindings are digital W/A/S/D. Mouse motion
        // is camera look, so using it for the movement stick makes the player
        // spin instead of walk. Keep the analog gesture as a directional
        // digital hold and release each edge explicitly.
        let deadZone = CGFloat(UT99TouchConfiguration.load().movementDeadZone)
        var desired = Set<Int32>()
        if active {
            if value.y > deadZone { desired.insert(119) } // W: forward
            if value.y < -deadZone { desired.insert(115) } // S: backward
            if value.x < -deadZone { desired.insert(97) } // A: strafe left
            if value.x > deadZone { desired.insert(100) } // D: strafe right
        }
        for key in movementKeys.subtracting(desired) { pushKey(key: key, pressed: false) }
        for key in desired.subtracting(movementKeys) { pushKey(key: key, pressed: true) }
        movementKeys = desired
    }

    func releaseMovementKeys() {
        for key in movementKeys { pushKey(key: key, pressed: false) }
        movementKeys.removeAll()
    }

    func publishTouchLook(_ value: CGPoint, active: Bool) {
        let sensitivity = max(0.25, min(3.0, UserDefaults.standard.double(forKey: SettingsKey.lookSensitivity)))
        let invertY = UserDefaults.standard.bool(forKey: SettingsKey.invertLookY)
        let tuned = UT99TouchInputTuning.transformedLook(
            value,
            sensitivity: sensitivity,
            configuration: UT99TouchConfiguration.load(),
            invertY: invertY
        )
        pushMouseMotion(
            xrel: Int32((tuned.x * 900).rounded()),
            yrel: Int32((tuned.y * 900).rounded())
        )
        if !active { pushMouseMotion(xrel: 0, yrel: 0) }
    }

    /// Publish an absolute pointer location before each optional left-button
    /// edge. UWindow uses SDL's logical point-space mouse coordinates, while
    /// Metal independently renders at the native backing scale.
    func publishGameSurfacePointer(location: CGPoint, pressed: Bool?) {
        let x = Int32(max(0, min(CGFloat(Int32.max), location.x)).rounded())
        let y = Int32(max(0, min(CGFloat(Int32.max), location.y)).rounded())
        let (window, windowID) = focusedSDLWindow()
        if let handle,
           let symbol = dlsym(handle, "SDL_UT99SendMousePointer") {
            typealias SendPointer = @convention(c) (
                UnsafeMutableRawPointer?, Int32, Int32, Int32
            ) -> Int32
            let edge: Int32 = pressed.map { $0 ? 1 : 0 } ?? -1
            let result = unsafeBitCast(symbol, to: SendPointer.self)(window, x, y, edge)
            var stateX: Int32 = -1
            var stateY: Int32 = -1
            if let stateSymbol = dlsym(handle, "SDL_GetMouseState") {
                typealias GetMouseState = @convention(c) (
                    UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?
                ) -> UInt32
                _ = unsafeBitCast(stateSymbol, to: GetMouseState.self)(&stateX, &stateY)
            }
            NSLog("UT99PointerBridge point=%.1f,%.1f logical=%d,%d state=%d,%d windowID=%u pressed=%@ transport=stateful result=%d",
                  location.x, location.y, x, y, stateX, stateY, windowID,
                  pressed.map { $0 ? "true" : "false" } ?? "motion", result)
            return
        }
        if let window,
           let handle,
           let symbol = dlsym(handle, "SDL_WarpMouseInWindow") {
            typealias WarpMouse = @convention(c) (UnsafeMutableRawPointer?, Int32, Int32) -> Void
            unsafeBitCast(symbol, to: WarpMouse.self)(window, x, y)
        }
        NSLog("UT99PointerBridge point=%.1f,%.1f logical=%d,%d windowID=%u pressed=%@ transport=queued",
              location.x, location.y, x, y, windowID,
              pressed.map { $0 ? "true" : "false" } ?? "motion")
        pushMouseMotion(windowID: windowID, x: x, y: y, xrel: 0, yrel: 0)
        if let pressed {
            pushMouseButton(button: 1, pressed: pressed, windowID: windowID, x: x, y: y)
        }
    }

    private func focusedSDLWindow() -> (UnsafeMutableRawPointer?, UInt32) {
        guard let handle else { return (nil, 0) }
        typealias GetFocus = @convention(c) () -> UnsafeMutableRawPointer?
        var window: UnsafeMutableRawPointer?
        if let symbol = dlsym(handle, "SDL_GetMouseFocus") {
            window = unsafeBitCast(symbol, to: GetFocus.self)()
        }
        if window == nil, let symbol = dlsym(handle, "SDL_GetKeyboardFocus") {
            window = unsafeBitCast(symbol, to: GetFocus.self)()
        }
        guard let window,
              let idSymbol = dlsym(handle, "SDL_GetWindowID") else { return (window, 0) }
        typealias GetWindowID = @convention(c) (UnsafeMutableRawPointer?) -> UInt32
        return (window, unsafeBitCast(idSymbol, to: GetWindowID.self)(window))
    }

    /// Forward the subset of iPad hardware-key events used by the stock UT99
    /// bindings into the original SDL keyboard path. SDL's renderer window is
    /// deliberately render-only on iOS, so UIKit must own this boundary.
    func publishHardwareKey(usage: Int, pressed: Bool) {
        guard let key = SDLKeySym(usage: usage) else { return }
        NSLog("UT99KeyboardBridge usage=%hu sym=%d pressed=%@", usage, key, pressed ? "true" : "false")
        pushKey(key: key, pressed: pressed)
    }

    private func SDLKeySym(usage: Int) -> Int32? {
        switch usage {
        case UIKeyboardHIDUsage.keyboardA.rawValue: return 97
        case UIKeyboardHIDUsage.keyboardB.rawValue: return 98
        case UIKeyboardHIDUsage.keyboardC.rawValue: return 99
        case UIKeyboardHIDUsage.keyboardD.rawValue: return 100
        case UIKeyboardHIDUsage.keyboardS.rawValue: return 115
        case UIKeyboardHIDUsage.keyboardW.rawValue: return 119
        case UIKeyboardHIDUsage.keyboardSpacebar.rawValue: return 32
        case UIKeyboardHIDUsage.keyboardReturnOrEnter.rawValue: return 13
        case UIKeyboardHIDUsage.keyboardEscape.rawValue: return 27
        case UIKeyboardHIDUsage.keyboardTab.rawValue: return 9
        case UIKeyboardHIDUsage.keyboardF1.rawValue: return (1 << 30) | 58
        case UIKeyboardHIDUsage.keyboardF2.rawValue: return (1 << 30) | 59
        case UIKeyboardHIDUsage.keyboardF3.rawValue: return (1 << 30) | 60
        case UIKeyboardHIDUsage.keyboardF4.rawValue: return (1 << 30) | 61
        case UIKeyboardHIDUsage.keyboardF5.rawValue: return (1 << 30) | 62
        case UIKeyboardHIDUsage.keyboardF6.rawValue: return (1 << 30) | 63
        case UIKeyboardHIDUsage.keyboardF7.rawValue: return (1 << 30) | 64
        case UIKeyboardHIDUsage.keyboardF8.rawValue: return (1 << 30) | 65
        case UIKeyboardHIDUsage.keyboardF9.rawValue: return (1 << 30) | 66
        case UIKeyboardHIDUsage.keyboardF10.rawValue: return (1 << 30) | 67
        case UIKeyboardHIDUsage.keyboardF11.rawValue: return (1 << 30) | 68
        case UIKeyboardHIDUsage.keyboardF12.rawValue: return (1 << 30) | 69
        case UIKeyboardHIDUsage.keyboardUpArrow.rawValue: return (1 << 30) | 82
        case UIKeyboardHIDUsage.keyboardDownArrow.rawValue: return (1 << 30) | 81
        case UIKeyboardHIDUsage.keyboardLeftArrow.rawValue: return (1 << 30) | 80
        case UIKeyboardHIDUsage.keyboardRightArrow.rawValue: return (1 << 30) | 79
        default: return nil
        }
    }

    /// Diagnostic-only input probe. It uses the same semantic bridge as the
    /// UIKit overlay, but is driven by a timer so a simulator without touch
    /// injection can still prove SDL_PushEvent delivery while the original
    /// engine loop is alive. It is enabled only by -UT99TouchSmokeTest.
    func runTouchSmokeTest() {
        let sequence: [(GoldenPadTouchOverlay.Action, Bool)] = [
            (.primaryFire, true), (.primaryFire, false),
            (.alternateFire, true), (.alternateFire, false),
            (.jump, true), (.jump, false),
            (.use, true), (.use, false),
            (.crouch, true), (.crouch, false),
            (.nextWeapon, true), (.previousWeapon, true),
            (.scoreboard, true), (.scoreboard, false),
            (.pause, true), (.pause, false)
        ]
        let start = DispatchTime.now().uptimeNanoseconds
        for (index, item) in sequence.enumerated() {
            let delay = DispatchTimeInterval.milliseconds(250 + index * 110)
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000
                self.appendSmokeLog(String(format: "%.3f action=%@ pressed=%@", elapsed, item.0.rawValue, item.1 ? "true" : "false"))
                self.publishTouchAction(item.0, pressed: item.1)
            }
        }
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .milliseconds(850)) { [weak self] in
            guard let self else { return }
            self.appendSmokeLog("0.850 move value=0.75,-0.40 active=true")
            self.publishTouchMove(CGPoint(x: 0.75, y: -0.40), active: true)
            self.appendSmokeLog("0.900 move value=0,0 active=false")
            self.publishTouchMove(.zero, active: false)
        }
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .milliseconds(1_050)) { [weak self] in
            guard let self else { return }
            self.appendSmokeLog("1.050 look value=0.35,-0.20 active=true")
            self.publishTouchLook(CGPoint(x: 0.35, y: -0.20), active: true)
            self.appendSmokeLog("1.100 look value=0,0 active=false")
            self.publishTouchLook(.zero, active: false)
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .milliseconds(2_100)) { [weak self] in
            self?.appendSmokeLog("complete")
        }
    }

    /// Readiness-gated meaningful-session probe for one remote v469 server.
    /// This stays above the original protocol: it waits for the engine's own
    /// welcome/possession records, then publishes the same SDL input events as
    /// touch, keyboard, and mouse. It is Simulator diagnostic evidence only.
    func runNetworkSessionSmokeTest() {
        let stdoutURL = applicationSupportRoot().appendingPathComponent("UT99-engine.stdout")
        let baseline = (try? stdoutURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        resetNetworkSessionSmokeLog()
        appendNetworkSessionSmokeLog("scheduled baselineOffset=\(baseline)")
        waitForNetworkSessionReady(stdoutURL: stdoutURL, baselineOffset: baseline, attempt: 0)
    }

    private func waitForNetworkSessionReady(stdoutURL: URL, baselineOffset: Int, attempt: Int) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .seconds(2)) { [weak self] in
            guard let self else { return }
            let data = (try? Data(contentsOf: stdoutURL)) ?? Data()
            let offset = min(max(0, baselineOffset), data.count)
            let text = String(decoding: data.dropFirst(offset), as: UTF8.self)
            if let welcome = text.range(of: "Welcomed by server"),
               text[welcome.upperBound...].contains("Possessed PlayerPawn") {
                let level = text[welcome.lowerBound...]
                    .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
                    .first.map(String.init) ?? "Welcomed by server"
                self.appendNetworkSessionSmokeLog("ready \(level)")
                self.runMeaningfulNetworkSessionSequence()
                return
            }
            guard attempt < 59 else {
                self.appendNetworkSessionSmokeLog("timeout waiting for remote welcome and possession")
                return
            }
            if attempt > 0, attempt % 10 == 0 {
                self.appendNetworkSessionSmokeLog("waiting attempt=\(attempt)")
            }
            self.waitForNetworkSessionReady(
                stdoutURL: stdoutURL,
                baselineOffset: baselineOffset,
                attempt: attempt + 1
            )
        }
    }

    private func runMeaningfulNetworkSessionSequence() {
        let schedule: (Int, @escaping () -> Void) -> Void = { milliseconds, work in
            DispatchQueue.global(qos: .userInitiated).asyncAfter(
                deadline: .now() + .milliseconds(milliseconds),
                execute: work
            )
        }
        let action: (GoldenPadTouchOverlay.Action, Bool) -> Void = { [weak self] input, pressed in
            self?.publishTouchAction(input, pressed: pressed)
        }

        appendNetworkSessionSmokeLog("phase=spawn fire=true")
        action(.primaryFire, true)
        action(.primaryFire, false)

        schedule(700) { [weak self] in
            self?.appendNetworkSessionSmokeLog("phase=combat movement=forward-right look=active fire=true")
            self?.publishTouchMove(CGPoint(x: 0.72, y: 0.92), active: true)
            self?.publishTouchLook(CGPoint(x: 0.28, y: -0.08), active: true)
            action(.primaryFire, true)
            action(.primaryFire, false)
        }
        schedule(2_500) { [weak self] in
            self?.appendNetworkSessionSmokeLog("phase=combat look=second-step fire=true")
            self?.publishTouchLook(CGPoint(x: -0.22, y: 0.06), active: true)
            action(.primaryFire, true)
            action(.primaryFire, false)
        }
        schedule(4_000) { [weak self] in
            self?.publishTouchMove(.zero, active: false)
            self?.publishTouchLook(.zero, active: false)
            self?.appendNetworkSessionSmokeLog("phase=combat movement=released look=released")
        }
        schedule(5_000) { [weak self] in
            self?.submitConsoleCommand("say ios469 session check")
            self?.appendNetworkSessionSmokeLog("phase=chat command=submitted")
        }
        schedule(10_000) { [weak self] in
            action(.scoreboard, true)
            self?.appendNetworkSessionSmokeLog("phase=scoreboard visible=true")
        }
        schedule(11_500) { [weak self] in
            action(.scoreboard, false)
            self?.appendNetworkSessionSmokeLog("phase=scoreboard visible=false")
        }
        schedule(13_000) { [weak self] in
            self?.submitConsoleCommand("suicide")
            self?.appendNetworkSessionSmokeLog("phase=death command=suicide-submitted")
        }
        schedule(22_000) { [weak self] in
            action(.primaryFire, true)
            action(.primaryFire, false)
            self?.appendNetworkSessionSmokeLog("phase=respawn attempt=1 fire=true")
        }
        schedule(28_000) { [weak self] in
            action(.primaryFire, true)
            action(.primaryFire, false)
            self?.appendNetworkSessionSmokeLog("phase=respawn attempt=2 fire=true")
        }
        schedule(30_000) { [weak self] in
            self?.publishTouchMove(CGPoint(x: -0.58, y: 0.88), active: true)
            self?.publishTouchLook(CGPoint(x: 0.18, y: 0.04), active: true)
            action(.primaryFire, true)
            action(.primaryFire, false)
            self?.appendNetworkSessionSmokeLog("phase=post-respawn movement=forward-left fire=true")
        }
        schedule(33_000) { [weak self] in
            self?.publishTouchMove(.zero, active: false)
            self?.publishTouchLook(.zero, active: false)
            self?.appendNetworkSessionSmokeLog("phase=post-respawn movement=released look=released")
        }
        schedule(35_000) { [weak self] in
            self?.submitConsoleCommand("stat net")
            self?.appendNetworkSessionSmokeLog("phase=network-stats command=submitted")
        }
        schedule(40_000) { [weak self] in
            self?.appendNetworkSessionSmokeLog("phase=session-input-sequence complete=true")
        }
        schedule(55_000) { [weak self] in
            self?.runStockMenuDisconnect()
        }
    }

    /// Exercise the same stock UMenu route a player uses instead of relying on
    /// a typed console command: Escape, Multiplayer, Disconnect from Server.
    /// The menu's fifth selectable item is Disconnect (separator rows are
    /// skipped by UWindow's keyboard navigation).
    private func runStockMenuDisconnect() {
        let stdoutURL = applicationSupportRoot().appendingPathComponent("UT99-engine.stdout")
        let baseline = (try? stdoutURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let keyPress: (Int32) -> Void = { [weak self] key in
            self?.pushKey(key: key, pressed: true)
            self?.pushKey(key: key, pressed: false)
        }
        let schedule: (Int, @escaping () -> Void) -> Void = { milliseconds, work in
            DispatchQueue.global(qos: .userInitiated).asyncAfter(
                deadline: .now() + .milliseconds(milliseconds),
                execute: work
            )
        }

        appendNetworkSessionSmokeLog("phase=disconnect route=stock-menu open=true")
        keyPress(27) // Escape opens the original Unreal menu.
        schedule(350) { [weak self] in
            self?.appendNetworkSessionSmokeLog("phase=disconnect route=stock-menu multiplayer=true")
            keyPress((1 << 30) | 79) // Right arrow selects Multiplayer.
        }
        for index in 0..<5 {
            schedule(600 + index * 180) {
                keyPress((1 << 30) | 81) // Down arrow; fifth item is Disconnect.
            }
        }
        schedule(1_650) { [weak self] in
            guard let self else { return }
            keyPress(13) // Return executes Disconnect from Server.
            self.appendNetworkSessionSmokeLog("phase=disconnect route=stock-menu submitted=true")
            self.verifyNetworkDisconnect(
                stdoutURL: stdoutURL,
                baselineOffset: baseline,
                attempt: 0
            )
        }
    }

    private func verifyNetworkDisconnect(stdoutURL: URL, baselineOffset: Int, attempt: Int) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .seconds(1)) { [weak self] in
            guard let self else { return }
            let data = (try? Data(contentsOf: stdoutURL)) ?? Data()
            let offset = min(max(0, baselineOffset), data.count)
            let text = String(decoding: data.dropFirst(offset), as: UTF8.self)
            let normalized = text.lowercased()
            if normalized.contains("browse: index.unr?failed"),
               normalized.contains("failed; returning to entry"),
               normalized.contains("possessed playerpawn"),
               normalized.contains(" entry.") {
                self.appendNetworkSessionSmokeLog(
                    "phase=disconnect verified=true route=stock-menu destination=Entry"
                )
                self.appendNetworkSessionSmokeLog("complete")
                return
            }
            guard attempt < 14 else {
                self.appendNetworkSessionSmokeLog("phase=disconnect verified=false timeout=true")
                return
            }
            self.verifyNetworkDisconnect(
                stdoutURL: stdoutURL,
                baselineOffset: baselineOffset,
                attempt: attempt + 1
            )
        }
    }

    private func submitConsoleCommand(_ command: String) {
        pushKey(key: 9, pressed: true) // Tab=Type in the staged stock User.ini.
        pushKey(key: 9, pressed: false)
        for byte in command.utf8 where byte >= 0x20 && byte <= 0x7e {
            pushKey(key: Int32(byte), pressed: true)
            pushKey(key: Int32(byte), pressed: false)
        }
        pushKey(key: 13, pressed: true)
        pushKey(key: 13, pressed: false)
    }

    /// Diagnostic-only stock-browser probe for Simulator. This deliberately
    /// enters the original UWindow menu and clicks the original "UT Servers"
    /// tab through SDL_PushEvent; it does not stand in for physical-device
    /// finger validation.
    func runServerBrowserPointerSmokeTest() {
        runServerBrowserPointerSmokeTest(joinFirstServer: false)
    }

    /// Extends the bounded original-browser probe by double-clicking the
    /// first populated server row. This is intentionally opt-in because the
    /// selected public endpoint and its current map can change between runs.
    func runServerBrowserJoinSmokeTest() {
        runServerBrowserPointerSmokeTest(joinFirstServer: true)
    }

    private func runServerBrowserPointerSmokeTest(joinFirstServer: Bool) {
        resetServerBrowserSmokeLog()
        let keyEdge: (Int32, Bool) -> Void = { [weak self] key, pressed in
            self?.pushKey(key: key, pressed: pressed)
        }
        let keyPress: (Int32) -> Void = { key in
            keyEdge(key, true)
            keyEdge(key, false)
        }
        let schedule: (Int, @escaping () -> Void) -> Void = { milliseconds, work in
            DispatchQueue.global(qos: .userInitiated).asyncAfter(
                deadline: .now() + .milliseconds(milliseconds),
                execute: work
            )
        }

        appendServerBrowserSmokeLog("scheduled stock UBrowser navigation joinFirstServer=\(joinFirstServer)")
        schedule(6_000) { [weak self] in
            self?.appendServerBrowserSmokeLog("open menu")
            keyPress(27) // Escape
        }
        schedule(6_350) { [weak self] in
            self?.appendServerBrowserSmokeLog("select Multiplayer")
            keyPress((1 << 30) | 79) // Right arrow
        }
        schedule(6_550) { [weak self] in
            self?.appendServerBrowserSmokeLog("select Find Internet Games")
            keyPress((1 << 30) | 81) // Down arrow
        }
        schedule(6_750) { [weak self] in
            self?.appendServerBrowserSmokeLog("open stock server browser")
            keyPress(13) // Return
        }
        schedule(9_500) { [weak self] in
            guard let self else { return }
            // v469e UBrowser is centered at its native 472x768-era extent.
            // This point is the localized UT Servers tab in 1180x820 logical
            // landscape coordinates; Metal's backing scale is independent.
            let location = CGPoint(x: 480, y: 23)
            self.appendServerBrowserSmokeLog("move to UT Servers x=480 y=23")
            self.publishGameSurfacePointer(location: location, pressed: nil)
        }
        schedule(10_000) { [weak self] in
            guard let self else { return }
            let location = CGPoint(x: 480, y: 23)
            self.appendServerBrowserSmokeLog("press UT Servers x=480 y=23")
            self.publishGameSurfacePointer(location: location, pressed: true)
        }
        schedule(10_120) { [weak self] in
            let location = CGPoint(x: 480, y: 23)
            self?.appendServerBrowserSmokeLog("release UT Servers x=480 y=23")
            self?.publishGameSurfacePointer(location: location, pressed: false)
        }
        schedule(15_000) { [weak self] in
            guard !joinFirstServer else { return }
            self?.appendServerBrowserSmokeLog("complete browser-only")
        }
        if joinFirstServer {
            let serverRow = CGPoint(x: 600, y: 60)
            schedule(30_000) { [weak self] in
                self?.appendServerBrowserSmokeLog("move to first server row x=600 y=60")
                self?.publishGameSurfacePointer(location: serverRow, pressed: nil)
            }
            for (offset, pressed) in [(30_200, true), (30_290, false), (30_410, true), (30_500, false)] {
                schedule(offset) { [weak self] in
                    self?.appendServerBrowserSmokeLog("first server row double-click pressed=\(pressed)")
                    self?.publishGameSurfacePointer(location: serverRow, pressed: pressed)
                }
            }
            schedule(31_000) { [weak self] in
                self?.appendServerBrowserSmokeLog("complete join-attempt")
            }
        }
    }

    private func pushKey(key: Int32, pressed: Bool) {
        var event = [UInt8](repeating: 0, count: 56)
        write32(pressed ? 0x300 : 0x301, at: 0, into: &event)
        event[12] = pressed ? 1 : 0
        write32(UInt32(bitPattern: key), at: 20, into: &event) // SDL_Keysym.sym
        push(event)
    }

    private func pushMouseButton(
        button: UInt8,
        pressed: Bool,
        windowID: UInt32 = 0,
        x: Int32 = 0,
        y: Int32 = 0
    ) {
        var event = [UInt8](repeating: 0, count: 56)
        write32(pressed ? 0x401 : 0x402, at: 0, into: &event)
        write32(windowID, at: 8, into: &event)
        event[16] = button
        event[17] = pressed ? 1 : 0
        event[18] = 1
        write32(UInt32(bitPattern: x), at: 20, into: &event)
        write32(UInt32(bitPattern: y), at: 24, into: &event)
        push(event)
    }

    private func pushMouseMotion(
        windowID: UInt32 = 0,
        x: Int32 = 0,
        y: Int32 = 0,
        xrel: Int32,
        yrel: Int32
    ) {
        var event = [UInt8](repeating: 0, count: 56)
        write32(0x400, at: 0, into: &event)
        write32(windowID, at: 8, into: &event)
        write32(UInt32(bitPattern: x), at: 20, into: &event)
        write32(UInt32(bitPattern: y), at: 24, into: &event)
        write32(UInt32(bitPattern: xrel), at: 28, into: &event)
        write32(UInt32(bitPattern: yrel), at: 32, into: &event)
        push(event)
    }

    private func pushMouseWheel(y: Int32) {
        var event = [UInt8](repeating: 0, count: 56)
        write32(0x403, at: 0, into: &event) // SDL_MOUSEWHEEL
        write32(UInt32(bitPattern: y), at: 20, into: &event)
        write32(0, at: 24, into: &event) // SDL_MOUSEWHEEL_NORMAL
        push(event)
    }

    private func push(_ event: [UInt8]) {
        guard let handle, let symbol = dlsym(handle, "SDL_PushEvent") else { return }
        typealias PushEvent = @convention(c) (UnsafeMutableRawPointer?) -> Int32
        let pushEvent = unsafeBitCast(symbol, to: PushEvent.self)
        var bytes = event
        bytes.withUnsafeMutableBytes { buffer in
            _ = pushEvent(buffer.baseAddress)
        }
    }

    private func write32(_ value: UInt32, at offset: Int, into buffer: inout [UInt8]) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { bytes in
            buffer.replaceSubrange(offset..<(offset + 4), with: bytes)
        }
    }

    private func appendSmokeLog(_ line: String) {
        let supportRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Unreal Tournament", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportRoot, withIntermediateDirectories: true)
        let url = supportRoot.appendingPathComponent("UT99-touch-smoke.log")
        let data = Data((line + "\n").utf8)
        if FileManager.default.fileExists(atPath: url.path), let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func resetServerBrowserSmokeLog() {
        let url = serverBrowserSmokeLogURL()
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? Data().write(to: url, options: .atomic)
    }

    private func applicationSupportRoot() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Unreal Tournament", isDirectory: true)
    }

    private func networkSessionSmokeLogURL() -> URL {
        applicationSupportRoot().appendingPathComponent("UT99-network-session-smoke.log")
    }

    private func resetNetworkSessionSmokeLog() {
        let url = networkSessionSmokeLogURL()
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? Data().write(to: url, options: .atomic)
    }

    private func appendNetworkSessionSmokeLog(_ line: String) {
        let url = networkSessionSmokeLogURL()
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let data = Data((timestamp + " " + line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
        } else {
            try? data.write(to: url, options: .atomic)
        }
        NSLog("UT99 network-session smoke %@", line)
    }

    private func appendServerBrowserSmokeLog(_ line: String) {
        let url = serverBrowserSmokeLogURL()
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
        } else {
            try? data.write(to: url, options: .atomic)
        }
        NSLog("UT99 server-browser smoke %@", line)
    }

    private func serverBrowserSmokeLogURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Unreal Tournament", isDirectory: true)
            .appendingPathComponent("UT99-server-browser-smoke.log")
    }
}
