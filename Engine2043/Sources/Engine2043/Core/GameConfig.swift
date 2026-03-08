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
        public static let triSpreadAngle: Float = .pi / 12
        public static let triSpreadDamage: Float = 0.7
        public static let gravBombMaxCharges = 3
        public static let gravBombStartCharges = 1
        public static let gravBombDetonateTime: Double = 0.4
        public static let gravBombBlastRadius: Float = 120
        public static let gravBombDamage: Float = 3

        // Lightning Arc
        public static let lightningArcRange: Float = 200
        public static let lightningArcDamagePerTick: Float = 0.8
        public static let lightningArcTickRate: Double = 10.0
        public static let lightningArcChainTargets: Int = 2
        public static let lightningArcChainDamageFalloff: Float = 0.5
        public static let lightningArcChainRange: Float = 80

        // Phase Laser
        public static let laserTickInterval: Double = 0.1
        public static let laserDamagePerTick: Float = 1.0
        public static let laserWidth: Float = 8
        public static let laserHeatPerSecond: Double = 1.0
        public static let laserCoolPerSecond: Double = 2.0
        public static let laserMaxHeat: Double = 1.0
        public static let laserOverheatCooldown: Double = 1.0

        // EMP Sweep
        public static let empSlowMoDuration: Double = 0.3

        // Overcharge Protocol
        public static let overchargeDuration: Double = 5.0
        public static let overchargeFireRateMultiplier: Double = 2.0
        public static let overchargeHitboxScale: Float = 1.5
    }

    public enum Item {
        public static let size = SIMD2<Float>(16, 16)
        public static let driftSpeed: Float = 40
        public static let despawnTime: Double = 8.0
        public static let energyRestoreAmount: Float = 15
        public static let chargeRestoreAmount: Int = 1
        public static let scoreBonusAmount: Int = 200
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
        public static let scoreBonus = SIMD4<Float>(1.0, 1.0, 0.4, 1.0)
        public static let weaponDoubleCannon = SIMD4<Float>(0.3, 0.5, 1.0, 1.0)
        public static let weaponTriSpread = SIMD4<Float>(1.0, 0.3, 0.3, 1.0)
        public static let weaponLightningArc = SIMD4<Float>(1.0, 0.9, 0.3, 1.0)
        public static let weaponPhaseLaser = SIMD4<Float>(0.4, 1.0, 0.4, 1.0)
    }
}
