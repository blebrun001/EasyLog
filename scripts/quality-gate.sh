#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[quality] checking forbidden high-risk patterns"
if rg -n --glob '*.swift' 'fatalError\(|try!|as!' Sources Tests; then
  echo "[quality] forbidden patterns found" >&2
  exit 1
fi

echo "[quality] checking duplication"
./scripts/check-duplication.sh

echo "[quality] swift test"
swift test
