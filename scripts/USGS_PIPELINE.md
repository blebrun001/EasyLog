# USGS Symbol Pipeline

This pipeline keeps Cake's USGS symbol resources consistent across preview and export.

## Standard Run

Use this for the normal workflow (Section 37 scope):

```bash
./scripts/build-resources.sh all section37
```

What it does:

- Rebuilds the symbol index from EPS metadata.
- Regenerates runtime catalogs used by the app.
- Regenerates isolated symbol PDFs used at render time.

## Full Catalog Run

Use this when you need every indexed section:

```bash
./scripts/build-resources.sh all all
```

This uses the same EPS-native crop logic and expands outputs to the full catalog.

## Core Scripts

1. `scripts/build_usgs_symbol_index.py`
2. `scripts/build_usgs_resource_catalog.py`
3. `scripts/build_usgs_section37_catalog.py`

## Notes

- The Pattern Chart step is not part of the standard pipeline.
- Isolated runtime entries use tile-local coordinates to keep renderer crop alignment stable.
