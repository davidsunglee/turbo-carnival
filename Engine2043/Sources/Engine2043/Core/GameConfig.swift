import simd

public enum GameConfig {
    public static let fixedTimeStep: Double = 1.0 / 60.0
    public static let maxFrameTime: Double = 1.0 / 4.0

    public static let designWidth: Float = 360
    public static let designHeight: Float = 640

    public enum Player {
        public static let speed: Float = 200
        public static let size = SIMD2<Float>(30, 30)
        public static let health: Float = 100
        public static let fireRate: Double = 4.0
        public static let damage: Float = 1.0
        public static let projectileSpeed: Float = 500
        public static let projectileSize = SIMD2<Float>(6, 12)
        public static let invulnerabilityDuration: Double = 0.5
        public static let collisionDamage: Float = 15
    }

    public enum Enemy {
        public static let tier1HP: Float = 2
        public static let tier1Size = SIMD2<Float>(24, 24)
        public static let tier1Speed: Float = 80
        public static let tier2HP: Float = 4
        public static let tier2Size = SIMD2<Float>(32, 32)
        public static let tier2Speed: Float = 60
        public static let tier3HullSize = SIMD2<Float>(280, 120)
        public static let tier3TurretHP: Float = 6
        public static let tier3TurretSize = SIMD2<Float>(20, 20)
        public static let tier3ScrollMultiplier: Float = 0.5
        public static let bossHP: Float = 60
        public static let bossSize = SIMD2<Float>(80, 80)
    }

    public enum Score {
        public static let tier1 = 10
        public static let tier2 = 50
        public static let tier3Turret = 100
        public static let boss = 500
    }

    public enum Weapon {
        public static let triSpreadAngle: Float = .pi / 9
        public static let triSpreadFireRate: Double = 3.0
        public static let triSpreadDamage: Float = 0.7

        public static let gravBombMaxCharges = 3
        public static let gravBombStartCharges = 1
        public static let gravBombDetonateTime: Double = 0.4
        public static let gravBombBlastRadius: Float = 120
        public static let gravBombDamage: Float = 3

        // Lightning Arc
        public static let lightningArcRange: Float = 200
        public static let lightningArcDamagePerTick: Float = 0.6
        public static let lightningArcTickRate: Double = 10.0
        public static let lightningArcChainTargets: Int = 2
        public static let lightningArcChainDamageFalloff: Float = 0.5
        public static let lightningArcChainRange: Float = 80
        public static let lightningArcRampDuration: Double = 0.5
        public static let lightningArcMinRampMultiplier: Float = 0.25
        public static let lightningArcItemCycleCooldown: Double = 0.3

        // Phase Laser
        public static let laserTickInterval: Double = 0.1
        public static let laserDamagePerTick: Float = 1.0
        public static let laserWidth: Float = 8
        public static let laserHeatPerSecond: Double = 1.0
        public static let laserCoolPerSecond: Double = 2.0
        public static let laserMaxHeat: Double = 1.0
        public static let laserOverheatCooldown: Double = 1.0
        public static let laserMaxHeatDamageMultiplier: Float = 1.6

        // EMP Sweep
        public static let empSlowMoDuration: Double = 0.8

        // Overcharge Protocol
        public static let overchargeDuration: Double = 4.0
        public static let overchargeFireRateMultiplier: Double = 2.0
        public static let overchargeHitboxScale: Float = 1.5
    }

    public enum Item {
        public static let size = SIMD2<Float>(24, 24)
        public static let driftSpeed: Float = 40
        public static let despawnTime: Double = 8.0
        public static let energyRestoreAmount: Float = 15
        public static let chargeRestoreAmount: Int = 1
    }

    public enum ShieldDrone {
        public static let orbitRadius: Float = 25
        public static let orbitSpeed: Float = 3.14
        public static let hitsPerDrone: Int = 3
        public static let maxDrones: Int = 4
        public static let droneSize = SIMD2<Float>(10, 10)
    }

    public enum Background {
        public static let starScrollSpeed: Float = 20
        public static let nebulaScrollSpeed: Float = 40
        public static let starCount = 35
        public static let nebulaCount = 5
    }

