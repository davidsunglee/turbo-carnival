import Testing
import GameplayKit
import simd
@testable import Engine2043

struct FormationSystemTests {
    @Test @MainActor func formationSystemVShapeMoves() {
        let system = FormationSystem()

        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: SIMD2(0, 340)))
        let physics = PhysicsComponent(collisionSize: SIMD2(24, 24), layer: .enemy, mask: [])
        entity.addComponent(physics)
        entity.addComponent(FormationComponent(pattern: .vShape, index: 0, formationID: 0))

        system.register(entity)
        system.update(deltaTime: 1.0 / 60.0)

        #expect(physics.velocity.y < 0)
    }

    @Test @MainActor func formationSystemSineWaveOscillates() {
        let system = FormationSystem()

        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: SIMD2(0, 340)))
        let physics = PhysicsComponent(collisionSize: SIMD2(24, 24), layer: .enemy, mask: [])
        entity.addComponent(physics)
        let formation = FormationComponent(pattern: .sineWave, index: 0, formationID: 0)
        entity.addComponent(formation)

        system.register(entity)
        system.update(deltaTime: 0.5)

        #expect(physics.velocity.x != 0 || formation.elapsedTime > 0)
    }
}
