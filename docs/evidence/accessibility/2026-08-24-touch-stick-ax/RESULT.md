# Touch-stick accessibility and scene-window result

Date: 2026-08-24

## Hypothesis

The fixed Movement and Aim surfaces can expose UT-specific directional actions to assistive input without changing their accepted visual geometry or two-thumb gesture ownership. The SDL presentation retry can use supported `UIWindowScene` inventories instead of deprecated process-wide window enumeration.

## Result

PASS in the iPad Air 11-inch (M4) Simulator; physical VoiceOver remains NOT RUN.

- Movement is a named accessibility element (`ut99.touch.move`) with Move forward/backward, Strafe left/right, and Stop movement actions.
- Movement actions retain a digital direction until Stop movement, matching UT99's W/A/S/D bridge. The live tree changed from `Value: Stopped` to `Value: Move forward` and back to `Value: Stopped` when those two actions were injected.
- A normal movement pan explicitly clears any held assistive direction before taking ownership, preventing stale state during input-mode handoff.
- Aim is a named accessibility element (`ut99.touch.aim`) with Look up/down and Turn left/right actions. Each action publishes one bounded relative-look step and truthfully remains `Value: Centered` afterward.
- Existing FIRE/ALT/JUMP/DUCK/USE/PREV/NEXT/SCORE/MENU labels and actions remain present.
- Normal movement/look pan recognizers and their explicit simultaneous-recognition pair are unchanged.
- SDL window discovery now enumerates connected `UIWindowScene.windows`; the deprecated `UIApplication.shared.windows` fallback and its iOS 15 warning are gone.
- Three ignored `FileHandle.seekToEnd()` return values were made explicit, leaving no warnings from `Sources/UT99Host` in either final package log.

## Verification

- `make test`: PASS.
- `make ios-engine-sim-real-package`: PASS.
- `make ios-engine-real-package`: PASS.
- Final Simulator executable SHA-256: `eaaaf3d3ef14a3cba6249c0d92a6b81d4530040888b046082c290873b196e12e`.
- Final iPhoneOS executable SHA-256: `d7048f6a494802590571cb5ff69ca5339c5bbdb172076c0a90cb032bd5425c0a`.
- Final GUI capture SHA-256: `0cfd0ed975ae52d675c23070ab8a03680408cf60bebadc3747fe5ed0d2853de4` (`final-ipad-runtime.png`, retained as ignored local raw evidence).
- Packaged runtime PID `97606` reached `Game engine initialized` and `Entering main loop` with an 1180×820-point / 2360×1640-pixel drawable.
- Computer Use read the final live tree and found both identifiers and all nine stick actions. It then successfully invoked Move forward, Stop movement, and Turn right.
- `tools/ensure_single_runtime.sh --check`: PASS with one booted iPad Simulator and one UT99Apple process.

The Simulator accessibility bridge emitted one nonfatal Foundation `NSMapGet` diagnostic after an injected secondary action. No project source calls that API, the runtime remained alive, and the final accessibility state was correct. This is recorded as automation-environment noise, not physical-device evidence.

## Remaining boundary

This pass proves packaged Simulator accessibility exposure and injected action handling only. It does not prove physical VoiceOver focus order, speech, rotor ergonomics, multi-touch interaction while VoiceOver is enabled, reach, haptics, or touch-only match completion.
