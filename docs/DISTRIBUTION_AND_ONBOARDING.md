# Distribution and first-run onboarding

## Current decision

UTP is ready to move from Simulator validation to signed physical-device testing. Public distribution is not yet authorized merely because a diagnostic IPA can be produced. The app binary and the game-data acquisition flow have separate permissions and Apple-platform requirements, so they remain separate release artifacts.

Online play is a launch-critical feature, not a later enhancement. The current Simulator build has already populated the original v469 server browser, joined public servers, downloaded data-only server packages, played through death and respawn, survived a map transition, and disconnected through the original menu. Physical-device networking and another player's observation remain required before release promotion.

## Recommended delivery model

### Beta

Use TestFlight for the first external beta once physical-device development signing passes. It is the most practical Apple-supported path for testers who are not registering device identifiers or building locally.

Ad Hoc IPA distribution is useful only for a bounded registered-device test group. A raw IPA on a normal webpage is not a general worldwide installation mechanism: Ad Hoc builds are limited to registered devices, while Apple website distribution requires eligibility, App Store Connect review/notarization, approved domains, installation licensing, and supported regions.

### Public release

Evaluate these channels in order:

1. App Store, if the engine/data permissions and review constraints can be satisfied.
2. TestFlight for a controlled public beta while those questions are resolved.
3. Apple-approved website or alternative-marketplace distribution in eligible regions; do not describe this as universal sideloading.
4. Locally signed builds for developers and preservation users.

The release website should publish version, build hash, supported OS/device list, privacy statement, data provenance, known issues, multiplayer status, and a prominent Install/TestFlight action appropriate to the visitor's region. It must never present an ad-hoc diagnostic IPA as generally installable.

## First-run game-data experience

The implemented candidate user flow is:

1. Install and open UTP.
2. See a short explanation that the app and Unreal Tournament data are separate.
3. Choose **Get Game Data** or **Import Files**.
4. Before any download, show the source, approximate size, terms/provenance link, destination, and explicit consent action.
5. Download the exact image used by OldUnreal's installers from OldUnreal mirrors (Archive.org fallback), require exactly `649633792` bytes and SHA-256 `e184984ca88f001c5ddd52035d76cd64e266e26c74975161b5ed72366c74704f`, extract only `Maps`, `Music`, `Sounds`, and `Textures`, reject executable/native content, and transactionally validate before replacing a working installation.
6. Delete temporary disc/archive material after completion or cancellation.
7. Enter the original menu with **Play Offline** and **Play Online** next actions.

[OldUnreal's current full-game installer page](https://www.oldunreal.com/downloads/unrealtournament/full-game-installers/) states that its installers download the original UT99 GOTY disc image from OldUnreal's servers, with Archive.org as a fallback, and apply the latest patch. [OldUnreal's patch repository](https://github.com/OldUnreal/UnrealTournamentPatches) states that the project was approved by Epic Games but is not an Epic project. Those sources support an authorized-source onboarding design; they do not automatically grant this project permission to mirror the ISO, redistribute a transformed OldUnreal engine, or bypass the source's terms. Written confirmation from the relevant rights holders/maintainers is a public-release gate.

This in-app path is implemented in `UT99GameDataAcquisition.swift` and reuses the existing transactional importer. A deterministic Joliet/ISO-9660 fixture and the locally ignored official image both pass extraction tests; the official image yields 283 accepted files, and v469e decompresses its `.unr.uz` maps at first engine launch. A companion web page can explain and deep-link into the installed app, but should not silently download hundreds of megabytes or imply that a browser can install arbitrary files directly into the app container.

The implementation is ready for physical acceptance, but its presence in source is not a claim that a public binary may redistribute the transformed engine or automate this acquisition in every release channel. Obtain written permission and Apple review clearance before enabling it in a public build.

## Online-play launch gate

Public launch messaging may say that online play is supported only after one physical-device run proves:

- community server-browser population;
- direct connect and DNS over device Wi-Fi;
- data-only package downloads and a custom-map load;
- movement, look, combat, scoreboard, death, respawn, and map transition;
- chat observed by a second player or controlled observer;
- clean disconnect/reconnect and background-path behavior; and
- no anti-cheat or compatibility issue on the documented tested servers.

The current evidence is recorded in [`NETWORK_COMPATIBILITY.md`](NETWORK_COMPATIBILITY.md) and `docs/evidence/network/`. OldUnreal's [v469e release](https://github.com/OldUnreal/UnrealTournamentPatches/releases/tag/v469e) recommends v469e for online play and says it automatically uses community master servers.

## Physical-device handoff

Required before the next run:

- exactly one trusted Developer Mode iPhone or iPad;
- one Apple Development identity and development team configured in Xcode;
- the canonical ignored game-data source already present, or a folder/ZIP selected through Files;
- a Wi-Fi path that permits public UT UDP traffic; and
- optionally a controller and iPad keyboard/mouse for their dedicated gates.

Run:

```bash
DEVELOPMENT_TEAM=YOURTEAMID make device-check
DEVELOPMENT_TEAM=YOURTEAMID make device-run
DEVELOPMENT_TEAM=YOURTEAMID make verify-device
UT99_DEVICE_AUTOSTART=1 DEVELOPMENT_TEAM=YOURTEAMID make device-run
```

Collect the first physical frame, touch-only Deck16 play, audible effects/music, three background/resume cycles, rotation/safe-area captures, sustained performance/memory/thermal observations, original server-browser play, and a diagnostic export. Do not replace failed physical evidence with Simulator evidence.

## Distribution gates still open

- Apple Development signing and physical G2.
- Permission to distribute the transformed OldUnreal runtime as a prebuilt app.
- Written confirmation that the implemented OldUnreal mirror/fallback acquisition UX may be enabled in a public build.
- App Store/TestFlight review feasibility and any required account/organization setup.
- Apple-approved website-distribution eligibility if that channel is pursued.
- Privacy, support, crash-reporting, release signing, update, and revocation operations.

Apple references: [beta and release distribution](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases), [distribution overview](https://developer.apple.com/documentation/technologyoverviews/distribution), and [website distribution](https://developer.apple.com/documentation/appdistribution/distributing-your-app-from-your-website).