    public enum Palette {
        public static let background = SIMD4<Float>(10.0 / 255.0, 0.0, 71.0 / 255.0, 1.0)
        public static let midground = SIMD4<Float>(0.0, 70.0 / 255.0, 135.0 / 255.0, 1.0)
        public static let player = SIMD4<Float>(0.0, 1.0, 210.0 / 255.0, 1.0)
        public static let enemy = SIMD4<Float>(247.0 / 255.0, 118.0 / 255.0, 142.0 / 255.0, 1.0)
        public static let hostileProjectile = SIMD4<Float>(1.0, 158.0 / 255.0, 100.0 / 255.0, 1.0)
        public static let item = SIMD4<Float>(224.0 / 255.0, 175.0 / 255.0, 104.0 / 255.0, 1.0)
        public static let tier2Enemy = SIMD4<Float>(1.0, 100.0 / 255.0, 160.0 / 255.0, 1.0)
        public static let capitalShipHull = SIMD4<Float>(40.0 / 255.0, 50.0 / 255.0, 80.0 / 255.0, 1.0)
        public static let bossCore = SIMD4<Float>(1.0, 68.0 / 255.0, 153.0 / 255.0, 1.0)
        public static let bossShield = SIMD4<Float>(0.6, 0.8, 1.0, 0.7)
        public static let weaponModule = SIMD4<Float>(0.3, 0.5, 1.0, 1.0)
        public static let gravBomb = SIMD4<Float>(1.0, 0.85, 0.3, 1.0)
        public static let gravBombBlast = SIMD4<Float>(1.0, 1.0, 0.8, 0.6)
        public static let turret = SIMD4<Float>(1.0, 0.4, 0.2, 1.0)
        public static let empFlash = SIMD4<Float>(0.5, 0.7, 1.0, 0.4)
        public static let overchargeGlow = SIMD4<Float>(1.0, 0.6, 0.0, 0.8)
        public static let laserBeam = SIMD4<Float>(0.4, 1.0, 0.4, 0.9)
        public static let chargeCell = SIMD4<Float>(0.6, 0.3, 1.0, 1.0)
        public static let shieldDrone = SIMD4<Float>(0.0, 1.0, 210.0 / 255.0, 1.0)
        public static let weaponDoubleCannon = SIMD4<Float>(0.0, 0.5, 1.0, 1.0)
        public static let weaponTriSpread = SIMD4<Float>(1.0, 0.0, 0.2, 1.0)
        public static let weaponLightningArc = SIMD4<Float>(1.0, 1.0, 0.0, 1.0)
        public static let weaponPhaseLaser = SIMD4<Float>(0.0, 1.0, 0.2, 1.0)
    }

    public enum Galaxy2 {
        public enum Enemy {
            public static let tier1HP: Float = 1.0
            public static let tier1Size = SIMD2<Float>(20, 20)
            public static let tier2HP: Float = 2.5
            public static let tier2Size = SIMD2<Float>(32, 32)
            public static let tier2Speed: Float = 70
            public static let tier3HullSize = SIMD2<Float>(216, 100)
            public static let tier3TurretHP: Float = 3.5
            public static let tier3TurretSize = SIMD2<Float>(20, 20)
            public static let bossHP: Float = 100
            public static let bossSize = SIMD2<Float>(100, 100)
            public static let bossArmorSlots: Int = 6
            public static let bossArmorSlotHP: Float = 4.0
        }

        public enum Asteroid {
            public static let smallSize = SIMD2<Float>(16, 16)
            public static let largeSize = SIMD2<Float>(40, 40)
            public static let smallHP: Float = 2.5
            public static let scrollSpeed: Float = 30
            public static let collisionDamage: Float = 18
            public static let sparseCount: Int = 8
            public static let denseFieldCount: Int = 12
            public static let denseFieldLargeFraction: Float = 0.3
        }

        public enum Score {
            public static let g2Tier1 = 15
            public static let g2Tier2 = 75
            public static let g2Tier3Turret = 150
            public static let g2Boss = 1000
            public static let asteroidSmall = 5
        }

