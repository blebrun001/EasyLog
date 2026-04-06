#!/usr/bin/env bash
set -euo pipefail

# Fails when newly added large files are not tracked by Git LFS.
# Threshold defaults to 5 MiB.
THRESHOLD_BYTES="${LARGE_FILE_THRESHOLD_BYTES:-5242880}"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not a git repository." >&2
  exit 1
fi

base_ref="${1:-origin/main}"
if git rev-parse --verify "$base_ref" >/dev/null 2>&1; then
  diff_cmd=(git diff --name-only --diff-filter=A "$base_ref...HEAD")
else
  diff_cmd=(git diff --cached --name-only --diff-filter=A)
fi

added_files=()
while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  added_files+=("$file")
done < <("${diff_cmd[@]}")

if [[ ${#added_files[@]} -eq 0 ]]; then
  exit 0
fi

failures=0
for file in "${added_files[@]}"; do
  [[ -f "$file" ]] || continue
  size=$(stat -f "%z" "$file")
  if [[ "$size" -le "$THRESHOLD_BYTES" ]]; then
    continue
  fi

  lfs_attr=$(git check-attr filter -- "$file" | awk -F': ' '{print $3}')
  if [[ "$lfs_attr" != "lfs" ]]; then
    mib=$(( size / 1024 / 1024 ))
    echo "Large file not under LFS: $file (${mib} MiB)" >&2
    failures=$((failures + 1))
  fi
done

if [[ "$failures" -gt 0 ]]; then
  echo "Detected $failures large file(s) outside Git LFS patterns." >&2
  echo "Update .gitattributes or move files to LFS before pushing." >&2
  exit 1
fi
