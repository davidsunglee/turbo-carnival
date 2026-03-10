import simd

@MainActor
public enum MenuInput {
    /// A menu option with a label, position, and bounding rect
    public struct Option {
        public let label: String
        public let position: SIMD2<Float>
        public let scale: Float

        public init(label: String, position: SIMD2<Float>, scale: Float = 2.0) {
            self.label = label
            self.position = position
            self.scale = scale
        }

        /// Bounding rect in game design coordinates (centered on position)
        public var bounds: (min: SIMD2<Float>, max: SIMD2<Float>) {
            let glyphW: Float = 6 * scale
            let glyphH: Float = 8 * scale
            let totalWidth = Float(label.count) * glyphW
            let halfW = totalWidth / 2
            let halfH = glyphH / 2
            // Add some padding for easier tapping
            let padX: Float = 10
            let padY: Float = 8
            return (
                min: SIMD2(position.x - halfW - padX, position.y - halfH - padY),
                max: SIMD2(position.x + halfW + padX, position.y + halfH + padY)
            )
        }
    }

    /// Check if a tap position hits any option, return its index
    public static func hitTest(tapPosition: SIMD2<Float>, options: [Option]) -> Int? {
        for (i, option) in options.enumerated() {
            let b = option.bounds
            if tapPosition.x >= b.min.x && tapPosition.x <= b.max.x &&
               tapPosition.y >= b.min.y && tapPosition.y <= b.max.y {
                return i
            }
        }
        return nil
    }
}
