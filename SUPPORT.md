# UTP support

UTP is a development project without a public binary. Support is focused
on reproducible source, build, Simulator, physical-device, and compatibility
reports.

## Before reporting a problem

1. Check [`docs/STATUS.md`](docs/STATUS.md) and
   [`docs/KNOWN_ISSUES.md`](docs/KNOWN_ISSUES.md).
2. Run `make doctor` for environment readiness.
3. Reproduce on the latest source when practical.
4. Record the exact command or menu path, environment, device/OS, Xcode
   version, and failure stage.
5. Run `make diagnostics` when the host can produce a redacted archive, then
   inspect it before sharing.

Use the structured
[bug report](https://github.com/chrissotraidis/utp/issues/new/choose) for
non-sensitive defects.

## What not to share

Never upload or link to:

- Unreal Tournament game packages, disc images, or prepared data;
- OldUnreal release binaries or generated iOS runtime images;
- app bundles, IPAs, signing certificates, provisioning profiles, or keys;
- Apple IDs, development team identifiers, tokens, passwords, or credentials;
- unredacted diagnostics containing private paths, account names, device
  identifiers, or private server details.

The project cannot help locate copyrighted game data or bypass platform
signing and distribution requirements.

## Useful report boundaries

Say whether the failure happened during bootstrap, build, signing/install,
first-run data setup, engine startup, offline play, online play, input, audio,
lifecycle, diagnostics, or packaging. A screenshot of a live process does not
by itself prove controls, sound, gameplay, or stability.

Sensitive vulnerabilities belong in a private security report; follow
[`SECURITY.md`](SECURITY.md).
