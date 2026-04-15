#!/usr/bin/env bash
set -euo pipefail

# Configure sparse-checkout presets for contributors.
# Usage:
#   ./scripts/setup-sparse-checkout.sh light
#   ./scripts/setup-sparse-checkout.sh full

MODE="${1:-light}"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not a git repository." >&2
  exit 1
fi

git sparse-checkout init --cone

case "$MODE" in
  light)
    git sparse-checkout set \
      .github \
      Sources/EasyLogApp \
      Sources/EasyLogKit/App \
      Sources/EasyLogKit/Core \
      Sources/EasyLogKit/Features \
      Sources/EasyLogKit/Infrastructure \
      Sources/EasyLogKit/Resources/USGSRuntime \
      Tests \
      scripts \
      Package.swift \
      README.md \
      project.yml
    ;;
  full)
    git sparse-checkout disable
    ;;
  *)
    echo "Invalid mode '$MODE'. Expected: light | full" >&2
    exit 1
    ;;
esac

echo "Sparse-checkout configured: $MODE"
