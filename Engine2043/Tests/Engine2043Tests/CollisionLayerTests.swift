import Testing
@testable import Engine2043

struct CollisionLayerTests {
    @Test func playerLayerRawValue() {
        let layer = CollisionLayer.player
        #expect(layer.rawValue == 1)
    }

    @Test func playerProjectileLayerRawValue() {
        let layer = CollisionLayer.playerProjectile
        #expect(layer.rawValue == 2)
    }

    @Test func enemyLayerRawValue() {
        let layer = CollisionLayer.enemy
        #expect(layer.rawValue == 4)
    }

    @Test func enemyProjectileLayerRawValue() {
        let layer = CollisionLayer.enemyProjectile
        #expect(layer.rawValue == 8)
    }

    @Test func itemLayerRawValue() {
        let layer = CollisionLayer.item
        #expect(layer.rawValue == 16)
    }

    @Test func bossShieldLayerRawValue() {
        let layer = CollisionLayer.bossShield
        #expect(layer.rawValue == 32)
    }

    @Test func blastLayerRawValue() {
        let layer = CollisionLayer.blast
        #expect(layer.rawValue == 64)
    }

    @Test func shieldDroneLayerRawValue() {
        let layer = CollisionLayer.shieldDrone
        #expect(layer.rawValue == 128)
    }

    @Test func asteroidLayerRawValue() {
        let layer = CollisionLayer.asteroid
        #expect(layer.rawValue == 256)
    }

    @Test func optionSetUnion() {
        let combined = CollisionLayer.player.union([.enemy])
        #expect(combined.rawValue == 5) // 1 | 4
    }

    @Test func optionSetIntersection() {
        let combined = CollisionLayer.player.union([.enemy])
        let hasPlayer = combined.contains(.player)
        let hasEnemy = combined.contains(.enemy)
        let hasItem = combined.contains(.item)
        
        #expect(hasPlayer)
        #expect(hasEnemy)
        #expect(!hasItem)
    }

    @Test func asteroidCoexistsWithExistingLayers() {
        let combined = CollisionLayer.asteroid.union([.player, .enemy])
        #expect(combined.contains(.asteroid))
        #expect(combined.contains(.player))
        #expect(combined.contains(.enemy))
        #expect(combined.rawValue == 261) // 1 | 4 | 256
    }

    @Test func asteroidInMask() {
        let mask: CollisionLayer = [.player, .asteroid, .playerProjectile]
        #expect(mask.contains(.player))
        #expect(mask.contains(.asteroid))
        #expect(mask.contains(.playerProjectile))
        #expect(!mask.contains(.enemy))
    }
}
