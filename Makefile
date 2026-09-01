.PHONY: doctor public-check bootstrap mac-baseline ios-device verify-device device-check device-build device-install device-run package-local ios15-experimental-package diagnostics clean-runtime audit-469e ios-shell data-pack prepare-sdl2-source sdl2-ios sdl2-shared-ios sdl2-shared-sim-ios ios-audio-deps ios-audio-sim ios-desktop-shim ios-desktop-shim-sim ios-fmod-stub ios-fmod-stub-sim ios-fmod-real ios-fmod-real-sim ios-engine-artifact ios-engine-real-artifact ios-engine-sim-real-artifact ios-engine-sim-artifact ios-engine-package ios-engine-real-package ios-engine-sim-real-package ios-engine-sim-package compare-sdl mac-hosted mac-hosted-entry mac-hosted-harness test

UT99_IOS_MIN ?= 17.0
UT99_IOS_SDK ?= $(shell xcrun --sdk iphoneos --show-sdk-version)
doctor:
	@./tools/doctor.sh
public-check:
	@./tools/check_public_repo.sh
bootstrap:
	@./tools/bootstrap_dependencies.sh
mac-baseline:
	@./tools/prepare_mac_baseline.sh
ios-device: device-build
verify-device:
	@./tools/verify_ios_device.sh
device-check:
	@./tools/run_ios_device.sh --check
device-build:
	@./tools/run_ios_device.sh --build
device-install:
	@./tools/run_ios_device.sh --install
device-run:
	@./tools/run_ios_device.sh --run
package-local:
	@./tools/package_local_ipa.sh
ios15-experimental-package:
	@UT99_IOS_MIN=15.0 UT99_PACKAGE_MODE=public UT99_RELEASE_VERSION="$${UT99_RELEASE_VERSION:-0.1.0-issue-6-test.1}" ./tools/package_local_ipa.sh
diagnostics:
	@./tools/collect_diagnostics.sh
clean-runtime:
	@./tools/ensure_single_runtime.sh --clean
audit-469e:
	@./tools/inspect_macho.sh

ios-shell:
	@./tools/run_ios_shell_simulator.sh

data-pack:
	@test -n "$(SOURCE)" || (echo 'Usage: make data-pack SOURCE=/path/to/UT99' >&2; exit 2)
	@python3 tools/prepare_ut99_data.py --source "$(SOURCE)" --output build/UT99Data --zip

prepare-sdl2-source:
	@./tools/prepare_sdl2_source.sh

sdl2-ios: prepare-sdl2-source
	@xcodebuild -project build/sources/SDL2-UT99/Xcode/SDL/SDL.xcodeproj -scheme xcFramework-iOS -configuration Release -derivedDataPath build/sdl2-xcframework CODE_SIGNING_ALLOWED=NO IPHONEOS_DEPLOYMENT_TARGET=$(UT99_IOS_MIN) build

sdl2-shared-ios: prepare-sdl2-source
	@xcodebuild -project build/sources/SDL2-UT99/Xcode/SDL/SDL.xcodeproj -scheme 'Shared Library-iOS' -sdk iphoneos -configuration Release -derivedDataPath build/sdl2-shared-ios CODE_SIGNING_ALLOWED=NO IPHONEOS_DEPLOYMENT_TARGET=$(UT99_IOS_MIN) EXCLUDED_SOURCE_FILE_NAMES=SDL_shaders_metal.metal OTHER_CFLAGS='$$(inherited) -ffile-prefix-map=$(realpath build)=build' OTHER_CPLUSPLUSFLAGS='$$(inherited) -ffile-prefix-map=$(realpath build)=build' build

sdl2-shared-sim-ios: prepare-sdl2-source
	@xcodebuild -project build/sources/SDL2-UT99/Xcode/SDL/SDL.xcodeproj -scheme 'Shared Library-iOS' -sdk iphonesimulator -configuration Release -derivedDataPath build/sdl2-shared-sim-ios CODE_SIGNING_ALLOWED=NO IPHONEOS_DEPLOYMENT_TARGET=$(UT99_IOS_MIN) EXCLUDED_SOURCE_FILE_NAMES=SDL_shaders_metal.metal build

ios-audio-deps:
	@UT99_IOS_MIN=$(UT99_IOS_MIN) ./tools/build_ios_dependencies.sh

