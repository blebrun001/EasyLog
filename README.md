# Cake

<p align="center">
  <img src="Sources/CakeApp/Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" alt="Cake app icon" width="180" />
</p>

Cake is a macOS app to create clear stratigraphic logs from structured geological data.

## What You Can Do

- Build and edit one or multiple logs in the same project.
- Manage units with name, thickness, lithology, grain size, and point features.
- See a live visual preview while you edit.
- Customize lithology colors with reusable profiles.
- Compare logs side by side on a shared altitude scale.
- Export results as:
  - `SVG` for editable vector output
  - `JPG` for raster output
  - `Export All` for batch export of every log

## Typical Workflow

1. Create or open a project.
2. Add, edit, reorder, or duplicate log units.
3. Tune preview settings and color profiles.
4. Validate the result visually.
5. Export one log or all logs.

## Run

```bash
make build
CAKE_RESOURCE_PROFILE=dev swift run CakeApp
```

## Test

```bash
make test
```

## Example Data

Use the sample project at `Examples/sample-project.json`.

## Resource Profiles

Set `CAKE_RESOURCE_PROFILE` to choose symbol resources:

- `dev` for development assets
- `release` for production assets

If not set, Cake uses `dev` in debug builds and `release` otherwise.
