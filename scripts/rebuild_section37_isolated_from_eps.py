#!/usr/bin/env python3
"""Rebuild Section 37 isolated PDFs from native EPS-derived symbol rectangles.

Source of truth:
- Sources/EasyLogKit/Resources/USGSRuntime/ResourceCatalog.release.json
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG_PATH = ROOT / "Sources/EasyLogKit/Resources/USGSRuntime/ResourceCatalog.release.json"
RESOURCES = ROOT / "Sources/EasyLogKit/Resources"
CROP_SWIFT = ROOT / "scripts/crop_pdf_symbol.swift"
CROP_BIN = ROOT / ".cache/usgs_11a02/bin/crop_pdf_symbol"


def ensure_crop_binary() -> Path:
    CROP_BIN.parent.mkdir(parents=True, exist_ok=True)
    if (not CROP_BIN.exists()) or (CROP_BIN.stat().st_mtime < CROP_SWIFT.stat().st_mtime):
        subprocess.run(["swiftc", str(CROP_SWIFT), "-o", str(CROP_BIN)], check=True)
    return CROP_BIN


def main() -> None:
    crop_bin = ensure_crop_binary()
    doc = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    entries = doc.get("entries", [])

    rebuilt = 0
    missing = 0
    for entry in entries:
        code = entry.get("code")
        if not isinstance(code, int) or code < 601 or code > 733:
            continue
        isolated_rel = entry.get("isolatedPdfPath")
        if not isinstance(isolated_rel, str) or not isolated_rel:
            continue

        source_pdf = RESOURCES / "USGS/11A02" / entry["pdf"]["path"]
        output_pdf = RESOURCES / isolated_rel
        if not source_pdf.exists():
            missing += 1
            continue

        rect = entry["symbolRect"]
        page = entry["pageSizePoints"]
        output_pdf.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            [
                str(crop_bin),
                str(source_pdf),
                str(output_pdf),
                str(rect["x"]),
                str(rect["y"]),
                str(rect["width"]),
                str(rect["height"]),
                str(page["width"]),
                str(page["height"]),
            ],
            check=True,
        )
        rebuilt += 1

    print(f"Rebuilt Section 37 isolated PDFs: {rebuilt}")
    print(f"Missing source PDFs: {missing}")


if __name__ == "__main__":
    main()