        public enum Palette {
            public static let g2Background = SIMD4<Float>(30.0 / 255.0, 10.0 / 255.0, 50.0 / 255.0, 1.0)
            public static let g2Midground = SIMD4<Float>(80.0 / 255.0, 20.0 / 255.0, 60.0 / 255.0, 1.0)
            public static let g2AsteroidSmall = SIMD4<Float>(0.5, 0.4, 0.35, 1.0)
            public static let g2AsteroidLarge = SIMD4<Float>(0.35, 0.3, 0.25, 1.0)
            public static let g2Tier1 = SIMD4<Float>(0.8, 0.5, 0.6, 1.0)
            public static let g2Tier2 = SIMD4<Float>(0.7, 0.4, 0.8, 1.0)
            public static let g2BossCore = SIMD4<Float>(0.9, 0.3, 0.5, 1.0)
            public static let g2TractorBeam = SIMD4<Float>(0.4, 0.8, 1.0, 0.6)
        }
    }

    public enum Galaxy3 {
        public enum Enemy {
            // Tier 1 — tracking drones
            public static let tier1HP: Float = 1.0
            public static let tier1Size = SIMD2<Float>(18, 18)
            public static let tier1Speed: Float = 120

            // Tier 2 — four-fighter squads
            public static let tier2HP: Float = 2.5
            public static let tier2Size = SIMD2<Float>(26, 26)
            public static let tier2Speed: Float = 80

            // Tier 3 — fortress nodes
            public static let fortressShieldGenHP: Float = 4.0
            public static let fortressMainBatteryHP: Float = 6.0
            public static let fortressPulseTurretHP: Float = 3.0
            public static let fortressNodeSize = SIMD2<Float>(24, 24)
            public static let fortressHullSize = SIMD2<Float>(240, 140)

            // Zenith Core Sentinel — boss
            public static let bossHP: Float = 150
            public static let bossSize = SIMD2<Float>(120, 120)
            public static let bossPhaseThresholds: [Float] = [0.75, 0.50, 0.25]
        }

        public enum Barrier {
            public static let collisionDamage: Float = 20
            public static let trenchWallWidth: Float = 60
            public static let gateSegmentSize = SIMD2<Float>(40, 120)
            public static let rotatingGateSpeed: Float = 1.5
        }

        public enum Corridor {
            public static let narrowWidth: Float = 80
            public static let standardWidth: Float = 120
            public static let wideWidth: Float = 180
        }

        public enum BossAttack {
            // Grid beam fire
            public static let gridBeamInterval: Double = 2.0
            public static let gridBeamProjectileSpeed: Float = 250

            // Radial burst
            public static let radialBurstInterval: Double = 3.0
            public static let radialBurstProjectileSpeed: Float = 200
            public static let radialBurstProjectileCount: Int = 12

            // Homing missiles
            public static let homingMissileInterval: Double = 4.0
            public static let homingMissileSpeed: Float = 160
            public static let homingMissileCount: Int = 3
            public static let homingMissileTurnRate: Float = 2.5
            public static let homingMissileLifetime: Double = 5.0

            // Shield window
            public static let shieldWindowDuration: Double = 3.0
            public static let shieldCooldown: Double = 8.0

            // EMP attack
            public static let empDisableDuration: Double = 2.0
            public static let empChargeTime: Double = 1.0
        }

        public enum Score {
            public static let g3Tier1 = 20
            public static let g3Tier2 = 100
            public static let g3FortressNode = 200
            public static let g3Boss = 2000
        }

        public enum Palette {
            public static let g3Background = SIMD4<Float>(5.0 / 255.0, 15.0 / 255.0, 30.0 / 255.0, 1.0)
            public static let g3Midground = SIMD4<Float>(20.0 / 255.0, 50.0 / 255.0, 80.0 / 255.0, 1.0)
            public static let g3Barrier = SIMD4<Float>(0.35, 0.4, 0.5, 1.0)
            public static let g3Tier1 = SIMD4<Float>(0.6, 0.8, 1.0, 1.0)
            public static let g3Tier2 = SIMD4<Float>(0.4, 0.6, 1.0, 1.0)
            public static let g3FortressHull = SIMD4<Float>(0.25, 0.3, 0.45, 1.0)
            public static let g3FortressShield = SIMD4<Float>(0.3, 0.9, 1.0, 0.6)
            public static let g3BossCore = SIMD4<Float>(1.0, 0.4, 0.2, 1.0)
            public static let g3BossShield = SIMD4<Float>(0.4, 0.7, 1.0, 0.7)
            public static let g3EmpFlash = SIMD4<Float>(0.8, 0.9, 1.0, 0.5)
        }
    }
}
