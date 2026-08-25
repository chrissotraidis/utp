# iOS OpenAL buffer-allocation pass — 2026-08-24

**Result: PASS for the simulator OpenAL allocation regression / PARTIAL G6.**

The previous audio-enabled run logged 280 `alGenBuffers ... Out of Memory` failures, beginning with the first buffer allocation. The pinned OpenAL Soft source included a pre-macOS-10.13 aligned-allocation fallback guarded only by `MAC_OS_X_VERSION_MIN_REQUIRED`. Apple's iOS headers also define that compatibility macro with a legacy macOS value, so the fallback compiled for iOS and sent low-alignment allocations to `posix_memalign`, which rejects alignments smaller than a pointer.

The dependency build now copies the pinned source into `build/sources/openal-soft-ios`, applies `third_party/patches/openal-soft-ios-aligned-allocation.patch`, and limits that fallback to `TARGET_OS_OSX`. Applying this patch does not modify the reference checkout. A packaging-path correction also ensures the device build writes to the directory embedded by Xcode.

One clean iPad Air 11-inch (M4) simulator was launched with `-UT99AutoStart -UT99AutoMatch -UT99AudioEnabled`. After a timed hold:

- zero `alGenBuffers` failures and zero `Out of Memory` audio errors were present;
- ALAudio initialized OpenAL Soft 1.25.2 and entered the original main loop;
- `StartMusic Godown` and `ALAudio: playing Godown Go Down` were logged;
- the process remained alive;
- native full-bleed rendering remained 1180×820 points / 2360×1640 pixels at 2×.

The rebuilt simulator, diagnostic-device, and real-FMOD-device OpenAL images all leave aligned `new`/`new[]` undefined and resolved from libc++. Both device app packages rebuilt and passed package verification. This does not prove audible speaker output, sound-effect fidelity, interruption/route recovery, or G6 on physical hardware.

## Evidence

- `ipad-openal-zero-buffer-errors-landscape-gui.jpeg` — authoritative true-landscape Simulator GUI capture.
- `UT99-engine.stdout` — original engine startup, OpenAL initialization, zero allocation-error run, native drawable, and music-playback records.
- `UnrealTournament.log` — copied engine log from the same run.
- `openal-symbols.txt` — hashes and aligned-allocation symbol disposition for simulator and device packages.
- `command.txt` and `environment.json` — bounded launch and environment record.

The runtime was shut down after capture; no simulator remains booted.
