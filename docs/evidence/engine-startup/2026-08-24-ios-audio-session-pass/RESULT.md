# iOS simulator audio-session follow-up

## Result

The source-level audio-session experiment was reverted. A clean launch with the playback-only `AVAudioSession` variant started the app, but the iPad simulator session disappeared before the timed log capture (`Bad or unknown session`), so this run is not counted as an audio pass.

The engine log written inside the app container did confirm OpenAL initialization on the active `Jump Desktop Audio` route, but did not reach music playback or provide a comparable buffer-failure count. The previous valid baseline remains the 16-effect-channel profile: music played and 280 `alGenBuffers ... Out of Memory` warnings were recorded. The 1- and 4-channel experiments were worse in their longer runs and are not selected.

## Scope

- Build: `make ios-engine-sim-package` — passed.
- Runtime: one iPad Air 11-inch (M4) simulator attempted; no other simulator was booted.
- Launch: `-UT99AutoStart -UT99AutoMatch -UT99AudioEnabled`.
- Physical audio: not tested; no iPad/iPhone is attached.

## Follow-up

Keep the existing `.playAndRecord`/`.gameChat` host session and 16-channel INI profile until a stable simulator run or physical-device audio route supplies evidence. The remaining 280 warnings are an OpenAL sound-buffer allocation limitation to investigate separately from the host session category.
