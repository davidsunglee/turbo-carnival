import simd

public enum GameConfig {
    public static let fixedTimeStep: Double = 1.0 / 60.0
    public static let maxFrameTime: Double = 1.0 / 4.0

    public static let designWidth: Float = 360
    public static let designHeight: Float = 640

    public enum Palette {
        public static let background = SIMD4<Float>(10.0 / 255.0, 0.0, 71.0 / 255.0, 1.0)
        public static let midground = SIMD4<Float>(0.0, 70.0 / 255.0, 135.0 / 255.0, 1.0)
        public static let player = SIMD4<Float>(0.0, 1.0, 210.0 / 255.0, 1.0)
        public static let enemy = SIMD4<Float>(247.0 / 255.0, 118.0 / 255.0, 142.0 / 255.0, 1.0)
        public static let hostileProjectile = SIMD4<Float>(1.0, 158.0 / 255.0, 100.0 / 255.0, 1.0)
        public static let item = SIMD4<Float>(224.0 / 255.0, 175.0 / 255.0, 104.0 / 255.0, 1.0)
    }
}
