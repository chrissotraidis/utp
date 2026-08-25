# Completion audit

Audit date: 2026-08-24

This ledger applies the completion checklist in `UT99_Agent_Goal_Loop.md` without promoting Simulator evidence to a physical-device gate. Status meanings:

- **PROVEN** — current evidence satisfies the requirement in its stated environment.
- **PARTIAL** — meaningful behavior is implemented/evidenced, but the full requirement is not closed.
- **PHYSICAL-ONLY BLOCKED** — the remaining proof requires a signed physical iPhone/iPad or attached hardware unavailable in this environment.
- **LOCAL ACTIONABLE** — work can still be completed on this Mac.

| Completion item | Status | Current evidence / exact remainder |
|---|---|---|
| PRD and goal loop are current | PROVEN | `docs/UT99_Apple_PRD.md`, `docs/UT99_Agent_Goal_Loop.md`, `docs/STATUS.md` |
| Stable developer command surface | PROVEN | `make bootstrap`, `make mac-baseline`, `make audit-469e`, `make mac-hosted-harness`, `make diagnostics`, packaging and runtime targets; `Tests/test_stable_commands.sh` |
| Pinned public bootstrap inputs | PROVEN | `make bootstrap` passes exact hashes/commits from `third_party/deps.lock.json`; downloads remain ignored under `ref/` |
| macOS v469e Metal baseline | PROVEN | `docs/evidence/macos-baseline/2026-08-23-v469e/`; `make mac-baseline` re-verifies the official DMG and ARM64 app |
| v469e hashes and complete native-image audit | PROVEN | `docs/evidence/engine-startup/2026-08-24-g1-complete-native-audit/`; eight native images and bounded dependency dispositions |
| macOS hosted executable entry | PROVEN | `docs/evidence/engine-startup/2026-08-23-mac-hosted/` |
| Native iOS host, embedded engine, Metal first frame | PHYSICAL-ONLY BLOCKED | Simulator original entry and device-target package pass; G2 requires signed install/launch and physical capture. No attached device, Development identity, or team is available. |
| No JIT / no downloaded executable code | PARTIAL | Static package/audit paths require no JIT and importer rejects executable content; final claim still needs the physical signed runtime path. |
| Original Unreal menu remains functional | PARTIAL | Simulator touch MENU sends the original Escape path; physical touch/controller confirmation remains. |
| Deck16 bot match | PARTIAL | Original `DM-Deck16][` gameplay and UT actions pass in Simulator; physical touch-only match remains. |
| CTF-Face | PARTIAL | Original `CTF-Face`/`Botpack.CTFGame` entry and FIRE transition pass in Simulator; physical touch-only play remains. |
| Audio and music | PHYSICAL-ONLY BLOCKED | OpenAL allocation/music startup passes in Simulator/device-target builds; audible output, effects fidelity, route changes, and interruptions require hardware. |
| Refined iPhone/iPad touch UI | PARTIAL | Final EctoPad-derived UT mapping, current iPad/iPhone screenshots, geometry, profiles, handedness, and live assistive FIRE pass. Finger reach, simultaneous multi-touch, haptics, VoiceOver traversal, and touch-only play require devices. |
| Physical controller | PHYSICAL-ONLY BLOCKED | GameController mappings compile and package; no controller/device pair is attached. |
| Keyboard and mouse | PHYSICAL-ONLY BLOCKED | UIKit keyboard/pointer bridges compile; authoritative iPad keyboard/mouse and mouse-button play are not evidenced. |
| Three-dot host menu and settings | PARTIAL | Native `UIMenu`/dark action-sheet, compact Touch Control Settings, data, diagnostics, multiplayer, graphics, audio, recovery and About paths exist. Physical interaction/accessibility traversal remains. The unreachable legacy custom menu was removed on this audit. |
| Folder/ZIP data importer | PARTIAL | Transaction, rollback, recovery, rejection, progress, cancellation and Simulator Files picker pass. Physical providers, low disk, and large-device latency remain. |
| Steam-origin game data | LOCAL ACTIONABLE | No Steam-origin import evidence is recorded; sanctioned ISO/GOTY content is covered. The local Steam library has no UT99 app/install, and the configured secondary Steam volume is not mounted, so no user-owned Steam source is currently available to test. |
| Lifecycle and recovery | PARTIAL | Simulator background/foreground, single-engine invariant, crash marker, Safe Mode and diagnostics pass. Physical suspend, watchdog/OOM, controlled return and share-sheet recovery remain. |
| Server browser/master query | PARTIAL | The Simulator slice now passes: point-accurate original UWindow input selects `UT Servers`, the stock browser visibly lists 775 servers, and original GameSpy/HTTP master plus server-ping traffic is captured. Real-finger/device networking and joining from a selected row remain open. |
| Direct connect and unmodified multiplayer | PARTIAL | The current native host sheet validates and normalizes a player-entered address, then hands it to v469e; live evidence records DNS, 469 challenge, download managers, welcome, remote map load, and visible session. Full movement/respawn/chat/map-transition sequence and physical networking remain. |
| Performance and stability | PHYSICAL-ONLY BLOCKED | FruCoRe presentation instrumentation works and Simulator metrics are recorded; physical FPS/pacing/thermals/memory/long-run evidence is required. |
| Local IPA packaging | PARTIAL | Diagnostic ad-hoc IPA and manifest pass integrity/no-game-data checks. Installable development-signed IPA is blocked by signing identity/team. |
| Clean-checkout reproduction | LOCAL ACTIONABLE | Bootstrap is now deterministic, but this working tree is largely untracked relative to commit `65b0066`; a meaningful clean-checkout proof requires first establishing a complete tracked repository snapshot. No user changes were reset or overwritten. |
| Runtime discipline | PROVEN | Exactly one iPad Simulator is booted for the active final runtime; EctoPad reference checkout is pristine at `461de17f549d98742bc3b2d031156f79ab3eaa9d`. |

## Current priority

The first release-promoting experiment remains physical G2:

```bash
DEVELOPMENT_TEAM=YOURTEAMID make device-check
DEVELOPMENT_TEAM=YOURTEAMID make device-run
DEVELOPMENT_TEAM=YOURTEAMID make verify-device
```

Until device/signing prerequisites exist, locally actionable work must not be described as physical-device completion. The most valuable remaining local items are Steam-origin importer evidence when a user-owned source becomes available, browser-driven join/session coverage, warning cleanup, and proving a fully tracked clean-checkout snapshot.
