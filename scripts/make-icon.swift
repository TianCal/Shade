// Draws the Shade app icon (a window whose left pane is dimmed) and writes
// Assets/AppIcon.icns plus Assets/icon.png for the README.
// Usage: swift scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let assets = root.appendingPathComponent("Assets")

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func fillGradient(_ ctx: CGContext, _ path: CGPath, top: UInt32, bottom: UInt32, from y0: CGFloat, to y1: CGFloat) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color(top), color(bottom)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: y0), end: CGPoint(x: 0, y: y1), options: [])
    ctx.restoreGState()
}

func roundedRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
}

/// Draws the icon on a 1024×1024 canvas in top-left coordinates, following Apple's icon grid
/// (824pt body with a 100pt margin).
func drawIcon(_ ctx: CGContext, scale: CGFloat) {
    // Shadows ignore the context transform: scale them by hand and point them down in device space
    func shadow(_ y: CGFloat, _ blur: CGFloat, _ alpha: CGFloat) {
        ctx.setShadow(offset: CGSize(width: 0, height: -y * scale), blur: blur * scale, color: color(0x000000, alpha))
    }

    // Body with a soft drop shadow
    let body = roundedRect(100, 100, 824, 824, 185)
    ctx.saveGState()
    shadow(10, 28, 0.35)
    ctx.addPath(body)
    ctx.setFillColor(color(0x1E2A44))
    ctx.fillPath()
    ctx.restoreGState()
    fillGradient(ctx, body, top: 0x2C3D63, bottom: 0x161F36, from: 100, to: 924)

    // Window
    let window = roundedRect(212, 272, 600, 480, 52)
    ctx.saveGState()
    shadow(18, 36, 0.45)
    ctx.addPath(window)
    ctx.setFillColor(color(0xF6F3EC))
    ctx.fillPath()
    ctx.restoreGState()

    // Traffic lights
    for (i, hex) in [0xEC6A5E, 0xF4BF4F, 0x61C554].enumerated() {
        ctx.setFillColor(color(UInt32(hex)))
        ctx.fillEllipse(in: CGRect(x: 248 + CGFloat(i) * 42 - 14, y: 312 - 14, width: 28, height: 28))
    }

    // Left pane dimmed, right pane bright
    fillGradient(ctx, roundedRect(240, 350, 264, 374, 24), top: 0x46516F, bottom: 0x323A52, from: 350, to: 724)
    fillGradient(ctx, roundedRect(520, 350, 264, 374, 24), top: 0xFFDE8F, bottom: 0xFFC24D, from: 350, to: 724)
}

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    let scale = CGFloat(size) / 1024
    // Flip to top-left coordinates
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: scale, y: -scale)
    drawIcon(ctx, scale: scale)
    return rep.representation(using: .png, properties: [:])!
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    try png(size: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try png(size: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
try png(size: 512).write(to: assets.appendingPathComponent("icon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", assets.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote Assets/AppIcon.icns and Assets/icon.png")
