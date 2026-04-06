#!/usr/bin/env python3
"""Build canonical FGDC Section 37 catalog for runtime/UI.

Output:
- Sources/CakeKit/Resources/USGSRuntime/Section37Catalog.json
"""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SYMBOLOGY_PATH = ROOT / "Sources/CakeKit/Features/Preview/Rendering/Symbology.swift"
INDEX_PATH = ROOT / "Sources/CakeKit/Resources/USGS/11A02/symbol-index.json"
OUT_PATH = ROOT / "Sources/CakeKit/Resources/USGSRuntime/Section37Catalog.json"


def parse_official_symbols_and_aliases() -> tuple[list[dict[str, object]], dict[int, int]]:
    content = SYMBOLOGY_PATH.read_text(encoding="utf-8")

    symbol_re = re.compile(r'USGSLithologySymbol\(code:\s*(\d+),\s*label:\s*"([^"]+)"\)')
    alias_block_re = re.compile(r"usgsLithologyAliases:\s*\[Int:\s*Int\]\s*=\s*\[(.*?)\]", re.S)
    alias_pair_re = re.compile(r"(\d+)\s*:\s*(\d+)")

    symbols = [{"code": int(code), "label": label} for code, label in symbol_re.findall(content)]
    if not symbols:
        raise RuntimeError(f"No USGSLithologySymbol entries found in {SYMBOLOGY_PATH}")

    aliases: dict[int, int] = {}
    alias_block = alias_block_re.search(content)
    if alias_block:
        for src, dst in alias_pair_re.findall(alias_block.group(1)):
            aliases[int(src)] = int(dst)

    return symbols, aliases


def main() -> None:
    symbols, aliases = parse_official_symbols_and_aliases()
    index = json.loads(INDEX_PATH.read_text(encoding="utf-8"))
    available_codes = {int(entry["code"]) for entry in index["entries"] if entry.get("code") is not None}

    entries = []
    for item in symbols:
        code = int(item["code"])
        render_code = aliases.get(code, code)
        entries.append(
            {
                "code": code,
                "label": item["label"],
                "renderCode": render_code,
                "hasDirectAsset": code in available_codes,
            }
        )

    payload = {
        "schemaVersion": 1,
        "source": "FGDC Section 37 Lithologic Patterns",
        "officialCount": len(entries),
        "availableAssetCount": len(available_codes),
        "aliases": aliases,
        "entries": entries,
    }

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUT_PATH} ({len(entries)} entries)")


if __name__ == "__main__":
    main()
