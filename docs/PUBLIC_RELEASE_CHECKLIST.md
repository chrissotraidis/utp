# UTP public release checklist

This checklist separates a public source snapshot from a downloadable binary.
Passing the source gate does not authorize or validate a public app release.

## Every public source update

- [ ] `make public-check` passes from the intended commit.
- [ ] Relevant deterministic tests or `make test` pass on macOS.
- [ ] README status, known issues, test matrix, and evidence boundaries agree.
- [ ] No game data, official runtime binary, generated engine image, app/IPA,
      signing material, credentials, private paths, or raw private evidence is
      publishable.
- [ ] Pinned dependency provenance and licensing intent remain accurate.
- [ ] Simulator, package, and device claims are kept distinct.
- [ ] The diff contains only reviewed release-scope files.

## Before making the repository public

- [ ] Inspect every public branch, tag, GitHub Actions artifact, and release.
- [ ] Inspect Git history for prohibited filenames and machine-specific content;
      decide explicitly whether a history rewrite is required.
- [ ] Confirm the repository description, topics, social preview, default
      branch, issue templates, and support/security routes.
- [ ] Enable GitHub private vulnerability reporting.
- [ ] Confirm `RIGHTS_AND_LICENSES.md` matches the intended source-available
      posture; do not label the project open source without an actual license.
- [ ] Run the gate from a clean clone of the exact public candidate commit.
- [ ] Verify that clone contains no ignored local inputs or generated output.
- [ ] Do not create a version tag merely for repository visibility.

## Before publishing any external beta or binary

- [ ] Close signed physical-device startup and first-frame G2 on the exact app.
- [ ] Complete touch-only play, audio routes/interruptions, controller,
      keyboard/mouse, lifecycle, networking, performance, thermal, memory, and
      update/data-preservation acceptance appropriate to the release claims.
- [ ] Obtain written permission to distribute the transformed OldUnreal
      runtime.
- [ ] Obtain written confirmation for the enabled game-data acquisition flow.
- [ ] Select and satisfy the Apple distribution channel: TestFlight, App Store,
      eligible website/alternative marketplace, or bounded registered-device
      Ad Hoc testing.
- [ ] Complete privacy disclosure/manifest, support, crash-reporting, signing,
      update, and revocation operations.
- [ ] Build from a clean tagged commit with a deliberate version and build
      number.
- [ ] Audit the exact app/IPA for platform, architecture, signing, entitlements,
      embedded dependencies/licenses, private data, and prohibited content.
- [ ] Install the exact packaged artifact in place on physical iPhone and iPad;
      verify first launch, imported-data preservation, saves/configuration,
      and relaunch.
- [ ] Publish honest release notes with the commit, Xcode/SDK, supported
      devices/OS versions, checksum, evidence, and known limitations.
- [ ] Download the hosted artifact again and prove byte identity and checksum.

## Current blockers

- Physical iPhone and iPad startup, gameplay, touch, audio, keyboard text entry,
  Xbox controller startup/hot-connect, pause/resume, and update preservation
  have been exercised for Preview 2. Pointer precision and the remaining
  defects are listed in `docs/KNOWN_ISSUES.md`.
- Transformed-runtime distribution permission is unresolved.
- Public-binary acquisition permission is unresolved.
- No TestFlight, App Store, or other general consumer channel is configured.
- Formal lifecycle, networking, performance, thermal, and broad-device
  acceptance remain open.

These blockers require Preview 2 to remain an explicitly unfinished,
re-signable developer artifact. They prevent describing it as a finished or
generally installable iOS release.