ios-audio-sim:
	@UT99_IOS_MIN=$(UT99_IOS_MIN) UT99_SDK=iphonesimulator UT99_DEP_SUFFIX=ios-sim ./tools/build_ios_dependencies.sh

ios-desktop-shim:
	@set -eu; mkdir -p build/ios-engine build/ios-engine/deps; SDKROOT="$$(xcrun --sdk iphoneos --show-sdk-path)"; xcrun clang -dynamiclib -arch arm64 -isysroot "$$SDKROOT" -miphoneos-version-min=$(UT99_IOS_MIN) -fobjc-arc -fblocks -fvisibility=default -install_name @rpath/UT99DesktopShim.dylib Sources/UT99Runtime/UT99DesktopShim.c -framework CoreFoundation -o build/ios-engine/UT99DesktopShim.dylib; xcrun clang -dynamiclib -arch arm64 -isysroot "$$SDKROOT" -miphoneos-version-min=$(UT99_IOS_MIN) -fobjc-arc -fblocks -fvisibility=default -install_name @rpath/UT99MetalShim.dylib Sources/UT99Runtime/UT99MetalShim.m -framework Foundation -framework Metal -framework QuartzCore -Wl,-reexport_framework,Metal -o build/ios-engine/UT99MetalShim.dylib; cp build/ios-engine/UT99MetalShim.dylib build/ios-engine/deps/UT99MetalShim.dylib; for name in UT99CocoaShim UT99ApplicationServicesShim UT99CoreServicesShim; do cp build/ios-engine/UT99DesktopShim.dylib "build/ios-engine/$$name.dylib"; install_name_tool -id "@rpath/$$name.dylib" "build/ios-engine/$$name.dylib"; codesign --force --sign - "build/ios-engine/$$name.dylib" >/dev/null; cp "build/ios-engine/$$name.dylib" "build/ios-engine/deps/$$name.dylib"; done

ios-desktop-shim-sim:
	@set -eu; mkdir -p build/ios-engine-ios-sim build/ios-engine-ios-sim/deps; SDKROOT="$$(xcrun --sdk iphonesimulator --show-sdk-path)"; xcrun clang -dynamiclib -arch arm64 -isysroot "$$SDKROOT" -mios-simulator-version-min=$(UT99_IOS_MIN) -fobjc-arc -fblocks -fvisibility=default -install_name @rpath/UT99DesktopShim.dylib Sources/UT99Runtime/UT99DesktopShim.c -framework CoreFoundation -o build/ios-engine-ios-sim/UT99DesktopShim.dylib; xcrun clang -dynamiclib -arch arm64 -isysroot "$$SDKROOT" -mios-simulator-version-min=$(UT99_IOS_MIN) -fobjc-arc -fblocks -fvisibility=default -install_name @rpath/UT99MetalShim.dylib Sources/UT99Runtime/UT99MetalShim.m -framework Foundation -framework Metal -framework QuartzCore -Wl,-reexport_framework,Metal -o build/ios-engine-ios-sim/UT99MetalShim.dylib; cp build/ios-engine-ios-sim/UT99MetalShim.dylib build/ios-engine-ios-sim/deps/UT99MetalShim.dylib; for name in UT99CocoaShim UT99ApplicationServicesShim UT99CoreServicesShim; do cp build/ios-engine-ios-sim/UT99DesktopShim.dylib "build/ios-engine-ios-sim/$$name.dylib"; install_name_tool -id "@rpath/$$name.dylib" "build/ios-engine-ios-sim/$$name.dylib"; codesign --force --sign - "build/ios-engine-ios-sim/$$name.dylib" >/dev/null; cp "build/ios-engine-ios-sim/$$name.dylib" "build/ios-engine-ios-sim/deps/$$name.dylib"; done

ios-fmod-stub:
	@mkdir -p build/ios-engine/deps; SDKROOT="$$(xcrun --sdk iphoneos --show-sdk-path)"; xcrun clang -dynamiclib -arch arm64 -isysroot "$$SDKROOT" -miphoneos-version-min=$(UT99_IOS_MIN) -fvisibility=default -install_name @rpath/libfmod.dylib Sources/UT99Runtime/UT99FMODShim.c -o build/ios-engine/deps/libfmod.dylib; codesign --force --sign - build/ios-engine/deps/libfmod.dylib >/dev/null

