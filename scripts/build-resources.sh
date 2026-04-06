#!/usr/bin/env bash
set -euo pipefail

# Generates runtime-ready USGS resource catalogs for dev/release profiles.
# Usage:
#   ./scripts/build-resources.sh            # dev profile
#   ./scripts/build-resources.sh release    # release profile
#   ./scripts/build-resources.sh all        # both
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${1:-${RESOURCE_PROFILE:-dev}}"

case "$PROFILE" in
  dev|release|all)
    ;;
  *)
    echo "Invalid profile '$PROFILE'. Expected: dev | release | all" >&2
    exit 1
    ;;
esac

python3 "$ROOT_DIR/scripts/build_usgs_resource_catalog.py" --profile "$PROFILE"
