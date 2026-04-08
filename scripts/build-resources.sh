#!/usr/bin/env bash
set -euo pipefail

# Generates runtime-ready USGS resource catalogs for dev/release profiles.
# Usage:
#   ./scripts/build-resources.sh                       # dev profile, section37 scope
#   ./scripts/build-resources.sh release               # release profile, section37 scope
#   ./scripts/build-resources.sh all                   # both profiles, section37 scope
#   ./scripts/build-resources.sh release all           # release profile, full catalog scope
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${1:-${RESOURCE_PROFILE:-dev}}"
SCOPE="${2:-${USGS_SCOPE:-section37}}"

case "$PROFILE" in
  dev|release|all)
    ;;
  *)
    echo "Invalid profile '$PROFILE'. Expected: dev | release | all" >&2
    exit 1
    ;;
esac

case "$SCOPE" in
  section37|all)
    ;;
  *)
    echo "Invalid scope '$SCOPE'. Expected: section37 | all" >&2
    exit 1
    ;;
esac

python3 "$ROOT_DIR/scripts/build_usgs_symbol_index.py"
python3 "$ROOT_DIR/scripts/build_usgs_resource_catalog.py" --profile "$PROFILE" --scope "$SCOPE"
python3 "$ROOT_DIR/scripts/build_usgs_section37_catalog.py"