ios-fmod-stub-sim:
	@mkdir -p build/ios-engine-ios-sim/deps; SDKROOT="$$(xcrun --sdk iphonesimulator --show-sdk-path)"; xcrun clang -dynamiclib -arch arm64 -isysroot "$$SDKROOT" -mios-simulator-version-min=$(UT99_IOS_MIN) -fvisibility=default -install_name @rpath/libfmod.dylib Sources/UT99Runtime/UT99FMODShim.c -o build/ios-engine-ios-sim/deps/libfmod.dylib; codesign --force --sign - build/ios-engine-ios-sim/deps/libfmod.dylib >/dev/null

ios-fmod-real: ios-desktop-shim
	@set -eu; mkdir -p build/ios-engine/deps; source="build/macos-baseline/UnrealTournament.app/Contents/Frameworks/libfmod.dylib"; thin="build/ios-engine/deps/libfmod-macos-arm64.dylib"; output="build/ios-engine/deps/libfmod.dylib"; test -f "$$source"; lipo -thin arm64 "$$source" -output "$$thin"; xcrun vtool -set-build-version ios $(UT99_IOS_MIN) $(UT99_IOS_SDK) -replace -output "$$output" "$$thin"; install_name_tool -id @rpath/libfmod.dylib "$$output"; install_name_tool -add_rpath @loader_path "$$output"; install_name_tool -change /System/Library/Frameworks/Carbon.framework/Versions/A/Carbon @rpath/UT99DesktopShim.dylib "$$output"; install_name_tool -change /System/Library/Frameworks/AudioUnit.framework/Versions/A/AudioUnit /System/Library/Frameworks/AudioToolbox.framework/AudioToolbox "$$output"; install_name_tool -change /System/Library/Frameworks/CoreAudio.framework/Versions/A/CoreAudio /System/Library/Frameworks/CoreAudio.framework/CoreAudio "$$output"; install_name_tool -change /System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation /System/Library/Frameworks/CoreFoundation.framework/CoreFoundation "$$output"; codesign --force --sign - "$$output" >/dev/null; rm -f "$$thin"; file "$$output"; otool -L "$$output"

ios-fmod-real-sim: ios-desktop-shim-sim
	@set -eu; mkdir -p build/ios-engine-ios-sim/deps; source="build/macos-baseline/UnrealTournament.app/Contents/Frameworks/libfmod.dylib"; thin="build/ios-engine-ios-sim/deps/libfmod-macos-arm64.dylib"; output="build/ios-engine-ios-sim/deps/libfmod.dylib"; test -f "$$source"; lipo -thin arm64 "$$source" -output "$$thin"; xcrun vtool -set-build-version iossim $(UT99_IOS_MIN) $(UT99_IOS_SDK) -replace -output "$$output" "$$thin"; install_name_tool -id @rpath/libfmod.dylib "$$output"; install_name_tool -add_rpath @loader_path "$$output"; install_name_tool -change /System/Library/Frameworks/Carbon.framework/Versions/A/Carbon @rpath/UT99DesktopShim.dylib "$$output"; install_name_tool -change /System/Library/Frameworks/AudioUnit.framework/Versions/A/AudioUnit /System/Library/Frameworks/AudioToolbox.framework/AudioToolbox "$$output"; install_name_tool -change /System/Library/Frameworks/CoreAudio.framework/Versions/A/CoreAudio /System/Library/Frameworks/CoreAudio.framework/CoreAudio "$$output"; install_name_tool -change /System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation /System/Library/Frameworks/CoreFoundation.framework/CoreFoundation "$$output"; codesign --force --sign - "$$output" >/dev/null; rm -f "$$thin"; file "$$output"; otool -L "$$output"

