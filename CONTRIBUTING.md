# Contributing to UT99Apple

Thanks for helping improve the iPhone and iPad experiment.

## Before opening an issue

- Read [`docs/STATUS.md`](docs/STATUS.md) and
  [`docs/KNOWN_ISSUES.md`](docs/KNOWN_ISSUES.md).
- Search existing issues first.
- Reproduce on the latest source when practical.
- Include the commit, environment, device/OS, Xcode version, build command,
  failure stage, and exact steps.
- Share only redacted diagnostics. Never attach proprietary game data,
  generated runtime images, apps/IPAs, signing files, credentials, or private
  personal paths.

Use the structured bug-report template so Simulator and physical-device
evidence remain distinguishable.

## Making a change

1. Keep the change focused and preserve the current architecture and evidence
   boundaries.
2. Keep upstream inputs under ignored `ref/` and generated output under
   ignored `build/`.
3. Update tracked source, tests, tools, or human-readable evidence—not fetched
   upstream trees or generated binaries.
4. Run the relevant deterministic tests or `make test` on macOS.
5. Run `make public-check` before committing.
6. Update status, known issues, and the test matrix only when the evidence
   actually changes.

Pull requests should list exact validation commands and name every remaining
physical-device, distribution, permission, or compatibility gate.

## Evidence rules

A successful compile, Simulator run, package audit, device install, and live
process each prove different things. None should be promoted into touch,
audio, controller, gameplay, lifecycle, thermal, long-session, or public
distribution acceptance without the matching evidence.

Raw screenshots, logs, archives, and device output stay local. Commit concise
redacted `RESULT.md` records under `docs/evidence/` only when they materially
advance or falsify a gate.

## Licensing

The repository currently has no top-level reuse license. Contributing does not
change that status or grant rights to third-party code, the official OldUnreal
runtime, Epic game data, or trademarks. See
[`RIGHTS_AND_LICENSES.md`](RIGHTS_AND_LICENSES.md).
