import GameplayKit

@MainActor
public final class RenderSystem {
    private var entities: [GKEntity] = []

    public init() {}

    public func register(_ entity: GKEntity) {
        guard entity.component(ofType: TransformComponent.self) != nil,
              entity.component(ofType: RenderComponent.self) != nil else { return }
        entities.append(entity)
    }

    public func unregister(_ entity: GKEntity) {
        entities.removeAll { $0 === entity }
    }

    public func collectSprites() -> [SpriteInstance] {
        var sprites: [SpriteInstance] = []
        sprites.reserveCapacity(entities.count)

        for entity in entities {
            guard let transform = entity.component(ofType: TransformComponent.self),
                  let render = entity.component(ofType: RenderComponent.self),
                  render.isVisible else { continue }

            sprites.append(SpriteInstance(
                position: transform.position,
                size: render.size,
                color: render.color,
                rotation: transform.rotation
            ))
        }

        return sprites
    }
}
