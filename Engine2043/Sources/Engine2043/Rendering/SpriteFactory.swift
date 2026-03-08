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

    static func makeSoftContext(width: Int, height: Int) -> CGContext? {
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
        ctx.setShouldAntialias(true)
        ctx.setAllowsAntialiasing(true)
        ctx.interpolationQuality = .high
        return ctx
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

    // MARK: - Tier 3 Capital Ship Hull (140x60)
    // Long hull with angular cutouts. Dark gray-blue (#323250) fill, lighter panel lines.

    public static func makeCapitalHull() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 140, h = 60
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cw = CGFloat(w)
        let ch = CGFloat(h)

        // Main hull body with angled bow
        ctx.setFillColor(cgColor(40, 50, 80))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 10, y: 5))
        ctx.addLine(to: CGPoint(x: cw - 10, y: 5))
        ctx.addLine(to: CGPoint(x: cw - 2, y: 15))
        ctx.addLine(to: CGPoint(x: cw - 2, y: ch - 15))
        ctx.addLine(to: CGPoint(x: cw - 10, y: ch - 5))
        ctx.addLine(to: CGPoint(x: 10, y: ch - 5))
        ctx.addLine(to: CGPoint(x: 2, y: ch - 15))
        ctx.addLine(to: CGPoint(x: 2, y: 15))
        ctx.closePath()
        ctx.fillPath()

        // Darker recessed panel lines
        ctx.setStrokeColor(cgColor(30, 35, 55))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 12, y: 20)); ctx.addLine(to: CGPoint(x: cw - 12, y: 20))
        ctx.move(to: CGPoint(x: 12, y: ch - 20)); ctx.addLine(to: CGPoint(x: cw - 12, y: ch - 20))
        ctx.move(to: CGPoint(x: 35, y: 8)); ctx.addLine(to: CGPoint(x: 35, y: ch - 8))
        ctx.move(to: CGPoint(x: 70, y: 8)); ctx.addLine(to: CGPoint(x: 70, y: ch - 8))
        ctx.move(to: CGPoint(x: 105, y: 8)); ctx.addLine(to: CGPoint(x: 105, y: ch - 8))
        ctx.strokePath()

        // Bridge highlight at center
        ctx.setFillColor(cgColor(60, 75, 110))
        ctx.fill(CGRect(x: 55, y: 22, width: 30, height: 16))

        // Outer edge highlight
        ctx.setStrokeColor(cgColor(70, 85, 120))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 10, y: 5))
        ctx.addLine(to: CGPoint(x: cw - 10, y: 5))
        ctx.addLine(to: CGPoint(x: cw - 2, y: 15))
        ctx.addLine(to: CGPoint(x: cw - 2, y: ch - 15))
        ctx.addLine(to: CGPoint(x: cw - 10, y: ch - 5))
        ctx.addLine(to: CGPoint(x: 10, y: ch - 5))
        ctx.addLine(to: CGPoint(x: 2, y: ch - 15))
        ctx.addLine(to: CGPoint(x: 2, y: 15))
        ctx.closePath()
        ctx.strokePath()

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Tier 3 Turret (24x24)
    // Octagonal ring. Orange-red (#ff6633) ring, dark center, bright barrel dot.

    public static func makeTurret() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 24, h = 24
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        // Octagon ring
        let outerR: CGFloat = 10
        let innerR: CGFloat = 6
        var outerPts: [CGPoint] = []
        var innerPts: [CGPoint] = []
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4
            outerPts.append(CGPoint(x: cx + outerR * cos(angle), y: cy + outerR * sin(angle)))
            innerPts.append(CGPoint(x: cx + innerR * cos(angle), y: cy + innerR * sin(angle)))
        }

        // Orange-red outer fill
        ctx.setFillColor(cgColor(255, 102, 51))
        ctx.beginPath()
        ctx.move(to: outerPts[0])
        for pt in outerPts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.fillPath()

        // Dark inner cutout
        ctx.setFillColor(cgColor(40, 20, 15))
        ctx.beginPath()
        ctx.move(to: innerPts[0])
        for pt in innerPts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.fillPath()

        // Barrel dot
        ctx.setFillColor(cgColor(255, 180, 120))
        ctx.fillEllipse(in: CGRect(x: cx - 2, y: cy - 2, width: 4, height: 4))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Boss Core (64x64)
    // Concentric geometric rings. Blue (#4499ff) outer, white-blue center, octagonal edges.

    public static func makeBossCore() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 64, h = 64
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        func octagon(center: CGPoint, radius: CGFloat) -> [CGPoint] {
            (0..<8).map { i in
                let angle = CGFloat(i) * .pi / 4
                return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            }
        }

        let center = CGPoint(x: cx, y: cy)

        // Dim outer glow ring
        let outerPts = octagon(center: center, radius: 28)
        ctx.setFillColor(cgColor(30, 60, 120))
        ctx.beginPath()
        ctx.move(to: outerPts[0])
        for pt in outerPts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.fillPath()

        // Blue outer ring stroke
        ctx.setStrokeColor(cgColor(68, 153, 255))
        ctx.setLineWidth(3)
        ctx.beginPath()
        ctx.move(to: outerPts[0])
        for pt in outerPts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.strokePath()

        // Mid ring
        let midPts = octagon(center: center, radius: 18)
        ctx.setFillColor(cgColor(20, 40, 80))
        ctx.beginPath()
        ctx.move(to: midPts[0])
        for pt in midPts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.fillPath()

        ctx.setStrokeColor(cgColor(100, 180, 255))
        ctx.setLineWidth(2)
        ctx.beginPath()
        ctx.move(to: midPts[0])
        for pt in midPts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.strokePath()

        // Inner core
        let innerPts = octagon(center: center, radius: 8)
        ctx.setFillColor(cgColor(150, 210, 255))
        ctx.beginPath()
        ctx.move(to: innerPts[0])
        for pt in innerPts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.fillPath()

        // Bright center dot
        ctx.setFillColor(cgColor(220, 240, 255))
        ctx.fillEllipse(in: CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Boss Shield Segment (40x12)
    // Elongated bar. Light cyan (#99ccff) with bright edge highlights.

    public static func makeBossShield() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 40, h = 12
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        // Rounded-rect body
        let rect = CGRect(x: 2, y: 2, width: CGFloat(w) - 4, height: CGFloat(h) - 4)
        let path = CGPath(roundedRect: rect, cornerWidth: 3, cornerHeight: 3, transform: nil)

        // Fill with semi-transparent cyan
        ctx.setFillColor(cgColor(100, 170, 220, 180))
        ctx.addPath(path)
        ctx.fillPath()

        // Bright edge highlight
        ctx.setStrokeColor(cgColor(153, 204, 255))
        ctx.setLineWidth(2)
        ctx.addPath(path)
        ctx.strokePath()

        // Center highlight line
        ctx.setStrokeColor(cgColor(200, 230, 255, 150))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 6, y: CGFloat(h) / 2))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 6, y: CGFloat(h) / 2))
        ctx.strokePath()

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Player Bullet (6x12)
    // Vertical elongated diamond, white core with cyan (#00ffd2) trailing edge.

    public static func makePlayerBullet() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 6, h = 12
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2

        // Cyan trailing edge (bottom half)
        ctx.setFillColor(cgColor(0, 255, 210))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 1))
        ctx.addLine(to: CGPoint(x: 1, y: CGFloat(h) / 2))
        ctx.addLine(to: CGPoint(x: cx, y: 2))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 1, y: CGFloat(h) / 2))
        ctx.closePath()
        ctx.fillPath()

        // White core (upper portion)
        ctx.setFillColor(cgColor(255, 255, 255))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 2))
        ctx.addLine(to: CGPoint(x: 2, y: CGFloat(h) / 2 + 1))
        ctx.addLine(to: CGPoint(x: cx, y: 4))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 2, y: CGFloat(h) / 2 + 1))
        ctx.closePath()
        ctx.fillPath()

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Tri-Spread Bullet (8x8)
    // Small rotated diamond, orange (#ff8033) outline, bright center.

    public static func makeTriSpreadBullet() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 8, h = 8
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        // Dark orange fill
        ctx.setFillColor(cgColor(100, 50, 20))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 1))
        ctx.addLine(to: CGPoint(x: 1, y: cy))
        ctx.addLine(to: CGPoint(x: cx, y: 1))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 1, y: cy))
        ctx.closePath()
        ctx.fillPath()

        // Orange outline
        ctx.setStrokeColor(cgColor(255, 128, 51))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 1))
        ctx.addLine(to: CGPoint(x: 1, y: cy))
        ctx.addLine(to: CGPoint(x: cx, y: 1))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 1, y: cy))
        ctx.closePath()
        ctx.strokePath()

        // Bright center
        ctx.setFillColor(cgColor(255, 200, 150))
        ctx.fillEllipse(in: CGRect(x: cx - 1, y: cy - 1, width: 2, height: 2))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Lightning Arc Icon (8x8)
    // Electric bolt icon for weapon module display.

    public static func makeLightningArcIcon() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 8, h = 8
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        // Cyan-white lightning bolt shape
        ctx.setStrokeColor(cgColor(100, 180, 255))
        ctx.setLineWidth(2)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 5, y: 0))
        ctx.addLine(to: CGPoint(x: 3, y: 3))
        ctx.addLine(to: CGPoint(x: 5, y: 3))
        ctx.addLine(to: CGPoint(x: 3, y: 7))
        ctx.strokePath()

        // Bright white core
        ctx.setStrokeColor(cgColor(220, 240, 255))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 5, y: 0))
        ctx.addLine(to: CGPoint(x: 3, y: 3))
        ctx.addLine(to: CGPoint(x: 5, y: 3))
        ctx.addLine(to: CGPoint(x: 3, y: 7))
        ctx.strokePath()

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Enemy Bullet (8x8)
    // Downward-pointing arrowhead, hostile orange (#ff9e64) outline, dark fill.

    public static func makeEnemyBullet() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 8, h = 8
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2

        // Dark fill
        ctx.setFillColor(cgColor(80, 40, 20))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: 1))
        ctx.addLine(to: CGPoint(x: 1, y: CGFloat(h) - 2))
        ctx.addLine(to: CGPoint(x: cx, y: CGFloat(h) - 4))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 1, y: CGFloat(h) - 2))
        ctx.closePath()
        ctx.fillPath()

        // Orange outline
        ctx.setStrokeColor(cgColor(255, 158, 100))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: 1))
        ctx.addLine(to: CGPoint(x: 1, y: CGFloat(h) - 2))
        ctx.addLine(to: CGPoint(x: cx, y: CGFloat(h) - 4))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 1, y: CGFloat(h) - 2))
        ctx.closePath()
        ctx.strokePath()

        // Bright core
        ctx.setFillColor(cgColor(255, 220, 180))
        ctx.fillEllipse(in: CGRect(x: cx - 1, y: 3, width: 2, height: 2))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Gravity Bomb Sprite (16x16)
    // Octagonal shell, gold (#ffda4d) outline, dark center, bright core dot.

    public static func makeGravBombSprite() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 16, h = 16
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        // Octagon
        let r: CGFloat = 6
        var pts: [CGPoint] = []
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4
            pts.append(CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle)))
        }

        // Dark fill
        ctx.setFillColor(cgColor(50, 40, 10))
        ctx.beginPath()
        ctx.move(to: pts[0])
        for pt in pts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.fillPath()

        // Gold outline
        ctx.setStrokeColor(cgColor(255, 218, 77))
        ctx.setLineWidth(2)
        ctx.beginPath()
        ctx.move(to: pts[0])
        for pt in pts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.strokePath()

        // Bright core dot
        ctx.setFillColor(cgColor(255, 240, 180))
        ctx.fillEllipse(in: CGRect(x: cx - 2, y: cy - 2, width: 4, height: 4))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Energy Drop (24x24)
    // Lightning bolt silhouette, gold (#e0af68) fill, white highlight line.

    public static func makeEnergyDrop() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 24, h = 24
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        // Outer glow (subtle gold halo)
        ctx.setFillColor(cgColor(224, 175, 104, 40))
        ctx.fillEllipse(in: CGRect(x: 2, y: 2, width: 20, height: 20))

        // Lightning bolt shape — larger, more detailed
        ctx.setFillColor(cgColor(224, 175, 104))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 14, y: 21))
        ctx.addLine(to: CGPoint(x: 7, y: 21))
        ctx.addLine(to: CGPoint(x: 11, y: 13))
        ctx.addLine(to: CGPoint(x: 7, y: 13))
        ctx.addLine(to: CGPoint(x: 14, y: 3))
        ctx.addLine(to: CGPoint(x: 16, y: 3))
        ctx.addLine(to: CGPoint(x: 12, y: 11))
        ctx.addLine(to: CGPoint(x: 16, y: 11))
        ctx.closePath()
        ctx.fillPath()

        // White highlight line down center
        ctx.setStrokeColor(cgColor(255, 255, 255, 200))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 13, y: 20))
        ctx.addLine(to: CGPoint(x: 10, y: 13))
        ctx.addLine(to: CGPoint(x: 14, y: 4))
        ctx.strokePath()

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Charge Cell (24x24)
    // Hexagonal battery, purple (#9966ff) outline, segmented interior, bright core.

    public static func makeChargeCell() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 24, h = 24
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        // Hexagon
        let r: CGFloat = 9
        var hexPts: [CGPoint] = []
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 6
            hexPts.append(CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle)))
        }

        // Dark purple fill
        ctx.setFillColor(cgColor(30, 15, 60))
        ctx.beginPath()
        ctx.move(to: hexPts[0])
        for pt in hexPts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.fillPath()

        // Purple outline
        ctx.setStrokeColor(cgColor(153, 102, 255))
        ctx.setLineWidth(2)
        ctx.beginPath()
        ctx.move(to: hexPts[0])
        for pt in hexPts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.strokePath()

        // Segment lines (3 horizontal lines)
        ctx.setStrokeColor(cgColor(80, 50, 140))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 5, y: cy - 3))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 5, y: cy - 3))
        ctx.move(to: CGPoint(x: 5, y: cy))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 5, y: cy))
        ctx.move(to: CGPoint(x: 5, y: cy + 3))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 5, y: cy + 3))
        ctx.strokePath()

        // Bright core
        ctx.setFillColor(cgColor(200, 180, 255))
        ctx.fillEllipse(in: CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Shield Drop (24x24)
    // Concentric cyan rings with bright center dot — "Cyan Halo" per spec.

    public static func makeShieldDrop() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 24, h = 24
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        // Outer ring
        ctx.setStrokeColor(cgColor(0, 255, 210, 100))
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: CGRect(x: 2, y: 2, width: 20, height: 20))

        // Middle ring
        ctx.setStrokeColor(cgColor(0, 255, 210, 180))
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: CGRect(x: 5, y: 5, width: 14, height: 14))

        // Inner ring
        ctx.setStrokeColor(cgColor(0, 255, 210, 255))
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: CGRect(x: 8, y: 8, width: 8, height: 8))

        // Bright center dot
        ctx.setFillColor(cgColor(200, 255, 240))
        ctx.fillEllipse(in: CGRect(x: cx - 2, y: cy - 2, width: 4, height: 4))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Shield Drone (10x10)
    // Small cyan filled circle — orbits the player ship.

    public static func makeShieldDrone() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 10, h = 10
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        // Cyan filled circle
        ctx.setFillColor(cgColor(0, 255, 210, 200))
        ctx.fillEllipse(in: CGRect(x: 1, y: 1, width: 8, height: 8))

        // Bright center
        ctx.setFillColor(cgColor(200, 255, 240))
        ctx.fillEllipse(in: CGRect(x: cx - 2, y: cy - 2, width: 4, height: 4))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Weapon Module (20x20)
    // Diamond frame with crosshair/plus inside, blue (#4d80ff) outline, darker fill.

    public static func makeWeaponModuleSprite() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 20, h = 20
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        // Dark fill diamond
        ctx.setFillColor(cgColor(15, 25, 60))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 2))
        ctx.addLine(to: CGPoint(x: 2, y: cy))
        ctx.addLine(to: CGPoint(x: cx, y: 2))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 2, y: cy))
        ctx.closePath()
        ctx.fillPath()

        // Blue outline diamond
        ctx.setStrokeColor(cgColor(77, 128, 255))
        ctx.setLineWidth(2)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 2))
        ctx.addLine(to: CGPoint(x: 2, y: cy))
        ctx.addLine(to: CGPoint(x: cx, y: 2))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 2, y: cy))
        ctx.closePath()
        ctx.strokePath()

        // Crosshair/plus inside
        ctx.setStrokeColor(cgColor(120, 160, 255))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: cy - 4))
        ctx.addLine(to: CGPoint(x: cx, y: cy + 4))
        ctx.move(to: CGPoint(x: cx - 4, y: cy))
        ctx.addLine(to: CGPoint(x: cx + 4, y: cy))
        ctx.strokePath()

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Grav Bomb Blast (128x128)
    // Radial gradient ring — gold-white center fading to transparent gold. Hollow center.

    public static func makeGravBombBlast() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 128, h = 128
        guard let ctx = makeSoftContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        // Draw radial gradient ring manually with concentric circles
        let maxR: CGFloat = 60
        let minR: CGFloat = 20
        let steps = 40
        for i in 0..<steps {
            let t = CGFloat(i) / CGFloat(steps)
            let r = maxR - t * (maxR - minR)
            let alpha = UInt8(min(255, Int((1.0 - t) * 0.6 * 255)))
            let green = UInt8(min(255, 218 + Int(t * 37)))
            ctx.setFillColor(cgColor(255, green, UInt8(min(255, 77 + Int(t * 103))), alpha))
            ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        }

        // Hollow center — clear inner circle
        ctx.setBlendMode(.clear)
        ctx.fillEllipse(in: CGRect(x: cx - minR + 4, y: cy - minR + 4,
                                    width: (minR - 4) * 2, height: (minR - 4) * 2))
        ctx.setBlendMode(.normal)

        // Bright ring at inner edge
        ctx.setStrokeColor(cgColor(255, 255, 230, 200))
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: CGRect(x: cx - minR + 3, y: cy - minR + 3,
                                      width: (minR - 3) * 2, height: (minR - 3) * 2))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - EMP Flash (128x128)
    // Full radial gradient — cyan-white center fading to transparent blue.

    public static func makeEmpFlash() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 128, h = 128
        guard let ctx = makeSoftContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        // Radial gradient from bright center to transparent edge
        let maxR: CGFloat = 60
        let steps = 50
        for i in (0..<steps).reversed() {
            let t = CGFloat(i) / CGFloat(steps)
            let r = maxR * (1.0 - t)
            let alpha = UInt8(min(255, Int(t * 0.5 * 255)))
            let red = UInt8(min(255, Int(128 * t + 80 * (1.0 - t))))
            let green = UInt8(min(255, Int(178 * t + 120 * (1.0 - t))))
            ctx.setFillColor(cgColor(red, green, 255, alpha))
            ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        }

        // Bright white center
        ctx.setFillColor(cgColor(220, 240, 255, 180))
        ctx.fillEllipse(in: CGRect(x: cx - 8, y: cy - 8, width: 16, height: 16))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Overcharge Glow (64x64)
    // Soft diamond/star shape — orange-yellow center with transparent falloff.

    public static func makeOverchargeGlow() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 64, h = 64
        guard let ctx = makeSoftContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        // Layered diamond shapes from outer (transparent) to inner (bright)
        let layers = 8
        for i in (0..<layers).reversed() {
            let t = CGFloat(i) / CGFloat(layers)
            let size = 28 * (1.0 - t) + 4
            let alpha = UInt8(min(255, Int(t * 0.8 * 255)))
            let green = UInt8(min(255, Int(153 * t + 100 * (1.0 - t))))
            ctx.setFillColor(cgColor(255, green, 0, alpha))
            ctx.beginPath()
            ctx.move(to: CGPoint(x: cx, y: cy + size))
            ctx.addLine(to: CGPoint(x: cx - size * 0.6, y: cy))
            ctx.addLine(to: CGPoint(x: cx, y: cy - size))
            ctx.addLine(to: CGPoint(x: cx + size * 0.6, y: cy))
            ctx.closePath()
            ctx.fillPath()
        }

        // Bright center
        ctx.setFillColor(cgColor(255, 230, 150, 220))
        ctx.fillEllipse(in: CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - HUD Bar Frame (64x8)
    // Rounded-rect border, cyan (#00ffd2) outline, transparent interior.

    public static func makeHudBarFrame() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 64, h = 8
        guard let ctx = makeSoftContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let rect = CGRect(x: 1, y: 1, width: CGFloat(w) - 2, height: CGFloat(h) - 2)
        let path = CGPath(roundedRect: rect, cornerWidth: 2, cornerHeight: 2, transform: nil)
        ctx.setStrokeColor(cgColor(0, 255, 210, 200))
        ctx.setLineWidth(1)
        ctx.addPath(path)
        ctx.strokePath()

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - HUD Bar Fill (32x4)
    // Horizontal gradient pill, player cyan.

    public static func makeHudBarFill() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 32, h = 4
        guard let ctx = makeSoftContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let rect = CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h))
        let path = CGPath(roundedRect: rect, cornerWidth: 2, cornerHeight: 2, transform: nil)

        // Gradient from bright left to slightly dimmer right
        for x in 0..<w {
            let t = CGFloat(x) / CGFloat(w)
            let alpha = UInt8(min(255, Int((1.0 - t * 0.3) * 255)))
            ctx.setFillColor(cgColor(0, 255, 210, alpha))
            ctx.fill(CGRect(x: CGFloat(x), y: 0, width: 1, height: CGFloat(h)))
        }

        // Clip to rounded rect shape
        ctx.setBlendMode(.destinationIn)
        ctx.addPath(path)
        ctx.fillPath()
        ctx.setBlendMode(.normal)

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - HUD Charge Pip (12x12)
    // Small octagon, gold outline, dark fill, bright center dot.

    public static func makeHudChargePip() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 12, h = 12
        guard let ctx = makeSoftContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2
        let r: CGFloat = 4.5

        var pts: [CGPoint] = []
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4
            pts.append(CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle)))
        }

        // Dark fill
        ctx.setFillColor(cgColor(40, 30, 10))
        ctx.beginPath()
        ctx.move(to: pts[0])
        for pt in pts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.fillPath()

        // Gold outline
        ctx.setStrokeColor(cgColor(255, 218, 77))
        ctx.setLineWidth(1.5)
        ctx.beginPath()
        ctx.move(to: pts[0])
        for pt in pts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.strokePath()

        // Bright center
        ctx.setFillColor(cgColor(255, 240, 180))
        ctx.fillEllipse(in: CGRect(x: cx - 1.5, y: cy - 1.5, width: 3, height: 3))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - HUD Weapon Icon (16x8)
    // Small chevron pointing up, tinted per weapon type at runtime.

    public static func makeHudWeaponIcon() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 16, h = 8
        guard let ctx = makeSoftContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2

        // White chevron (will be tinted by RenderComponent.color at runtime)
        ctx.setFillColor(cgColor(255, 255, 255))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 1))
        ctx.addLine(to: CGPoint(x: 2, y: 2))
        ctx.addLine(to: CGPoint(x: 4, y: 2))
        ctx.addLine(to: CGPoint(x: cx, y: CGFloat(h) - 3))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 4, y: 2))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 2, y: 2))
        ctx.closePath()
        ctx.fillPath()

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - HUD Heat Frame (16x3)
    // Thin rounded-rect outline, neutral gray.

    public static func makeHudHeatFrame() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 16, h = 3
        guard let ctx = makeSoftContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let rect = CGRect(x: 0.5, y: 0.5, width: CGFloat(w) - 1, height: CGFloat(h) - 1)
        let path = CGPath(roundedRect: rect, cornerWidth: 1, cornerHeight: 1, transform: nil)
        ctx.setStrokeColor(cgColor(150, 150, 150, 180))
        ctx.setLineWidth(0.5)
        ctx.addPath(path)
        ctx.strokePath()

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - HUD Heat Fill (14x2)
    // Simple gradient pill, tinted green-to-red at runtime.

    public static func makeHudHeatFill() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 14, h = 2
        guard let ctx = makeSoftContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        // White fill (tinted at runtime)
        ctx.setFillColor(cgColor(255, 255, 255))
        let rect = CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h))
        let path = CGPath(roundedRect: rect, cornerWidth: 1, cornerHeight: 1, transform: nil)
        ctx.addPath(path)
        ctx.fillPath()

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }
}
