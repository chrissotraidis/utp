#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

sdk="${UT99_SDK:-iphoneos}"
suffix="${UT99_DEP_SUFFIX:-ios}"
minflag="${UT99_MIN_FLAG:--miphoneos-version-min=17.0}"
sdkroot="$(xcrun --sdk "$sdk" --show-sdk-path)"
cmake_common=(
  -G Ninja
  -DCMAKE_SYSTEM_NAME=iOS
  -DCMAKE_OSX_SYSROOT="$sdk"
  -DCMAKE_OSX_ARCHITECTURES=arm64
  -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0
)

# AvailabilityMacros reports a legacy macOS compatibility value even for iOS
# targets. OpenAL Soft's old-macOS aligned-new fallback therefore compiled into
# iOS and sent ordinary low-alignment objects through posix_memalign, which
# rejects alignments smaller than sizeof(void*). Build from a generated source
# copy and apply the narrow, recorded platform guard; leave ref unchanged.
openal_source="build/sources/openal-soft-ios"
openal_build="build/deps/openal-$suffix-iosfix"
mkdir -p "$openal_source"
rsync -a --exclude '.git/' ref/OpenAL-Soft/ "$openal_source/"
patch -d "$openal_source" -p1 < third_party/patches/openal-soft-ios-aligned-allocation.patch

cmake -S "$openal_source" -B "$openal_build" "${cmake_common[@]}" \
  -DALSOFT_EXAMPLES=OFF -DALSOFT_TESTS=OFF -DALSOFT_UTILS=OFF -DALSOFT_INSTALL=OFF \
  -DALSOFT_BACKEND_PIPEWIRE=OFF -DALSOFT_BACKEND_PULSEAUDIO=OFF -DALSOFT_BACKEND_ALSA=OFF \
  -DALSOFT_BACKEND_JACK=OFF -DALSOFT_BACKEND_OSS=OFF
cmake --build "$openal_build" --parallel 4

cmake -S ref/libxmp -B "build/deps/libxmp-$suffix" "${cmake_common[@]}" \
  -DBUILD_SHARED=ON -DBUILD_STATIC=OFF -DBUILD_TESTING=OFF
cmake --build "build/deps/libxmp-$suffix" --parallel 4

# libsndfile's CMake generator selects GNU version-script flags for the generic
# iOS system name. Darwin makes it emit the Apple exported-symbols list.
cmake -S ref/libsndfile -B "build/deps/libsndfile-$suffix-darwin" -G Ninja \
  -DCMAKE_SYSTEM_NAME=Darwin -DCMAKE_OSX_SYSROOT="$sdk" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
  -DBUILD_SHARED_LIBS=ON -DBUILD_PROGRAMS=OFF -DBUILD_EXAMPLES=OFF \
  -DBUILD_TESTING=OFF -DENABLE_EXTERNAL_LIBS=OFF -DENABLE_MPEG=OFF
cmake --build "build/deps/libsndfile-$suffix-darwin" --parallel 4

mpg_src="build/deps/mpg123-$suffix"
mkdir -p "$mpg_src"
if [[ ! -f "$mpg_src/configure" ]]; then
  tar -xjf ref/mpg123-1.33.6.tar.bz2 -C "$mpg_src" --strip-components=1
fi
if [[ ! -f "$mpg_src/Makefile" ]]; then
  (
    cd "$mpg_src"
    CC="xcrun -sdk $sdk clang" \
    CFLAGS="-arch arm64 -isysroot $sdkroot $minflag" \
    LDFLAGS="-arch arm64 -isysroot $sdkroot $minflag" \
    ./configure --host=arm-apple-darwin --disable-programs --disable-network \
      --disable-modules --disable-libout123 --disable-libsyn123 \
      --enable-shared --disable-static --with-cpu=generic
  )
fi
make -C "$mpg_src" -j4

if [[ "$suffix" == "ios" ]]; then
  engine_dir="build/ios-engine"
else
  engine_dir="build/ios-engine-$suffix"
fi
out="$engine_dir/deps"
mkdir -p "$out"
cp "$openal_build"/libopenal.1.*.dylib "$out/libopenal.dylib"
cp "build/deps/libxmp-$suffix"/libxmp.4.*.dylib "$out/libxmp.dylib"
cp "build/deps/libsndfile-$suffix-darwin"/libsndfile.1.*.dylib "$out/libsndfile.dylib"
cp "$mpg_src/src/libmpg123/.libs/libmpg123.0.dylib" "$out/libmpg123.dylib"

for name in libopenal libxmp libsndfile libmpg123; do
  install_name_tool -id "@rpath/$name.dylib" "$out/$name.dylib"
  codesign --force --sign - "$out/$name.dylib" >/dev/null
done

echo "iOS dependency outputs ($sdk):"
for file in "$out"/*.dylib; do
  file "$file"
  xcrun vtool -show-build "$file" | rg 'platform|minos|sdk' || true
  otool -D "$file" | tail -1
done
