#!/usr/bin/env bash
set -euo pipefail

# Rasterizes EPS symbols to PNG using Ghostscript for fast preview loading.
# Use `USGS_RASTER_DPI` to tune quality/size trade-offs.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_DIR="$ROOT_DIR/Sources/EasyLogKit/Resources/USGS/11A02"
GS_BIN="$(command -v gs || true)"
DPI="${USGS_RASTER_DPI:-600}"

if [[ -z "$GS_BIN" ]]; then
  echo "Ghostscript (gs) is required but not found in PATH." >&2
  exit 1
fi

for variant in ai8 cs2; do
  src="$BASE_DIR/$variant"
  dst="$BASE_DIR/raster/$variant"
  mkdir -p "$dst"

  while IFS= read -r -d '' eps; do
    name="$(basename "$eps")"
    out="$dst/${name%.*}.png"
    "$GS_BIN" -dSAFER -dBATCH -dNOPAUSE -sDEVICE=pngalpha -r"$DPI" -o "$out" "$eps" >/dev/null
  done < <(find "$src" -type f -iname '*.eps' -print0)
done

echo "Raster conversion complete at ${DPI} DPI."
