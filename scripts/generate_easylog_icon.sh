#!/usr/bin/env bash
set -euo pipefail

# Generates macOS app icon assets from a source PNG.
# Output: `Sources/EasyLogApp/Resources/EasyLog.icns` +
#         `Sources/EasyLogApp/Resources/Assets.xcassets/AppIcon.appiconset`.
# Usage:
#   ./scripts/generate_easylog_icon.sh [optional-source-png-path]

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/Sources/EasyLogApp/Resources"
ASSETS_DIR="$OUT_DIR/Assets.xcassets"
APPICON_DIR="$ASSETS_DIR/AppIcon.appiconset"
ICNS_PATH="$OUT_DIR/EasyLog.icns"
ICONSET_DIR="$ROOT_DIR/.build/EasyLog.iconset"

DEFAULT_SOURCE="$OUT_DIR/IconSource/newicon.png"
SOURCE_PATH="${1:-$DEFAULT_SOURCE}"
if [[ "$SOURCE_PATH" != /* ]]; then
  SOURCE_PATH="$ROOT_DIR/$SOURCE_PATH"
fi

if [[ ! -f "$SOURCE_PATH" ]]; then
  echo "Source icon not found: $SOURCE_PATH" >&2
  exit 1
fi

source_width="$(sips -g pixelWidth "$SOURCE_PATH" | awk '/pixelWidth/ {print $2}')"
source_height="$(sips -g pixelHeight "$SOURCE_PATH" | awk '/pixelHeight/ {print $2}')"

if [[ -z "$source_width" || -z "$source_height" ]]; then
  echo "Unable to read source image dimensions: $SOURCE_PATH" >&2
  exit 1
fi

if [[ "$source_width" != "$source_height" ]]; then
  echo "Source image must be square. Got ${source_width}x${source_height}: $SOURCE_PATH" >&2
  exit 1
fi

mkdir -p "$OUT_DIR" "$ASSETS_DIR"
rm -rf "$ICONSET_DIR" "$APPICON_DIR"
mkdir -p "$ICONSET_DIR" "$APPICON_DIR"

cleanup() {
  rm -rf "$ICONSET_DIR"
}
trap cleanup EXIT

cat > "$ASSETS_DIR/Contents.json" <<'JSON'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

render_png() {
  local px="$1"
  local file="$2"
  sips -s format png -z "$px" "$px" "$SOURCE_PATH" --out "$ICONSET_DIR/$file" >/dev/null
}

render_png 16 icon_16x16.png
render_png 32 icon_16x16@2x.png
render_png 32 icon_32x32.png
render_png 64 icon_32x32@2x.png
render_png 128 icon_128x128.png
render_png 256 icon_128x128@2x.png
render_png 256 icon_256x256.png
render_png 512 icon_256x256@2x.png
render_png 512 icon_512x512.png
render_png 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"

cp "$ICONSET_DIR"/icon_16x16.png "$APPICON_DIR"/
cp "$ICONSET_DIR"/icon_16x16@2x.png "$APPICON_DIR"/
cp "$ICONSET_DIR"/icon_32x32.png "$APPICON_DIR"/
cp "$ICONSET_DIR"/icon_32x32@2x.png "$APPICON_DIR"/
cp "$ICONSET_DIR"/icon_128x128.png "$APPICON_DIR"/
cp "$ICONSET_DIR"/icon_128x128@2x.png "$APPICON_DIR"/
cp "$ICONSET_DIR"/icon_256x256.png "$APPICON_DIR"/
cp "$ICONSET_DIR"/icon_256x256@2x.png "$APPICON_DIR"/
cp "$ICONSET_DIR"/icon_512x512.png "$APPICON_DIR"/
cp "$ICONSET_DIR"/icon_512x512@2x.png "$APPICON_DIR"/

cat > "$APPICON_DIR/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

echo "Generated from: $SOURCE_PATH"
echo "Generated: $ICNS_PATH"
echo "Generated: $APPICON_DIR"
