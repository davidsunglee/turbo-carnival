import simd

@MainActor
public final class GalaxyTitleCard {
    public enum Phase { case fadeIn, hold, fadeOut, done }
    
    public private(set) var phase: Phase = .fadeIn
    public private(set) var alpha: Float = 0
    
    private let title: String
    private let fadeInDuration: Double = 0.8
    private let holdDuration: Double = 1.5
    private let fadeOutDuration: Double = 0.8
    private var timer: Double = 0
    
    public var isDone: Bool { phase == .done }
    
    public init(title: String) {
        self.title = title
    }
    
    public func update(deltaTime: Double) {
        timer += deltaTime
        
        switch phase {
        case .fadeIn:
            let progress = min(1.0, timer / fadeInDuration)
            alpha = Float(progress)
            if progress >= 1.0 {
                phase = .hold
                timer = 0
            }
            
        case .hold:
            alpha = 1.0
            if timer >= holdDuration {
                phase = .fadeOut
                timer = 0
            }
            
        case .fadeOut:
            let progress = min(1.0, timer / fadeOutDuration)
            alpha = Float(1.0 - progress)
            if progress >= 1.0 {
                phase = .done
                alpha = 0
            }
            
        case .done:
            alpha = 0
        }
    }
    
    public func collectSprites(effectSheet: EffectTextureSheet?) -> [SpriteInstance] {
        guard let effectSheet else { return [] }
        
        let color = SIMD4<Float>(1, 1, 1, alpha)
        let sprites = BitmapText.makeSprites(
            title,
            at: SIMD2<Float>(0, 0),
            color: color,
            scale: 3.0,
            effectSheet: effectSheet
        )
        
        return sprites
    }
}
