// Engine2043/Sources/Engine2043/Rendering/BitmapText.swift
import simd

@MainActor
public enum BitmapText {
    public static func makeSprites(
        _ text: String,
        at position: SIMD2<Float>,
        color: SIMD4<Float>,
        scale: Float = 1.0,
        effectSheet: EffectTextureSheet
    ) -> [SpriteInstance] {
        var sprites: [SpriteInstance] = []
        let glyphW: Float = 6 * scale
        let glyphH: Float = 8 * scale
        let totalWidth = Float(text.count) * glyphW
        var x = position.x - totalWidth / 2 + glyphW / 2
        for char in text {
            if char != " " {
                let key = "glyph_\(char)"
                if let uv = effectSheet.uvRect(for: key) {
                    sprites.append(SpriteInstance(
                        position: SIMD2(x, position.y),
                        size: SIMD2(glyphW, glyphH),
                        color: color,
                        uvRect: uv
                    ))
                }
            }
            x += glyphW
        }
        return sprites
    }
}
