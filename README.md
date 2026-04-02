# Cake (macOS SwiftUI MWE)

Cake is a data-driven macOS application for creating a minimal stratigraphic log from structured geological input.

## Architecture

`CakeKit` is organized by layers:

- `Core`: project model and validation rules
- `Features/Editor`: unit list + minimal unit editing UI
- `Features/Preview`: scene generation, symbology, CoreGraphics rendering, preview/settings UI
- `Infrastructure`: JSON persistence, export services, utility helpers
- `App`: view model, use-cases, and app composition views

`CakeApp` is the SwiftUI executable entry point.

## MWE Scope

- Two-panel UI:
  - Left: project metadata, unit list, minimal unit form
  - Right: live preview, toolbar, rendering settings
- Unit editing fields:
  - `name`
  - `thickness`
  - `lithology`
  - `grainSize` (controls log width in X)
- Real-time preview refresh after edits
- JSON project open/save
- Export:
  - SVG (editable vector)
  - JPG (DPI-aware raster)

## Compatibility Note

Legacy JSON files that include removed custom-field structures (for example `customFieldDefinitions` or `customFields`) are no longer supported.

## Run

```bash
swift run CakeApp
```

## Test

```bash
swift test
```

## USGS EPS Sync

```bash
./scripts/sync_usgs_11a02_eps.sh && ./scripts/build_usgs_symbol_index.py
```

## JSON Project Example

See [Examples/sample-project.json](/Users/brice/Documents/Iphes/Cake/Examples/sample-project.json).
