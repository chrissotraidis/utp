# iOS data-transaction and single-engine-state pass — 2026-08-24

Classification: **PASS** for journaled simulator import rollback/replacement and the one-engine host invariant; **PARTIAL** for G2/FR-011 because no physical iPad or iPhone was attached.

## Hypothesis

A complete backup plus an atomic phase journal can replace imported Maps, Music, Sounds, Textures, and their manifest without leaving a partial live data set, while keeping the generated System tree untouched. The same explicit host state can reject a second engine entry.

## Result

- A forced interruption after two installed items left a committing journal. Recovery restored the previous map and manifest, removed partial new content, and left no transaction debris.
- A subsequent successful commit replaced all four content directories and installed a SHA-256 manifest that verified 4/4 fixture files.
- The generated `System/keep.txt` fixture survived rollback and successful replacement.
- Manifest verification uses bounded 1 MiB streaming reads rather than loading each package fully into memory.
- Game Data now exposes Verify, Repair/Reimport, and Export Manifest actions. Import is refused while the original engine is active.
- The host now records the PRD state names and blocks duplicate start requests. The smoke recorded `blocked=true state=Running`; engine evidence contains one cwd entry and one `Entering main loop.` record.
- Starting from the host menu removes the panel before SDL presents the first frame. The accepted gameplay capture has no stale menu over Deck16.
- Host diagnostics now resolve `Frameworks/UnrealTournament.dylib` and report `Engine image: embedded` instead of the former false `missing` result.

## Visual and runtime evidence

- `ipad-data-transaction-host-menu-landscape.png` — true 2360×1640 host/menu capture after rollback/replacement passed
- `ipad-data-transaction-gameplay-landscape.png` — true 2360×1640 Deck16 regression after the same build launched the original engine
- `UT99-import-transaction-smoke.log` — rollback/replacement/System-preservation/debris result
- `UT99-duplicate-start-smoke.log` — second entry rejected in `Running`
- `UT99-engine.stdout` and `UnrealTournament.log` — v469e, 1180×820 points, 2360×1640 pixels, FruCoRe, game initialization, and one main loop
- `UT99-system.log` — Ready → StartingEngine → Running transitions and renderer attachment
- `UT99-host-system.log` — host-only relaunch
- `accessibility.txt` — authoritative Simulator accessibility excerpt for corrected host diagnostics

## Limits

This does not prove physical Files-picker storage behavior, import cancellation during long copy/hash work, low-disk recovery, Steam-origin package compatibility, or physical engine startup. The simulator was shut down after capture and the runtime guard reported zero booted simulators.