ios-engine-artifact: sdl2-shared-ios ios-desktop-shim ios-fmod-stub ios-audio-deps
	@test -f build/macos-baseline/UnrealTournament.app/Contents/MacOS/UnrealTournament || (echo 'Run the macOS baseline setup before this target' >&2; exit 2)
	@python3 tools/prepare_ios_engine_artifact.py --source build/macos-baseline/UnrealTournament.app/Contents/MacOS/UnrealTournament --output build/ios-engine/UnrealTournament.dylib --report build/ios-engine/report.json --ios-min $(UT99_IOS_MIN) --ios-sdk $(UT99_IOS_SDK) --shim build/ios-engine/UT99DesktopShim.dylib --available build/ios-engine/UT99DesktopShim.dylib --available build/ios-engine/UT99MetalShim.dylib --available build/ios-engine/UT99CocoaShim.dylib --available build/ios-engine/UT99ApplicationServicesShim.dylib --available build/ios-engine/UT99CoreServicesShim.dylib --available build/sdl2-shared-ios/Build/Products/Release-iphoneos/libSDL2.dylib --available build/ios-engine/deps/libopenal.dylib --available build/ios-engine/deps/libxmp.dylib --available build/ios-engine/deps/libmpg123.dylib --available build/ios-engine/deps/libsndfile.dylib --available build/ios-engine/deps/libfmod.dylib --fmod-stub
	@UT99_IOS_MIN=$(UT99_IOS_MIN) ./tools/build_ios_frucore_metallib.sh build/macos-baseline/UnrealTournament.app/Contents/Resources/default.metallib build/ios-engine/default.metallib ios

ios-engine-real-artifact: sdl2-shared-ios ios-desktop-shim ios-fmod-real ios-audio-deps
	@test -f build/macos-baseline/UnrealTournament.app/Contents/MacOS/UnrealTournament || (echo 'Run the macOS baseline setup before this target' >&2; exit 2)
	@python3 tools/prepare_ios_engine_artifact.py --source build/macos-baseline/UnrealTournament.app/Contents/MacOS/UnrealTournament --output build/ios-engine/UnrealTournament.dylib --report build/ios-engine/real-report.json --ios-min $(UT99_IOS_MIN) --ios-sdk $(UT99_IOS_SDK) --shim build/ios-engine/UT99DesktopShim.dylib --available build/ios-engine/UT99DesktopShim.dylib --available build/ios-engine/UT99MetalShim.dylib --available build/ios-engine/UT99CocoaShim.dylib --available build/ios-engine/UT99ApplicationServicesShim.dylib --available build/ios-engine/UT99CoreServicesShim.dylib --available build/sdl2-shared-ios/Build/Products/Release-iphoneos/libSDL2.dylib --available build/ios-engine/deps/libopenal.dylib --available build/ios-engine/deps/libxmp.dylib --available build/ios-engine/deps/libmpg123.dylib --available build/ios-engine/deps/libsndfile.dylib --available build/ios-engine/deps/libfmod.dylib
	@UT99_IOS_MIN=$(UT99_IOS_MIN) ./tools/build_ios_frucore_metallib.sh build/macos-baseline/UnrealTournament.app/Contents/Resources/default.metallib build/ios-engine/default.metallib ios

ios-engine-sim-real-artifact: sdl2-shared-sim-ios ios-desktop-shim-sim ios-fmod-real-sim ios-audio-sim
	@test -f build/macos-baseline/UnrealTournament.app/Contents/MacOS/UnrealTournament || (echo 'Run the macOS baseline setup before this target' >&2; exit 2)
	@mkdir -p build/ios-engine-ios-sim; python3 tools/prepare_ios_engine_artifact.py --source build/macos-baseline/UnrealTournament.app/Contents/MacOS/UnrealTournament --output build/ios-engine-ios-sim/UnrealTournament.dylib --report build/ios-engine-ios-sim/report.json --ios-min $(UT99_IOS_MIN) --ios-sdk $(UT99_IOS_SDK) --platform iossim --shim build/ios-engine-ios-sim/UT99DesktopShim.dylib --available build/ios-engine-ios-sim/UT99DesktopShim.dylib --available build/ios-engine-ios-sim/UT99MetalShim.dylib --available build/ios-engine-ios-sim/UT99CocoaShim.dylib --available build/ios-engine-ios-sim/UT99ApplicationServicesShim.dylib --available build/ios-engine-ios-sim/UT99CoreServicesShim.dylib --available build/sdl2-shared-sim-ios/Build/Products/Release-iphonesimulator/libSDL2.dylib --available build/ios-engine-ios-sim/deps/libopenal.dylib --available build/ios-engine-ios-sim/deps/libxmp.dylib --available build/ios-engine-ios-sim/deps/libmpg123.dylib --available build/ios-engine-ios-sim/deps/libsndfile.dylib --available build/ios-engine-ios-sim/deps/libfmod.dylib
	@UT99_IOS_MIN=$(UT99_IOS_MIN) ./tools/build_ios_frucore_metallib.sh build/macos-baseline/UnrealTournament.app/Contents/Resources/default.metallib build/ios-engine-ios-sim/default.metallib iossim

