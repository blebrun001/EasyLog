# Asset Layout Guidance

## Goal
Keep runtime assets and source pipeline assets clearly separated.

## Current Policy
- Runtime assets consumed by the app live under `Sources/EasyLogKit/Resources/USGSRuntime`.
- Heavy USGS source assets stay under `Sources/EasyLogKit/Resources/USGS` and are built by scripts.

## Workflow Recommendation
1. Regenerate runtime catalogs with `./scripts/build-resources.sh`.
2. Validate large-file policy with `./scripts/check-large-assets.sh`.
3. Avoid editing runtime catalogs manually.
4. Keep new source assets out of app-facing runtime folders unless required by runtime.
