#!/usr/bin/env swift
import AppKit
import CoreGraphics

func drawIcon(size: CGFloat) -> Data? {
    // Draw into a fixed-pixel NSBitmapImageRep so the output is exactly
    // `size × size` real pixels regardless of the current screen backing
    // scale (otherwise retina displays produce 2x-size PNGs that actool
    // rejects).
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    ) else { return nil }

    let gc = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gc
    defer {
        NSGraphicsContext.restoreGraphicsState()
    }

    guard let ctx = gc?.cgContext else { return nil }

    // macOS icon mask: rounded square.
    let radius = size * 0.224
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let path = CGPath(
        roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil
    )
    ctx.addPath(path)
    ctx.clip()

    // Background: vibrant magenta → deep violet
    let space = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(red: 0.96, green: 0.33, blue: 0.58, alpha: 1.0),
        CGColor(red: 0.52, green: 0.16, blue: 0.74, alpha: 1.0),
    ]
    if let gradient = CGGradient(
        colorsSpace: space, colors: colors as CFArray, locations: [0, 1]
    ) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: size),
            end: CGPoint(x: size, y: 0),
            options: []
        )
    }

    // Subtle light wash in top-left
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.08))
    ctx.fillEllipse(in: CGRect(
        x: -size * 0.2, y: size * 0.55, width: size * 0.9, height: size * 0.6))

    let center = CGPoint(x: size / 2, y: size / 2)

    // Outer lens ring (white with slight translucency)
    let lensOuter = size * 0.58
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    ctx.fillEllipse(in: CGRect(
        x: center.x - lensOuter / 2, y: center.y - lensOuter / 2,
        width: lensOuter, height: lensOuter))

    // Dark lens glass
    let lensInner = size * 0.44
    ctx.setFillColor(CGColor(red: 0.10, green: 0.08, blue: 0.20, alpha: 1.0))
    ctx.fillEllipse(in: CGRect(
        x: center.x - lensInner / 2, y: center.y - lensInner / 2,
        width: lensInner, height: lensInner))

    // Lens inner glass gradient (blue → magenta)
    let coreColors = [
        CGColor(red: 0.25, green: 0.35, blue: 0.85, alpha: 1.0),
        CGColor(red: 0.85, green: 0.24, blue: 0.68, alpha: 1.0),
    ]
    if let coreGrad = CGGradient(
        colorsSpace: space, colors: coreColors as CFArray, locations: [0, 1]
    ) {
        ctx.saveGState()
        let coreRect = CGRect(
            x: center.x - lensInner / 2 + size * 0.025,
            y: center.y - lensInner / 2 + size * 0.025,
            width: lensInner - size * 0.05, height: lensInner - size * 0.05)
        ctx.addEllipse(in: coreRect)
        ctx.clip()
        ctx.drawLinearGradient(
            coreGrad,
            start: CGPoint(x: coreRect.minX, y: coreRect.maxY),
            end: CGPoint(x: coreRect.maxX, y: coreRect.minY),
            options: []
        )
        ctx.restoreGState()
    }

    // Lens highlight
    let hlD = size * 0.10
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.85))
    ctx.fillEllipse(in: CGRect(
        x: center.x - hlD / 2 - size * 0.08,
        y: center.y - hlD / 2 + size * 0.08,
        width: hlD, height: hlD))

    // Sparkles (AI hint)
    drawSparkle(ctx: ctx, at: CGPoint(x: size * 0.80, y: size * 0.78), armLen: size * 0.085, alpha: 1.0)
    drawSparkle(ctx: ctx, at: CGPoint(x: size * 0.90, y: size * 0.58), armLen: size * 0.045, alpha: 0.85)
    drawSparkle(ctx: ctx, at: CGPoint(x: size * 0.20, y: size * 0.18), armLen: size * 0.055, alpha: 0.75)

    return rep.representation(using: .png, properties: [:])
}

func drawSparkle(ctx: CGContext, at p: CGPoint, armLen: CGFloat, alpha: CGFloat) {
    ctx.saveGState()
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: alpha))
    // Vertical arm
    ctx.fillEllipse(in: CGRect(
        x: p.x - armLen * 0.18, y: p.y - armLen,
        width: armLen * 0.36, height: armLen * 2))
    // Horizontal arm
    ctx.fillEllipse(in: CGRect(
        x: p.x - armLen, y: p.y - armLen * 0.18,
        width: armLen * 2, height: armLen * 0.36))
    ctx.restoreGState()
}

// MARK: - Entry

let args = CommandLine.arguments
let outDir: URL
if args.count > 1 {
    outDir = URL(fileURLWithPath: args[1])
} else {
    outDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Sources/PhotoBoothPro/Assets.xcassets/AppIcon.appiconset")
}

try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let specs: [(px: CGFloat, filename: String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for spec in specs {
    guard let data = drawIcon(size: spec.px) else {
        FileHandle.standardError.write(
            Data("Failed to render \(spec.filename)\n".utf8))
        continue
    }
    let url = outDir.appendingPathComponent(spec.filename)
    do {
        try data.write(to: url)
        print("Wrote \(spec.filename) (\(Int(spec.px))×\(Int(spec.px)))")
    } catch {
        FileHandle.standardError.write(
            Data("Failed writing \(url.path): \(error)\n".utf8))
    }
}

print("Done.")
