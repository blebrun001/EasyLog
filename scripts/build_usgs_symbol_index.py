#!/usr/bin/env python3
import json
import re
import subprocess
from pathlib import Path

# Parses EPS files and emits `symbol-index.json` used at runtime to map
# USGS symbol-id -> asset paths + artboard/symbol rectangle metadata.
ROOT = Path(__file__).resolve().parent.parent
BASE = ROOT / "Sources/CakeKit/Resources/USGS/11A02"
OUT = BASE / "symbol-index.json"

CODE_LABEL_RE = re.compile(r"\((\d{3})\\r\) Tj")
LABEL_PART_RE = re.compile(r"\((.*?)\) Tj", re.S)
SYMBOL_TAG_RE = re.compile(r"\(([^)]+)\)\s+0 0 1 1 0 0 0 0 0 \[[^\]]+\] p")
FLOAT_RE = re.compile(r"(-?\d+(?:\.\d+)?)")
ART_SIZE_RE = re.compile(r"%AI5_ArtSize:\s*([0-9.]+)\s+([0-9.]+)")
SECTION_RE = re.compile(r"A-(\d{2})-(\d{2})", re.IGNORECASE)
BLOCK_RE = re.compile(
    r'<block xMin="([0-9.]+)" yMin="([0-9.]+)" xMax="([0-9.]+)" yMax="([0-9.]+)">(.*?)</block>',
    re.S,
)
WORD_RE = re.compile(r"<word [^>]*>(.*?)</word>", re.S)


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


def normalize_symbol_tag(tag: str) -> str:
    out = []
    for ch in tag.strip():
        if ch.isalnum():
            out.append(ch.lower())
        else:
            out.append("-")
    normalized = "".join(out).strip("-")
    while "--" in normalized:
        normalized = normalized.replace("--", "-")
    return normalized or "symbol"


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


