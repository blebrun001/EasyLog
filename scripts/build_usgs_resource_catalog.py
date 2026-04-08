#!/usr/bin/env python3
"""Build a unified runtime USGS 11A02 symbol catalog (PDF-only).

Outputs:
- Sources/CakeKit/Resources/USGSRuntime/ResourceCatalog.<profile>.json
- Sources/CakeKit/Resources/isolated/*.pdf (one cropped symbol per PDF)
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
USGS_BASE = ROOT / "Sources/CakeKit/Resources/USGS/11A02"
INDEX_PATH = USGS_BASE / "symbol-index.json"
OUT_BASE = ROOT / "Sources/CakeKit/Resources/USGSRuntime"
ISOLATED_BASE = ROOT / "Sources/CakeKit/Resources/isolated"
SYMBOLOGY_PATH = ROOT / "Sources/CakeKit/Features/Preview/Rendering/Symbology.swift"
SWIFT_CROP_SOURCE = ROOT / "scripts/crop_pdf_symbol.swift"
SWIFT_CROP_BINARY = ROOT / ".cache/usgs_11a02/bin/crop_pdf_symbol"

DEV_MIN_ENTRY_COUNT = 120


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


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


def relative_source_path(path: Path) -> str:
    return path.relative_to(ROOT).as_posix().replace("Sources/CakeKit/Resources/", "")


def build_entries_from_index() -> list[dict[str, Any]]:
    if not INDEX_PATH.exists():
        raise FileNotFoundError(f"Missing symbol index: {INDEX_PATH}")

    index = json.loads(INDEX_PATH.read_text(encoding="utf-8"))
    entries: list[dict[str, Any]] = []
    pdf_meta_cache: dict[Path, tuple[str, int]] = {}

    for item in index["entries"]:
        symbol_id = item["symbolId"]
        code = item.get("code")
        label = item.get("label") or item.get("symbolTag") or symbol_id
        section = item.get("section", "Unknown")
        source_file = item.get("sourceFileNameUSGS", "unknown.pdf")

        variant_entry = item.get("ai8") or item.get("cs2")
        if not variant_entry:
            continue
        variant = "ai8" if item.get("ai8") else "cs2"

        pdf_abs = ROOT / "Sources/CakeKit/Resources" / variant_entry["pdfFile"]
        if not pdf_abs.exists():
            continue
        cached = pdf_meta_cache.get(pdf_abs)
        if cached is None:
            cached = (sha256_file(pdf_abs), pdf_abs.stat().st_size)
            pdf_meta_cache[pdf_abs] = cached
        pdf_sha, pdf_bytes = cached

        entries.append(
            {
                "id": f"usgs-{symbol_id}-{variant}".replace("#", "-"),
                "symbolId": symbol_id,
                "code": code,
                "label": label,
                "section": section,
                "sourceFileNameUSGS": source_file,
                "variant": variant,
                "epsRelativePath": variant_entry["epsFile"],
                "pageSizePoints": variant_entry["pageSizePoints"],
                "symbolRect": variant_entry["symbolRect"],
                "pdf": {
                    "path": f"pdf/{variant}/{Path(variant_entry['pdfFile']).name}",
                    "sha256": pdf_sha,
                    "bytes": pdf_bytes,
                },
            }
        )

    entries.sort(key=lambda item: (item["section"], item["symbolId"], item["variant"]))
    return entries


def select_dev_entries(entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    section37 = [entry for entry in entries if entry["section"] == "Sec37"]
    by_section: dict[str, list[dict[str, Any]]] = {}
    for entry in entries:
        by_section.setdefault(entry["section"], []).append(entry)

    selected = list(section37)
    seen = {entry["id"] for entry in selected}

    for section in sorted(by_section):
        for entry in by_section[section][:4]:
            if entry["id"] not in seen:
                selected.append(entry)
                seen.add(entry["id"])
        if len(selected) >= DEV_MIN_ENTRY_COUNT:
            break

    if len(selected) < DEV_MIN_ENTRY_COUNT:
        for entry in entries:
            if entry["id"] in seen:
                continue
            selected.append(entry)
            seen.add(entry["id"])
            if len(selected) >= DEV_MIN_ENTRY_COUNT:
                break

    selected.sort(key=lambda item: (item["section"], item["symbolId"], item["variant"]))
    return selected


def select_section37_entries(entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    official_codes, aliases = parse_official_codes_and_aliases()
    render_codes = {aliases.get(code, code) for code in official_codes}
    section37 = [
        entry for entry in entries
        if entry.get("section") == "Sec37" and isinstance(entry.get("code"), int) and int(entry["code"]) in render_codes
    ]
    by_code: dict[int, list[dict[str, Any]]] = {}
    for entry in section37:
        code = int(entry["code"])
        by_code.setdefault(code, []).append(entry)

    selected: list[dict[str, Any]] = []
    for code in sorted(by_code):
        candidates = by_code[code]
        ai8 = next((candidate for candidate in candidates if candidate.get("variant") == "ai8"), None)
        selected.append(ai8 or candidates[0])
    return selected


def assert_release_consistency(entries: list[dict[str, Any]]) -> None:
    official_codes, aliases = parse_official_codes_and_aliases()
    code_entries = {int(entry["code"]) for entry in entries if entry["code"] is not None}
    allowed_missing = set(aliases.keys())
    missing = official_codes - code_entries
    extra = code_entries - official_codes
    if missing != allowed_missing:
        raise RuntimeError(
            "Section 37 coverage mismatch in unified catalog: "
            f"missing={sorted(missing)} expected_allowed_missing={sorted(allowed_missing)}"
        )
    if extra:
        raise RuntimeError(f"Section 37 coverage mismatch in unified catalog: extra={sorted(extra)}")
    for src, dst in aliases.items():
        if dst not in code_entries:
            raise RuntimeError(f"Alias target {dst} missing in unified catalog")


def ensure_crop_binary() -> Path:
    SWIFT_CROP_BINARY.parent.mkdir(parents=True, exist_ok=True)
    needs_rebuild = (
        not SWIFT_CROP_BINARY.exists()
        or SWIFT_CROP_BINARY.stat().st_mtime < SWIFT_CROP_SOURCE.stat().st_mtime
    )
    if needs_rebuild:
        subprocess.run(
            ["swiftc", str(SWIFT_CROP_SOURCE), "-o", str(SWIFT_CROP_BINARY)],
            check=True,
        )
    return SWIFT_CROP_BINARY


def canonical_isolated_name(source_file: str, symbol_id: str, taken: set[str]) -> str:
    stem = Path(source_file).stem
    suffix = Path(source_file).suffix or ".pdf"
    safe_symbol = symbol_id.replace("#", "__").replace("/", "-").replace(":", "-")
    candidate = f"{stem}__{safe_symbol}{suffix}"
    if candidate not in taken:
        taken.add(candidate)
        return candidate
    index = 2
    while True:
        candidate = f"{stem}__{safe_symbol}-{index}{suffix}"
        if candidate not in taken:
            taken.add(candidate)
            return candidate
        index += 1


def strip_text_from_pdf(input_pdf: Path, output_pdf: Path) -> bool:
    try:
        subprocess.run(
            [
                "gs",
                "-q",
                "-dBATCH",
                "-dNOPAUSE",
                "-sDEVICE=pdfwrite",
                "-dCompatibilityLevel=1.6",
                "-dFILTERTEXT",
                f"-sOutputFile={output_pdf}",
                str(input_pdf),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return output_pdf.exists() and output_pdf.stat().st_size > 0
    except Exception:
        return False


def has_vector_geometry(pdf_path: Path) -> bool:
    with tempfile.TemporaryDirectory() as tmpdir:
        svg_path = Path(tmpdir) / "preview.svg"
        try:
            subprocess.run(
                [
                    "pdftocairo",
                    "-svg",
                    str(pdf_path),
                    str(svg_path),
                ],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception:
            return False
        if not svg_path.exists():
            return False
        svg = svg_path.read_text(encoding="utf-8", errors="ignore")
        geometry_markers = ("<path", "<line", "<polyline", "<polygon", "<circle", "<ellipse")
        return any(marker in svg for marker in geometry_markers)


def is_viable_symbol_pdf(pdf_path: Path) -> bool:
    # After text stripping, keep only PDFs that still carry vector geometry.
    return has_vector_geometry(pdf_path)


def materialize_isolated_pdfs(entries: list[dict[str, Any]]) -> dict[str, str]:
    ISOLATED_BASE.mkdir(parents=True, exist_ok=True)
    for existing in ISOLATED_BASE.glob("*.pdf"):
        existing.unlink()

    crop_bin = ensure_crop_binary()
    isolated_map: dict[str, str] = {}
    taken_names: set[str] = set()
    for entry in entries:
        symbol_id = entry["symbolId"]
        if symbol_id in isolated_map:
            continue

        source_rel = entry["pdf"]["path"]
        source_abs = USGS_BASE / source_rel
        if not source_abs.exists():
            continue

        # Keep the original source PDF for crop extraction.
        # Text filtering via Ghostscript can drop symbol geometry on some files.
        textless_source = source_abs

        rect = entry["symbolRect"]
        page = entry["pageSizePoints"]
        isolated_name = canonical_isolated_name(entry["sourceFileNameUSGS"], symbol_id, taken_names)
        isolated_abs = ISOLATED_BASE / isolated_name
        subprocess.run(
            [
                str(crop_bin),
                str(textless_source),
                str(isolated_abs),
                str(rect["x"]),
                str(rect["y"]),
                str(rect["width"]),
                str(rect["height"]),
                str(page["width"]),
                str(page["height"]),
            ],
            check=True,
        )
        if not is_viable_symbol_pdf(isolated_abs):
            isolated_abs.unlink(missing_ok=True)
            continue
        isolated_map[symbol_id] = f"isolated/{isolated_name}"

    return isolated_map


def build_catalog(profile: str, scope: str, entries: list[dict[str, Any]]) -> dict[str, Any]:
    if scope == "section37":
        selected_entries = select_section37_entries(entries)
        isolated_source_entries = selected_entries
    elif profile == "dev":
        selected_entries = select_dev_entries(entries)
        isolated_source_entries = entries
    else:
        selected_entries = entries
        isolated_source_entries = entries

    isolated_map = materialize_isolated_pdfs(isolated_source_entries)

    output_entries: list[dict[str, Any]] = []
    for entry in selected_entries:
        isolated_path = isolated_map.get(entry["symbolId"])
        if not isolated_path:
            continue
        copied = dict(entry)
        copied["isolatedPdfPath"] = isolated_path
        output_entries.append(copied)

    return {
        "schemaVersion": 2,
        "profile": profile,
        "scope": scope,
        "sourceIndex": relative_source_path(INDEX_PATH),
        "totalEntries": len(output_entries),
        "generatedBy": "scripts/build_usgs_resource_catalog.py",
        "entries": output_entries,
    }


def write_catalog(profile: str, payload: dict[str, Any]) -> None:
    OUT_BASE.mkdir(parents=True, exist_ok=True)
    out_path = OUT_BASE / f"ResourceCatalog.{profile}.json"
    out_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {out_path} ({payload['totalEntries']} entries)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", choices=["dev", "release", "all"], default=os.environ.get("RESOURCE_PROFILE", "dev"))
    parser.add_argument(
        "--scope",
        choices=["section37", "all"],
        default=os.environ.get("USGS_SCOPE", "section37"),
        help="Catalog scope: section37 (stable production target) or all (full USGS catalog pass).",
    )
    args = parser.parse_args()

    entries = build_entries_from_index()
    profiles = ["dev", "release"] if args.profile == "all" else [args.profile]
    for profile in profiles:
        payload = build_catalog(profile=profile, scope=args.scope, entries=entries)
        if profile == "release":
            assert_release_consistency(payload["entries"])
        write_catalog(profile=profile, payload=payload)


if __name__ == "__main__":
    main()
