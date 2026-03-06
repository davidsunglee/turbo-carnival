import Testing
@testable import Engine2043

struct GameTimeTests {
    @Test func initialState() {
        let time = GameTime()
        #expect(time.totalTime == 0)
        #expect(time.deltaTime == 0)
        #expect(time.accumulator == 0)
        #expect(time.fixedUpdateCount == 0)
    }

    @Test func advanceClampsToMaxFrameTime() {
        var time = GameTime()
        time.advance(by: 1.0)
        #expect(time.deltaTime == GameConfig.maxFrameTime)
        #expect(time.totalTime == GameConfig.maxFrameTime)
    }

    @Test func fixedUpdateAccumulation() {
        var time = GameTime()
        time.advance(by: 1.0 / 30.0) // ~2 fixed steps

        #expect(time.shouldPerformFixedUpdate())
        time.consumeFixedUpdate()
        #expect(time.fixedUpdateCount == 1)

        #expect(time.shouldPerformFixedUpdate())
        time.consumeFixedUpdate()
        #expect(time.fixedUpdateCount == 2)

        #expect(!time.shouldPerformFixedUpdate())
    }

    @Test func interpolationFactor() {
        var time = GameTime()
        let halfStep = GameConfig.fixedTimeStep / 2
        time.advance(by: halfStep)
        #expect(time.interpolationFactor >= 0.49)
        #expect(time.interpolationFactor <= 0.51)
    }

    @Test func spriteInstanceMemoryLayout() {
        #expect(MemoryLayout<SpriteInstance>.size == 64)
        #expect(MemoryLayout<SpriteInstance>.stride == 64)
    }

    @Test func uniformsMemoryLayout() {
        #expect(MemoryLayout<Uniforms>.size == 64)
    }

    @Test func postProcessUniformsMemoryLayout() {
        // Must be 16-byte aligned for Metal buffer binding
        #expect(MemoryLayout<PostProcessUniforms>.size == 16)
        #expect(MemoryLayout<PostProcessUniforms>.stride % 16 == 0)
    }
}
