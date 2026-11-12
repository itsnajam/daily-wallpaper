#!/bin/bash
# Build "Daily Wallpaper.app" with the Command Line Tools only (no Xcode).
# Compiles a universal binary, assembles the bundle, ad-hoc signs it, and zips
# it into dist/. Made by Najam · https://najam.dev
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Daily Wallpaper"
EXEC_NAME="DailyWallpaper"
BUILD="$HERE/build"
DIST="$HERE/dist"
APP="$BUILD/$APP_NAME.app"
SOURCES="$HERE/app/Sources"
RES="$HERE/app/Resources"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc not found. Install the Command Line Tools: xcode-select --install" >&2
  exit 1
fi

rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$DIST"

echo "Compiling arm64..."
swiftc -O -parse-as-library -target arm64-apple-macos14.0 "$SOURCES"/*.swift -o "$BUILD/$EXEC_NAME-arm64"
echo "Compiling x86_64..."
swiftc -O -parse-as-library -target x86_64-apple-macos14.0 "$SOURCES"/*.swift -o "$BUILD/$EXEC_NAME-x86_64"
lipo -create "$BUILD/$EXEC_NAME-arm64" "$BUILD/$EXEC_NAME-x86_64" -output "$APP/Contents/MacOS/$EXEC_NAME"

cp "$RES/Info.plist" "$APP/Contents/Info.plist"

# App icon from the committed source PNG.
ICONSET="$BUILD/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$RES/icon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$RES/icon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature so the app runs locally (Gatekeeper still asks on first open).
codesign --force --sign - "$APP"

ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/Daily-Wallpaper.zip"

echo
echo "Built: $APP"
du -sh "$APP" | awk '{print "App size: " $1}'
echo "Zip:   $DIST/Daily-Wallpaper.zip"