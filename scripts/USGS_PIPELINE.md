# USGS EPS Native Pipeline

Source of truth is EPS-native index metadata:

1. `scripts/build_usgs_symbol_index.py`
2. `scripts/build_usgs_resource_catalog.py`
3. `scripts/build_usgs_section37_catalog.py`

## Standard production run (Section 37 stable)

```bash
./scripts/build-resources.sh all section37
```

- Builds `symbol-index.json` from EPS metadata.
- Generates runtime catalogs scoped to Section 37 only.
- Rebuilds isolated symbol PDFs used by runtime rendering.

## Full catalog run (all sections)

```bash
./scripts/build-resources.sh all all
```

- Uses the exact same EPS-native crop logic (`symbolRect`).
- Expands runtime catalogs and isolated outputs to all indexed symbols.

## Notes

- No Pattern Chart step is part of this standard flow.
- Runtime isolated entries are published with tile-local coordinates:
  - `symbolRect = {x:0,y:0,width,height}`
  - `pageSizePoints = {width,height}`
  This keeps renderer crop coordinates aligned with isolated PDFs.
