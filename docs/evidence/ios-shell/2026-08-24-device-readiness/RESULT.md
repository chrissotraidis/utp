# Physical-device readiness tooling — 2026-08-24

**Classification: PASS for deterministic readiness/tooling; NOT RUN for PRD G2 physical execution.**

## Hypothesis

Once exactly one trusted iPhone/iPad and an Apple development team are available, the existing real-FMOD iPhoneOS candidate can be automatically provisioned, installed through CoreDevice, and launched without changing the rehosting architecture.

## Experiment

- Inputs: current worktree based on `65b00668ff963d2e0a98679e1c8611ba30d80169`; Xcode 26.6; iOS SDK 26.5; verified real-FMOD device package pipeline.
- Commands: `make doctor`, `make device-check`, and `make test`.
- Success signal: the doctor emits all required readiness fields without device/identity secrets; the runner either identifies one usable physical device and signing path or exits before cleaning/building/installing with a precise prerequisite; deterministic tests pass.
- Failure signal: simulators or the host Mac are counted as physical iOS hardware, a missing prerequisite causes a mutation, or readiness fields/tests are absent.
- Cleanup: none required; the check path is read-only. One existing iPhone Simulator and one UT99 client remain active.

## Result

PASS for tooling. `make doctor` now reports canonical PRD/goal/EctoPad/input presence, required tools, signing identity count, configured-team count, physical CoreDevice iOS/iPadOS count, simulator count, project processes, and repository state. It does not print certificate names, team identifiers, physical device names, or UDIDs.

The prepared runner selects exactly one physical iOS/iPadOS device, requires an explicitly supplied `DEVELOPMENT_TEAM`, enforces the single-runtime policy before mutation, builds the real-FMOD candidate with Xcode automatic provisioning, verifies the app, installs it through CoreDevice, and launches the host. Automated engine/match arguments require the explicit `UT99_DEVICE_AUTOSTART=1` opt-in.

Current readiness is intentionally blocked before mutation:

```text
signing_identity_count=0
project_development_team_count=0
device_signing_ready=no
physical_ios_ipados_devices=0
device_readiness=blocked reason=no_physical_ios_ipados_device physical_ios_ipados_devices=0
```

`make test` passes, including `UT99 doctor report PASS` and `UT99 physical-device readiness PASS outcome=3`.

## Decision

Keep G2 active. Attach and trust exactly one Developer Mode iPhone/iPad and configure Apple Development signing, then run:

```bash
DEVELOPMENT_TEAM=<team-id> make device-check
DEVELOPMENT_TEAM=<team-id> make device-run
```

After importing valid data on the device, rerun with `UT99_DEVICE_AUTOSTART=1` to attempt G3/G5/G7 evidence. Do not claim any physical gate from this host-only readiness pass.
