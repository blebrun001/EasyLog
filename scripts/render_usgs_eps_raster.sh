#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_DIR="$ROOT_DIR/Sources/CakeKit/Resources/USGS/11A02"
GS_BIN="$(command -v gs || true)"

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
    "$GS_BIN" -dSAFER -dBATCH -dNOPAUSE -sDEVICE=pngalpha -r300 -o "$out" "$eps" >/dev/null
  done < <(find "$src" -type f -iname '*.eps' -print0)
done

echo "Raster conversion complete."