ios-engine-sim-artifact: sdl2-shared-sim-ios ios-desktop-shim-sim ios-fmod-stub-sim ios-audio-sim
	@test -f build/macos-baseline/UnrealTournament.app/Contents/MacOS/UnrealTournament || (echo 'Run the macOS baseline setup before this target' >&2; exit 2)
	@python3 tools/prepare_ios_engine_artifact.py --source build/macos-baseline/UnrealTournament.app/Contents/MacOS/UnrealTournament --output build/ios-engine-ios-sim/UnrealTournament.dylib --report build/ios-engine-ios-sim/stub-report.json --ios-min $(UT99_IOS_MIN) --ios-sdk $(UT99_IOS_SDK) --platform iossim --shim build/ios-engine-ios-sim/UT99DesktopShim.dylib --available build/ios-engine-ios-sim/UT99DesktopShim.dylib --available build/ios-engine-ios-sim/UT99MetalShim.dylib --available build/ios-engine-ios-sim/UT99CocoaShim.dylib --available build/ios-engine-ios-sim/UT99ApplicationServicesShim.dylib --available build/ios-engine-ios-sim/UT99CoreServicesShim.dylib --available build/sdl2-shared-sim-ios/Build/Products/Release-iphonesimulator/libSDL2.dylib --available build/ios-engine-ios-sim/deps/libopenal.dylib --available build/ios-engine-ios-sim/deps/libxmp.dylib --available build/ios-engine-ios-sim/deps/libmpg123.dylib --available build/ios-engine-ios-sim/deps/libsndfile.dylib --available build/ios-engine-ios-sim/deps/libfmod.dylib --fmod-stub
	@UT99_IOS_MIN=$(UT99_IOS_MIN) ./tools/build_ios_frucore_metallib.sh build/macos-baseline/UnrealTournament.app/Contents/Resources/default.metallib build/ios-engine-ios-sim/default.metallib iossim

ios-engine-package: ios-engine-artifact
	@UT99_ENGINE_EMBED=1 xcodebuild -project UT99Apple.xcodeproj -scheme UT99Apple -sdk iphoneos -configuration Debug -derivedDataPath build/ios-engine-app CODE_SIGNING_ALLOWED=NO IPHONEOS_DEPLOYMENT_TARGET=$(UT99_IOS_MIN) build
	@if [ -d build/UT99Data ]; then mkdir -p build/ios-engine-app/Build/Products/Debug-iphoneos/UT99Apple.app/UT99Data; cp -R build/UT99Data/. build/ios-engine-app/Build/Products/Debug-iphoneos/UT99Apple.app/UT99Data/; ./tools/prepare_embedded_runtime_data.sh build/ios-engine-app/Build/Products/Debug-iphoneos/UT99Apple.app; fi
	@codesign --force --deep --sign - build/ios-engine-app/Build/Products/Debug-iphoneos/UT99Apple.app >/dev/null
	@./tools/verify_ios_package.sh build/ios-engine-app/Build/Products/Debug-iphoneos/UT99Apple.app
	@echo "Ad-hoc device package: build/ios-engine-app/Build/Products/Debug-iphoneos/UT99Apple.app"

ios-engine-real-package: ios-engine-real-artifact
	@UT99_ENGINE_EMBED=1 xcodebuild -project UT99Apple.xcodeproj -scheme UT99Apple -sdk iphoneos -configuration Debug -derivedDataPath build/ios-engine-real-app CODE_SIGNING_ALLOWED=NO IPHONEOS_DEPLOYMENT_TARGET=$(UT99_IOS_MIN) build
	@if [ -d build/UT99Data ]; then mkdir -p build/ios-engine-real-app/Build/Products/Debug-iphoneos/UT99Apple.app/UT99Data; cp -R build/UT99Data/. build/ios-engine-real-app/Build/Products/Debug-iphoneos/UT99Apple.app/UT99Data/; ./tools/prepare_embedded_runtime_data.sh build/ios-engine-real-app/Build/Products/Debug-iphoneos/UT99Apple.app; fi
	@codesign --force --deep --sign - build/ios-engine-real-app/Build/Products/Debug-iphoneos/UT99Apple.app >/dev/null
	@./tools/verify_ios_package.sh build/ios-engine-real-app/Build/Products/Debug-iphoneos/UT99Apple.app
	@echo "Ad-hoc real-FMOD device package: build/ios-engine-real-app/Build/Products/Debug-iphoneos/UT99Apple.app"

