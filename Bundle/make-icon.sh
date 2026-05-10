#!/bin/bash
# Generates Bundle/AppIcon.icns from scratch using Swift + AppKit.
#
# Design: continuous-rounded square, deep red → orange diagonal gradient
# (Motorola palette inspired), centered SF Symbol "earbuds" in white.
#
# Output:  Bundle/AppIcon.icns
# Usage:   bash Bundle/make-icon.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
ICONSET="$WORK_DIR/MotoBuds.iconset"
OUT="$ROOT/Bundle/AppIcon.icns"
mkdir -p "$ICONSET"

echo "==> rendering iconset → $ICONSET"

swift - "$ICONSET" <<'SWIFT'
import AppKit

let outputDir = CommandLine.arguments[1]

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16.png",      16),
    ("icon_16x16@2x.png",   32),
    ("icon_32x32.png",      32),
    ("icon_32x32@2x.png",   64),
    ("icon_128x128.png",   128),
    ("icon_128x128@2x.png",256),
    ("icon_256x256.png",   256),
    ("icon_256x256@2x.png",512),
    ("icon_512x512.png",   512),
    ("icon_512x512@2x.png",1024),
]

func renderPNG(pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 32
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let p = CGFloat(pixels)
    let rect = NSRect(x: 0, y: 0, width: p, height: p)

    // 1. Continuous-corner rounded square clip (~22% radius — Apple style).
    let radius = p * 0.22
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    bgPath.addClip()

    // 2. Background gradient — Motorola red → orange.
    let deep   = NSColor(red: 0.62, green: 0.10, blue: 0.10, alpha: 1.0)
    let red    = NSColor(red: 0.88, green: 0.15, blue: 0.10, alpha: 1.0)
    let orange = NSColor(red: 0.96, green: 0.42, blue: 0.18, alpha: 1.0)
    NSGradient(colors: [deep, red, orange])!
        .draw(in: rect, angle: -55)

    // 3. Subtle top highlight.
    let highlight = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.24),
        NSColor.white.withAlphaComponent(0.0),
    ])!
    highlight.draw(in: NSRect(x: 0, y: p * 0.55, width: p, height: p * 0.45),
                   angle: 270)

    // 4. SF Symbol earbuds, white, with a soft drop shadow.
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = p * 0.025
    shadow.shadowOffset = NSSize(width: 0, height: -p * 0.012)
    shadow.set()

    let pointSize = p * 0.56
    let symbol = NSImage(systemSymbolName: "earbuds",
                         accessibilityDescription: nil)!
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        .applying(.init(paletteColors: [NSColor.white]))
    let drawn = symbol.withSymbolConfiguration(config)!
    let s = drawn.size
    let drawRect = NSRect(
        x: (p - s.width)  / 2,
        y: (p - s.height) / 2,
        width: s.width, height: s.height
    )
    drawn.draw(in: drawRect)

    return bitmap.representation(using: .png, properties: [:])!
}

for (name, px) in sizes {
    let data = renderPNG(pixels: px)
    let url = URL(fileURLWithPath: outputDir).appendingPathComponent(name)
    try! data.write(to: url)
    print("    \(name) (\(px)x\(px))")
}
SWIFT

echo "==> packing $OUT"
iconutil -c icns -o "$OUT" "$ICONSET"
rm -rf "$WORK_DIR"
echo "==> done: $OUT"
