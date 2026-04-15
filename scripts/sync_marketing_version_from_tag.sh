#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_YML="$ROOT_DIR/project.yml"
PBXPROJ="$ROOT_DIR/EasyLog.xcodeproj/project.pbxproj"

if [[ ! -f "$PROJECT_YML" ]]; then
  echo "project.yml not found at $PROJECT_YML" >&2
  exit 1
fi
if [[ ! -f "$PBXPROJ" ]]; then
  echo "project.pbxproj not found at $PBXPROJ" >&2
  exit 1
fi

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  if ! TAG="$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null)"; then
    echo "No tag provided and no git tag found." >&2
    exit 1
  fi
fi

VERSION="${TAG#v}"
if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}([-.+][0-9A-Za-z.-]+)?$ ]]; then
  echo "Tag '$TAG' does not look like a supported version (expected vX.Y or vX.Y.Z)." >&2
  exit 1
fi

VERSION="$VERSION" perl -0777 -i -pe '
BEGIN { $v = $ENV{VERSION}; $changed = 0; }
if (s{(  EasyLogApp:\n(?:.*?\n)*?    settings:\n      base:\n)(.*?)(\n  [A-Za-z0-9_-]+:\n)}{
    my ($head, $base, $tail) = ($1, $2, $3);
    if ($base =~ s/^        MARKETING_VERSION:.*$/        MARKETING_VERSION: $v/m) {
      $changed = 1;
    } elsif ($base =~ s/(^        GENERATE_INFOPLIST_FILE:.*$\n)/$1        MARKETING_VERSION: $v\n/m) {
      $changed = 1;
    } else {
      $base = "        MARKETING_VERSION: $v\n" . $base;
      $changed = 1;
    }
    $head . $base . $tail;
}es) {
  # replaced
}
END {
  if (!$changed) {
    die "Could not locate EasyLogApp base settings to set MARKETING_VERSION.\n";
  }
}
' "$PROJECT_YML"

if ! rg -q "MARKETING_VERSION =" "$PBXPROJ"; then
  echo "No MARKETING_VERSION entries found in $PBXPROJ. Please add them once for Debug/Release app configs." >&2
  exit 1
fi

VERSION="$VERSION" perl -i -pe '
BEGIN { $v = $ENV{VERSION}; }
s/^(\s*MARKETING_VERSION = ).*;/${1}$v;/mg;
' "$PBXPROJ"

echo "Updated EasyLogApp MARKETING_VERSION to $VERSION in project.yml and project.pbxproj"
