#!/usr/bin/env python3
"""Build profile-specific USGS runtime catalogs.

The catalog is the runtime contract used by CakeKit to resolve symbol assets
without scanning authoring sources. It supports:
- release profile: all symbols available in symbol-index
- dev profile: deterministic subset for faster local iteration
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
USGS_BASE = ROOT / "Sources/CakeKit/Resources/USGS/11A02"
INDEX_PATH = USGS_BASE / "symbol-index.json"
OUT_BASE = ROOT / "Sources/CakeKit/Resources/USGSRuntime"
SYMBOLOGY_PATH = ROOT / "Sources/CakeKit/Features/Preview/Rendering/Symbology.swift"

DEV_SEED_CODES = [
    607, 609, 619, 627, 601, 602, 603, 605, 606,
    611, 615, 620, 621, 622, 625, 633, 634,
]
DEV_MIN_CODE_COUNT = 36


def parse_official_codes_and_aliases() -> tuple[set[int], dict[int, int]]:
    content = SYMBOLOGY_PATH.read_text(encoding="utf-8")
    symbol_re = re.compile(r'USGSLithologySymbol\(code:\s*(\d+),\s*label:\s*"([^"]+)"\)')
    alias_block_re = re.compile(r"usgsLithologyAliases:\s*\[Int:\s*Int\]\s*=\s*\[(.*?)\]", re.S)
    alias_pair_re = re.compile(r"(\d+)\s*:\s*(\d+)")

    official_codes = {int(code) for code, _ in symbol_re.findall(content)}
    aliases: dict[int, int] = {}
    alias_block = alias_block_re.search(content)
    if alias_block:
        for src, dst in alias_pair_re.findall(alias_block.group(1)):
            aliases[int(src)] = int(dst)
    return official_codes, aliases


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def normalize_id(code: int, variant: str, label: str) -> str:
    label_slug = "".join(ch.lower() if ch.isalnum() else "-" for ch in label).strip("-")
    while "--" in label_slug:
        label_slug = label_slug.replace("--", "-")
    return f"usgs-{code}-{variant}-{label_slug}"


def relative_source_path(p: Path) -> str:
    return p.relative_to(ROOT).as_posix().replace("Sources/CakeKit/Resources/", "")


def build_entry(code: int, label: str, variant: str, variant_entry: dict[str, Any]) -> dict[str, Any]:
    png_source_rel = variant_entry["pngFile"]
    pdf_source_rel = variant_entry["pdfFile"]
    eps_rel = variant_entry["epsFile"]

    prefix = "USGS/11A02/"
    if not png_source_rel.startswith(prefix) or not pdf_source_rel.startswith(prefix):
        raise ValueError("Unexpected source paths in symbol-index; expected USGS/11A02 prefix.")

    png_rel = png_source_rel[len(prefix):]
    pdf_rel = pdf_source_rel[len(prefix):]

    png_abs = ROOT / "Sources/CakeKit/Resources" / png_source_rel
    pdf_abs = ROOT / "Sources/CakeKit/Resources" / pdf_source_rel

    if not png_abs.exists() or not pdf_abs.exists():
        missing = []
        if not png_abs.exists():
            missing.append(str(png_abs))
        if not pdf_abs.exists():
            missing.append(str(pdf_abs))
        raise FileNotFoundError(f"Missing runtime asset(s): {', '.join(missing)}")

    entry_id = normalize_id(code=code, variant=variant, label=label)
    return {
        "id": entry_id,
        "code": code,
        "label": label,
        "variant": variant,
        "epsRelativePath": eps_rel,
        "pageSizePoints": variant_entry["pageSizePoints"],
        "symbolRect": variant_entry["symbolRect"],
        "png": {
            "path": png_rel,
            "sha256": sha256_file(png_abs),
            "bytes": png_abs.stat().st_size,
        },
        "pdf": {
            "path": pdf_rel,
            "sha256": sha256_file(pdf_abs),
            "bytes": pdf_abs.stat().st_size,
        },
    }


def selected_codes_for_dev(all_codes: list[int]) -> set[int]:
    selected = [code for code in DEV_SEED_CODES if code in all_codes]
    for code in all_codes:
        if len(selected) >= DEV_MIN_CODE_COUNT:
            break
        if code not in selected:
            selected.append(code)
    return set(selected)


def build_catalog(profile: str, entries: list[dict[str, Any]]) -> dict[str, Any]:
    all_codes = sorted({entry["code"] for entry in entries})
    if profile == "dev":
        allowed_codes = selected_codes_for_dev(all_codes)
        selected_entries = [entry for entry in entries if entry["code"] in allowed_codes]
    else:
        selected_entries = entries

    out_entries: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    for entry in selected_entries:
        label = entry["label"]
        # Prefer ai8 and include fallback variant when available.
        for variant in ("ai8", "cs2"):
            variant_entry = entry.get(variant)
            if not variant_entry:
                continue
            runtime_entry = build_entry(code=entry["code"], label=label, variant=variant, variant_entry=variant_entry)
            if runtime_entry["id"] in seen_ids:
                raise RuntimeError(f"Catalog id collision: {runtime_entry['id']}")
            seen_ids.add(runtime_entry["id"])
            out_entries.append(runtime_entry)

    out_entries.sort(key=lambda item: (item["code"], item["variant"]))

    return {
        "schemaVersion": 1,
        "profile": profile,
        "sourceIndex": relative_source_path(INDEX_PATH),
        "totalEntries": len(out_entries),
        "generatedBy": "scripts/build_usgs_resource_catalog.py",
        "entries": out_entries,
    }


def assert_catalog_consistency(profile: str, payload: dict[str, Any]) -> None:
    official_codes, aliases = parse_official_codes_and_aliases()
    runtime_codes = {entry["code"] for entry in payload["entries"]}

    if profile == "release":
        allowed_missing = set(aliases.keys())
        missing = official_codes - runtime_codes
        extra = runtime_codes - official_codes
        if missing != allowed_missing:
            raise RuntimeError(
                "Section 37 catalog mismatch: "
                f"missing={sorted(missing)} expected_allowed_missing={sorted(allowed_missing)}"
            )
        if extra:
            raise RuntimeError(f"Section 37 catalog mismatch: extra runtime codes={sorted(extra)}")
        for alias_source, alias_target in aliases.items():
            if alias_source not in official_codes:
                raise RuntimeError(f"Alias source code {alias_source} is not in official Section 37 list")
            if alias_target not in runtime_codes:
                raise RuntimeError(f"Alias target code {alias_target} is missing from runtime catalog")
    else:
        if not runtime_codes.issubset(official_codes):
            raise RuntimeError(
                f"Dev catalog must stay a subset of official Section 37 codes. extra={sorted(runtime_codes - official_codes)}"
            )


def write_catalog(profile: str, payload: dict[str, Any]) -> None:
    OUT_BASE.mkdir(parents=True, exist_ok=True)
    out_path = OUT_BASE / f"ResourceCatalog.{profile}.json"
    out_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {out_path} ({payload['totalEntries']} entries)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", choices=["dev", "release", "all"], default=os.environ.get("RESOURCE_PROFILE", "dev"))
    args = parser.parse_args()

    document = json.loads(INDEX_PATH.read_text(encoding="utf-8"))
    entries: list[dict[str, Any]] = document["entries"]

    profiles = ["dev", "release"] if args.profile == "all" else [args.profile]
    for profile in profiles:
        payload = build_catalog(profile=profile, entries=entries)
        assert_catalog_consistency(profile=profile, payload=payload)
        write_catalog(profile=profile, payload=payload)


if __name__ == "__main__":
    main()
