# Cake

<p align="center">
  <img src="Sources/CakeApp/Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" alt="Cake app icon" width="180" />
</p>

Cake is a macOS SwiftUI application for building a minimal, data-driven stratigraphic log from structured geological input.

## Architecture

`CakeKit` is organized in layers:

- `Core`: project model and validation rules
- `Features/Editor`: unit list and unit editing UI
- `Features/Preview`: scene generation, symbology, CoreGraphics renderer, preview/settings UI
- `Infrastructure`: JSON persistence, export services, utility helpers
- `App`: view model, use cases, and composition views

`CakeApp` is the executable SwiftUI entry point.

## Current Scope

- Two-panel UI:
  - Left: project metadata, unit list, and unit form
  - Right: live preview, toolbar, rendering settings
- Multi-log projects with tabs:
  - One JSON document can contain multiple logs
  - Create or duplicate logs from the UI
- Unit fields:
  - `name`
  - `thickness`
  - `lithology`
  - `grainSize` (controls log width on X)
- Real-time preview refresh after edits
- JSON project open/save
- Export:
  - `SVG` (editable vector)
  - `JPG` (DPI-aware raster)
  - `Export All` to batch-export all logs in a project

## Run

```bash
make build
CAKE_RESOURCE_PROFILE=dev swift run CakeApp
```

## Test

```bash
make test
```

## Xcode Project

Regenerate the Xcode project after updating `project.yml`:

```bash
xcodegen generate
```

## App Icon Generation

Generate `Cake.icns` and `Assets.xcassets/AppIcon.appiconset`:

```bash
./scripts/generate_cake_icon.sh
```

## USGS Assets

Build runtime resource catalogs (`dev`, `release`, or `all`):

```bash
./scripts/build-resources.sh dev
./scripts/build-resources.sh release
./scripts/build-resources.sh all
```

Sync EPS symbols and rebuild source indexes:

```bash
./scripts/sync_usgs_11a02_eps.sh && ./scripts/build_usgs_symbol_index.py
```

Generate the unified runtime catalog + isolated PDF symbol resources:

```bash
./scripts/build_usgs_resource_catalog.py --profile all
```

Regenerate PDF derivatives from EPS:

```bash
./scripts/render_usgs_eps_pdf.sh
```

`CakeKit` now loads symbols from generated runtime catalogs and isolated PDFs:

- `Sources/CakeKit/Resources/USGSRuntime/ResourceCatalog.dev.json`
- `Sources/CakeKit/Resources/USGSRuntime/ResourceCatalog.release.json`
- `Sources/CakeKit/Resources/isolated/`

Symbology rendering uses only `usgsLithologyCode` at runtime.
The editor no longer exposes a "full USGS catalog override" mode.

Profile selection is controlled by `CAKE_RESOURCE_PROFILE=dev|release`.
Default profile is `dev` for debug builds and `release` otherwise.

## Build Size Strategy

- Build artifacts are kept outside the repo by default (`~/Library/Caches/Cake-build`) via `make`.
- Raw EPS authoring sources remain in the repository, but runtime packaging only includes generated catalogs + runtime PDF assets.
- For release parity in CI, run `./scripts/build-resources.sh release` before building.

## Git Large Files (Future Additions)

Large USGS assets are protected by `.gitattributes` LFS patterns.

Check newly added large files:

```bash
./scripts/check-large-assets.sh
```

## Lightweight Clone (Contributors)

Partial clone + sparse-checkout example:

```bash
git clone --filter=blob:none <repo-url>
cd Cake
./scripts/setup-sparse-checkout.sh light
```

To restore full checkout:

```bash
./scripts/setup-sparse-checkout.sh full
```

## Local Git Ref Maintenance

If duplicate refs appear locally (for example `main 2`), inspect/fix with:

```bash
./scripts/fix-local-git-refs.sh
./scripts/fix-local-git-refs.sh --apply
```

## Compatibility Note

Legacy JSON files that include removed custom field structures (for example `customFieldDefinitions` or `customFields`) are not supported.

Minimum deployment target is configured to `macOS 26.0` in the Xcode project (`project.yml` / `.pbxproj`).
SwiftPM uses `.macOS(.v15)` as its highest explicit named platform constant.

## Example Project

See [Examples/sample-project.json](Examples/sample-project.json).

## GitHub Release (Unsigned DMG)

The repository includes a GitHub Actions workflow that builds an unsigned macOS app bundle, packages it as a DMG, and publishes a GitHub pre-release with checksum.

- Trigger on pushed tags matching `vX.Y.Z`
- Manual fallback via `workflow_dispatch` in Actions
- Generated assets:
  - `CakeApp-vX.Y.Z-unsigned.dmg`
  - `CakeApp-vX.Y.Z-unsigned.dmg.sha256`

### Publish a release

Create and push a version tag:

```bash
git tag v1.2.3
git push origin v1.2.3
```

Then open the corresponding GitHub release and download the DMG artifact.

### Verify checksum

```bash
shasum -a 256 -c CakeApp-v1.2.3-unsigned.dmg.sha256
```

### Gatekeeper note

The DMG is intentionally unsigned and not notarized, so macOS will show a security warning on first launch.
