import GameplayKit
import simd

@MainActor
public final class FormationSystem {
    private var entities: [GKEntity] = []

    public init() {}

    public func register(_ entity: GKEntity) {
        guard entity.component(ofType: FormationComponent.self) != nil,
              entity.component(ofType: PhysicsComponent.self) != nil,
              entity.component(ofType: TransformComponent.self) != nil else { return }
        entities.append(entity)
    }

    public func unregister(_ entity: GKEntity) {
        entities.removeAll { $0 === entity }
    }

    public func update(deltaTime: Double) {
        for entity in entities {
            guard let formation = entity.component(ofType: FormationComponent.self),
                  let physics = entity.component(ofType: PhysicsComponent.self) else { continue }

            formation.elapsedTime += deltaTime

            switch formation.pattern {
            case .vShape:
                physics.velocity = SIMD2(0, -GameConfig.Enemy.tier1Speed)

            case .sineWave:
                let frequency: Float = 2.0
                let amplitude: Float = 120.0
                let xVel = cos(Float(formation.elapsedTime) * frequency + formation.phaseOffset) * amplitude
                physics.velocity = SIMD2(xVel, -GameConfig.Enemy.tier1Speed)

            case .staggeredLine:
                let delayOffset = Float(formation.index) * 0.3
                if Float(formation.elapsedTime) > delayOffset {
                    physics.velocity = SIMD2(0, -GameConfig.Enemy.tier1Speed * 1.2)
                } else {
                    physics.velocity = .zero
                }
            }
        }
    }
}
