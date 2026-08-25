# Third-party build inputs

Pinned versions, provenance, licenses, and shipping intent are recorded in
`deps.lock.json`. Source checkouts and downloaded archives live under ignored
`ref/`; generated target-specific source copies and binaries live under
ignored `build/`.

OpenAL Soft is built from its pinned checkout through a generated
source copy. `patches/openal-soft-ios-aligned-allocation.patch` prevents its
pre-macOS-10.13 aligned-allocation fallback from being selected for iOS, where
`AvailabilityMacros.h` otherwise publishes a misleading macOS compatibility
value. Applying this build patch does not modify the checkout under `ref/`.
