# GoldenPad reference inventory

The reference checkout is preserved read-only at ignored `ref/GoldenPad/`.

- Repository: https://github.com/chrissotraidis/goldenpad
- Checkout: `54474a40e93b77259d10c7594919e6a05f5e276d`
- README baseline: native Apple ARM64 runtime, Metal presentation, user-supplied data import, touch controls, controllers, diagnostics, and iOS/iPadOS 17+.
- Relevant UI patterns inspected: landscape game surface, persistent touch-control configuration, right-side settings/menu affordance, diagnostics/status surfaces, and user-data import flow.
- License/provenance: see `ref/GoldenPad/docs/SOURCE_LICENSES.md` and `ref/GoldenPad/docs/source-license-manifest.tsv`; no source was copied into UTP in this pass.

The UTP shell uses independently written UIKit equivalents of the inspected GoldenPad touch patterns and maps them to UT99's distinct controls. The host menu now exposes persisted profiles, drag/pinch layout editing, reset-to-default, and the three-dot interaction surface. Visual and physical parity remains a validation target rather than a claim that the UT99 overlay is source-identical to GoldenPad.
