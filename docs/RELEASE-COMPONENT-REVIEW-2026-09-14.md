# Preview 3 component review — 14 September 2026

## Evidence and scope

Inspected `UTP-0.1.0-preview.3-unsigned.ipa` from the earlier saved review download.
Release: https://github.com/chrissotraidis/utp/releases/tag/v0.1.0-preview.3

This is an archive-directory inspection, not a binary provenance, source-completeness,
or legal clearance audit. It does not cover the separate issue-6 test IPA or later
local iOS compatibility candidates. No app behavior or release availability changed.

Archive size: `10359408` bytes.

SHA-256: `fb7876fd4d1916889d9050b6173c483aaed38957220811ce5832804b366efbae`.

## Observed contents

The archive includes `UnrealTournament.dylib`, SDL2, OpenAL, mpg123, libsndfile,
libxmp, `libfmod.dylib`, project shim libraries, and three font files. The five
listed dependencies in `third_party/deps.lock.json` are therefore marked as shipped
for this release. Their existing pins have not been independently matched to the
binary contents. The original macOS input archive is not included unchanged;
that does not mean its transformed output is absent.

The member listing does not show the GOTY disc image or standalone Maps, Music,
Sounds, or Textures directories. This is not proof that every embedded resource
is free of third-party material. No standalone license/notice file appears in the
listing; embedded notices, accompanying release files, and applicable delivery
obligations require separate examination.

## Remaining decisions

1. Identify the exact transformed-runtime input and applicable terms or separate
   permission. Preserve any private agreement; public absence is not proof of no permission.
2. Reconcile the previously stated written-permission gate with existing public
   runtime distribution and acquisition behavior. Free acquisition through the
   publisher-linked OldUnreal route is distinct from downstream runtime rights.
3. Match shipped libraries to source versions, local patches, notices, and any
   applicable source/relinking obligations. Determine what is required before
   claiming compliance or a breach.
4. Establish FMOD and font provenance and terms, which the dependency list does
   not currently document. File names alone do not establish version or license.
5. Repeat the inventory for any candidate promoted beyond Preview 3. Make an
   explicit release decision after resolving material rights/source gaps.

References: [Epic UT page](https://www.epicgames.com/unrealtournament),
[OldUnreal installers](https://www.oldunreal.com/downloads/unrealtournament/full-game-installers/),
[OldUnreal terms and notices](https://github.com/OldUnreal/UnrealTournamentPatches/blob/master/LICENSE.md).

## Exact archive members

```text
Payload/UT99Apple.app/default.metallib
Payload/UT99Apple.app/AppIcon60x60@2x.png
Payload/UT99Apple.app/UT99Apple
Payload/UT99Apple.app/Assets.car
Payload/UT99Apple.app/AppIcon76x76@2x~ipad.png
Payload/UT99Apple.app/UT99FontSupport/Tinos-Regular.ttf
Payload/UT99Apple.app/UT99FontSupport/CourierPrime.ttf
Payload/UT99Apple.app/UT99FontSupport/OpenSans-Regular.ttf
Payload/UT99Apple.app/Frameworks/libxmp.dylib
Payload/UT99Apple.app/Frameworks/libsndfile.dylib
Payload/UT99Apple.app/Frameworks/UT99CoreServicesShim.dylib
Payload/UT99Apple.app/Frameworks/UnrealTournament.dylib
Payload/UT99Apple.app/Frameworks/libmpg123.dylib
Payload/UT99Apple.app/Frameworks/UT99ApplicationServicesShim.dylib
Payload/UT99Apple.app/Frameworks/libSDL2.dylib
Payload/UT99Apple.app/Frameworks/libfmod.dylib
Payload/UT99Apple.app/Frameworks/libopenal.dylib
Payload/UT99Apple.app/Frameworks/UT99DesktopShim.dylib
Payload/UT99Apple.app/Frameworks/UT99CocoaShim.dylib
Payload/UT99Apple.app/Frameworks/UT99MetalShim.dylib
Payload/UT99Apple.app/Info.plist
Payload/UT99Apple.app/PkgInfo
```
