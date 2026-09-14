# Rights and licensing boundary

UTP currently has no top-level license grant. Unless an individual file
says otherwise, public access to project-owned integration code, scripts,
documentation, tests, and original patch content does not grant permission to
copy, modify, redistribute, sublicense, or sell it.

The project builds against or studies pinned third-party projects and release
inputs, including OldUnreal Unreal Tournament v469e, SDL2, FruCoRe/OpenGLDrv,
OpenAL Soft, mpg123, libsndfile, and libxmp. This notice does not relicense,
supersede, or claim ownership of those works. Their rights remain with their
respective authors and are governed by the terms supplied with each project.
Pinned build provenance and release-specific shipping observations are recorded in
[`third_party/deps.lock.json`](third_party/deps.lock.json).

The repository does not grant rights to Unreal Tournament, Unreal, Epic game
data, the official OldUnreal runtime, imported server packages, screenshots of
copyrighted game content, or related names and trademarks. No game data,
official runtime binary, or generated iOS engine image is included in the
source repository.

Public unsigned previews have already been published and contain a transformed
engine runtime. The source-repository exclusions above are not a statement
that the downloadable app excludes all game-derived code. See the
[Preview 3 component review](docs/RELEASE-COMPONENT-REVIEW-2026-09-14.md).

Earlier project documentation required written permission for transformed-runtime
distribution and the in-app acquisition flow. This review has not established
whether that gate was satisfied; it does not establish that permission is absent.
Reconcile the applicable input terms and any separate permission with the exact
shipped behavior before representing that gate as closed. Apple requirements
must be assessed for the actual distribution channel. Publication or a working
build is not itself evidence of distribution rights.

UTP is an independent, unofficial preservation and engineering project.
It is not affiliated with or endorsed by Epic Games, OldUnreal, or Apple.
