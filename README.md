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

## Run

```bash
swift run CakeApp
```

## Test

```bash
swift test
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

Sync EPS symbols and rebuild the index:

```bash
./scripts/sync_usgs_11a02_eps.sh && ./scripts/build_usgs_symbol_index.py
```

Increase raster quality (default `600` DPI):

```bash
USGS_RASTER_DPI=1200 ./scripts/render_usgs_eps_raster.sh
```

Regenerate PDF derivatives from EPS:

```bash
./scripts/render_usgs_eps_pdf.sh
```

## Compatibility Note

Legacy JSON files that include removed custom field structures (for example `customFieldDefinitions` or `customFields`) are not supported.

## Example Project

See [Examples/sample-project.json](/Users/brice/Documents/Iphes/Cake/Examples/sample-project.json).
