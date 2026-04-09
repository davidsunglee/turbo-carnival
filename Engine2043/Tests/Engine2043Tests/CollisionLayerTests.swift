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

    @Test func barrierLayerRawValue() {
        let layer = CollisionLayer.barrier
        #expect(layer.rawValue == 512) // 1 << 9
    }

    @Test func barrierCoexistsWithExistingLayers() {
        let combined = CollisionLayer.barrier.union([.player, .enemy, .asteroid])
        #expect(combined.contains(.barrier))
        #expect(combined.contains(.player))
        #expect(combined.contains(.enemy))
        #expect(combined.contains(.asteroid))
        #expect(combined.rawValue == 773) // 1 | 4 | 256 | 512
    }

    @Test func barrierInPlayerMask() {
        // Player mask should be able to include barrier for symmetric collision
        let playerMask: CollisionLayer = [.enemy, .enemyProjectile, .item, .barrier]
        #expect(playerMask.contains(.barrier))
        #expect(playerMask.contains(.enemy))
        #expect(!playerMask.contains(.playerProjectile))
    }

    @Test func barrierSymmetricCollision() {
        // Barrier's mask includes player, player's mask includes barrier
        let barrierLayer: CollisionLayer = .barrier
        let barrierMask: CollisionLayer = [.player]
        let playerLayer: CollisionLayer = .player
        let playerMask: CollisionLayer = [.barrier]

        // From player's perspective: barrier layer intersects player mask
        let playerSeesBarrier = !barrierLayer.intersection(playerMask).isEmpty
        // From barrier's perspective: player layer intersects barrier mask
        let barrierSeesPlayer = !playerLayer.intersection(barrierMask).isEmpty

        #expect(playerSeesBarrier)
        #expect(barrierSeesPlayer)
    }

    // MARK: - Layer Uniqueness and Orthogonality

    @Test func allLayersHaveUniqueRawValues() {
        let layers: [CollisionLayer] = [
            .player, .playerProjectile, .enemy, .enemyProjectile,
            .item, .bossShield, .blast, .shieldDrone, .asteroid, .barrier
        ]
        var seen = Set<UInt16>()
        for layer in layers {
            #expect(!seen.contains(layer.rawValue), "Duplicate raw value: \(layer.rawValue)")
            seen.insert(layer.rawValue)
        }
    }

    @Test func allLayersArePowersOfTwo() {
        let layers: [CollisionLayer] = [
            .player, .playerProjectile, .enemy, .enemyProjectile,
            .item, .bossShield, .blast, .shieldDrone, .asteroid, .barrier
        ]
        for layer in layers {
            let raw = layer.rawValue
            // A power of two has exactly one bit set: raw & (raw - 1) == 0
            #expect(raw > 0 && (raw & (raw - 1)) == 0,
                    "Layer raw value \(raw) is not a power of two")
        }
    }

    @Test func barrierDoesNotOverlapPlayerProjectile() {
        // Verify barrier and playerProjectile are distinct bits
        let combined = CollisionLayer.barrier.intersection(.playerProjectile)
        #expect(combined.isEmpty)
    }

    @Test func barrierProjectileMaskCanIncludePlayerProjectile() {
        // Barrier should be hittable by player projectiles
        let barrierMask: CollisionLayer = [.player, .playerProjectile]
        #expect(barrierMask.contains(.playerProjectile))
        #expect(barrierMask.contains(.player))
        #expect(!barrierMask.contains(.enemy))
    }
}
