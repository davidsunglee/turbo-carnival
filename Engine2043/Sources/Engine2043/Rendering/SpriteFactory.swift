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
}
