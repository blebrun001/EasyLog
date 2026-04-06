#!/usr/bin/env bash
set -euo pipefail

# Removes accidental duplicate local refs like "main 2" created by Finder copies.
# Non-destructive by default: pass --apply to delete duplicates.
APPLY="${1:-}" 

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not a git repository." >&2
  exit 1
fi

git_dir="$(git rev-parse --git-dir)"
dup_refs=()
while IFS= read -r ref; do
  [[ -z "$ref" ]] && continue
  dup_refs+=("$ref")
done < <(find "$git_dir/refs" -type f -name '* 2' -print)

if [[ ${#dup_refs[@]} -eq 0 ]]; then
  echo "No duplicate refs detected."
  exit 0
fi

echo "Duplicate refs:"
printf ' - %s\n' "${dup_refs[@]}"

if [[ "$APPLY" != "--apply" ]]; then
  echo "Dry-run only. Re-run with --apply to remove these duplicate ref files."
  exit 0
fi

for ref in "${dup_refs[@]}"; do
  rm -f "$ref"
done

echo "Duplicate refs removed."
