import CoreGraphics

public enum SpriteFactory {

    // MARK: - Helpers

    static func makeContext(width: Int, height: Int) -> CGContext? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.setShouldAntialias(false)
        ctx.setAllowsAntialiasing(false)
        ctx.interpolationQuality = .none
        return ctx
    }

    static func extractPixels(from ctx: CGContext, width: Int, height: Int) -> [UInt8] {
        guard let data = ctx.data else { return [] }
        let byteCount = width * height * 4
        return Array(UnsafeBufferPointer(
            start: data.assumingMemoryBound(to: UInt8.self),
            count: byteCount
        ))
    }

    static func cgColor(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8 = 255) -> CGColor {
        CGColor(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a) / 255.0
        )
    }

    // MARK: - Player Ship (48x48)
    // Diamond/chevron pointing up. Cyan (#00ffd2) outline, dark interior, bright core, engine glow.

    public static func makePlayerShip() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 48, h = 48
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2

        // Dark interior fill
        ctx.setFillColor(cgColor(0, 40, 35))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 4))
        ctx.addLine(to: CGPoint(x: 6, y: 10))
        ctx.addLine(to: CGPoint(x: cx - 4, y: 18))
        ctx.addLine(to: CGPoint(x: cx, y: 4))
        ctx.addLine(to: CGPoint(x: cx + 4, y: 18))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 6, y: 10))
        ctx.closePath()
        ctx.fillPath()

        // Bright cyan outline
        ctx.setStrokeColor(cgColor(0, 255, 210))
        ctx.setLineWidth(2)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 4))
        ctx.addLine(to: CGPoint(x: 6, y: 10))
        ctx.addLine(to: CGPoint(x: cx - 4, y: 18))
        ctx.addLine(to: CGPoint(x: cx, y: 4))
        ctx.addLine(to: CGPoint(x: cx + 4, y: 18))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 6, y: 10))
        ctx.closePath()
        ctx.strokePath()

        // Cockpit core - bright dot
        ctx.setFillColor(cgColor(200, 255, 240))
        ctx.fillEllipse(in: CGRect(x: cx - 3, y: 28, width: 6, height: 6))

        // Engine glow at tail
        ctx.setFillColor(cgColor(0, 200, 180, 180))
        ctx.fillEllipse(in: CGRect(x: cx - 4, y: 2, width: 8, height: 6))
        ctx.setFillColor(cgColor(150, 255, 230, 120))
        ctx.fillEllipse(in: CGRect(x: cx - 2, y: 0, width: 4, height: 4))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Tier 1 Swarmer (32x32)
    // Downward-pointing dart. Pink/magenta (#f7768e) outline, dark fill, bright core.

    public static func makeSwarmer() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 32, h = 32
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2

        // Dark magenta fill
        ctx.setFillColor(cgColor(100, 30, 50))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: 4))
        ctx.addLine(to: CGPoint(x: 4, y: CGFloat(h) - 4))
        ctx.addLine(to: CGPoint(x: cx, y: CGFloat(h) - 10))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 4, y: CGFloat(h) - 4))
        ctx.closePath()
        ctx.fillPath()

        // Pink outline
        ctx.setStrokeColor(cgColor(247, 118, 142))
        ctx.setLineWidth(2)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: 4))
        ctx.addLine(to: CGPoint(x: 4, y: CGFloat(h) - 4))
        ctx.addLine(to: CGPoint(x: cx, y: CGFloat(h) - 10))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 4, y: CGFloat(h) - 4))
        ctx.closePath()
        ctx.strokePath()

        // Energy core
        ctx.setFillColor(cgColor(255, 200, 210))
        ctx.fillEllipse(in: CGRect(x: cx - 2, y: 14, width: 4, height: 4))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Tier 2 Bruiser (40x40)
    // Hexagonal body. Blue-cyan (#6490c0) outline, thick edges, turret dots, bright core.

    public static func makeBruiser() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 40, h = 40
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        // Hexagon vertices (flat-top orientation)
        let r: CGFloat = 17
        var hexPoints: [CGPoint] = []
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 6
            hexPoints.append(CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle)))
        }

        // Dark blue fill
        ctx.setFillColor(cgColor(25, 40, 80))
        ctx.beginPath()
        ctx.move(to: hexPoints[0])
        for pt in hexPoints.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.fillPath()

        // Blue-cyan outline (thick)
        ctx.setStrokeColor(cgColor(100, 144, 192))
        ctx.setLineWidth(3)
        ctx.beginPath()
        ctx.move(to: hexPoints[0])
        for pt in hexPoints.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.strokePath()

        // Turret dots on sides
        ctx.setFillColor(cgColor(160, 200, 240))
        ctx.fillEllipse(in: CGRect(x: 4, y: cy - 2, width: 4, height: 4))
        ctx.fillEllipse(in: CGRect(x: CGFloat(w) - 8, y: cy - 2, width: 4, height: 4))

        // Bright core
        ctx.setFillColor(cgColor(200, 230, 255))
        ctx.fillEllipse(in: CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }
}
