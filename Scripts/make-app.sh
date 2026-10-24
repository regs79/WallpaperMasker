#!/bin/zsh
# Builds a release binary and wraps it in WallpaperMasker.app next to this repo's Package.swift.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release
APP="$ROOT/WallpaperMasker.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/WallpaperMasker" "$APP/Contents/MacOS/WallpaperMasker"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
[ -f "$ROOT/Resources/AppIcon.icns" ] || "$ROOT/Scripts/make-icon.sh"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"
