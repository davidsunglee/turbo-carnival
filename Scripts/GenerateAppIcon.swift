#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024

// --- Helpers ---

func cgColor(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8 = 255) -> CGColor {
    CGColor(
        red: CGFloat(r) / 255.0,
        green: CGFloat(g) / 255.0,
        blue: CGFloat(b) / 255.0,
        alpha: CGFloat(a) / 255.0
    )
}

// --- Create context ---

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: size * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Failed to create CGContext")
}
ctx.setShouldAntialias(true)
ctx.setAllowsAntialiasing(true)
ctx.interpolationQuality = .high

let s = CGFloat(size)
let cx = s / 2
let cy = s / 2

// --- Background: deep space #0a0047 ---

ctx.setFillColor(cgColor(10, 0, 71))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// --- Radial glow behind ship ---
// Draw multiple concentric ellipses with decreasing opacity

let glowLayers: [(radius: CGFloat, alpha: UInt8)] = [
    (320, 15),
    (260, 25),
    (200, 35),
    (150, 50),
    (100, 40),
]

for layer in glowLayers {
    ctx.setFillColor(cgColor(0, 255, 210, layer.alpha))
    ctx.fillEllipse(in: CGRect(
        x: cx - layer.radius,
        y: cy - layer.radius,
        width: layer.radius * 2,
        height: layer.radius * 2
    ))
}

// --- Apply ~15° clockwise rotation around center ---
// Note: CG rotates counterclockwise, so negative angle for clockwise visual rotation
// CG coordinate system has Y pointing up, so -15° in CG = 15° clockwise visually

ctx.saveGState()
ctx.translateBy(x: cx, y: cy)
ctx.rotate(by: -15.0 * .pi / 180.0)
ctx.translateBy(x: -cx, y: -cy)

// --- Ship drawing (scaled up from 48x48 to ~500px tall) ---
// The in-game ship is a diamond/chevron. We scale the proportions.

let shipScale: CGFloat = 10.5  // 48 * 10.5 ≈ 504
let shipCx = cx
// Offset ship slightly toward the center of the icon
let shipBaseY = cy - (CGFloat(48) * shipScale / 2) + 20

func sp(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    // Map from 48x48 sprite coordinates to icon coordinates
    // In SpriteFactory, Y=48 is top (nose), Y=0 is bottom (tail) — CG coords
    CGPoint(
        x: shipCx + (x - 24) * shipScale,
        y: shipBaseY + y * shipScale
    )
}

// Dark interior fill
ctx.setFillColor(cgColor(0, 40, 35))
ctx.beginPath()
ctx.move(to: sp(24, 44))    // nose
ctx.addLine(to: sp(6, 10))   // left wing tip
ctx.addLine(to: sp(20, 18))  // left inner
ctx.addLine(to: sp(24, 4))   // tail center (was cy, 4 at 48px)
ctx.addLine(to: sp(28, 18))  // right inner
ctx.addLine(to: sp(42, 10))  // right wing tip
ctx.closePath()
ctx.fillPath()

// Bright cyan outline
ctx.setStrokeColor(cgColor(0, 255, 210))
ctx.setLineWidth(6)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.beginPath()
ctx.move(to: sp(24, 44))
ctx.addLine(to: sp(6, 10))
ctx.addLine(to: sp(20, 18))
ctx.addLine(to: sp(24, 4))
ctx.addLine(to: sp(28, 18))
ctx.addLine(to: sp(42, 10))
ctx.closePath()
ctx.strokePath()

// Inner edge highlights (dimmer cyan)
ctx.setStrokeColor(cgColor(0, 180, 150, 100))
ctx.setLineWidth(2)
ctx.beginPath()
ctx.move(to: sp(20, 18))
ctx.addLine(to: sp(24, 44))
ctx.addLine(to: sp(28, 18))
ctx.strokePath()

// Cockpit core - bright dot
ctx.setFillColor(cgColor(200, 255, 240))
let cockpitCenter = sp(24, 30)
let cockpitRadius: CGFloat = 18
ctx.fillEllipse(in: CGRect(
    x: cockpitCenter.x - cockpitRadius,
    y: cockpitCenter.y - cockpitRadius,
    width: cockpitRadius * 2,
    height: cockpitRadius * 2
))

// Cockpit glow
ctx.setFillColor(cgColor(0, 255, 210, 80))
let cockpitGlowR: CGFloat = 30
ctx.fillEllipse(in: CGRect(
    x: cockpitCenter.x - cockpitGlowR,
    y: cockpitCenter.y - cockpitGlowR,
    width: cockpitGlowR * 2,
    height: cockpitGlowR * 2
))

// Engine glow at tail
let engineCenter = sp(24, 2)
ctx.setFillColor(cgColor(0, 200, 180, 180))
ctx.fillEllipse(in: CGRect(x: engineCenter.x - 25, y: engineCenter.y - 20, width: 50, height: 40))
ctx.setFillColor(cgColor(150, 255, 230, 150))
ctx.fillEllipse(in: CGRect(x: engineCenter.x - 12, y: engineCenter.y - 10, width: 24, height: 20))

// --- Thrust lines trailing from engine ---

let thrustStart = sp(24, 0)

// Main thrust line
ctx.setStrokeColor(cgColor(0, 255, 210, 150))
ctx.setLineWidth(5)
ctx.beginPath()
ctx.move(to: thrustStart)
ctx.addLine(to: CGPoint(x: thrustStart.x, y: thrustStart.y - 120))
ctx.strokePath()

// Fading thrust
ctx.setStrokeColor(cgColor(0, 255, 210, 80))
ctx.setLineWidth(3)
ctx.beginPath()
ctx.move(to: CGPoint(x: thrustStart.x, y: thrustStart.y - 120))
ctx.addLine(to: CGPoint(x: thrustStart.x, y: thrustStart.y - 200))
ctx.strokePath()

// Side thrust lines (spread slightly)
ctx.setStrokeColor(cgColor(0, 255, 210, 100))
ctx.setLineWidth(3)
ctx.beginPath()
ctx.move(to: CGPoint(x: thrustStart.x - 10, y: thrustStart.y + 5))
ctx.addLine(to: CGPoint(x: thrustStart.x - 18, y: thrustStart.y - 90))
ctx.strokePath()

ctx.beginPath()
ctx.move(to: CGPoint(x: thrustStart.x + 10, y: thrustStart.y + 5))
ctx.addLine(to: CGPoint(x: thrustStart.x + 18, y: thrustStart.y - 90))
ctx.strokePath()

ctx.restoreGState()

// --- Export as PNG ---

guard let image = ctx.makeImage() else {
    fatalError("Failed to create CGImage")
}

let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let projectRoot = scriptDir.deletingLastPathComponent()
let outputDir = projectRoot
    .appendingPathComponent("Shared")
    .appendingPathComponent("Assets.xcassets")
    .appendingPathComponent("AppIcon.appiconset")

// Create directory
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let outputURL = outputDir.appendingPathComponent("AppIcon.png")

guard let dest = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    fatalError("Failed to create image destination")
}

CGImageDestinationAddImage(dest, image, nil)

guard CGImageDestinationFinalize(dest) else {
    fatalError("Failed to write PNG")
}

print("✓ App icon saved to \(outputURL.path)")
