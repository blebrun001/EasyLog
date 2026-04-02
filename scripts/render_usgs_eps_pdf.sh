#!/usr/bin/env bash
set -euo pipefail

# Converts EPS symbols to PDF counterparts used for higher-fidelity rendering.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_DIR="$ROOT_DIR/Sources/CakeKit/Resources/USGS/11A02"
GS_BIN="$(command -v gs || true)"

if [[ -z "$GS_BIN" ]]; then
  echo "Ghostscript (gs) is required but not found in PATH." >&2
  exit 1
fi

for variant in ai8 cs2; do
  src="$BASE_DIR/$variant"
  dst="$BASE_DIR/pdf/$variant"
  mkdir -p "$dst"

  while IFS= read -r -d '' eps; do
    name="$(basename "$eps")"
    out="$dst/${name%.*}.pdf"
    "$GS_BIN" -dSAFER -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -o "$out" "$eps" >/dev/null
  done < <(find "$src" -type f -iname '*.eps' -print0)
done

echo "PDF conversion complete."
