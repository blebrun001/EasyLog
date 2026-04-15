#!/usr/bin/env bash
set -euo pipefail

# Downloads FGDC/USGS 11A02 EPS archives, extracts them, and updates the
# local manifest used by the symbol resolver.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_URL="https://pubs.usgs.gov/tm/2006/11A02/"
TARGET_DIR="$ROOT_DIR/Sources/EasyLogKit/Resources/USGS/11A02"
DOWNLOAD_DIR="$ROOT_DIR/.cache/usgs_11a02/downloads"
WORK_DIR="$ROOT_DIR/.cache/usgs_11a02/work"
MANIFEST_PATH="$TARGET_DIR/manifest.json"

mkdir -p "$TARGET_DIR" "$DOWNLOAD_DIR" "$WORK_DIR" "$TARGET_DIR/ai8" "$TARGET_DIR/cs2"

echo "Fetching USGS page: $BASE_URL"
HTML_PATH="$WORK_DIR/index.html"
curl -L -s "$BASE_URL" -o "$HTML_PATH"

ZIP_LINKS_RAW="$WORK_DIR/zip-links.txt"
python3 - <<'PY' "$HTML_PATH" > "$ZIP_LINKS_RAW"
import re, sys
from pathlib import Path
html = Path(sys.argv[1]).read_text(encoding='latin-1', errors='ignore')
links = re.findall(r'href="((?:ai8|cs2)/[^"#?]+\.zip)"', html, flags=re.I)
# preserve order and dedupe
seen = set()
out = []
for link in links:
    norm = link.strip()
    if norm not in seen:
        seen.add(norm)
        out.append(norm)
for link in out:
    print(link)
PY

ZIP_LINKS=()
while IFS= read -r line; do
  [[ -n "$line" ]] && ZIP_LINKS+=("$line")
done < "$ZIP_LINKS_RAW"

if [[ ${#ZIP_LINKS[@]} -eq 0 ]]; then
  echo "No ai8/cs2 zip links found on $BASE_URL" >&2
  exit 1
fi

echo "Found ${#ZIP_LINKS[@]} zip archives"

for rel in "${ZIP_LINKS[@]}"; do
  url="${BASE_URL}${rel}"
  variant="${rel%%/*}"
  zip_name="$(basename "$rel")"
  zip_path="$DOWNLOAD_DIR/$zip_name"
  extract_dir="$WORK_DIR/extract-${zip_name%.zip}"

  echo "Downloading $url"
  curl -L -s "$url" -o "$zip_path"

  rm -rf "$extract_dir"
  mkdir -p "$extract_dir"
  unzip -oq "$zip_path" -d "$extract_dir"

  while IFS= read -r -d '' eps_file; do
    clean_name="$(basename "$eps_file")"
    # ignore AppleDouble sidecars and hidden files
    if [[ "$clean_name" == ._* ]]; then
      continue
    fi
    cp "$eps_file" "$TARGET_DIR/$variant/$clean_name"
  done < <(find "$extract_dir" -type f \( -iname '*.eps' -o -iname '*.EPS' \) -print0)
done

if [[ -x "$ROOT_DIR/scripts/render_usgs_eps_raster.sh" ]]; then
  "$ROOT_DIR/scripts/render_usgs_eps_raster.sh"
fi
if [[ -x "$ROOT_DIR/scripts/render_usgs_eps_pdf.sh" ]]; then
  "$ROOT_DIR/scripts/render_usgs_eps_pdf.sh"
fi

python3 - <<'PY' "$TARGET_DIR" "$BASE_URL" "$MANIFEST_PATH" "${ZIP_LINKS[@]}"
import json, re, sys, hashlib, datetime
from pathlib import Path

target_dir = Path(sys.argv[1])
base_url = sys.argv[2]
manifest_path = Path(sys.argv[3])
zip_links = sys.argv[4:]

section_to_archive = {}
for rel in zip_links:
    variant = rel.split('/', 1)[0].lower()
    zip_name = Path(rel).name
    section_match = re.search(r'(Sec\d+)', zip_name, re.IGNORECASE)
    section = section_match.group(1).lower() if section_match else "preface"
    section_to_archive[(variant, section)] = rel

records = []
for variant in ("ai8", "cs2"):
    variant_dir = target_dir / variant
    if not variant_dir.exists():
        continue
    for eps in sorted(variant_dir.glob('*.eps')):
        data = eps.read_bytes()
        sha = hashlib.sha256(data).hexdigest()
        section_guess = None
        sec_match = re.search(r'A-(\d{2})-', eps.name, re.IGNORECASE)
        if sec_match:
            section_guess = f"sec{int(sec_match.group(1)):02d}"
        archive_rel = section_to_archive.get((variant, section_guess or "preface"))
        records.append({
            "sourceURL": (base_url + archive_rel) if archive_rel else None,
            "section": section_guess.upper() if section_guess else None,
            "format": variant,
            "zipFile": Path(archive_rel).name if archive_rel else None,
            "epsFile": eps.name,
            "pngFile": f"raster/{variant}/{eps.stem}.png",
            "pdfFile": f"pdf/{variant}/{eps.stem}.pdf",
            "sha256": sha,
            "sizeBytes": len(data)
        })

manifest = {
    "sourcePage": base_url,
    "syncedAtUTC": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00', 'Z'),
    "archives": [
        {
            "url": base_url + rel,
            "format": rel.split('/', 1)[0].lower(),
            "zipFile": Path(rel).name,
            "section": (re.search(r'(Sec\d+)', Path(rel).name, re.IGNORECASE).group(1) if re.search(r'(Sec\d+)', Path(rel).name, re.IGNORECASE) else None)
        }
        for rel in zip_links
    ],
    "files": records
}

manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding='utf-8')
print(f"Wrote {manifest_path} with {len(records)} EPS records")
PY

echo "Sync complete."
