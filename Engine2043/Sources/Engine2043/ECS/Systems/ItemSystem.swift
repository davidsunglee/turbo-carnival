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

            let margin: Float = GameConfig.Item.size.x / 2
            if transform.position.x > halfWidth - margin {
                item.bounceDirection = -1
            } else if transform.position.x < -halfWidth + margin {
                item.bounceDirection = 1
            }

            if item.isWeaponModule {
                switch item.displayedWeapon {
                case .doubleCannon: render.color = GameConfig.Palette.weaponDoubleCannon
                case .triSpread: render.color = GameConfig.Palette.weaponTriSpread
                case .lightningArc: render.color = GameConfig.Palette.weaponLightningArc
                case .phaseLaser: render.color = GameConfig.Palette.weaponPhaseLaser
                }
            } else {
                switch item.utilityItemType {
                case .energyCell:
                    render.color = GameConfig.Palette.item
                    render.spriteId = "energyDrop"
                case .chargeCell:
                    render.color = GameConfig.Palette.chargeCell
                    render.spriteId = "chargeCell"
                case .orbitingShield:
                    render.color = GameConfig.Palette.shieldDrone
                    render.spriteId = "shieldDrop"
                }
            }
        }
    }

    public func handleProjectileHit(on entity: GKEntity) {
        guard let item = entity.component(ofType: ItemComponent.self) else { return }
        item.advanceCycle()
    }
}