ios-engine-sim-real-package: ios-engine-sim-real-artifact
	@UT99_ENGINE_EMBED=1 xcodebuild -project UT99Apple.xcodeproj -scheme UT99Apple -sdk iphonesimulator -configuration Debug -derivedDataPath build/ios-engine-sim-real-app CODE_SIGNING_ALLOWED=NO IPHONEOS_DEPLOYMENT_TARGET=$(UT99_IOS_MIN) build
	@if [ -d build/UT99Data ]; then mkdir -p build/ios-engine-sim-real-app/Build/Products/Debug-iphonesimulator/UT99Apple.app/UT99Data; cp -R build/UT99Data/. build/ios-engine-sim-real-app/Build/Products/Debug-iphonesimulator/UT99Apple.app/UT99Data/; ./tools/prepare_embedded_runtime_data.sh build/ios-engine-sim-real-app/Build/Products/Debug-iphonesimulator/UT99Apple.app; fi
	@codesign --force --deep --sign - build/ios-engine-sim-real-app/Build/Products/Debug-iphonesimulator/UT99Apple.app >/dev/null
	@./tools/verify_ios_package.sh build/ios-engine-sim-real-app/Build/Products/Debug-iphonesimulator/UT99Apple.app
	@echo "Ad-hoc real-FMOD simulator package: build/ios-engine-sim-real-app/Build/Products/Debug-iphonesimulator/UT99Apple.app"

ios-engine-sim-package: ios-engine-sim-artifact
	@UT99_ENGINE_EMBED=1 xcodebuild -project UT99Apple.xcodeproj -scheme UT99Apple -sdk iphonesimulator -configuration Debug -derivedDataPath build/ios-engine-sim-app CODE_SIGNING_ALLOWED=NO IPHONEOS_DEPLOYMENT_TARGET=$(UT99_IOS_MIN) build
	@if [ -d build/UT99Data ]; then mkdir -p build/ios-engine-sim-app/Build/Products/Debug-iphonesimulator/UT99Apple.app/UT99Data; cp -R build/UT99Data/. build/ios-engine-sim-app/Build/Products/Debug-iphonesimulator/UT99Apple.app/UT99Data/; ./tools/prepare_embedded_runtime_data.sh build/ios-engine-sim-app/Build/Products/Debug-iphonesimulator/UT99Apple.app; fi
	@codesign --force --deep --sign - build/ios-engine-sim-app/Build/Products/Debug-iphonesimulator/UT99Apple.app >/dev/null
	@./tools/verify_ios_package.sh build/ios-engine-sim-app/Build/Products/Debug-iphonesimulator/UT99Apple.app
	@echo "Ad-hoc simulator diagnostic package: build/ios-engine-sim-app/Build/Products/Debug-iphonesimulator/UT99Apple.app"

compare-sdl:
	@python3 tools/compare_sdl_abi.py

mac-hosted:
	@./tools/run_mac_hosted_harness.sh

mac-hosted-entry: mac-hosted
	@./tools/run_mac_hosted_entry.sh
mac-hosted-harness: mac-hosted-entry
test:
	@bash -n tools/*.sh
	@./Tests/test_doctor_report.sh
	@./Tests/test_device_readiness.sh
	@./Tests/test_device_gate_script.sh
	@./Tests/test_local_ipa_packaging.sh
	@./Tests/test_ios_compatibility_build.sh
	@./Tests/test_runtime_guard.sh
	@./Tests/test_complete_macho_audit.sh
	@./Tests/test_openal_ios_patch.sh
	@./Tests/test_metal_performance_metrics.sh
	@./Tests/test_data_import_transaction.sh
	@./Tests/test_game_data_acquisition.sh
	@./Tests/test_runtime_recovery.sh
	@./Tests/test_diagnostics_archive.sh
	@./Tests/test_host_state_and_data_menu.sh
	@./Tests/test_stable_commands.sh
	@./Tests/test_touch_configuration.sh
	@./Tests/test_touch_profiles.sh
	@./Tests/test_touch_layout_geometry.sh
