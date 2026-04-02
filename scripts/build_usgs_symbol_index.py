#!/usr/bin/env python3
import json
import re
from pathlib import Path

# Parses EPS files and emits `symbol-index.json` used at runtime to map
# USGS code -> asset paths + artboard/symbol rectangle metadata.
ROOT = Path(__file__).resolve().parent.parent
BASE = ROOT / "Sources/CakeKit/Resources/USGS/11A02"
OUT = BASE / "symbol-index.json"

CODE_LABEL_RE = re.compile(r"\((\d{3})\\r\) Tj")
LABEL_PART_RE = re.compile(r"\((.*?)\) Tj", re.S)
SYMBOL_TAG_RE = re.compile(r"\((\d{3})\) 0 0 1 1 0 0 0 0 0 \[[^\]]+\] p")
FLOAT_RE = re.compile(r"(-?\d+(?:\.\d+)?)")
ART_SIZE_RE = re.compile(r"%AI5_ArtSize:\s*([0-9.]+)\s+([0-9.]+)")


def clean_label(text: str) -> str:
    return " ".join(
        text.replace("\\003", " ")
            .replace("\\(", "(")
            .replace("\\)", ")")
            .replace("\r", " ")
            .replace("\n", " ")
            .replace("\t", " ")
            .replace("- ", "")
            .split()
    )


def parse_code_labels(content: str) -> dict[int, str]:
    out: dict[int, str] = {}
    i = 0
    while True:
        m = CODE_LABEL_RE.search(content, i)
        if not m:
            break
        code = int(m.group(1))
        start = m.end()
        stop_match = re.search(r"\(\\r\) TX", content[start:])
        if not stop_match:
            i = start
            continue
        block = content[start : start + stop_match.start()]
        parts = []
        for pm in LABEL_PART_RE.finditer(block):
            chunk = clean_label(pm.group(1))
            if chunk and not chunk.isdigit():
                parts.append(chunk)
        label = " ".join(parts).strip()
        if label and code not in out:
            out[code] = label
        i = start + stop_match.end()
    return out


def parse_symbol_rects(content: str) -> dict[int, dict]:
    rects: dict[int, dict] = {}
    for m in SYMBOL_TAG_RE.finditer(content):
        code = int(m.group(1))
        # inspect nearby path statements to infer symbol bounding rect
        tail = content[m.end() : m.end() + 380]
        lines = [ln.strip() for ln in tail.splitlines() if ln.strip()]
        points = []
        for ln in lines[:12]:
            if ln.endswith((" m", " L", " l", " c", " v", " y")):
                nums = FLOAT_RE.findall(ln)
                if len(nums) >= 2:
                    x = float(nums[0])
                    y = float(nums[1])
                    points.append((x, y))
            if ln == "b":
                break
        if len(points) >= 3:
            xs = [p[0] for p in points]
            ys = [p[1] for p in points]
            min_x, max_x = min(xs), max(xs)
            min_y, max_y = min(ys), max(ys)
            rects[code] = {
                "x": round(min_x, 4),
                "y": round(min_y, 4),
                "width": round(max_x - min_x, 4),
                "height": round(max_y - min_y, 4),
            }
    return rects


def parse_page_size_points(content: str) -> tuple[float, float]:
    m = ART_SIZE_RE.search(content)
    if m:
        return float(m.group(1)), float(m.group(2))
    return 612.0, 792.0


def collect_variant(variant: str) -> dict[int, dict]:
    variant_dir = BASE / variant
    by_code: dict[int, dict] = {}
    for eps in sorted(variant_dir.glob("*.eps")):
        txt = eps.read_text(encoding="latin-1", errors="ignore")
        labels = parse_code_labels(txt)
        rects = parse_symbol_rects(txt)
        page_w, page_h = parse_page_size_points(txt)
        for code, label in labels.items():
            rect = rects.get(code)
            if rect is None:
                continue
            if code not in by_code:
                by_code[code] = {
                    "code": code,
                    "label": label,
                    "epsFile": f"USGS/11A02/{variant}/{eps.name}",
                    "pngFile": f"USGS/11A02/raster/{variant}/{eps.stem}.png",
                    "pdfFile": f"USGS/11A02/pdf/{variant}/{eps.stem}.pdf",
                    "pageSizePoints": {"width": page_w, "height": page_h},
                    "symbolRect": rect,
                    "variant": variant,
                }
    return by_code


def main() -> None:
    ai8_map = collect_variant("ai8")
    cs2_map = collect_variant("cs2")
    all_codes = sorted(set(ai8_map.keys()) | set(cs2_map.keys()))

    entries = []
    for code in all_codes:
        preferred = ai8_map.get(code)
        fallback = cs2_map.get(code)
        if preferred is None and fallback is None:
            continue
        chosen = preferred or fallback
        entries.append(
            {
                "code": code,
                "label": chosen["label"],
                "preferredVariant": "ai8",
                "fallbackVariant": "cs2",
                "epsFile": chosen["epsFile"],
                "symbolRect": chosen["symbolRect"],
                "ai8": ai8_map.get(code),
                "cs2": cs2_map.get(code),
            }
        )

    payload = {
        "source": "https://pubs.usgs.gov/tm/2006/11A02/",
        "totalSymbols": len(entries),
        "entries": entries,
    }
    OUT.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} with {len(entries)} entries")


if __name__ == "__main__":
    main()
