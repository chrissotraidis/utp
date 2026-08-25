# macOS v469e baseline — 2026-08-23

**Classification: PASS for the macOS oracle; not an iOS gate.**

- Official v469e universal app copied from the ignored DMG into ignored `build/macos-baseline/`.
- GOTY content came from the sanctioned OldUnreal ISO and was prepared into the local Application Support data root.
- Startup reached the original engine, SDL client, lighting, renderer, `Entry`, `CityIntro`, player possession, and the main loop.
- FruCoRe was selected in `UnrealTournament.ini`; the log reports `Frucore: Using RGB10A2 frame buffer`.
- Metal-era startup evidence is in `stdout-frucore.log`; screenshot evidence is `macos-frucore-screen.png`.
- A separate OpenGL run also reached the main loop and is retained as comparison evidence in `stdout-second.log` and `macos-screen.png`.
- The client was terminated after capture, and the runtime guard reports no UT process or booted simulator.
- A corrected launch-context recheck again reached `CityIntro`, player possession, and a rendered first-person frame (`stdout-recheck-*.log` and `macos-recheck-*.png`). Direct map arguments were intentionally not counted as separate Deck16/Face passes because this client configuration forces `LocalMap=CityIntro.unr`; those scenarios remain represented by the iPad diagnostic path.

This establishes a reproducible behavioral/rendering oracle. It does not prove any iOS engine startup, code signing, or device behavior.
