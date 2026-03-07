import GameplayKit
import simd

@MainActor
public final class ItemSystem {
    private var entities: [GKEntity] = []
    public private(set) var pendingDespawns: [GKEntity] = []

    private let bounceSpeed: Float = 30
    private let halfWidth: Float

    public init() {
        halfWidth = GameConfig.designWidth / 2
    }

    public func register(_ entity: GKEntity) {
        guard entity.component(ofType: ItemComponent.self) != nil,
              entity.component(ofType: PhysicsComponent.self) != nil,
              entity.component(ofType: TransformComponent.self) != nil,
              entity.component(ofType: RenderComponent.self) != nil else { return }
        entities.append(entity)
    }

    public func unregister(_ entity: GKEntity) {
        entities.removeAll { $0 === entity }
    }

    public func update(deltaTime: Double) {
        pendingDespawns.removeAll(keepingCapacity: true)

        for entity in entities {
            guard let item = entity.component(ofType: ItemComponent.self),
                  let physics = entity.component(ofType: PhysicsComponent.self),
                  let transform = entity.component(ofType: TransformComponent.self),
                  let render = entity.component(ofType: RenderComponent.self) else { continue }

            item.timeAlive += deltaTime

            if item.shouldDespawn {
                pendingDespawns.append(entity)
                continue
            }

            physics.velocity.y = -GameConfig.Item.driftSpeed
            physics.velocity.x = item.bounceDirection * bounceSpeed

            let margin: Float = 16 / 2
            if transform.position.x > halfWidth - margin {
                item.bounceDirection = -1
            } else if transform.position.x < -halfWidth + margin {
                item.bounceDirection = 1
            }

            if item.isWeaponModule {
                render.color = GameConfig.Palette.weaponModule
            } else {
                switch item.utilityItemType {
                case .energyCell:
                    render.color = GameConfig.Palette.item
                case .chargeCell:
                    render.color = GameConfig.Palette.chargeCell
                case .scoreBonus:
                    render.color = GameConfig.Palette.scoreBonus
                }
            }
        }
    }

    public func handleProjectileHit(on entity: GKEntity) {
        guard let item = entity.component(ofType: ItemComponent.self) else { return }
        item.advanceCycle()
    }
}
