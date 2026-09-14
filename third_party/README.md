# Third-party build inputs

Pinned build versions, provenance, licenses, and scoped shipping observations
are recorded in `deps.lock.json`. The shipping observation applies to Preview 3
only; archive member presence does not verify the recorded binary versions.
The [component review](../docs/RELEASE-COMPONENT-REVIEW-2026-09-14.md) also
records engine, FMOD, font, and shim files not covered by the dependency list. Source checkouts and downloaded archives live under ignored
`ref/`; generated target-specific source copies and binaries live under
ignored `build/`.

OpenAL Soft is built from its pinned checkout through a generated
source copy. `patches/openal-soft-ios-aligned-allocation.patch` prevents its
pre-macOS-10.13 aligned-allocation fallback from being selected for iOS, where
`AvailabilityMacros.h` otherwise publishes a misleading macOS compatibility
value. Applying this build patch does not modify the checkout under `ref/`.
