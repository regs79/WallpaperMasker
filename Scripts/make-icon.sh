#!/bin/zsh
# Renders Resources/icon.svg into Resources/AppIcon.icns (all macOS icon sizes).
# Replace icon.svg with your own 1024×1024 artwork and re-run.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVG="$ROOT/Resources/icon.svg"
SET="$ROOT/.build/AppIcon.iconset"
rm -rf "$SET"; mkdir -p "$SET"

# NSImage renders SVG natively on macOS 11+; emit each size as PNG.
cat > "$ROOT/.build/render-icon.swift" <<'SWIFT'
import AppKit
let args = CommandLine.arguments
let svg = NSImage(contentsOfFile: args[1])!
let outDir = args[2]
for (name, px) in [("16x16",16),("16x16@2x",32),("32x32",32),("32x32@2x",64),("128x128",128),("128x128@2x",256),
                   ("256x256",256),("256x256@2x",512),("512x512",512),("512x512@2x",1024)] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    svg.draw(in: NSRect(x: 0, y: 0, width: px, height: px), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/icon_\(name).png"))
}
SWIFT
swiftc -O "$ROOT/.build/render-icon.swift" -o "$ROOT/.build/render-icon" 2>/dev/null
"$ROOT/.build/render-icon" "$SVG" "$SET"
iconutil -c icns "$SET" -o "$ROOT/Resources/AppIcon.icns"
echo "Wrote $ROOT/Resources/AppIcon.icns"