def parse_symbol_rects(content: str) -> dict[str, dict]:
    rects: dict[str, dict] = {}
    for m in SYMBOL_TAG_RE.finditer(content):
        tag = m.group(1).strip()
        # inspect nearby path statements to infer symbol bounding rect
        tail = content[m.end() : m.end() + 600]
        lines = [ln.strip() for ln in tail.splitlines() if ln.strip()]
        points = []
        for ln in lines[:20]:
            if ln.endswith((" m", " L", " l", " c", " v", " y")):
                nums = FLOAT_RE.findall(ln)
                if len(nums) >= 2:
                    x = float(nums[0])
                    y = float(nums[1])
                    points.append((x, y))
            if ln in {"b", "B", "s", "S", "f", "F"} and len(points) >= 3:
                break
        if len(points) >= 3:
            xs = [p[0] for p in points]
            ys = [p[1] for p in points]
            min_x, max_x = min(xs), max(xs)
            min_y, max_y = min(ys), max(ys)
            rects[tag] = {
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


def infer_section(file_name: str) -> str:
    m = SECTION_RE.search(file_name)
    if m:
        return f"Sec{int(m.group(1)):02d}"
    return "Preface"


def fallback_symbol_rows_from_pdf(pdf_path: Path, page_width: float, page_height: float) -> list[dict]:
    if not pdf_path.exists():
        return []
    try:
        out = subprocess.run(
            ["pdftotext", "-bbox-layout", str(pdf_path), "-"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
    except Exception:
        return []

    rows = []
    for m in BLOCK_RE.finditer(out):
        x_min = float(m.group(1))
        y_min_top = float(m.group(2))
        x_max = float(m.group(3))
        y_max_top = float(m.group(4))
        body = m.group(5)
        words = [w.strip() for w in WORD_RE.findall(body) if w.strip()]
        text = " ".join(words).strip()
        if not text:
            continue
        # Heuristic: description column blocks live near left side and contain rich text.
        if not (70 <= x_min <= 120):
            continue
        if len(text) < 18:
            continue
        if text.lower().startswith(("symbols may", "use when", "usually reserved")):
            continue

        block_h = max(y_max_top - y_min_top, 6)
        # Convert from top-based PDF text coordinates to bottom-based user-space coordinates.
        y_bottom = max(page_height - y_max_top - 1.5, 0.0)
        rows.append(
            {
                "label": text[:160],
                "symbolRect": {
                    "x": 274.0,
                    "y": round(y_bottom, 4),
                    "width": 78.0,
                    "height": round(block_h + 2.5, 4),
                },
            }
        )

    # Deduplicate by close y position.
    deduped = []
    seen_keys = set()
    for row in sorted(rows, key=lambda r: r["symbolRect"]["y"]):
        key = int(round(row["symbolRect"]["y"] * 2))
        if key in seen_keys:
            continue
        seen_keys.add(key)
        deduped.append(row)
    return deduped


def collect_variant(variant: str) -> dict[str, dict]:
    variant_dir = BASE / variant
    by_symbol_id: dict[str, dict] = {}
    for eps in sorted(variant_dir.glob("*.eps")):
        txt = eps.read_text(encoding="latin-1", errors="ignore")
        labels = parse_code_labels(txt)
        rects = parse_symbol_rects(txt)
        page_w, page_h = parse_page_size_points(txt)
        section = infer_section(eps.name)
        pdf_path = BASE / "pdf" / variant / f"{eps.stem}.pdf"

        for tag, rect in rects.items():
            try:
                code = int(tag)
            except ValueError:
                code = None
            label = labels.get(code, tag) if code is not None else tag
            symbol_id = f"{eps.stem}#{normalize_symbol_tag(tag)}"
            if symbol_id in by_symbol_id:
                continue
            by_symbol_id[symbol_id] = {
                "symbolId": symbol_id,
                "symbolTag": tag,
                "code": code,
                "label": label,
                "section": section,
                "sourceFileNameUSGS": f"{eps.stem}.pdf",
                "epsFile": f"USGS/11A02/{variant}/{eps.name}",
                "pngFile": f"USGS/11A02/raster/{variant}/{eps.stem}.png",
                "pdfFile": f"USGS/11A02/pdf/{variant}/{eps.stem}.pdf",
                "pageSizePoints": {"width": page_w, "height": page_h},
                "symbolRect": rect,
                "variant": variant,
            }

        if not rects:
            fallback_rows = fallback_symbol_rows_from_pdf(pdf_path=pdf_path, page_width=page_w, page_height=page_h)
            for idx, row in enumerate(fallback_rows, start=1):
                symbol_id = f"{eps.stem}#row-{idx:03d}"
                if symbol_id in by_symbol_id:
                    continue
                by_symbol_id[symbol_id] = {
                    "symbolId": symbol_id,
                    "symbolTag": f"row-{idx:03d}",
                    "code": None,
                    "label": row["label"],
                    "section": section,
                    "sourceFileNameUSGS": f"{eps.stem}.pdf",
                    "epsFile": f"USGS/11A02/{variant}/{eps.name}",
                    "pngFile": f"USGS/11A02/raster/{variant}/{eps.stem}.png",
                    "pdfFile": f"USGS/11A02/pdf/{variant}/{eps.stem}.pdf",
                    "pageSizePoints": {"width": page_w, "height": page_h},
                    "symbolRect": row["symbolRect"],
                    "variant": variant,
                }
    return by_symbol_id


def main() -> None:
    ai8_map = collect_variant("ai8")
    cs2_map = collect_variant("cs2")
    all_symbol_ids = sorted(set(ai8_map.keys()) | set(cs2_map.keys()))

    entries = []
    for symbol_id in all_symbol_ids:
        preferred = ai8_map.get(symbol_id)
        fallback = cs2_map.get(symbol_id)
        if preferred is None and fallback is None:
            continue
        chosen = preferred or fallback
        entries.append(
            {
                "symbolId": symbol_id,
                "symbolTag": chosen["symbolTag"],
                "code": chosen["code"],
                "label": chosen["label"],
                "section": chosen["section"],
                "sourceFileNameUSGS": chosen["sourceFileNameUSGS"],
                "preferredVariant": "ai8",
                "fallbackVariant": "cs2",
                "ai8": ai8_map.get(symbol_id),
                "cs2": cs2_map.get(symbol_id),
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
