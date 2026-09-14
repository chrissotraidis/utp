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
4. Resolve FMOD provenance and redistribution terms. Font metadata has now been
   inspected; see the follow-up below. Check source matching and any additional
   upstream font notices before marking delivery complete.
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

## Follow-up: font metadata and FMOD build path

The three fonts' actual name tables identify Tinos 1.23 and Open Sans 1.10 as
Apache-2.0, and Courier Prime 1.203 as SIL OFL 1.1. Courier Prime includes the
full OFL and its copyright notice in the font metadata. Their hashes match the
package verifier. Accessible copies of these notices and license texts are now
in [third_party/notices](../third_party/notices/README.md). This narrows the
previous font uncertainty; lack of standalone files did not mean no embedded
license existed. The published IPA is unchanged.

The `ios-fmod-real` Makefile target reads `libfmod.dylib` from the local OldUnreal
macOS baseline, extracts arm64, changes the target platform and library load paths,
and signs the result. There is also a separate source-built stub target; do not
confuse the two. This identifies the real target's build provenance, not an exact
binary match or permission to modify/redistribute that library. Verify applicable
terms for the input shipped with v469e and match the Preview 3 library to that path.

The live Preview 3 release asset list contained only the IPA at this review time;
there was no separate notice/source supplement asset. The repository itself has
source and input pins. Completeness of required source and notice delivery remains
an open check, rather than an inference from asset count alone.

## Repeatable package review companion

`tools/package_local_ipa.sh` now generates an `*-review.zip` companion after the
final IPA is assembled. Its manifest records the IPA hash and every file's hash,
and it includes the verified font notices. The local package manifest records
the companion filename and checksum. Changed or missing font bytes stop companion
generation so old notices cannot silently describe different fonts.

Publish both files together. The companion is explicitly partial: it does not
contain Corresponding Source, runtime permission, or all dependency notices.
The signed app is untouched; no payload, game files, or credentials are copied
into the companion. Existing binaries require a separately generated companion.

## Applicable-terms review

The [v469e-tag notices](https://github.com/OldUnreal/UnrealTournamentPatches/blob/v469e/LICENSE.md)
and [current notices](https://github.com/OldUnreal/UnrealTournamentPatches/blob/master/LICENSE.md)
are different. Do not use the current linked Epic agreement as proof of the exact
agreement governing the historical input. OldUnreal's documented Epic approval
is project-specific; this record does not infer downstream permissions from it.

[FMOD's current public EULA](https://www.fmod.com/legal) includes conditional
redistribution paths. Exact FMOD version, applicable terms/custom permissions,
modification/distribution scope, and runtime attribution remain to be verified.
Check existing in-game credits before adding a duplicate credit. Current FMOD
Studio-specific branding instructions should not be imposed on this runtime
without confirming applicability. No income or license violation is inferred
from the presence of a support link or from this review.

## Prepared extended notices and exact FMOD version

The original, hash-matched macOS DMG contains a multi-platform `LICENSE.md` that
was not retained in the extracted baseline. An unchanged copy is now staged in
[OldUnreal-v469e notices](../third_party/notices/OldUnreal-v469e/README.md).
This is a notice collection, not a discovered engine/FMOD license grant.

[Library notices](../third_party/notices/libraries/README.md) were extracted from
the exact pinned SDL2, OpenAL Soft, libsndfile and libxmp Git objects and the
hash-matched mpg123 source archive. Their provenance manifest records checksums.
The companion generator now includes these copies. Matching all these inputs to
the released library bytes and satisfying all source requirements remains open.

Static inspection of both the baseline and Preview 3 FMOD version function
returns `0x00020210`, identifying FMOD Core 2.02.10. The Preview 3 FMOD SHA-256 is
`d2849e22cc826da3c2580dcddf1962177e80b2efab5cb1d211a6b6642278b889`.
Its bytes differ from the macOS input; the documented build transforms platform
and load-path metadata. No binary was executed to obtain this evidence.

The remaining permission question is specific: what applicable agreement covers
modifying and redistributing this version/input in UTP? The current public FMOD
EULA is not assumed to govern the historical input. Repository source visibility,
free downloads and support links do not answer that question by themselves.
