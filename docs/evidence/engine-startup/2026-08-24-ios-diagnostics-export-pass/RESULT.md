# iOS diagnostic export verification — 2026-08-24

**Gate:** G2 support requirement / FR-050 and FR-051 preparation.

**Classification:** PASS for deterministic archive tests, one-Simulator app-generated archive inspection, and all three package builds; PARTIAL for G2 because no physical iPhone/iPad or Files share-sheet round trip was available.

## What was proven

- `UT99DiagnosticsArchive` emits a valid deterministic stored ZIP and rejects empty, unsafe, traversal, absolute, and duplicate entry names before writing.
- CRC arithmetic and the central-directory external-attributes field are correct; the new tests exposed and fixed defects in the previous private writer.
- Home-directory paths and common password/token/authorization/developer-team fields are redacted. The bundle warns that server addresses should be reviewed before sharing.
- `-UT99DiagnosticsExportSmokeTest` ran in the packaged iPad Air 11-inch Simulator app and wrote `UT99-diagnostics-smoke.zip` into Application Support through the same assembly path used by the host menu.
- The pulled 178,362-byte archive contains `diagnostics.txt`, `logs/UT99-engine.stdout`, and `recovery/UT99-last-failure.json`; `unzip -t` reports all entries OK and a whole-archive scan finds no account home prefix or unredacted common secret assignment.
- `diagnostics.txt` reports host/runtime state, Simulator Metal device, memory/audio/network/thermal state, touch profile, and embedded engine SHA-256 `0206263e79ca78a3d1231fa2ea41fcc147a7c7e01ffa46d2d15bb09b2604f1e6`.
- `make test`, simulator package, stub-FMOD iPhoneOS package, and real-FMOD iPhoneOS package all pass sequentially.
- Runtime cleanup reports zero booted simulators.

## What remains unproven

- Tapping Export diagnostics ZIP and saving/sharing it through `UIActivityViewController` on physical hardware.
- Files-provider destination behavior and opening the saved archive outside the app sandbox.
- Physical crash reports, watchdog/OOM classification, and diagnostic export after those device failures.
- G2 itself; `devicectl` reported no attached devices.

## Evidence

- `UT99-diagnostics-smoke.zip` — exact app-generated archive; SHA-256 `ebeb62004fc4f2d3ed18061a634718b630c2569e9a8dddf75e35f407a59f1d18`.
- `unzip-test.txt`, `archive-entries.txt`, `diagnostics.txt`, `UT99-diagnostics-smoke.log`, `redaction-scan.txt` — independent archive inspection.
- `simulator.log`, `launch.txt`, `simulator-diagnostics-smoke.png` — one-runtime app execution and visual status.
- `make-test.log` — deterministic suite.
- `simulator-package.log`, `device-stub-package.log`, `device-real-fmod-package.log` — sequential package builds and verification.
- `device-list.txt`, `doctor.log`, `hashes.txt`, `environment.json`, `commands.txt` — environment and reproducibility metadata.

## Next decision

Keep G2 open. When a physical iPad is attached, run the host/import/render/input/audio checks and complete an actual diagnostic share-sheet save/reopen round trip. Until then, continue only bounded simulator or packaging work that closes a named PRD gap.
