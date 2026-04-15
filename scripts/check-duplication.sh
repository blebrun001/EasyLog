#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from pathlib import Path
from collections import defaultdict
import os

MIN_LINES = 20
MAX_REPORT = 10
STRICT = os.environ.get("DUPLICATION_STRICT", "0") == "1"

files = [p for p in Path('Sources').rglob('*.swift')] + [p for p in Path('Tests').rglob('*.swift')]

def normalize(line: str) -> str:
    line = line.strip()
    if not line:
        return ''
    if line.startswith('//'):
        return ''
    return ' '.join(line.split())

blocks = defaultdict(set)
for path in files:
    raw = path.read_text(encoding='utf-8').splitlines()
    lines = [normalize(l) for l in raw]
    lines = [l for l in lines if l]
    for i in range(len(lines) - MIN_LINES + 1):
        block = '\n'.join(lines[i:i+MIN_LINES])
        blocks[block].add(str(path))

dups = [(b, sorted(list(paths))) for b, paths in blocks.items() if len(paths) > 1]
if not dups:
    print('[dup] no large duplicated blocks found')
    raise SystemExit(0)

print('[dup] duplicated >=20-line normalized blocks detected:')
for idx, (_, paths) in enumerate(sorted(dups, key=lambda x: len(x[1]), reverse=True)[:MAX_REPORT], 1):
    print(f'  {idx}. shared by {len(paths)} files: {", ".join(paths[:4])}')

if STRICT:
    raise SystemExit(1)
print('[dup] warning only (set DUPLICATION_STRICT=1 to fail)')
raise SystemExit(0)
PY
