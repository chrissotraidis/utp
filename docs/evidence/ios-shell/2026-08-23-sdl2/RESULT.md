# SDL2 iOS replacement build — 2026-08-23

**Classification: PASS for dependency build feasibility.**

- Source: official SDL2 `release-2.32.10`, commit `5d249570393f7a37e037abf22cd6012a4cc56a71`.
- `Static Library-iOS` built for the iOS Simulator.
- `xcFramework-iOS` built successfully for device and simulator slices.
- Generated products were moved out of the read-only reference checkout into ignored `build/sdl2-ios-products/`.
- ABI comparison found 87 observed v469e SDL2 imports and zero missing exports in the arm64 iOS static library; see `abi.json`.

This proves an iOS SDL2 replacement can be built; it does not prove ABI compatibility with the v469e engine or renderer.
