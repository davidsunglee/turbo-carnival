import Testing
@testable import Engine2043

struct SpriteFactoryTests {
    @Test func makePlayerShipReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makePlayerShip()
        #expect(width == 48)
        #expect(height == 48)
        #expect(pixels.count == 48 * 48 * 4)
    }

    @Test func makePlayerShipHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makePlayerShip()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeSwarmerReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeSwarmer()
        #expect(width == 32)
        #expect(height == 32)
        #expect(pixels.count == 32 * 32 * 4)
    }

    @Test func makeBruiserReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeBruiser()
        #expect(width == 40)
        #expect(height == 40)
        #expect(pixels.count == 40 * 40 * 4)
    }

    @Test func makeCapitalHullReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeCapitalHull()
        #expect(width == 140)
        #expect(height == 60)
        #expect(pixels.count == 140 * 60 * 4)
    }

    @Test func makeTurretReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeTurret()
        #expect(width == 24)
        #expect(height == 24)
        #expect(pixels.count == 24 * 24 * 4)
    }

    @Test func makeBossCoreReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeBossCore()
        #expect(width == 64)
        #expect(height == 64)
        #expect(pixels.count == 64 * 64 * 4)
    }

    @Test func makeBossShieldReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeBossShield()
        #expect(width == 40)
        #expect(height == 12)
        #expect(pixels.count == 40 * 12 * 4)
    }

    // MARK: - Projectile Sprites

    @Test func makePlayerBulletReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makePlayerBullet()
        #expect(width == 6)
        #expect(height == 12)
        #expect(pixels.count == 6 * 12 * 4)
    }

    @Test func makePlayerBulletHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makePlayerBullet()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeTriSpreadBulletReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeTriSpreadBullet()
        #expect(width == 8)
        #expect(height == 8)
        #expect(pixels.count == 8 * 8 * 4)
    }

    @Test func makeTriSpreadBulletHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeTriSpreadBullet()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeLightningArcIconReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeLightningArcIcon()
        #expect(width == 8)
        #expect(height == 8)
        #expect(pixels.count == 8 * 8 * 4)
    }

    @Test func makeLightningArcIconHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeLightningArcIcon()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeEnemyBulletReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeEnemyBullet()
        #expect(width == 8)
        #expect(height == 8)
        #expect(pixels.count == 8 * 8 * 4)
    }

    @Test func makeEnemyBulletHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeEnemyBullet()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeGravBombSpriteReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeGravBombSprite()
        #expect(width == 16)
        #expect(height == 16)
        #expect(pixels.count == 16 * 16 * 4)
    }

    @Test func makeGravBombSpriteHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeGravBombSprite()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    // MARK: - Pickup Sprites

    @Test func makeEnergyDropReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeEnergyDrop()
        #expect(width == 24)
        #expect(height == 24)
        #expect(pixels.count == 24 * 24 * 4)
    }

    @Test func makeEnergyDropHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeEnergyDrop()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeChargeCellReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeChargeCell()
        #expect(width == 24)
        #expect(height == 24)
        #expect(pixels.count == 24 * 24 * 4)
    }

    @Test func makeChargeCellHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeChargeCell()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeShieldDropReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeShieldDrop()
        #expect(width == 24)
        #expect(height == 24)
        #expect(pixels.count == 24 * 24 * 4)
    }

    @Test func makeShieldDropHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeShieldDrop()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeShieldDroneReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeShieldDrone()
        #expect(width == 10)
        #expect(height == 10)
        #expect(pixels.count == 10 * 10 * 4)
    }

    @Test func makeShieldDroneHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeShieldDrone()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    // MARK: - Effect Sprites

    @Test func makeGravBombBlastReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeGravBombBlast()
        #expect(width == 128)
        #expect(height == 128)
        #expect(pixels.count == 128 * 128 * 4)
    }

    @Test func makeGravBombBlastHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeGravBombBlast()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeEmpFlashReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeEmpFlash()
        #expect(width == 128)
        #expect(height == 128)
        #expect(pixels.count == 128 * 128 * 4)
    }

    @Test func makeEmpFlashHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeEmpFlash()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeOverchargeGlowReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeOverchargeGlow()
        #expect(width == 64)
        #expect(height == 64)
        #expect(pixels.count == 64 * 64 * 4)
    }

    @Test func makeOverchargeGlowHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeOverchargeGlow()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    // MARK: - HUD Sprites

    @Test func makeHudBarFrameReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeHudBarFrame()
        #expect(width == 64)
        #expect(height == 8)
        #expect(pixels.count == 64 * 8 * 4)
    }

    @Test func makeHudBarFrameHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeHudBarFrame()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeHudBarFillReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeHudBarFill()
        #expect(width == 32)
        #expect(height == 4)
        #expect(pixels.count == 32 * 4 * 4)
    }

    @Test func makeHudBarFillHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeHudBarFill()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeHudChargePipReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeHudChargePip()
        #expect(width == 12)
        #expect(height == 12)
        #expect(pixels.count == 12 * 12 * 4)
    }

    @Test func makeHudChargePipHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeHudChargePip()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeHudWeaponIconReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeHudWeaponIcon()
        #expect(width == 16)
        #expect(height == 8)
        #expect(pixels.count == 16 * 8 * 4)
    }

    @Test func makeHudWeaponIconHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeHudWeaponIcon()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeHudHeatFrameReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeHudHeatFrame()
        #expect(width == 16)
        #expect(height == 3)
        #expect(pixels.count == 16 * 3 * 4)
    }

    @Test func makeHudHeatFrameHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeHudHeatFrame()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeHudHeatFillReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeHudHeatFill()
        #expect(width == 14)
        #expect(height == 2)
        #expect(pixels.count == 14 * 2 * 4)
    }

    @Test func makeHudHeatFillHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeHudHeatFill()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    // MARK: - Atlas

    @Test @MainActor func textureAtlasSpriteNames() {
        let names = TextureAtlas.spriteNames
        #expect(names.contains("player"))
        #expect(names.contains("swarmer"))
        #expect(names.contains("bruiser"))
        #expect(names.contains("capitalHull"))
        #expect(names.contains("turret"))
        #expect(names.contains("bossCore"))
        #expect(names.contains("bossShield"))
    }

    @Test @MainActor func effectTextureSheetSpriteNames() {
        let names = EffectTextureSheet.spriteNames
        #expect(names.contains("gravBombBlast"))
        #expect(names.contains("empFlash"))
        #expect(names.contains("overchargeGlow"))
        #expect(names.contains("hudBarFrame"))
        #expect(names.contains("hudBarFill"))
        #expect(names.contains("hudChargePip"))
        #expect(names.contains("hudWeaponIcon"))
        #expect(names.contains("hudHeatFrame"))
        #expect(names.contains("hudHeatFill"))
    }

    @Test @MainActor func textureAtlasIncludesProjectileAndPickupSprites() {
        let names = TextureAtlas.spriteNames
        #expect(names.contains("playerBullet"))
        #expect(names.contains("triSpreadBullet"))
        #expect(names.contains("lightningArcIcon"))
        #expect(names.contains("enemyBullet"))
        #expect(names.contains("gravBombSprite"))
        #expect(names.contains("energyDrop"))
        #expect(names.contains("chargeCell"))
        #expect(names.contains("weaponDoubleCannon"))
        #expect(names.contains("weaponTriSpread"))
        #expect(names.contains("weaponLightningArc"))
        #expect(names.contains("weaponPhaseLaser"))
        #expect(names.contains("shieldDrop"))
        #expect(names.contains("shieldDrone"))
    }

    @Test func doubleCannonDropSpriteHasCorrectDimensions() {
        let (pixels, w, h) = SpriteFactory.makeDoubleCannonDrop()
        #expect(w == 24)
        #expect(h == 24)
        #expect(pixels.count == 24 * 24 * 4)
        // Verify not blank — at least one non-zero alpha pixel
        let hasContent = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasContent)
    }

    @Test func triSpreadDropSpriteHasCorrectDimensions() {
        let (pixels, w, h) = SpriteFactory.makeTriSpreadDrop()
        #expect(w == 24)
        #expect(h == 24)
        #expect(pixels.count == 24 * 24 * 4)
        let hasContent = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasContent)
    }

    @Test func lightningArcDropSpriteHasCorrectDimensions() {
        let (pixels, w, h) = SpriteFactory.makeLightningArcDrop()
        #expect(w == 24)
        #expect(h == 24)
        #expect(pixels.count == 24 * 24 * 4)
        let hasContent = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasContent)
    }

    @Test func phaseLaserDropSpriteHasCorrectDimensions() {
        let (pixels, w, h) = SpriteFactory.makePhaseLaserDrop()
        #expect(w == 24)
        #expect(h == 24)
        #expect(pixels.count == 24 * 24 * 4)
        let hasContent = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasContent)
    }

    @Test @MainActor func effectTextureSheetIncludesGlyphSprites() {
        let names = EffectTextureSheet.spriteNames
        #expect(names.contains("glyph_0"))
        #expect(names.contains("glyph_9"))
        #expect(names.contains("glyph_A"))
        #expect(names.contains("glyph_Z"))
        #expect(names.contains("glyph_-"))
    }

    // MARK: - Bitmap Font Glyphs

    @Test func makeBitmapGlyphReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeBitmapGlyph("A")
        #expect(width == 6)
        #expect(height == 8)
        #expect(pixels.count == 6 * 8 * 4)
    }

    @Test func makeBitmapGlyphHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeBitmapGlyph("A")
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeBitmapGlyphSpaceIsTransparent() {
        let (pixels, _, _) = SpriteFactory.makeBitmapGlyph(" ")
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(!hasVisiblePixels)
    }

    @Test func makeBitmapGlyphAllDigitsProduceContent() {
        for char: Character in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"] {
            let (pixels, w, h) = SpriteFactory.makeBitmapGlyph(char)
            #expect(w == 6)
            #expect(h == 8)
            let hasContent = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
            #expect(hasContent, "Glyph '\(char)' should have visible pixels")
        }
    }

    // MARK: - Galaxy 3 Sprites

    @Test func makeG3TrackingDroneReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeG3TrackingDrone()
        #expect(width == 18)
        #expect(height == 18)
        #expect(pixels.count == 18 * 18 * 4)
    }

    @Test func makeG3TrackingDroneHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeG3TrackingDrone()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeG3FighterReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeG3Fighter()
        #expect(width == 26)
        #expect(height == 26)
        #expect(pixels.count == 26 * 26 * 4)
    }

    @Test func makeG3FighterHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeG3Fighter()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeG3FortressHullReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeG3FortressHull()
        #expect(width == 120)
        #expect(height == 70)
        #expect(pixels.count == 120 * 70 * 4)
    }

    @Test func makeG3FortressHullHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeG3FortressHull()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeG3FortressNodeReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeG3FortressNode()
        #expect(width == 24)
        #expect(height == 24)
        #expect(pixels.count == 24 * 24 * 4)
    }

    @Test func makeG3FortressNodeHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeG3FortressNode()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeG3BarrierWallReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeG3BarrierWall()
        #expect(width == 40)
        #expect(height == 120)
        #expect(pixels.count == 40 * 120 * 4)
    }

    @Test func makeG3BarrierWallHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeG3BarrierWall()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeG3ZenithCoreReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeG3ZenithCore()
        #expect(width == 80)
        #expect(height == 80)
        #expect(pixels.count == 80 * 80 * 4)
    }

    @Test func makeG3ZenithCoreHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeG3ZenithCore()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeG3ZenithShieldReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeG3ZenithShield()
        #expect(width == 40)
        #expect(height == 12)
        #expect(pixels.count == 40 * 12 * 4)
    }

    @Test func makeG3ZenithShieldHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeG3ZenithShield()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeG3EmpProjectileReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeG3EmpProjectile()
        #expect(width == 10)
        #expect(height == 10)
        #expect(pixels.count == 10 * 10 * 4)
    }

    @Test func makeG3EmpProjectileHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeG3EmpProjectile()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test @MainActor func textureAtlasIncludesGalaxy3Sprites() {
        let names = TextureAtlas.spriteNames
        #expect(names.contains("g3TrackingDrone"))
        #expect(names.contains("g3Fighter"))
        #expect(names.contains("g3FortressHull"))
        #expect(names.contains("g3FortressNode"))
        #expect(names.contains("g3BarrierWall"))
        #expect(names.contains("g3ZenithCore"))
        #expect(names.contains("g3ZenithShield"))
        #expect(names.contains("g3EmpProjectile"))
    }

    // MARK: - Galaxy 3 Sprite Content Integrity

    @Test func galaxy3SpritesAllHaveNonZeroDimensions() {
        // Verify all Galaxy 3 sprites produce valid, non-empty pixel data
        let sprites: [(String, () -> ([UInt8], Int, Int))] = [
            ("g3TrackingDrone", SpriteFactory.makeG3TrackingDrone),
            ("g3Fighter", SpriteFactory.makeG3Fighter),
            ("g3FortressHull", SpriteFactory.makeG3FortressHull),
            ("g3FortressNode", SpriteFactory.makeG3FortressNode),
            ("g3BarrierWall", SpriteFactory.makeG3BarrierWall),
            ("g3ZenithCore", SpriteFactory.makeG3ZenithCore),
            ("g3ZenithShield", SpriteFactory.makeG3ZenithShield),
            ("g3EmpProjectile", SpriteFactory.makeG3EmpProjectile),
        ]

        for (name, factory) in sprites {
            let (pixels, w, h) = factory()
            #expect(w > 0, "\(name) width should be positive")
            #expect(h > 0, "\(name) height should be positive")
            #expect(pixels.count == w * h * 4, "\(name) pixel count should match dimensions")
            let hasContent = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
            #expect(hasContent, "\(name) should have visible pixels")
        }
    }
}
