import AppKit
import Foundation

// Mask the full-bleed artwork into a macOS-style squircle with transparent
// corners and margins, producing a 1024x1024 icon source PNG.
let src = CommandLine.arguments[1]
let dst = CommandLine.arguments[2]
guard let img = NSImage(contentsOfFile: src) else {
    FileHandle.standardError.write(Data("cannot read source\n".utf8)); exit(1)
}
let canvas = 1024
let inset = 100
let side = CGFloat(canvas - inset * 2)
let radius = side * 0.2237

guard let outRep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: canvas, pixelsHigh: canvas,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { exit(1) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: outRep)
let rect = NSRect(x: CGFloat(inset), y: CGFloat(inset), width: side, height: side)
NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
img.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

guard let png = outRep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: dst))
print("wrote \(dst)")