import simd

@MainActor
public final class GalaxySelectScene: GameScene {
    private let backgroundSystem = BackgroundSystem()
    public var inputProvider: (any InputProvider)?
    public var viewportManager: ViewportManager?

    // Selection state
    public private(set) var selectedIndex: Int = 0
    public private(set) var requestedTransition: SceneTransition?

    // Galaxy entry data
    private static let galaxyNames = [
        "GALAXY 1  NGC-2043 PERIMETER",
        "GALAXY 2  KAY'SHARA EXPANSE",
        "GALAXY 3  ZENITH ARMADA GRID",
    ]

    // Layout constants
    private static let titleY: Float = 180
    private static let entryBaseY: Float = 70
    private static let entrySpacing: Float = 40
    private static let entryScale: Float = 2.0
    private static let hintY: Float = -240

    // Hit-test options for galaxy entries
    private let entryOptions: [MenuInput.Option]

    // iOS "BACK" button
    #if os(iOS)
    private let backOption = MenuInput.Option(label: "BACK", position: SIMD2(0, -270), scale: 1.0)
    #endif

    // Edge detection for fire (prevents held-fire from title screen auto-launching)
    private var prevFire = true

    // Repeat guard
    private var prevMenuUp = false
    private var prevMenuDown = false
    private var menuRepeatTimer: Double = 0
    private let initialRepeatDelay: Double = 0.3
    private let repeatRate: Double = 0.12

    public init() {
        entryOptions = Self.galaxyNames.enumerated().map { i, name in
            MenuInput.Option(
                label: name,
                position: SIMD2(0, Self.entryBaseY - Float(i) * Self.entrySpacing),
                scale: Self.entryScale
            )
        }
    }

    public func fixedUpdate(time: GameTime) {
        let dt = time.fixedDeltaTime
        backgroundSystem.update(deltaTime: dt)

        guard let input = inputProvider?.poll() else { return }

        // Back / ESC
        if input.menuBack {
            requestedTransition = .toTitle
            return
        }

        // Tap hit-test on galaxy entries
        if let tapPos = input.tapPosition {
            if let hit = MenuInput.hitTest(tapPosition: tapPos, options: entryOptions) {
                launchGalaxy(hit)
                return
            }
            #if os(iOS)
            if MenuInput.hitTest(tapPosition: tapPos, options: [backOption]) != nil {
                requestedTransition = .toTitle
                return
            }
            #endif
        }

        // Fire launches selected galaxy (edge-triggered: fresh press only)
        if input.primaryFire && !prevFire {
            launchGalaxy(selectedIndex)
            prevFire = input.primaryFire
            return
        }

        // Menu navigation with repeat guard
        if menuRepeatTimer > 0 { menuRepeatTimer -= dt }

        let freshDown = input.menuDown && !prevMenuDown
        let freshUp = input.menuUp && !prevMenuUp
        let repeatDown = input.menuDown && prevMenuDown && menuRepeatTimer <= 0
        let repeatUp = input.menuUp && prevMenuUp && menuRepeatTimer <= 0

        if freshDown || repeatDown {
            selectedIndex = (selectedIndex + 1) % 3
            menuRepeatTimer = freshDown ? initialRepeatDelay : repeatRate
        }
        if freshUp || repeatUp {
            selectedIndex = (selectedIndex + 2) % 3
            menuRepeatTimer = freshUp ? initialRepeatDelay : repeatRate
        }

        prevMenuUp = input.menuUp
        prevMenuDown = input.menuDown
        prevFire = input.primaryFire
    }

    public func update(time: GameTime) {}

    public func collectSprites(atlas: TextureAtlas?) -> [SpriteInstance] {
        backgroundSystem.collectSprites()
    }

    public func collectEffectSprites(effectSheet: EffectTextureSheet?) -> [SpriteInstance] {
        guard let effectSheet else { return [] }
        var sprites: [SpriteInstance] = []

        let cyanColor = GameConfig.Palette.player
        let goldColor = GameConfig.Palette.item
        let dimWhite = SIMD4<Float>(1, 1, 1, 0.5)

        // Title
        sprites.append(contentsOf: BitmapText.makeSprites(
            "SELECT GALAXY",
            at: SIMD2(0, Self.titleY),
            color: dimWhite,
            scale: 2.0,
            effectSheet: effectSheet
        ))

        // Galaxy entries
        for i in 0..<3 {
            let entryY = Self.entryBaseY - Float(i) * Self.entrySpacing
            let isSelected = i == selectedIndex
            let entryColor = isSelected
                ? SIMD4<Float>(cyanColor.x, cyanColor.y, cyanColor.z, 1.0)
                : dimWhite
            let text = Self.galaxyNames[i]

            // Entry text
            sprites.append(contentsOf: BitmapText.makeSprites(
                text,
                at: SIMD2(0, entryY),
                color: entryColor,
                scale: Self.entryScale,
                effectSheet: effectSheet
            ))

            // Cursor > (left of highlighted entry)
            if isSelected {
                let glyphW: Float = 6 * Self.entryScale
                let textWidth = Float(text.count) * glyphW
                let cursorX = -(textWidth / 2) - glyphW * 1.5
                sprites.append(contentsOf: BitmapText.makeSprites(
                    ">",
                    at: SIMD2(cursorX, entryY),
                    color: SIMD4(cyanColor.x, cyanColor.y, cyanColor.z, 1.0),
                    scale: Self.entryScale,
                    effectSheet: effectSheet
                ))
            }

            // Cleared * indicator (right of entry)
            if ProgressStore.isCleared(galaxy: i + 1) {
                let glyphW: Float = 6 * Self.entryScale
                let textWidth = Float(text.count) * glyphW
                let starX = (textWidth / 2) + glyphW * 1.5
                sprites.append(contentsOf: BitmapText.makeSprites(
                    "*",
                    at: SIMD2(starX, entryY),
                    color: SIMD4(goldColor.x, goldColor.y, goldColor.z, 1.0),
                    scale: Self.entryScale,
                    effectSheet: effectSheet
                ))
            }
        }

        // Input hint
        #if os(iOS)
        let hintText = "SWIPE TO SELECT  TAP TO LAUNCH"
        #else
        let hintText = "UP/DOWN SELECT  SPACE LAUNCH  ESC BACK"
        #endif
        sprites.append(contentsOf: BitmapText.makeSprites(
            hintText,
            at: SIMD2(0, Self.hintY),
            color: SIMD4(1, 1, 1, 0.3),
            scale: 1.0,
            effectSheet: effectSheet
        ))

        // iOS "BACK" option
        #if os(iOS)
        sprites.append(contentsOf: BitmapText.makeSprites(
            backOption.label,
            at: backOption.position,
            color: dimWhite,
            scale: backOption.scale,
            effectSheet: effectSheet
        ))
        #endif

        return sprites
    }

    // MARK: - Private

    private func launchGalaxy(_ index: Int) {
        switch index {
        case 0: requestedTransition = .toGame
        case 1: requestedTransition = .toGalaxy2(nil)
        case 2: requestedTransition = .toGalaxy3(nil)
        default: break
        }
    }
}
