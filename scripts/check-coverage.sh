#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

threshold="${COVERAGE_THRESHOLD:-70}"

profdata="$(find .build -type f -name default.profdata | head -n 1)"
binary="$(find .build -type f -path '*EasyLogPackageTests.xctest/Contents/MacOS/EasyLogPackageTests' | head -n 1)"

if [[ -z "$profdata" || -z "$binary" ]]; then
  echo "[coverage] Missing coverage artifacts. Run: swift test --enable-code-coverage" >&2
  exit 1
fi

report="$(xcrun llvm-cov report "$binary" -instr-profile "$profdata")"

effective_line="$(
  echo "$report" | awk '
    BEGIN { lines=0; missed=0 }
    /^Sources\/EasyLogKit\// {
      path=$1
      # Scope chosen for this project: business/services/rendering/persistence/export.
      # SwiftUI view layers and AppKit file dialog bridge are intentionally excluded.
      if (path ~ /\/UI\//) next
      if (path ~ /MainContentView.swift$/) next
      if (path ~ /FileDialoging.swift$/) next
      lines += $8
      missed += $9
    }
    END {
      covered = lines - missed
      pct = (lines > 0) ? (covered / lines) * 100 : 0
      printf "%.2f %d %d", pct, covered, lines
    }
  '
)"

coverage_pct="$(echo "$effective_line" | awk '{print $1}')"
covered_lines="$(echo "$effective_line" | awk '{print $2}')"
total_lines="$(echo "$effective_line" | awk '{print $3}')"

echo "[coverage] Effective coverage (Sources/EasyLogKit non-UI scope): ${coverage_pct}% (${covered_lines}/${total_lines} lines)"
echo "[coverage] Required threshold: ${threshold}%"

if awk -v actual="$coverage_pct" -v min="$threshold" 'BEGIN { exit (actual + 0.0 >= min + 0.0) ? 0 : 1 }'; then
  echo "[coverage] threshold satisfied"
else
  echo "[coverage] threshold NOT met" >&2
  exit 1
fi
