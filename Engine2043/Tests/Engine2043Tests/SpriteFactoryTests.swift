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
}
