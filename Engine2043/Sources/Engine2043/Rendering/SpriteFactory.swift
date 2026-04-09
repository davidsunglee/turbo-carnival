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

    // MARK: - Double Cannon Drop (24x24)
    // Two parallel vertical barrels with bright muzzle dots at top.

    public static func makeDoubleCannonDrop() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 24, h = 24
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        // Outer glow
        ctx.setFillColor(cgColor(0, 128, 255, 40))
        ctx.fillEllipse(in: CGRect(x: 2, y: 2, width: 20, height: 20))

        // Left barrel
        ctx.setFillColor(cgColor(0, 128, 255))
        ctx.fill(CGRect(x: 6, y: 5, width: 4, height: 14))
        // Right barrel
        ctx.fill(CGRect(x: 14, y: 5, width: 4, height: 14))

        // Barrel highlights
        ctx.setStrokeColor(cgColor(255, 255, 255, 200))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 8, y: 6))
        ctx.addLine(to: CGPoint(x: 8, y: 18))
        ctx.move(to: CGPoint(x: 16, y: 6))
        ctx.addLine(to: CGPoint(x: 16, y: 18))
        ctx.strokePath()

        // Muzzle flash dots
        ctx.setFillColor(cgColor(200, 230, 255))
        ctx.fillEllipse(in: CGRect(x: 6.5, y: 3, width: 3, height: 3))
        ctx.fillEllipse(in: CGRect(x: 14.5, y: 3, width: 3, height: 3))

        // Base connecting piece
        ctx.setFillColor(cgColor(0, 100, 200))
        ctx.fill(CGRect(x: 8, y: 17, width: 8, height: 3))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Tri-Spread Drop (24x24)
    // Three lines fanning upward from a common base — trident/spread shape.

    public static func makeTriSpreadDrop() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 24, h = 24
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        // Outer glow
        ctx.setFillColor(cgColor(255, 0, 51, 40))
        ctx.fillEllipse(in: CGRect(x: 2, y: 2, width: 20, height: 20))

        let baseX: CGFloat = 12
        let baseY: CGFloat = 20

        // Three spread lines (thick, filled)
        ctx.setStrokeColor(cgColor(255, 0, 51))
        ctx.setLineWidth(3)
        ctx.setLineCap(.round)
        ctx.beginPath()
        // Center prong
        ctx.move(to: CGPoint(x: baseX, y: baseY))
        ctx.addLine(to: CGPoint(x: baseX, y: 4))
        // Left prong
        ctx.move(to: CGPoint(x: baseX, y: baseY))
        ctx.addLine(to: CGPoint(x: 4, y: 6))
        // Right prong
        ctx.move(to: CGPoint(x: baseX, y: baseY))
        ctx.addLine(to: CGPoint(x: 20, y: 6))
        ctx.strokePath()

        // White highlight on center prong
        ctx.setStrokeColor(cgColor(255, 255, 255, 200))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: baseX, y: baseY - 1))
        ctx.addLine(to: CGPoint(x: baseX, y: 5))
        ctx.strokePath()

        // Bright tips
        ctx.setFillColor(cgColor(255, 200, 210))
        ctx.fillEllipse(in: CGRect(x: baseX - 1.5, y: 3, width: 3, height: 3))
        ctx.fillEllipse(in: CGRect(x: 3, y: 5, width: 3, height: 3))
        ctx.fillEllipse(in: CGRect(x: 19, y: 5, width: 3, height: 3))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Lightning Arc Drop (24x24)
    // Plasma ring — circle with 3-4 jagged sparks radiating outward.

    public static func makeLightningArcDrop() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 24, h = 24
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        // Outer glow
        ctx.setFillColor(cgColor(255, 255, 0, 40))
        ctx.fillEllipse(in: CGRect(x: 2, y: 2, width: 20, height: 20))

        // Main plasma ring
        ctx.setStrokeColor(cgColor(255, 255, 0))
        ctx.setLineWidth(2.5)
        ctx.strokeEllipse(in: CGRect(x: 6, y: 6, width: 12, height: 12))

        // Bright inner ring
        ctx.setFillColor(cgColor(255, 255, 200))
        ctx.fillEllipse(in: CGRect(x: cx - 2, y: cy - 2, width: 4, height: 4))

        // 4 jagged sparks radiating outward
        ctx.setStrokeColor(cgColor(255, 255, 100))
        ctx.setLineWidth(1.5)
        ctx.setLineCap(.round)
        ctx.beginPath()
        // Top spark
        ctx.move(to: CGPoint(x: cx, y: 6))
        ctx.addLine(to: CGPoint(x: cx - 1, y: 3))
        ctx.addLine(to: CGPoint(x: cx + 1, y: 1))
        // Right spark
        ctx.move(to: CGPoint(x: 18, y: cy))
        ctx.addLine(to: CGPoint(x: 21, y: cy - 1))
        ctx.addLine(to: CGPoint(x: 23, y: cy + 1))
        // Bottom spark
        ctx.move(to: CGPoint(x: cx, y: 18))
        ctx.addLine(to: CGPoint(x: cx + 1, y: 21))
        ctx.addLine(to: CGPoint(x: cx - 1, y: 23))
        // Left spark
        ctx.move(to: CGPoint(x: 6, y: cy))
        ctx.addLine(to: CGPoint(x: 3, y: cy + 1))
        ctx.addLine(to: CGPoint(x: 1, y: cy - 1))
        ctx.strokePath()

        // White highlight on ring top
        ctx.setStrokeColor(cgColor(255, 255, 255, 200))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.addArc(center: CGPoint(x: cx, y: cy), radius: 6, startAngle: -.pi * 0.7, endAngle: -.pi * 0.3, clockwise: false)
        ctx.strokePath()

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Phase Laser Drop (24x24)
    // Focused beam line with lens circle at base, radiating lines at tip.

    public static func makePhaseLaserDrop() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 24, h = 24
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2

        // Outer glow
        ctx.setFillColor(cgColor(0, 255, 51, 40))
        ctx.fillEllipse(in: CGRect(x: 2, y: 2, width: 20, height: 20))

        // Beam line (thick)
        ctx.setStrokeColor(cgColor(0, 255, 51))
        ctx.setLineWidth(3)
        ctx.setLineCap(.round)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: 18))
        ctx.addLine(to: CGPoint(x: cx, y: 5))
        ctx.strokePath()

        // Lens circle at base
        ctx.setStrokeColor(cgColor(0, 200, 40))
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: CGRect(x: cx - 4, y: 16, width: 8, height: 6))

        // Radiating lines at tip
        ctx.setStrokeColor(cgColor(0, 255, 51))
        ctx.setLineWidth(1.5)
        ctx.setLineCap(.round)
        ctx.beginPath()
        // Center tip
        ctx.move(to: CGPoint(x: cx, y: 5))
        ctx.addLine(to: CGPoint(x: cx, y: 2))
        // Left ray
        ctx.move(to: CGPoint(x: cx, y: 5))
        ctx.addLine(to: CGPoint(x: cx - 4, y: 2))
        // Right ray
        ctx.move(to: CGPoint(x: cx, y: 5))
        ctx.addLine(to: CGPoint(x: cx + 4, y: 2))
        ctx.strokePath()

        // White highlight down beam center
        ctx.setStrokeColor(cgColor(255, 255, 255, 200))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: 17))
        ctx.addLine(to: CGPoint(x: cx, y: 6))
        ctx.strokePath()

        // Bright tip dot
        ctx.setFillColor(cgColor(200, 255, 220))
        ctx.fillEllipse(in: CGRect(x: cx - 1.5, y: 2, width: 3, height: 3))

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

    // MARK: - Bitmap Font Glyphs (6x8 each)
    // 5x7 pixel font in a 6x8 cell. Row 7 and column 5 are transparent spacing.
    // Each UInt8 encodes 5 pixels: bit 4 = leftmost, bit 0 = rightmost.

    private static let glyphPatterns: [Character: [UInt8]] = [
        "0": [0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E],
        "1": [0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E],
        "2": [0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F],
        "3": [0x0E, 0x11, 0x01, 0x06, 0x01, 0x11, 0x0E],
        "4": [0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02],
        "5": [0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E],
        "6": [0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E],
        "7": [0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08],
        "8": [0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E],
        "9": [0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C],
        "A": [0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11],
        "B": [0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E],
        "C": [0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E],
        "D": [0x1C, 0x12, 0x11, 0x11, 0x11, 0x12, 0x1C],
        "E": [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F],
        "F": [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10],
        "G": [0x0E, 0x11, 0x10, 0x13, 0x11, 0x11, 0x0E],
        "H": [0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11],
        "I": [0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E],
        "J": [0x07, 0x02, 0x02, 0x02, 0x02, 0x12, 0x0C],
        "K": [0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11],
        "L": [0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F],
        "M": [0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11],
        "N": [0x11, 0x11, 0x19, 0x15, 0x13, 0x11, 0x11],
        "O": [0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E],
        "P": [0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10],
        "Q": [0x0E, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0D],
        "R": [0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11],
        "S": [0x0E, 0x11, 0x10, 0x0E, 0x01, 0x11, 0x0E],
        "T": [0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04],
        "U": [0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E],
        "V": [0x11, 0x11, 0x11, 0x11, 0x11, 0x0A, 0x04],
        "W": [0x11, 0x11, 0x11, 0x15, 0x15, 0x1B, 0x11],
        "X": [0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11],
        "Y": [0x11, 0x11, 0x0A, 0x04, 0x04, 0x04, 0x04],
        "Z": [0x1F, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1F],
        "-": [0x00, 0x00, 0x00, 0x0E, 0x00, 0x00, 0x00],
        ".": [0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x06],
        ":": [0x00, 0x06, 0x06, 0x00, 0x06, 0x06, 0x00],
        " ": [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
    ]

    // MARK: - Galaxy 2: Asteroid Small (16x16)
    // Irregular 6-sided polygon, gray-brown fill, lighter edge highlights.

    public static func makeAsteroidSmall() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 16, h = 16
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        // Deterministic irregular hexagon — hardcoded offsets
        let pts: [CGPoint] = [
            CGPoint(x: 8, y: 1),
            CGPoint(x: 14, y: 4),
            CGPoint(x: 15, y: 9),
            CGPoint(x: 11, y: 14),
            CGPoint(x: 4, y: 13),
            CGPoint(x: 1, y: 7),
        ]

        // Gray-brown fill
        ctx.setFillColor(cgColor(110, 95, 80))
        ctx.beginPath()
        ctx.move(to: pts[0])
        for pt in pts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.fillPath()

        // Slightly lighter edge highlight
        ctx.setStrokeColor(cgColor(145, 130, 110))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: pts[0])
        for pt in pts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.strokePath()

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Galaxy 2: Asteroid Large (40x40)
    // Bigger, darker, more angular irregular polygon with heavier outlines.

    public static func makeAsteroidLarge() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 40, h = 40
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        // Deterministic irregular 7-sided polygon — hardcoded
        let pts: [CGPoint] = [
            CGPoint(x: 20, y: 2),
            CGPoint(x: 35, y: 6),
            CGPoint(x: 38, y: 18),
            CGPoint(x: 32, y: 34),
            CGPoint(x: 18, y: 38),
            CGPoint(x: 5, y: 30),
            CGPoint(x: 2, y: 14),
        ]

        // Darker gray-brown fill
        ctx.setFillColor(cgColor(80, 68, 55))
        ctx.beginPath()
        ctx.move(to: pts[0])
        for pt in pts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.fillPath()

        // Interior surface detail — lighter mid-band
        ctx.setFillColor(cgColor(95, 82, 68))
        let innerPts: [CGPoint] = [
            CGPoint(x: 20, y: 8),
            CGPoint(x: 30, y: 12),
            CGPoint(x: 28, y: 22),
            CGPoint(x: 18, y: 28),
            CGPoint(x: 10, y: 22),
            CGPoint(x: 12, y: 12),
        ]
        ctx.beginPath()
        ctx.move(to: innerPts[0])
        for pt in innerPts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.fillPath()

        // Heavier outline
        ctx.setStrokeColor(cgColor(130, 115, 96))
        ctx.setLineWidth(2)
        ctx.beginPath()
        ctx.move(to: pts[0])
        for pt in pts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.strokePath()

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Galaxy 2: Mining Barge Hull (108x50)
    // Dark industrial gray-purple with panel lines and structural detail.

    public static func makeMiningBargeHull() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 108, h = 50
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cw = CGFloat(w)
        let ch = CGFloat(h)

        // Main hull — dark gray-purple
        ctx.setFillColor(cgColor(45, 38, 58))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 8, y: 4))
        ctx.addLine(to: CGPoint(x: cw - 8, y: 4))
        ctx.addLine(to: CGPoint(x: cw - 2, y: 14))
        ctx.addLine(to: CGPoint(x: cw - 2, y: ch - 14))
        ctx.addLine(to: CGPoint(x: cw - 8, y: ch - 4))
        ctx.addLine(to: CGPoint(x: 8, y: ch - 4))
        ctx.addLine(to: CGPoint(x: 2, y: ch - 14))
        ctx.addLine(to: CGPoint(x: 2, y: 14))
        ctx.closePath()
        ctx.fillPath()

        // Panel lines — darker recesses
        ctx.setStrokeColor(cgColor(30, 24, 42))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 10, y: 16)); ctx.addLine(to: CGPoint(x: cw - 10, y: 16))
        ctx.move(to: CGPoint(x: 10, y: ch - 16)); ctx.addLine(to: CGPoint(x: cw - 10, y: ch - 16))
        ctx.move(to: CGPoint(x: 28, y: 6)); ctx.addLine(to: CGPoint(x: 28, y: ch - 6))
        ctx.move(to: CGPoint(x: 54, y: 6)); ctx.addLine(to: CGPoint(x: 54, y: ch - 6))
        ctx.move(to: CGPoint(x: 80, y: 6)); ctx.addLine(to: CGPoint(x: 80, y: ch - 6))
        ctx.strokePath()

        // Mining arm recesses — dark rectangular bays
        ctx.setFillColor(cgColor(28, 22, 38))
        ctx.fill(CGRect(x: 4, y: 18, width: 16, height: 14))
        ctx.fill(CGRect(x: cw - 20, y: 18, width: 16, height: 14))

        // Bridge — slightly lighter purple
        ctx.setFillColor(cgColor(62, 50, 78))
        ctx.fill(CGRect(x: 42, y: 18, width: 24, height: 14))

        // Outer edge highlight
        ctx.setStrokeColor(cgColor(78, 65, 98))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 8, y: 4))
        ctx.addLine(to: CGPoint(x: cw - 8, y: 4))
        ctx.addLine(to: CGPoint(x: cw - 2, y: 14))
        ctx.addLine(to: CGPoint(x: cw - 2, y: ch - 14))
        ctx.addLine(to: CGPoint(x: cw - 8, y: ch - 4))
        ctx.addLine(to: CGPoint(x: 8, y: ch - 4))
        ctx.addLine(to: CGPoint(x: 2, y: ch - 14))
        ctx.addLine(to: CGPoint(x: 2, y: 14))
        ctx.closePath()
        ctx.strokePath()

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Galaxy 2: Mining Barge Turret (24x24)
    // Octagonal ring, purple-tinted.

    public static func makeMiningBargeTurret() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 24, h = 24
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2
        let outerR: CGFloat = 10
        let innerR: CGFloat = 6
        var outerPts: [CGPoint] = []
        var innerPts: [CGPoint] = []
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4
            outerPts.append(CGPoint(x: cx + outerR * cos(angle), y: cy + outerR * sin(angle)))
            innerPts.append(CGPoint(x: cx + innerR * cos(angle), y: cy + innerR * sin(angle)))
        }

        // Purple-tinted outer fill
        ctx.setFillColor(cgColor(140, 80, 180))
        ctx.beginPath()
        ctx.move(to: outerPts[0])
        for pt in outerPts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.fillPath()

        // Dark inner cutout
        ctx.setFillColor(cgColor(30, 18, 45))
        ctx.beginPath()
        ctx.move(to: innerPts[0])
        for pt in innerPts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.fillPath()

        // Bright purple barrel dot
        ctx.setFillColor(cgColor(210, 170, 255))
        ctx.fillEllipse(in: CGRect(x: cx - 2, y: cy - 2, width: 4, height: 4))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Galaxy 2: Lithic Harvester Core (80x80)
    // Octagonal core with purple-magenta tones. Heavy armor plating.

    public static func makeLithicHarvesterCore() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 80, h = 80
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

        // Outer armor ring — dark purple
        let outerPts = octagon(center: center, radius: 36)
        ctx.setFillColor(cgColor(55, 28, 70))
        ctx.beginPath()
        ctx.move(to: outerPts[0])
        for pt in outerPts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.fillPath()

        // Outer stroke — bright magenta
        ctx.setStrokeColor(cgColor(200, 60, 180))
        ctx.setLineWidth(3)
        ctx.beginPath()
        ctx.move(to: outerPts[0])
        for pt in outerPts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.strokePath()

        // Armor plating detail lines
        ctx.setStrokeColor(cgColor(80, 40, 100))
        ctx.setLineWidth(1.5)
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4
            let inner = CGPoint(x: cx + 24 * cos(angle), y: cy + 24 * sin(angle))
            let outer2 = CGPoint(x: cx + 34 * cos(angle), y: cy + 34 * sin(angle))
            ctx.beginPath()
            ctx.move(to: inner)
            ctx.addLine(to: outer2)
            ctx.strokePath()
        }

        // Mid ring
        let midPts = octagon(center: center, radius: 22)
        ctx.setFillColor(cgColor(40, 20, 55))
        ctx.beginPath()
        ctx.move(to: midPts[0])
        for pt in midPts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.fillPath()

        ctx.setStrokeColor(cgColor(160, 80, 200))
        ctx.setLineWidth(2)
        ctx.beginPath()
        ctx.move(to: midPts[0])
        for pt in midPts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.strokePath()

        // Inner core — bright magenta-purple
        let innerPts = octagon(center: center, radius: 10)
        ctx.setFillColor(cgColor(200, 120, 220))
        ctx.beginPath()
        ctx.move(to: innerPts[0])
        for pt in innerPts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.fillPath()

        // Bright center dot
        ctx.setFillColor(cgColor(240, 210, 255))
        ctx.fillEllipse(in: CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Galaxy 2: Tractor Beam Segment (4x32)
    // Thin cyan-white beam segment.

    public static func makeTractorBeamSegment() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 4, h = 32
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cw = CGFloat(w)

        // Cyan-white vertical beam — bright center, fades at edges
        for x in 0..<w {
            let t = abs(CGFloat(x) - cw / 2 + 0.5) / (cw / 2)
            let alpha = UInt8(min(255, Int((1.0 - t * 0.6) * 220)))
            let brightness = UInt8(min(255, Int(200 + (1.0 - t) * 55)))
            ctx.setFillColor(cgColor(brightness, 255, 255, alpha))
            ctx.fill(CGRect(x: CGFloat(x), y: 0, width: 1, height: CGFloat(h)))
        }

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Galaxy 2: G2 Interceptor (20x20)
    // Sleek downward dart, muted pink/violet tones.

    public static func makeG2Interceptor() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 20, h = 20
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2

        // Muted pink-violet fill
        ctx.setFillColor(cgColor(90, 50, 100))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: 2))
        ctx.addLine(to: CGPoint(x: 3, y: CGFloat(h) - 3))
        ctx.addLine(to: CGPoint(x: cx, y: CGFloat(h) - 8))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 3, y: CGFloat(h) - 3))
        ctx.closePath()
        ctx.fillPath()

        // Pink-violet outline
        ctx.setStrokeColor(cgColor(180, 120, 200))
        ctx.setLineWidth(1.5)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: 2))
        ctx.addLine(to: CGPoint(x: 3, y: CGFloat(h) - 3))
        ctx.addLine(to: CGPoint(x: cx, y: CGFloat(h) - 8))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 3, y: CGFloat(h) - 3))
        ctx.closePath()
        ctx.strokePath()

        // Bright energy core
        ctx.setFillColor(cgColor(230, 200, 240))
        ctx.fillEllipse(in: CGRect(x: cx - 2, y: 8, width: 4, height: 4))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Galaxy 2: G2 Fighter (40x40)
    // Hexagonal body, violet/magenta tones with extra detail.

    public static func makeG2Fighter() -> (pixels: [UInt8], width: Int, height: Int) {
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

        // Dark violet fill
        ctx.setFillColor(cgColor(45, 22, 65))
        ctx.beginPath()
        ctx.move(to: hexPoints[0])
        for pt in hexPoints.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.fillPath()

        // Violet-magenta outline (thick)
        ctx.setStrokeColor(cgColor(180, 80, 200))
        ctx.setLineWidth(3)
        ctx.beginPath()
        ctx.move(to: hexPoints[0])
        for pt in hexPoints.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.strokePath()

        // Inner panel detail lines
        ctx.setStrokeColor(cgColor(80, 40, 110))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx - 8, y: cy - 6)); ctx.addLine(to: CGPoint(x: cx + 8, y: cy - 6))
        ctx.move(to: CGPoint(x: cx - 8, y: cy + 6)); ctx.addLine(to: CGPoint(x: cx + 8, y: cy + 6))
        ctx.strokePath()

        // Turret dots on sides
        ctx.setFillColor(cgColor(210, 160, 240))
        ctx.fillEllipse(in: CGRect(x: 4, y: cy - 2, width: 4, height: 4))
        ctx.fillEllipse(in: CGRect(x: CGFloat(w) - 8, y: cy - 2, width: 4, height: 4))

        // Bright magenta core
        ctx.setFillColor(cgColor(230, 180, 255))
        ctx.fillEllipse(in: CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Tractor Beam Glow Effect (32x64)
    // Soft cyan gradient glow strip, fading from center outward.

    public static func makeTractorBeamGlow() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 32, h = 64
        guard let ctx = makeSoftContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cw = CGFloat(w)

        // Horizontal gradient — bright at center, transparent at edges
        for x in 0..<w {
            let t = abs(CGFloat(x) - cw / 2 + 0.5) / (cw / 2)  // 0 at center, 1 at edge
            let alpha = UInt8(min(255, Int((1.0 - t * t) * 180)))
            let greenBlue = UInt8(min(255, Int(200 + (1.0 - t) * 55)))
            ctx.setFillColor(cgColor(0, greenBlue, 255, alpha))
            ctx.fill(CGRect(x: CGFloat(x), y: 0, width: 1, height: CGFloat(h)))
        }

        // Bright center line
        ctx.setFillColor(cgColor(180, 255, 255, 200))
        ctx.fill(CGRect(x: cw / 2 - 1, y: 0, width: 2, height: CGFloat(h)))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Bitmap Font Glyphs (6x8 each)
    public static func makeBitmapGlyph(_ char: Character) -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 6, h = 8
        let pattern = glyphPatterns[char] ?? [UInt8](repeating: 0, count: 7)
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }
        ctx.setFillColor(cgColor(255, 255, 255))
        for row in 0..<7 {
            let bits = pattern[row]
            for col in 0..<5 {
                if bits & (1 << (4 - col)) != 0 {
                    ctx.fill(CGRect(x: CGFloat(col), y: CGFloat(h - 1 - row), width: 1, height: 1))
                }
            }
        }
        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Galaxy 3: Tracking Drone (18x18)
    // Small dart shape, icy blue tones.

    public static func makeG3TrackingDrone() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 18, h = 18
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2

        // Dark icy-blue fill
        ctx.setFillColor(cgColor(30, 60, 100))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 2))
        ctx.addLine(to: CGPoint(x: 2, y: 4))
        ctx.addLine(to: CGPoint(x: cx, y: 8))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 2, y: 4))
        ctx.closePath()
        ctx.fillPath()

        // Icy blue outline
        ctx.setStrokeColor(cgColor(153, 204, 255))
        ctx.setLineWidth(1.5)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 2))
        ctx.addLine(to: CGPoint(x: 2, y: 4))
        ctx.addLine(to: CGPoint(x: cx, y: 8))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 2, y: 4))
        ctx.closePath()
        ctx.strokePath()

        // Bright core dot
        ctx.setFillColor(cgColor(200, 230, 255))
        ctx.fillEllipse(in: CGRect(x: cx - 2, y: 10, width: 4, height: 4))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Galaxy 3: Fighter (26x26)
    // Angular fighter, deeper blue palette.

    public static func makeG3Fighter() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 26, h = 26
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        // Dark blue fill — angular hexagonal shape
        ctx.setFillColor(cgColor(25, 40, 80))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 2))
        ctx.addLine(to: CGPoint(x: 2, y: cy + 4))
        ctx.addLine(to: CGPoint(x: 4, y: 4))
        ctx.addLine(to: CGPoint(x: cx, y: 2))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 4, y: 4))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 2, y: cy + 4))
        ctx.closePath()
        ctx.fillPath()

        // Deep blue outline
        ctx.setStrokeColor(cgColor(102, 153, 255))
        ctx.setLineWidth(2)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 2))
        ctx.addLine(to: CGPoint(x: 2, y: cy + 4))
        ctx.addLine(to: CGPoint(x: 4, y: 4))
        ctx.addLine(to: CGPoint(x: cx, y: 2))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 4, y: 4))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 2, y: cy + 4))
        ctx.closePath()
        ctx.strokePath()

        // Wing detail lines
        ctx.setStrokeColor(cgColor(50, 80, 130))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 6, y: cy))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 6, y: cy))
        ctx.strokePath()

        // Engine glow dots
        ctx.setFillColor(cgColor(150, 200, 255))
        ctx.fillEllipse(in: CGRect(x: 5, y: cy + 2, width: 3, height: 3))
        ctx.fillEllipse(in: CGRect(x: CGFloat(w) - 8, y: cy + 2, width: 3, height: 3))

        // Bright core
        ctx.setFillColor(cgColor(180, 220, 255))
        ctx.fillEllipse(in: CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Galaxy 3: Fortress Hull (120x70)
    // Half-size of design (240x140), dark industrial plating.

    public static func makeG3FortressHull() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 120, h = 70
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        // Dark hull base fill
        ctx.setFillColor(cgColor(64, 77, 115))
        ctx.fill(CGRect(x: 2, y: 2, width: w - 4, height: h - 4))

        // Darker inner panel
        ctx.setFillColor(cgColor(45, 55, 85))
        ctx.fill(CGRect(x: 8, y: 8, width: w - 16, height: h - 16))

        // Panel line details — horizontal
        ctx.setStrokeColor(cgColor(80, 95, 130))
        ctx.setLineWidth(1)
        for yOff in stride(from: 14, to: h - 8, by: 14) {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 10, y: CGFloat(yOff)))
            ctx.addLine(to: CGPoint(x: CGFloat(w - 10), y: CGFloat(yOff)))
            ctx.strokePath()
        }

        // Panel line details — vertical
        for xOff in stride(from: 20, to: w - 8, by: 24) {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: CGFloat(xOff), y: 10))
            ctx.addLine(to: CGPoint(x: CGFloat(xOff), y: CGFloat(h - 10)))
            ctx.strokePath()
        }

        // Hull outline
        ctx.setStrokeColor(cgColor(100, 115, 150))
        ctx.setLineWidth(2)
        ctx.stroke(CGRect(x: 2, y: 2, width: w - 4, height: h - 4))

        // Corner rivets
        let rivetColor = cgColor(120, 135, 170)
        ctx.setFillColor(rivetColor)
        ctx.fillEllipse(in: CGRect(x: 4, y: 4, width: 4, height: 4))
        ctx.fillEllipse(in: CGRect(x: CGFloat(w - 8), y: 4, width: 4, height: 4))
        ctx.fillEllipse(in: CGRect(x: 4, y: CGFloat(h - 8), width: 4, height: 4))
        ctx.fillEllipse(in: CGRect(x: CGFloat(w - 8), y: CGFloat(h - 8), width: 4, height: 4))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Galaxy 3: Fortress Node (24x24)
    // Small turret/generator node.

    public static func makeG3FortressNode() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 24, h = 24
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        // Base octagon
        ctx.setFillColor(cgColor(50, 65, 100))
        let r: CGFloat = 10
        ctx.beginPath()
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4 - .pi / 8
            let pt = CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
            if i == 0 { ctx.move(to: pt) } else { ctx.addLine(to: pt) }
        }
        ctx.closePath()
        ctx.fillPath()

        // Outline
        ctx.setStrokeColor(cgColor(120, 160, 220))
        ctx.setLineWidth(1.5)
        ctx.beginPath()
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4 - .pi / 8
            let pt = CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
            if i == 0 { ctx.move(to: pt) } else { ctx.addLine(to: pt) }
        }
        ctx.closePath()
        ctx.strokePath()

        // Central energy core
        ctx.setFillColor(cgColor(180, 220, 255))
        ctx.fillEllipse(in: CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8))

        // Inner ring
        ctx.setStrokeColor(cgColor(100, 150, 200))
        ctx.setLineWidth(1)
        ctx.strokeEllipse(in: CGRect(x: cx - 6, y: cy - 6, width: 12, height: 12))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Galaxy 3: Barrier Wall (40x120)
    // Grey-blue metal barrier segment.

    public static func makeG3BarrierWall() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 40, h = 120
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        // Base fill
        ctx.setFillColor(cgColor(89, 102, 128))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        // Darker inner panels
        ctx.setFillColor(cgColor(70, 82, 110))
        ctx.fill(CGRect(x: 4, y: 4, width: w - 8, height: h - 8))

        // Horizontal rivets / panel lines
        ctx.setStrokeColor(cgColor(110, 125, 155))
        ctx.setLineWidth(1)
        for yOff in stride(from: 15, to: h, by: 20) {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 4, y: CGFloat(yOff)))
            ctx.addLine(to: CGPoint(x: CGFloat(w - 4), y: CGFloat(yOff)))
            ctx.strokePath()
        }

        // Edge highlight (left)
        ctx.setFillColor(cgColor(130, 145, 175))
        ctx.fill(CGRect(x: 0, y: 0, width: 2, height: h))

        // Edge shadow (right)
        ctx.setFillColor(cgColor(55, 65, 90))
        ctx.fill(CGRect(x: w - 2, y: 0, width: 2, height: h))

        // Outer border
        ctx.setStrokeColor(cgColor(100, 115, 145))
        ctx.setLineWidth(1.5)
        ctx.stroke(CGRect(x: 1, y: 1, width: w - 2, height: h - 2))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Galaxy 3: Zenith Core (80x80)
    // Boss core, warm orange-red glow.

    public static func makeG3ZenithCore() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 80, h = 80
        guard let ctx = makeSoftContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        // Outer glow halo
        ctx.setFillColor(cgColor(255, 80, 30, 40))
        ctx.fillEllipse(in: CGRect(x: cx - 38, y: cy - 38, width: 76, height: 76))

        // Main body — dark armored shell
        ctx.setFillColor(cgColor(60, 25, 15))
        ctx.fillEllipse(in: CGRect(x: cx - 30, y: cy - 30, width: 60, height: 60))

        // Armored ring
        ctx.setStrokeColor(cgColor(180, 70, 30))
        ctx.setLineWidth(3)
        ctx.strokeEllipse(in: CGRect(x: cx - 28, y: cy - 28, width: 56, height: 56))

        // Inner ring detail
        ctx.setStrokeColor(cgColor(120, 50, 20))
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: CGRect(x: cx - 20, y: cy - 20, width: 40, height: 40))

        // Central eye / core
        ctx.setFillColor(cgColor(255, 120, 50))
        ctx.fillEllipse(in: CGRect(x: cx - 10, y: cy - 10, width: 20, height: 20))

        // Hot center
        ctx.setFillColor(cgColor(255, 200, 150))
        ctx.fillEllipse(in: CGRect(x: cx - 5, y: cy - 5, width: 10, height: 10))

        // Vent lines radiating from center
        ctx.setStrokeColor(cgColor(200, 80, 30, 180))
        ctx.setLineWidth(1)
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4
            ctx.beginPath()
            ctx.move(to: CGPoint(x: cx + 14 * cos(angle), y: cy + 14 * sin(angle)))
            ctx.addLine(to: CGPoint(x: cx + 26 * cos(angle), y: cy + 26 * sin(angle)))
            ctx.strokePath()
        }

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Galaxy 3: Zenith Shield (40x12)
    // Shield segment, blue tint.

    public static func makeG3ZenithShield() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 40, h = 12
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        // Semi-transparent blue shield fill
        ctx.setFillColor(cgColor(102, 179, 255, 180))
        ctx.fill(CGRect(x: 2, y: 2, width: w - 4, height: h - 4))

        // Bright edge outline
        ctx.setStrokeColor(cgColor(150, 210, 255, 220))
        ctx.setLineWidth(1.5)
        ctx.stroke(CGRect(x: 1, y: 1, width: w - 2, height: h - 2))

        // Center highlight line
        ctx.setFillColor(cgColor(200, 235, 255, 200))
        ctx.fill(CGRect(x: 4, y: h / 2 - 1, width: w - 8, height: 2))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Galaxy 3: EMP Projectile (10x10)
    // Bright flash projectile.

    public static func makeG3EmpProjectile() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 10, h = 10
        guard let ctx = makeSoftContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        // Outer glow
        ctx.setFillColor(cgColor(204, 230, 255, 100))
        ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: w, height: h))

        // Inner bright flash
        ctx.setFillColor(cgColor(220, 240, 255, 220))
        ctx.fillEllipse(in: CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6))

        // Hot center
        ctx.setFillColor(cgColor(255, 255, 255, 255))
        ctx.fillEllipse(in: CGRect(x: cx - 1.5, y: cy - 1.5, width: 3, height: 3))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }
}
