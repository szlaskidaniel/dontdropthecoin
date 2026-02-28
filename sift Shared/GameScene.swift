//
//  GameScene.swift
//  fizz Shared
//

import SpriteKit
import CoreImage
import simd
import AVFoundation

#if os(iOS)
import CoreMotion
import UIKit
#endif

// MARK: - Light Categories

private struct LightCategory {
    static let scene: UInt32 = 1 << 0
}

// MARK: - Physics Categories

private struct PhysicsCategory {
    static let wall:     UInt32 = 1 << 0
    static let crystal:  UInt32 = 1 << 1
    static let junk:     UInt32 = 1 << 2
    static let balloon:  UInt32 = 1 << 3
    static let web:      UInt32 = 1 << 4
    static let ambient:  UInt32 = 1 << 5
    static let ambientWall: UInt32 = 1 << 6
    static let allEmoji: UInt32 = crystal | junk | balloon
}

// MARK: - Emoji Type

enum EmojiType: CaseIterable {
    case crystal, apple, teddy, shoe, banana, book, gift, duck, donut, puzzle, balloon

    var character: String {
        switch self {
        case .crystal:        return "💎"
        case .apple:          return "🍎"
        case .teddy:          return "🧸"
        case .shoe:           return "👟"
        case .banana:         return "🍌"
        case .book:           return "📘"
        case .gift:           return "🎁"
        case .duck:           return "🦆"
        case .donut:          return "🍩"
        case .puzzle:         return "🧩"
        case .balloon:        return "🎈"
        }
    }

    var isCrystal: Bool { self == .crystal}
    var isJunk: Bool { !isCrystal && !isBalloon }
    var isBalloon: Bool { self == .balloon }

    var physicsCategory: UInt32 {
        switch self {
        case .crystal:                  return PhysicsCategory.crystal
        case .balloon:                  return PhysicsCategory.balloon
        default:                        return PhysicsCategory.junk
        }
    }

    var nodeName: String {
        if isCrystal { return "crystal" }
        if isBalloon { return "balloon" }
        return "junk"
    }

    /// Density — crystals are dense and gem-like, junk is light and throwable.
    var density: CGFloat {
        switch self {
        case .crystal:        return 3.5
        case .apple:          return 0.6
        case .teddy:          return 0.5
        case .shoe:           return 0.7
        case .banana:         return 0.5
        case .book:           return 0.9
        case .gift:           return 0.6
        case .duck:           return 0.5
        case .donut:          return 0.6
        case .puzzle:         return 0.8
        case .balloon:        return 0.15
        }
    }

    /// Friction — crystals are smooth and slide easily, junk slides too.
    var friction: CGFloat {
        switch self {
        case .crystal: return 0.3
        case .apple:                    return 0.15
        case .teddy:                    return 0.10
        case .shoe:                     return 0.20
        case .banana:                   return 0.12
        case .book:                     return 0.25
        case .gift:                     return 0.18
        case .duck:                     return 0.10
        case .donut:                    return 0.14
        case .puzzle:                   return 0.22
        case .balloon:                  return 0.05
        }
    }

    /// Bounciness — crystals are hard and bouncy like gemstones, junk bounces around for fun.
    var restitution: CGFloat {
        switch self {
        case .crystal:        return 0.65
        case .apple:          return 0.55
        case .teddy:          return 0.60
        case .shoe:           return 0.50
        case .banana:         return 0.50
        case .book:           return 0.35
        case .gift:           return 0.58
        case .duck:           return 0.62
        case .donut:          return 0.45
        case .puzzle:         return 0.52
        case .balloon:        return 0.70
        }
    }

    /// Radius for the physics body circle.
    var radius: CGFloat {
        switch self {
        case .crystal:        return 18
        case .apple:          return 16
        case .teddy:          return 24
        case .shoe:           return 22
        case .banana:         return 20
        case .book:           return 22
        case .gift:           return 20
        case .duck:           return 22
        case .donut:          return 20
        case .puzzle:         return 22
        case .balloon:        return 40
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .teddy, .shoe: return 42
        case .gift, .duck:  return 40
        case .puzzle:       return 38
        case .balloon:      return 72
        default:            return 36
        }
    }

    /// Random junk type; one additional type unlocks every third stage.
    static func randomJunk(forStage stage: Int) -> EmojiType {
        let basePool: [EmojiType] = [.apple, .teddy, .shoe]
        let unlocksByStage: [EmojiType] = [.banana, .book, .gift, .duck, .donut, .puzzle]
        let unlockedCount = max(0, stage / 3)
        let unlocked = Array(unlocksByStage.prefix(unlockedCount))
        let pool = basePool + unlocked
        return pool.randomElement()!
    }

    /// Random crystal type.
    static func randomCrystal() -> EmojiType {
        let pool: [EmojiType] = [.crystal, .crystal, .crystal]
        return pool.randomElement()!
    }
}

// MARK: - Crystal Palette

private enum CrystalColorVariant: CaseIterable {
    case cyan
    case amber
    case ruby
    case emerald

    var weight: Int {
        switch self {
        case .cyan: return 38
        case .amber: return 24
        case .ruby: return 20
        case .emerald: return 18
        }
    }

    var coreColor: SKColor {
        switch self {
        case .cyan:    return SKColor(red: 0.30, green: 0.86, blue: 1.00, alpha: 1.0)
        case .amber:   return SKColor(red: 1.00, green: 0.77, blue: 0.25, alpha: 1.0)
        case .ruby:    return SKColor(red: 0.95, green: 0.25, blue: 0.35, alpha: 1.0)
        case .emerald: return SKColor(red: 0.28, green: 0.92, blue: 0.56, alpha: 1.0)
        }
    }

    var glowVector: vector_float4 {
        switch self {
        case .cyan:    return vector_float4(0.30, 0.95, 1.00, 1.0)
        case .amber:   return vector_float4(1.00, 0.82, 0.30, 1.0)
        case .ruby:    return vector_float4(1.00, 0.28, 0.40, 1.0)
        case .emerald: return vector_float4(0.28, 0.98, 0.60, 1.0)
        }
    }

    var coreVector: vector_float4 {
        switch self {
        case .cyan:    return vector_float4(0.22, 0.74, 1.00, 1.0)
        case .amber:   return vector_float4(0.96, 0.66, 0.18, 1.0)
        case .ruby:    return vector_float4(0.86, 0.14, 0.24, 1.0)
        case .emerald: return vector_float4(0.15, 0.75, 0.36, 1.0)
        }
    }

    static func weightedRandom() -> CrystalColorVariant {
        let totalWeight = allCases.reduce(0) { $0 + $1.weight }
        var ticket = Int.random(in: 0..<totalWeight)
        for color in allCases {
            ticket -= color.weight
            if ticket < 0 { return color }
        }
        return .cyan
    }
}

// MARK: - Glass Shader Source (GLSL)

/// Custom fragment shader that adds a specular sheen and inner glow to the jar.
/// Applied as a fillShader on the jar's glass shape node.
private let glassShaderSource = """
void main() {
    vec2 uv = v_tex_coord;

    // Signed distance from center (0,0) to edge (1,1 range)
    vec2 centered = (uv - 0.5) * 2.0;

    // Edge glow: only visible right at the edges, fades to fully transparent in the center
    float edgeDist = length(centered);
    float innerGlow = smoothstep(0.6, 1.0, edgeDist) * 0.06;

    // The center of the jar must be fully transparent so objects inside are visible
    vec4 glowColor = vec4(0.3, 0.85, 0.9, 1.0) * innerGlow;

    gl_FragColor = glowColor;
}
"""

/// Custom stroke shader that creates a subtle gradient along the jar outline.
private let jarStrokeShaderSource = """
void main() {
    float t = v_path_distance / u_path_length;
    // Gradient from cool blue-white at bottom to warm white at top
    vec3 bottomColor = vec3(0.5, 0.6, 0.9);
    vec3 topColor = vec3(0.9, 0.9, 1.0);
    vec3 mixed = mix(bottomColor, topColor, t);
    float alpha = mix(0.25, 0.45, t);
    gl_FragColor = vec4(mixed * alpha, alpha);
}
"""

/// Crystal shader: colorized gemstone glow, internal facets, and directional rim lighting.
private let crystalGlowShaderSource = """
float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec2 hash22(vec2 p) {
    return vec2(hash21(p), hash21(p + 19.19));
}

float voronoi(vec2 x) {
    vec2 n = floor(x);
    vec2 f = fract(x);
    float minDist = 10.0;

    for (int j = -1; j <= 1; ++j) {
        for (int i = -1; i <= 1; ++i) {
            vec2 g = vec2(float(i), float(j));
            vec2 o = hash22(n + g);
            vec2 r = g + o - f;
            minDist = min(minDist, length(r));
        }
    }
    return minDist;
}

void main() {
    vec2 uv = v_tex_coord;
    vec4 base = texture2D(u_texture, uv) * v_color_mix.a;
    float alpha = base.a;

    if (alpha <= 0.001) {
        gl_FragColor = vec4(0.0);
        return;
    }

    vec2 centered = uv - vec2(0.5);
    float dist = length(centered);

    float c = cos(u_rotation * 0.28);
    float s = sin(u_rotation * 0.28);
    mat2 rot = mat2(c, -s, s, c);
    vec2 facetUV = rot * (centered * 6.0 + vec2(u_facet_seed * 2.3, -u_facet_seed * 1.7));
    float cell = voronoi(facetUV + vec2(u_time * 0.08, -u_time * 0.06));
    float facets = smoothstep(0.30, 0.08, cell);
    float facetLines = smoothstep(0.11, 0.0, abs(cell - 0.18));

    vec2 lightDir = normalize(u_light_dir + vec2(0.0001, 0.0001));
    vec2 normal2D = normalize(centered + vec2(0.0001, 0.0001));
    float ndl = dot(normal2D, lightDir);

    float edgeMask = smoothstep(0.24, 0.62, dist);
    float rim = pow(max(ndl, 0.0), 1.8) * edgeMask;
    float darkSide = max(-ndl, 0.0) * 0.28;
    float shimmer = 0.90 + 0.10 * sin((uv.y + uv.x) * 21.0 + u_time * 3.2 + u_facet_seed * 6.0);

    vec3 gemBase = mix(base.rgb, u_core_color.rgb, 0.74);
    vec3 facetTint = mix(gemBase * 0.86, u_glow_color.rgb, facets * 0.52);
    facetTint += vec3(1.0) * facetLines * 0.07;

    float glowMask = smoothstep(0.66, 0.22, dist) * (0.58 + edgeMask * 0.42);
    vec3 glow = u_glow_color.rgb * glowMask * 0.15 * shimmer;
    vec3 lit = facetTint + glow + (u_glow_color.rgb * rim * 0.42);
    lit *= (1.0 - darkSide);

    gl_FragColor = vec4(lit, alpha);
}
"""

// MARK: - GameScene

class GameScene: SKScene {

    // MARK: Properties

    weak var viewModel: GameViewModel?

    private var bgMusicPlayer: AVAudioPlayer?

    #if os(iOS)
    private let motionManager = CMMotionManager()
    private let crystalImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let wallImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    #endif

    private let gravityStrength: CGFloat = 14.0
    private let balloonLiftForce: CGFloat = 6.0

    /// Jar geometry (synchronised from VesselGeometry in buildJar).
    private var jarMinX: CGFloat = 0
    private var jarMaxX: CGFloat = 0
    private var jarBottomY: CGFloat = 0
    private var jarTopY: CGFloat = 0
    private var jarPath: CGMutablePath?

    /// Current vessel shape and its computed geometry.
    private var currentVesselShape: VesselShape = BottleVessel()
    private var currentGeometry: VesselGeometry?

    /// The primary light source for the scene.
    private var primaryLight: SKLightNode?

    /// Effect node wrapping only static jar visuals, rasterized for performance.
    private var jarEffectNode: SKEffectNode?

    /// Individual dirt stain and smudge nodes scattered on the jar glass.
    private var dirtNodes: [SKNode] = []

    /// Precompiled glass shader — avoid recompilation per frame.
    private let glassShader = SKShader(source: glassShaderSource)
    private let jarStrokeShader = SKShader(source: jarStrokeShaderSource)

    /// Texture cache for emoji sprites (avoids re-rendering each frame).
    private var emojiTextureCache: [String: SKTexture] = [:]
    private var glintTexture: SKTexture?

    private var stageWon = false
    private var gameOver = false
    private var isTransitioningShape = false

    // MARK: Vessel Morph
    private var morphInterpolator: VesselMorphInterpolator?
    private var morphProgress: CGFloat = 0
    private var morphStartTime: TimeInterval = 0
    private var isMorphing = false
    private let morphDuration: TimeInterval = 1.2
    private var morphOutlineNode: SKShapeNode?
    private var morphInnerFillNode: SKShapeNode?
    private var morphGlassFillNode: SKShapeNode?
    private var morphOuterGlowNode: SKShapeNode?
    private var morphLeftRimNode: SKShapeNode?
    private var morphRightRimNode: SKShapeNode?
    private var morphHighlightNode: SKShapeNode?
    private var morphBackWallMask: SKShapeNode?
    private var morphFrameCounter: Int = 0
    private var lastPhysicsUpdateFrame: Int = 0

    private var lastHapticTime: TimeInterval = 0
    private var crystalSpawnIndex: Int = 0

    /// Container node for all bokeh background orbs.
    private var bokehContainerNode: SKNode?
    /// Per-depth-layer containers for parallax offset.
    private var bokehLayerNodes: [SKNode] = []

    /// Smoothed tilt values for bokeh parallax (updated from CoreMotion).
    private var bokehTiltX: CGFloat = 0
    private var bokehTiltY: CGFloat = 0

    /// Track which nodes have already received their exit boost so we only apply it once.
    private var boostedNodes: Set<ObjectIdentifier> = []

    // MARK: Sticky Web
    /// Nodes currently stuck in a web zone, keyed by the node. Value is the web node they are stuck in.
    private var stuckNodes: [SKNode: SKNode] = [:]
    private let shakeAccelerationThreshold: Double = 2.5
    private var lastShakeTime: TimeInterval = 0

    private var isGameplayActive: Bool {
        viewModel?.gameState == .playing
    }

    // MARK: - Factory

    class func newGameScene() -> GameScene {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .aspectFit
        return scene
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .black

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        view.ignoresSiblingOrder = true
        #if os(iOS)
        let maxFPS = view.window?.windowScene?.screen.maximumFramesPerSecond ?? 60
        view.preferredFramesPerSecond = min(120, maxFPS)
        #endif
        view.showsFPS = false
        view.showsNodeCount = true

        #if os(iOS)
        // Disable expensive scene effects in low-power mode.
        shouldEnableEffects = !ProcessInfo.processInfo.isLowPowerModeEnabled
        #else
        shouldEnableEffects = true
        #endif

        physicsWorld.gravity = CGVector(dx: 0, dy: -gravityStrength)
        physicsWorld.speed = 1.0
        physicsWorld.contactDelegate = self

        #if os(iOS)
        crystalImpactGenerator.prepare()
        wallImpactGenerator.prepare()
        #endif

        // Radial gradient background (center-lit studio environment)
        let bgNode = SKSpriteNode(texture: makeRadialGradientTexture(
            size: self.size,
            innerColor: SKColor(red: 0.10, green: 0.10, blue: 0.22, alpha: 1),
            outerColor: SKColor(red: 0.04, green: 0.02, blue: 0.08, alpha: 1)
        ))
        bgNode.position  = CGPoint(x: frame.midX, y: frame.midY)
        bgNode.zPosition = -10
        bgNode.name      = "background"
        // Keep background out of dynamic lighting for cheaper draw.
        bgNode.lightingBitMask    = 0
        bgNode.shadowedBitMask    = 0
        bgNode.shadowCastBitMask  = 0
        addChild(bgNode)

        // --- Bokeh depth background ---
        setupBokehBackground()

        // --- Single global light ---
        setupLighting()

        // --- Jar-only rasterized effect node ---
        setupJarEffectNode()

        buildJar(shape: VesselShapeRegistry.shape(forStage: 1))
        spawnAmbientBackgroundItems()
        startMotion()
        startBackgroundMusic()
    }

    /// Called from the UI when the player taps Start or Play Again.
    func beginGame() {
        // Remove any leftover nodes from a previous game
        children.filter {
            $0.name == "crystal" || $0.name == "junk" || $0.name == "balloon" ||
            $0.name == "banner" || $0.name == "web" ||
            $0.name == "ambientCrystal" || $0.name == "ambientEmoji"
        }
        .forEach { node in
            node.removeAllActions()
            node.removeFromParent()
        }

        stuckNodes.removeAll()
        boostedNodes.removeAll()
        crystalSpawnIndex = 0
        stageWon = false
        gameOver = false
        isTransitioningShape = false

        // Cancel any in-progress morph.
        if isMorphing {
            isMorphing = false
            morphInterpolator = nil
            morphOutlineNode = nil
            morphInnerFillNode = nil
            morphGlassFillNode = nil
            morphOuterGlowNode = nil
            morphLeftRimNode = nil
            morphRightRimNode = nil
            morphHighlightNode = nil
            morphBackWallMask = nil
        }

        // Rebuild jar for stage 1 shape if the previous game ended at a different shape.
        let stage1Shape = VesselShapeRegistry.shape(forStage: 1)
        if stage1Shape.name != currentVesselShape.name {
            teardownJar()
            buildJar(shape: stage1Shape)
        }

        fillJar()
    }

    override func willMove(from view: SKView) {
        #if os(iOS)
        motionManager.stopDeviceMotionUpdates()
        #endif
        stopBackgroundMusic()
    }

    // MARK: - Background Music

    private func startBackgroundMusic() {
        guard bgMusicPlayer == nil || bgMusicPlayer?.isPlaying == false else { return }

        guard let url = Bundle.main.url(forResource: "bg_music", withExtension: "mp3") else { return }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1 // loop indefinitely
            player.volume = 0.4
            player.prepareToPlay()
            player.play()
            bgMusicPlayer = player
        } catch {
            print("Background music failed to load: \(error)")
        }
    }

    private func stopBackgroundMusic() {
        bgMusicPlayer?.stop()
        bgMusicPlayer = nil
    }

    // MARK: - Dynamic Lighting

    private func setupLighting() {
        // Single global light for the entire scene.
        let light = SKLightNode()
        light.name = "primaryLight"
        light.position = CGPoint(x: frame.midX, y: frame.maxY - 40)
        light.zPosition = 50

        light.categoryBitMask = LightCategory.scene
        light.lightColor = SKColor(white: 0.92, alpha: 1)
        light.ambientColor = SKColor(red: 0.30, green: 0.28, blue: 0.36, alpha: 1)
        light.shadowColor = SKColor(red: 0.0, green: 0.0, blue: 0.05, alpha: 0.22)
        light.falloff = 0.55

        addChild(light)
        primaryLight = light

        // Fill light — positioned inside the jar body to illuminate objects from up close
        let fillLight = SKLightNode()
        fillLight.name = "fillLight"
        fillLight.position = CGPoint(x: frame.midX, y: frame.midY - 60)
        fillLight.zPosition = 50

        fillLight.categoryBitMask = LightCategory.scene
        fillLight.lightColor = SKColor(red: 0.5, green: 0.5, blue: 0.6, alpha: 1)
        fillLight.ambientColor = SKColor(red: 0, green: 0, blue: 0, alpha: 1)
        fillLight.shadowColor = SKColor(white: 0, alpha: 0)
        fillLight.falloff = 1.0

        addChild(fillLight)
    }

    // MARK: - Jar Effect Node

    private func setupJarEffectNode() {
        let effectNode = SKEffectNode()
        effectNode.name = "jarEffectNode"
        effectNode.zPosition = 6
        effectNode.shouldEnableEffects = shouldEnableEffects
        effectNode.shouldRasterize = true

        // Keep this node rasterized only; per-node blur here softens the whole jar and creates edge artifacts.
        effectNode.filter = nil

        addChild(effectNode)
        jarEffectNode = effectNode
    }

    // MARK: - Jar Construction

    /// Removes all jar-related nodes so the jar can be rebuilt with a new shape.
    /// Does NOT remove `jarEffectNode` itself — only its children.
    private func teardownJar() {
        // Physics nodes
        childNode(withName: "wall")?.removeFromParent()
        childNode(withName: "ambientWall")?.removeFromParent()

        // Ambient background items (they reference the old ambientWall)
        children.filter {
            $0.name == "ambientCrystal" || $0.name == "ambientEmoji"
        }.forEach { $0.removeFromParent() }

        // Back wall crop node
        childNode(withName: "jarBackWallCrop")?.removeFromParent()

        // Visual root (all layers inside jarEffectNode)
        jarEffectNode?.removeAllChildren()

        // Reflection emitter
        childNode(withName: "jarReflectionEmitter")?.removeFromParent()

        // Dirt overlays
        for node in dirtNodes { node.removeFromParent() }
        dirtNodes.removeAll()

        // Clear geometry cache
        jarPath = nil
        currentGeometry = nil
    }

    private func buildJar(shape: VesselShape) {
        currentVesselShape = shape
        let geometry = shape.buildGeometry(
            frameWidth: frame.width,
            frameHeight: frame.height
        )
        currentGeometry = geometry

        // Synchronise legacy jar variables used throughout the scene.
        jarMinX    = geometry.minX
        jarMaxX    = geometry.maxX
        jarBottomY = geometry.bottomY
        jarTopY    = geometry.topY
        jarPath    = geometry.path

        let path       = geometry.path
        let shoulderY  = geometry.shoulderY
        let neckH      = geometry.neckHeight
        let bodyCornerR = geometry.bodyCornerRadius
        let bodyW      = geometry.bodyWidth
        let cx         = geometry.centerX
        let by         = geometry.bottomY
        let h          = geometry.height

        // Physics body
        let jarNode = SKNode()
        jarNode.name = "wall"
        let body = SKPhysicsBody(edgeChainFrom: path)
        body.isDynamic          = false
        body.friction           = 0.40
        body.restitution        = 0.30
        body.categoryBitMask    = PhysicsCategory.wall
        body.collisionBitMask   = PhysicsCategory.allEmoji
        body.contactTestBitMask = PhysicsCategory.allEmoji
        jarNode.physicsBody = body
        addChild(jarNode)

        // Closed jar collider used only for ambient background items.
        let ambientContainmentPath = CGMutablePath()
        ambientContainmentPath.addPath(path)
        ambientContainmentPath.closeSubpath()

        let ambientWallNode = SKNode()
        ambientWallNode.name = "ambientWall"
        let ambientWallBody = SKPhysicsBody(edgeLoopFrom: ambientContainmentPath)
        ambientWallBody.isDynamic = false
        ambientWallBody.friction = 0.35
        ambientWallBody.restitution = 0.35
        ambientWallBody.categoryBitMask = PhysicsCategory.ambientWall
        ambientWallBody.collisionBitMask = PhysicsCategory.ambient
        ambientWallBody.contactTestBitMask = 0
        ambientWallNode.physicsBody = ambientWallBody
        addChild(ambientWallNode)

        let jarVisualRoot = SKNode()
        jarVisualRoot.name = "jarVisualRoot"
        jarVisualRoot.zPosition = 0
        jarEffectNode?.addChild(jarVisualRoot)

        // Dedicated rasterized node for static glow/lighting details.
        let glowEffectsNode = SKEffectNode()
        glowEffectsNode.name = "jarGlowEffectsNode"
        glowEffectsNode.zPosition = 2
        glowEffectsNode.shouldEnableEffects = shouldEnableEffects
        glowEffectsNode.shouldRasterize = true
        jarVisualRoot.addChild(glowEffectsNode)

        // --- Layer 0: Back wall shadow catcher ---
        // Clip the tint to the jar path to avoid showing a rectangular backdrop.
        let backWallPath = CGMutablePath()
        backWallPath.addPath(path)
        backWallPath.closeSubpath()

        let backWallMask = SKShapeNode(path: backWallPath)
        backWallMask.fillColor = .white
        backWallMask.strokeColor = .clear
        backWallMask.isAntialiased = true

        let backWall = SKSpriteNode(
            color: SKColor(red: 0.05, green: 0.04, blue: 0.10, alpha: 0.12),
            size: CGSize(width: bodyW + 20, height: h + 20)
        )
        backWall.position = CGPoint(x: cx, y: by + h / 2)
        backWall.name = "jarBackWall"
        backWall.lightingBitMask   = LightCategory.scene
        backWall.shadowedBitMask   = LightCategory.scene
        backWall.shadowCastBitMask = 0

        let backWallCropNode = SKCropNode()
        backWallCropNode.name = "jarBackWallCrop"
        backWallCropNode.zPosition = -5
        backWallCropNode.maskNode = backWallMask
        backWallCropNode.addChild(backWall)
        addChild(backWallCropNode)

        // --- Layer 1: Inner fill (depth tint) ---
        let innerFill = SKShapeNode(path: path)
        innerFill.name        = "jarInnerFill"
        innerFill.strokeColor = .clear
        innerFill.fillColor   = SKColor(red: 0.4, green: 0.5, blue: 0.8, alpha: 0.04)
        innerFill.lineJoin    = .round
        innerFill.isAntialiased = true
        innerFill.zPosition   = 0
        jarVisualRoot.addChild(innerFill)

        // --- Layer 2: Glass fill with custom shader (specular sheen + inner glow) ---
        // The shader produces near-zero alpha in the center so objects inside remain visible.
        // zPosition 8 puts this in front of everything as a transparent overlay.
        let glassFill = SKShapeNode(path: path)
        glassFill.name        = "jarGlass"
        glassFill.strokeColor = .clear
        glassFill.fillColor   = SKColor(white: 1.0, alpha: 0.01)  // near-transparent base; shader drives actual output
        glassFill.fillShader  = glassShader
        glassFill.lineJoin    = .round
        glassFill.zPosition   = 2
        glassFill.isAntialiased = true
        jarVisualRoot.addChild(glassFill)

        // --- Layer 3: Main glass outline with gradient stroke shader ---
        let outline = SKShapeNode(path: path)
        outline.name        = "jarOutline"
        outline.strokeColor = .white      // shader overrides this
        outline.lineWidth   = 3.5
        outline.lineCap     = .round
        outline.lineJoin    = .round
        outline.fillColor   = .clear
        outline.strokeShader = jarStrokeShader
        outline.glowWidth   = 2.5
        outline.isAntialiased = true
        outline.zPosition   = 1
        jarVisualRoot.addChild(outline)

        // --- Layer 3b: Outer edge glow (soft glass catch light) ---
        let outerGlow = SKShapeNode(path: path)
        outerGlow.name = "jarOuterGlow"
        outerGlow.strokeColor = SKColor(red: 0.88, green: 0.94, blue: 1.0, alpha: 0.24)
        outerGlow.lineWidth = 2.0
        outerGlow.lineCap = .round
        outerGlow.lineJoin = .round
        outerGlow.fillColor = .clear
        outerGlow.glowWidth = 4.6
        outerGlow.isAntialiased = true
        outerGlow.zPosition = 0
        glowEffectsNode.addChild(outerGlow)

        // --- Layer 3c: Inner rim light (glass thickness cue) ---
        // Keep this on the shoulders/sides only so the floor doesn't get bright artifacts.
        let innerRimOffset: CGFloat = 8.0

        if let leftRimPath = shape.leftInnerRimPath(geometry: geometry, offset: innerRimOffset) {
            let leftInnerRim = SKShapeNode(path: leftRimPath)
            leftInnerRim.name = "jarInnerRimLight"
            leftInnerRim.strokeColor = SKColor(white: 1.0, alpha: 0.24)
            leftInnerRim.lineWidth = 1.4
            leftInnerRim.lineCap = .round
            leftInnerRim.lineJoin = .round
            leftInnerRim.fillColor = .clear
            leftInnerRim.glowWidth = 1.8
            leftInnerRim.isAntialiased = true
            leftInnerRim.zPosition = 1
            glowEffectsNode.addChild(leftInnerRim)
        }

        if let rightRimPath = shape.rightInnerRimPath(geometry: geometry, offset: innerRimOffset) {
            let rightInnerRim = SKShapeNode(path: rightRimPath)
            rightInnerRim.name = "jarInnerRimLight"
            rightInnerRim.strokeColor = SKColor(white: 1.0, alpha: 0.24)
            rightInnerRim.lineWidth = 1.4
            rightInnerRim.lineCap = .round
            rightInnerRim.lineJoin = .round
            rightInnerRim.fillColor = .clear
            rightInnerRim.glowWidth = 1.8
            rightInnerRim.isAntialiased = true
            rightInnerRim.zPosition = 1
            glowEffectsNode.addChild(rightInnerRim)
        }

        // --- Layer 4: Left-side highlight (light reflection) ---
        let hlOff: CGFloat = 3  // inset from the main outline
        if let hlPath = shape.leftHighlightPath(geometry: geometry, offset: hlOff) {
            let highlight = SKShapeNode(path: hlPath)
            highlight.name        = "jarHighlight"
            highlight.strokeColor = SKColor(white: 1, alpha: 0.15)
            highlight.lineWidth   = 1.5
            highlight.lineCap     = .round
            highlight.lineJoin    = .round
            highlight.fillColor   = .clear
            highlight.glowWidth   = 1.0
            highlight.isAntialiased = true
            highlight.zPosition   = 3
            jarVisualRoot.addChild(highlight)
        }

        // --- Layer 5: Ambient occlusion in lower inner corners ---
        let aoSize = CGSize(width: bodyCornerR * 1.9, height: bodyCornerR * 1.6)
        let leftAO = SKSpriteNode(texture: makeAmbientOcclusionSpotTexture(size: aoSize), size: aoSize)
        leftAO.name = "jarAmbientOcclusionLeft"
        leftAO.position = CGPoint(
            x: jarMinX + bodyCornerR + 14,
            y: by + bodyCornerR + 8
        )
        leftAO.alpha = 0.22
        leftAO.blendMode = .multiply
        leftAO.zPosition = 1
        glowEffectsNode.addChild(leftAO)

        let rightAO = SKSpriteNode(texture: makeAmbientOcclusionSpotTexture(size: aoSize), size: aoSize)
        rightAO.name = "jarAmbientOcclusionRight"
        rightAO.position = CGPoint(
            x: jarMaxX - bodyCornerR - 14,
            y: by + bodyCornerR + 8
        )
        rightAO.alpha = 0.22
        rightAO.blendMode = .multiply
        rightAO.zPosition = 1
        glowEffectsNode.addChild(rightAO)

        // Jar reflection shimmer particles
        addJarReflectionParticles()

        // Dirt / smudge overlays (opacity controlled by EnergyManager.dirtLevel)
        addJarDirtOverlays()
    }

    // MARK: - Jar Reflection Particles

    private func addJarReflectionParticles() {
        let emitter = SKEmitterNode()
        emitter.particleTexture = makeCircleTexture(radius: 4)

        emitter.particleBirthRate       = 1.5
        emitter.numParticlesToEmit      = 0     // infinite
        emitter.particleLifetime        = 6.0
        emitter.particleLifetimeRange   = 3.0

        emitter.particlePositionRange   = CGVector(
            dx: jarMaxX - jarMinX - 20,
            dy: jarTopY - jarBottomY - 40
        )

        emitter.particleSpeed           = 4.0
        emitter.particleSpeedRange      = 2.0
        emitter.emissionAngle           = .pi / 2
        emitter.emissionAngleRange      = .pi / 4

        emitter.particleAlpha           = 0.0
        emitter.particleAlphaSequence   = SKKeyframeSequence(
            keyframeValues: [NSNumber(value: 0),
                             NSNumber(value: 0.15),
                             NSNumber(value: 0.15),
                             NSNumber(value: 0)],
            times: [0, 0.2, 0.8, 1.0]
        )

        emitter.particleScale           = 0.4
        emitter.particleScaleRange      = 0.3
        emitter.particleColor           = .white
        emitter.particleColorBlendFactor = 1.0

        emitter.position = CGPoint(
            x: frame.midX,
            y: jarBottomY + (jarTopY - jarBottomY) / 2
        )
        emitter.zPosition = -2
        emitter.name = "jarReflectionEmitter"
        addChild(emitter)
    }

    // MARK: - Jar Dirt Overlays

    /// Called once from buildJar to set up initial dirt state.
    private func addJarDirtOverlays() {
        updateDirtOverlays()
    }

    /// Rebuild dirt overlays based on completed plays.
    /// The first play of the day shows a clean jar — stains only appear after finishing a game.
    /// Each completed play adds a new cluster of stains that accumulate in isolated spots.
    func updateDirtOverlays() {
        // Remove old dirt nodes
        for node in dirtNodes { node.removeFromParent() }
        dirtNodes.removeAll()

        // Stains represent *completed* plays, so subtract the in-progress one.
        // playsUsedToday is incremented at game start, so during the first play it's 1,
        // but we want 0 stains until that play finishes.
        let completedPlays = max(0, EnergyManager.shared.playsUsedToday - (viewModel?.gameState == .playing ? 1 : 0))
        guard completedPlays > 0 else { return }

        // Seeded RNG — deterministic positions for a given completed count.
        var rng = DirtRNG(seed: UInt64(completedPlays &* 7919 &+ 42))

        for playIndex in 1...completedPlays {
            addStainBatch(playIndex: playIndex, rng: &rng)
        }
    }

    /// Adds one batch of dirt marks for a single completed play.
    /// Dirt concentrates around the neck/rim (where hands touch) and the bottom/corners
    /// (where grime settles). The middle body stays mostly clean.
    private func addStainBatch(playIndex: Int, rng: inout DirtRNG) {
        let jarW = jarMaxX - jarMinX
        let jarH = jarTopY - jarBottomY
        let cx = (jarMinX + jarMaxX) / 2
        // Neck zone: the narrow opening at the top where fingers grip
        let neckW = jarW * 0.38
        let neckTopY = jarTopY
        let neckBottomY = jarTopY - jarH * 0.30

        // --- Neck / rim stains (2-4 per play) — where hands grab the jar ---
        let neckCount = 2 + rng.nextInt(bound: 3)
        for _ in 0..<neckCount {
            let x = cx + rng.nextCGFloat(in: -neckW * 0.55 ... neckW * 0.55)
            let y = rng.nextCGFloat(in: neckBottomY ... neckTopY)
            let w = rng.nextCGFloat(in: 22...46)
            let h = rng.nextCGFloat(in: 16...34)

            let smudge = makeSmudgeBlotch(size: CGSize(width: w, height: h), rng: &rng)
            smudge.position = CGPoint(x: x, y: y)
            smudge.zPosition = 7
            smudge.zRotation = rng.nextCGFloat(in: -0.8...0.8)
            smudge.alpha = min(0.24 + CGFloat(playIndex) * 0.08, 0.58)
            smudge.name = "dirtStain"
            addChild(smudge)
            dirtNodes.append(smudge)
        }

        // --- Rim grime spots around the lip (2-3 per play) ---
        let rimSpotCount = 2 + rng.nextInt(bound: 2)
        for _ in 0..<rimSpotCount {
            let x = cx + rng.nextCGFloat(in: -neckW * 0.50 ... neckW * 0.50)
            let y = neckTopY - rng.nextCGFloat(in: 0...18)
            let r = rng.nextCGFloat(in: 4...9)

            let spot = makeGrimeSpot(radius: r, rng: &rng)
            spot.position = CGPoint(x: x, y: y)
            spot.zPosition = 7
            spot.alpha = min(0.28 + CGFloat(playIndex) * 0.07, 0.60)
            spot.name = "dirtStain"
            addChild(spot)
            dirtNodes.append(spot)
        }

        // --- Bottom / corner dirt (grows each play) ---
        addBottomDirt(playIndex: playIndex, rng: &rng)

        // --- Rare mid-body stain: only ~20% chance, just 1 small mark ---
        if rng.nextInt(bound: 10) < 2 {
            let x = cx + rng.nextCGFloat(in: -jarW * 0.32 ... jarW * 0.32)
            let y = jarBottomY + jarH * 0.25 + rng.nextCGFloat(in: 0 ... jarH * 0.35)
            let r = rng.nextCGFloat(in: 4...8)

            let spot = makeGrimeSpot(radius: r, rng: &rng)
            spot.position = CGPoint(x: x, y: y)
            spot.zPosition = 7
            spot.alpha = min(0.18 + CGFloat(playIndex) * 0.06, 0.40)
            spot.name = "dirtStain"
            addChild(spot)
            dirtNodes.append(spot)
        }
    }

    /// Adds dirt buildup along the jar floor and into the lower corners.
    private func addBottomDirt(playIndex: Int, rng: inout DirtRNG) {
        let jarW = jarMaxX - jarMinX
        let cx = (jarMinX + jarMaxX) / 2
        let alpha = min(0.18 + CGFloat(playIndex) * 0.07, 0.52)

        // Floor smudge — a wide, flat blotch along the bottom
        let floorW = jarW * (0.22 + CGFloat(playIndex) * 0.09)
        let floorH: CGFloat = 10 + CGFloat(playIndex) * 4
        let floorDust = makeSmudgeBlotch(
            size: CGSize(width: min(floorW, jarW * 0.65), height: floorH),
            rng: &rng
        )
        floorDust.position = CGPoint(
            x: cx + rng.nextCGFloat(in: -jarW * 0.06 ... jarW * 0.06),
            y: jarBottomY + floorH * 0.5 + 8
        )
        floorDust.zPosition = 7
        floorDust.alpha = alpha + 0.08
        floorDust.name = "dirtStain"
        addChild(floorDust)
        dirtNodes.append(floorDust)

        // Left corner — blotch + spots
        let leftBlotch = makeSmudgeBlotch(
            size: CGSize(width: rng.nextCGFloat(in: 18...30), height: rng.nextCGFloat(in: 14...24)),
            rng: &rng
        )
        leftBlotch.position = CGPoint(
            x: jarMinX + rng.nextCGFloat(in: 18...42),
            y: jarBottomY + rng.nextCGFloat(in: 14...36)
        )
        leftBlotch.zPosition = 7
        leftBlotch.zRotation = rng.nextCGFloat(in: -0.5...0.5)
        leftBlotch.alpha = alpha + 0.06
        leftBlotch.name = "dirtStain"
        addChild(leftBlotch)
        dirtNodes.append(leftBlotch)

        let leftSpotCount = 1 + rng.nextInt(bound: 2)
        for _ in 0..<leftSpotCount {
            let r = rng.nextCGFloat(in: 4...10)
            let spot = makeGrimeSpot(radius: r, rng: &rng)
            spot.position = CGPoint(
                x: jarMinX + rng.nextCGFloat(in: 10...48),
                y: jarBottomY + rng.nextCGFloat(in: 8...40)
            )
            spot.zPosition = 7
            spot.alpha = alpha + 0.05
            spot.name = "dirtStain"
            addChild(spot)
            dirtNodes.append(spot)
        }

        // Right corner — blotch + spots
        let rightBlotch = makeSmudgeBlotch(
            size: CGSize(width: rng.nextCGFloat(in: 18...30), height: rng.nextCGFloat(in: 14...24)),
            rng: &rng
        )
        rightBlotch.position = CGPoint(
            x: jarMaxX - rng.nextCGFloat(in: 18...42),
            y: jarBottomY + rng.nextCGFloat(in: 14...36)
        )
        rightBlotch.zPosition = 7
        rightBlotch.zRotation = rng.nextCGFloat(in: -0.5...0.5)
        rightBlotch.alpha = alpha + 0.06
        rightBlotch.name = "dirtStain"
        addChild(rightBlotch)
        dirtNodes.append(rightBlotch)

        let rightSpotCount = 1 + rng.nextInt(bound: 2)
        for _ in 0..<rightSpotCount {
            let r = rng.nextCGFloat(in: 4...10)
            let spot = makeGrimeSpot(radius: r, rng: &rng)
            spot.position = CGPoint(
                x: jarMaxX - rng.nextCGFloat(in: 10...48),
                y: jarBottomY + rng.nextCGFloat(in: 8...40)
            )
            spot.zPosition = 7
            spot.alpha = alpha + 0.05
            spot.name = "dirtStain"
            addChild(spot)
            dirtNodes.append(spot)
        }
    }

    // MARK: Dirt Sprite Factories

    /// Flat opaque smudge blotch — like a thumbprint on glass. No arcs, no glow.
    /// Uses an irregular filled shape with slight transparency variation.
    private func makeSmudgeBlotch(size: CGSize, rng: inout DirtRNG) -> SKSpriteNode {
        let pw = max(Int(size.width * 2), 8)
        let ph = max(Int(size.height * 2), 8)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let ctx = CGContext(
            data: nil, width: pw, height: ph,
            bitsPerComponent: 8, bytesPerRow: pw * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return SKSpriteNode() }

        ctx.clear(CGRect(origin: .zero, size: CGSize(width: pw, height: ph)))

        let cx = CGFloat(pw) / 2
        let cy = CGFloat(ph) / 2
        let rx = CGFloat(pw) * 0.42
        let ry = CGFloat(ph) * 0.42

        // Build an irregular blob path using perturbed ellipse points
        let pointCount = 10
        let blobPath = CGMutablePath()
        var points: [CGPoint] = []
        for i in 0..<pointCount {
            let angle = (CGFloat(i) / CGFloat(pointCount)) * .pi * 2
            let wobble = rng.nextCGFloat(in: 0.70...1.0)
            let px = cx + cos(angle) * rx * wobble
            let py = cy + sin(angle) * ry * wobble
            points.append(CGPoint(x: px, y: py))
        }
        blobPath.move(to: points[0])
        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]
            let mpx = (prev.x + curr.x) / 2
            let mpy = (prev.y + curr.y) / 2
            blobPath.addQuadCurve(to: CGPoint(x: mpx, y: mpy), control: prev)
        }
        let last = points.last!
        let first = points[0]
        blobPath.addQuadCurve(to: first, control: last)
        blobPath.closeSubpath()

        // Fill with a dirty brownish color
        let r = rng.nextCGFloat(in: 0.38...0.50)
        let g = rng.nextCGFloat(in: 0.32...0.42)
        let b = rng.nextCGFloat(in: 0.22...0.30)
        ctx.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 0.60))
        ctx.addPath(blobPath)
        ctx.fillPath()

        // Add a slightly different inner blob for texture variation
        let innerPath = CGMutablePath()
        var innerPts: [CGPoint] = []
        for i in 0..<8 {
            let angle = (CGFloat(i) / 8.0) * .pi * 2 + rng.nextCGFloat(in: -0.3...0.3)
            let wobble = rng.nextCGFloat(in: 0.30...0.55)
            let px = cx + cos(angle) * rx * wobble
            let py = cy + sin(angle) * ry * wobble
            innerPts.append(CGPoint(x: px, y: py))
        }
        innerPath.move(to: innerPts[0])
        for i in 1..<innerPts.count {
            innerPath.addLine(to: innerPts[i])
        }
        innerPath.closeSubpath()
        ctx.setFillColor(CGColor(red: r * 0.85, green: g * 0.85, blue: b * 0.85, alpha: 0.35))
        ctx.addPath(innerPath)
        ctx.fillPath()

        guard let image = ctx.makeImage() else { return SKSpriteNode() }
        let tex = SKTexture(cgImage: image)
        let sprite = SKSpriteNode(texture: tex, size: size)
        sprite.blendMode = .alpha
        return sprite
    }

    /// A short smear mark — like a finger dragged across dirty glass.
    private func makeSmearMark(rng: inout DirtRNG) -> SKSpriteNode {
        let length = rng.nextCGFloat(in: 35...70)
        let thickness = rng.nextCGFloat(in: 8...18)
        let pw = max(Int(length * 2), 8)
        let ph = max(Int(thickness * 4), 8)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let ctx = CGContext(
            data: nil, width: pw, height: ph,
            bitsPerComponent: 8, bytesPerRow: pw * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return SKSpriteNode() }

        ctx.clear(CGRect(origin: .zero, size: CGSize(width: pw, height: ph)))

        let midY = CGFloat(ph) / 2
        let startX = CGFloat(pw) * 0.08
        let endX = CGFloat(pw) * 0.92

        // Dirty brownish color
        let r = rng.nextCGFloat(in: 0.40...0.52)
        let g = rng.nextCGFloat(in: 0.34...0.44)
        let b = rng.nextCGFloat(in: 0.24...0.32)

        // Draw 2-3 overlapping thick strokes for a smeared look
        let strokeCount = 2 + rng.nextInt(bound: 2)
        for s in 0..<strokeCount {
            let yOff = rng.nextCGFloat(in: -thickness * 0.4 ... thickness * 0.4)
            let lw = thickness * rng.nextCGFloat(in: 0.6...1.0)
            let alpha = rng.nextCGFloat(in: 0.30...0.55)

            ctx.setStrokeColor(CGColor(red: r, green: g, blue: b, alpha: alpha))
            ctx.setLineWidth(lw)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            let path = CGMutablePath()
            path.move(to: CGPoint(x: startX, y: midY + yOff))

            let segs = 3 + rng.nextInt(bound: 3)
            let segW = (endX - startX) / CGFloat(segs)
            for i in 1...segs {
                let px = startX + segW * CGFloat(i)
                let py = midY + yOff + rng.nextCGFloat(in: -lw * 0.5 ... lw * 0.5)
                path.addLine(to: CGPoint(x: px, y: py))
            }
            ctx.addPath(path)
            ctx.strokePath()

            _ = s  // silence unused warning
        }

        guard let image = ctx.makeImage() else { return SKSpriteNode() }
        let tex = SKTexture(cgImage: image)
        let displaySize = CGSize(width: length, height: thickness * 2)
        let sprite = SKSpriteNode(texture: tex, size: displaySize)
        sprite.blendMode = .alpha
        return sprite
    }

    /// Small grime spot — an opaque irregular dot like dried residue on glass.
    private func makeGrimeSpot(radius: CGFloat, rng: inout DirtRNG) -> SKSpriteNode {
        let pixSize = max(Int(radius * 4), 6)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let ctx = CGContext(
            data: nil, width: pixSize, height: pixSize,
            bitsPerComponent: 8, bytesPerRow: pixSize * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return SKSpriteNode() }

        ctx.clear(CGRect(origin: .zero, size: CGSize(width: pixSize, height: pixSize)))

        let center = CGPoint(x: CGFloat(pixSize) / 2, y: CGFloat(pixSize) / 2)
        let r = CGFloat(pixSize) * 0.44

        // Irregular polygon shape
        let sides = 5 + rng.nextInt(bound: 4)
        let path = CGMutablePath()
        for i in 0..<sides {
            let angle = (CGFloat(i) / CGFloat(sides)) * .pi * 2
            let wobble = rng.nextCGFloat(in: 0.65...1.0)
            let px = center.x + cos(angle) * r * wobble
            let py = center.y + sin(angle) * r * wobble
            if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
            else { path.addLine(to: CGPoint(x: px, y: py)) }
        }
        path.closeSubpath()

        let red = rng.nextCGFloat(in: 0.36...0.48)
        let green = rng.nextCGFloat(in: 0.30...0.40)
        let blue = rng.nextCGFloat(in: 0.20...0.28)
        ctx.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 0.70))
        ctx.addPath(path)
        ctx.fillPath()

        guard let image = ctx.makeImage() else { return SKSpriteNode() }
        let tex = SKTexture(cgImage: image)
        let displaySize = CGSize(width: radius * 2, height: radius * 2)
        let sprite = SKSpriteNode(texture: tex, size: displaySize)
        sprite.blendMode = .alpha
        return sprite
    }

    /// Simple seeded RNG for deterministic dirt placement per play count.
    private struct DirtRNG {
        private var state: UInt64

        init(seed: UInt64) { state = seed == 0 ? 1 : seed }

        mutating func next() -> UInt64 {
            state ^= state &<< 13
            state ^= state &>> 7
            state ^= state &<< 17
            return state
        }

        mutating func nextDouble() -> Double {
            return Double(next() % 1_000_000) / 1_000_000.0
        }

        mutating func nextCGFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
            let t = CGFloat(nextDouble())
            return range.lowerBound + t * (range.upperBound - range.lowerBound)
        }

        mutating func nextInt(bound: Int) -> Int {
            guard bound > 0 else { return 0 }
            return Int(next() % UInt64(bound))
        }
    }

    // MARK: - Emoji Texture Rendering

    /// Renders an emoji character into a texture suitable for SKSpriteNode + normal mapping.
    private func emojiTexture(for type: EmojiType) -> SKTexture {
        let key = type.character
        if let cached = emojiTextureCache[key] { return cached }

        let fontSize = type.fontSize
        let padding: CGFloat = 8
        let size = CGSize(width: fontSize + padding * 2, height: fontSize + padding * 2)

        #if os(iOS)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            let str = NSAttributedString(
                string: type.character,
                attributes: [
                    .font: UIFont.systemFont(ofSize: fontSize),
                ]
            )
            let strSize = str.size()
            let origin = CGPoint(
                x: (size.width - strSize.width) / 2,
                y: (size.height - strSize.height) / 2
            )
            str.draw(at: origin)
        }
        let texture = SKTexture(image: image)
        #else
        let image = NSImage(size: size, flipped: false) { rect in
            let str = NSAttributedString(
                string: type.character,
                attributes: [
                    .font: NSFont.systemFont(ofSize: fontSize),
                ]
            )
            let strSize = str.size()
            let origin = CGPoint(
                x: (size.width - strSize.width) / 2,
                y: (size.height - strSize.height) / 2
            )
            str.draw(at: origin)
            return true
        }
        let texture = SKTexture(image: image)
        #endif

        emojiTextureCache[key] = texture
        return texture
    }

    /// Creates a small white circle texture for particle emitters (cross-platform).
    private func makeCircleTexture(radius: CGFloat) -> SKTexture {
        let diameter = radius * 2
        let size = CGSize(width: diameter, height: diameter)

        #if os(iOS)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
        #else
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.white.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        return SKTexture(image: image)
        #endif
    }

    /// Creates a slightly shrunken copy of an open jar path, used for inner rim lighting.
    private func makeInsetPath(from path: CGPath, inset: CGFloat, around center: CGPoint) -> CGPath {
        let bounds = path.boundingBoxOfPath
        guard bounds.width > 0, bounds.height > 0 else { return path }

        let sx = max((bounds.width - inset * 2) / bounds.width, 0.85)
        let sy = max((bounds.height - inset * 2) / bounds.height, 0.85)

        var toOrigin = CGAffineTransform(translationX: -center.x, y: -center.y)
        let originPath = path.copy(using: &toOrigin) ?? path

        var scale = CGAffineTransform(scaleX: sx, y: sy)
        let scaledPath = originPath.copy(using: &scale) ?? originPath

        var fromOrigin = CGAffineTransform(translationX: center.x, y: center.y)
        return scaledPath.copy(using: &fromOrigin) ?? path
    }

    /// Creates a subtle radial dark spot used for ambient occlusion near glass corners.
    private func makeAmbientOcclusionSpotTexture(size: CGSize) -> SKTexture {
        let width = max(Int(size.width), 4)
        let height = max(Int(size.height), 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return SKTexture() }

        let center = CGPoint(x: CGFloat(width) * 0.5, y: CGFloat(height) * 0.5)
        let radius = max(CGFloat(width), CGFloat(height)) * 0.55
        let colors: [CGFloat] = [
            0.0, 0.0, 0.0, 0.18,
            0.0, 0.0, 0.0, 0.0
        ]
        if let gradient = CGGradient(
            colorSpace: colorSpace,
            colorComponents: colors,
            locations: [0.0, 1.0],
            count: 2
        ) {
            ctx.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: radius,
                options: [.drawsAfterEndLocation]
            )
        }

        guard let image = ctx.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }

    // MARK: - Radial Gradient Background

    private func makeRadialGradientTexture(
        size: CGSize,
        innerColor: SKColor,
        outerColor: SKColor
    ) -> SKTexture {
        let w = Int(size.width)
        let h = Int(size.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return SKTexture() }

        // Center-lit: light source slightly above center for studio look
        let center = CGPoint(x: CGFloat(w) / 2, y: CGFloat(h) * 0.60)
        let radius = max(CGFloat(w), CGFloat(h)) * 0.75

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        #if os(iOS)
        innerColor.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        outerColor.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        #else
        let ic = innerColor.usingColorSpace(.deviceRGB) ?? innerColor
        let oc = outerColor.usingColorSpace(.deviceRGB) ?? outerColor
        ic.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        oc.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        #endif

        let colors = [r1, g1, b1, a1, r2, g2, b2, a2] as [CGFloat]
        guard let gradient = CGGradient(
            colorSpace: colorSpace,
            colorComponents: colors,
            locations: [0.0, 1.0],
            count: 2
        ) else { return SKTexture() }

        ctx.drawRadialGradient(
            gradient,
            startCenter: center, startRadius: 0,
            endCenter: center, endRadius: radius,
            options: [.drawsAfterEndLocation]
        )

        guard let image = ctx.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }

    // MARK: - Bokeh Background

    /// Creates a soft, radially-faded circle texture for bokeh orbs.
    /// The texture uses a smooth Gaussian-like falloff so edges are extremely diffused.
    private func makeBokehOrbTexture(diameter: CGFloat, color: SKColor) -> SKTexture {
        let size = Int(diameter)
        guard size > 0 else { return SKTexture() }
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let ctx = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return SKTexture() }

        ctx.clear(CGRect(origin: .zero, size: CGSize(width: size, height: size)))

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if os(iOS)
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        let c = color.usingColorSpace(.deviceRGB) ?? color
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif

        let center = CGPoint(x: CGFloat(size) / 2, y: CGFloat(size) / 2)
        let radius = CGFloat(size) / 2

        // Three-stop gradient: bright center -> mid falloff -> transparent edge
        let components: [CGFloat] = [
            r, g, b, a,           // center — full glow
            r, g, b, a * 0.35,   // mid — soft falloff
            r, g, b, 0.0         // edge — fully transparent
        ]
        let locations: [CGFloat] = [0.0, 0.45, 1.0]

        guard let gradient = CGGradient(
            colorSpace: colorSpace,
            colorComponents: components,
            locations: locations,
            count: 3
        ) else { return SKTexture() }

        ctx.drawRadialGradient(
            gradient,
            startCenter: center, startRadius: 0,
            endCenter: center, endRadius: radius,
            options: []
        )

        guard let image = ctx.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }

    /// Builds the layered bokeh background with parallax depth.
    /// Three layers of soft orbs drift at different speeds, creating a deep 3D feel.
    private func setupBokehBackground() {
        // Remove any previous bokeh nodes
        bokehContainerNode?.removeFromParent()
        bokehLayerNodes.removeAll()

        let container = SKNode()
        container.name = "bokehContainer"
        container.zPosition = -9
        addChild(container)
        bokehContainerNode = container

        // Color palette — saturated tones that read as luminous against dark bg
        let palette: [(color: SKColor, weight: Int)] = [
            (SKColor(red: 0.20, green: 0.30, blue: 0.80, alpha: 1.0), 30),  // midnight blue
            (SKColor(red: 0.40, green: 0.18, blue: 0.70, alpha: 1.0), 25),  // purple
            (SKColor(red: 0.15, green: 0.55, blue: 0.70, alpha: 1.0), 20),  // teal
            (SKColor(red: 0.25, green: 0.70, blue: 0.80, alpha: 1.0), 12),  // cyan flash
            (SKColor(red: 0.50, green: 0.28, blue: 0.72, alpha: 1.0), 13),  // violet
        ]
        let totalWeight = palette.reduce(0) { $0 + $1.weight }

        func weightedRandomColor() -> SKColor {
            var ticket = Int.random(in: 0..<totalWeight)
            for entry in palette {
                ticket -= entry.weight
                if ticket < 0 { return entry.color }
            }
            return palette[0].color
        }

        // Layer definitions: (count, sizeRange, alphaRange, driftSpeed, zOffset)
        // Back layer: large, very blurry, slow — creates deep space
        // Mid layer: medium, moderate blur, medium speed
        // Front layer: smaller, slightly sharper, faster — closest to camera
        struct BokehLayer {
            let count: Int
            let sizeRange: ClosedRange<CGFloat>
            let alphaRange: ClosedRange<CGFloat>
            let driftSpeed: CGFloat       // points per second
            let zOffset: CGFloat
            let breatheDuration: ClosedRange<Double>
        }

        let layers: [BokehLayer] = [
            // Back — large, soft, slow drift
            BokehLayer(count: 6, sizeRange: 140...280, alphaRange: 0.35...0.55,
                       driftSpeed: 2.5, zOffset: 0, breatheDuration: 8.0...14.0),
            // Mid — medium orbs
            BokehLayer(count: 7, sizeRange: 70...160, alphaRange: 0.25...0.45,
                       driftSpeed: 5.0, zOffset: 1, breatheDuration: 6.0...10.0),
            // Front — smaller, brightest, fastest drift for parallax contrast
            BokehLayer(count: 6, sizeRange: 35...100, alphaRange: 0.20...0.40,
                       driftSpeed: 8.0, zOffset: 2, breatheDuration: 4.0...8.0),
        ]

        let sceneW = self.size.width
        let sceneH = self.size.height

        for (layerIndex, layer) in layers.enumerated() {
            // Each depth layer gets its own container for parallax offset
            let layerNode = SKNode()
            layerNode.name = "bokehLayer\(layerIndex)"
            layerNode.zPosition = layer.zOffset
            container.addChild(layerNode)
            bokehLayerNodes.append(layerNode)

            for _ in 0..<layer.count {
                let diameter = CGFloat.random(in: layer.sizeRange)
                let orbAlpha = CGFloat.random(in: layer.alphaRange)

                // Bake color directly into the texture for maximum brightness
                let orbColor = weightedRandomColor()
                let texture = makeBokehOrbTexture(diameter: diameter, color: orbColor)
                let orb = SKSpriteNode(texture: texture)
                orb.size = CGSize(width: diameter, height: diameter)

                orb.alpha = orbAlpha
                orb.blendMode = .add
                orb.zPosition = 0

                // No lighting interactions
                orb.lightingBitMask = 0
                orb.shadowedBitMask = 0
                orb.shadowCastBitMask = 0

                // Random starting position across the full scene
                let startX = CGFloat.random(in: -diameter/2 ... sceneW + diameter/2)
                let startY = CGFloat.random(in: -diameter/2 ... sceneH + diameter/2)
                orb.position = CGPoint(x: startX, y: startY)

                layerNode.addChild(orb)

                // --- Drift animation (slow, continuous, looping) ---
                let driftRange = sceneW * 0.3 + diameter
                let driftDuration = Double(driftRange / layer.driftSpeed)

                // Random drift direction with slight upward bias (like rising bubbles)
                let angle = CGFloat.random(in: 0 ... .pi * 2)
                let dx = cos(angle) * driftRange * 0.5
                let dy = sin(angle) * driftRange * 0.3 + driftRange * 0.15  // upward bias

                let drift = SKAction.sequence([
                    .moveBy(x: dx, y: dy, duration: driftDuration),
                    .moveBy(x: -dx, y: -dy, duration: driftDuration)
                ])
                // Add slight timing variance so orbs don't sync
                let driftWithDelay = SKAction.sequence([
                    .wait(forDuration: Double.random(in: 0...3)),
                    .repeatForever(drift)
                ])
                orb.run(driftWithDelay, withKey: "bokehDrift")

                // --- Breathing opacity animation ---
                let breatheDuration = Double.random(in: layer.breatheDuration)
                let peakAlpha = orbAlpha
                let troughAlpha = orbAlpha * CGFloat.random(in: 0.40...0.70)

                let breathe = SKAction.sequence([
                    .fadeAlpha(to: troughAlpha, duration: breatheDuration / 2),
                    .fadeAlpha(to: peakAlpha, duration: breatheDuration / 2)
                ])
                let breatheWithDelay = SKAction.sequence([
                    .wait(forDuration: Double.random(in: 0...breatheDuration)),
                    .repeatForever(breathe)
                ])
                orb.run(breatheWithDelay, withKey: "bokehBreathe")
            }
        }
    }

    /// Offsets each bokeh depth layer opposite to device tilt for subtle parallax.
    /// Back layers shift more, front layers shift less — reversed depth cue.
    private func updateBokehParallax() {
        // Maximum pixel offset per layer (increases with depth index).
        // Layer 0 (back/largest) shifts most, layer 2 (front/smallest) shifts least.
        let maxOffsets: [CGFloat] = [30, 18, 9]

        for (i, layerNode) in bokehLayerNodes.enumerated() {
            guard i < maxOffsets.count else { continue }
            let strength = maxOffsets[i]
            // Opposite direction: negate tilt values
            layerNode.position = CGPoint(
                x: -bokehTiltX * strength,
                y: -bokehTiltY * strength
            )
        }
    }

    // MARK: - Fill Jar

    private func fillJar() {
        let counts = itemCounts(for: stage)
        let crystalCount = counts.crystals
        let junkCount = counts.junk
        let balloonCount = counts.balloons
        let jarW = jarMaxX - jarMinX
        let cx   = frame.midX

        // Build a shuffled list of all item types so positions are fully random
        var items: [EmojiType] = []
        items += Array(repeating: EmojiType.crystal, count: crystalCount)
        for _ in 0..<junkCount { items.append(.randomJunk(forStage: stage)) }
        items += Array(repeating: EmojiType.balloon, count: balloonCount)
        items.shuffle()

        // Place all items at random positions throughout the jar
        for type in items {
            let x = CGFloat.random(in: (cx - jarW * 0.30)...(cx + jarW * 0.30))
            let y = CGFloat.random(in: jarBottomY + 40 ... jarBottomY + 300)
            placeEmoji(type: type, at: CGPoint(x: x, y: y))
        }

        // Spawn sticky webs (obstacle zones) — only from stage 10 onward
        if stage >= 10 {
            let webCount = min(stage - 9, 3)  // 1 web at stage 10, up to 3
            for _ in 0..<webCount {
                let x = CGFloat.random(in: (cx - jarW * 0.25)...(cx + jarW * 0.25))
                let y = CGFloat.random(in: jarBottomY + 80 ... jarBottomY + 220)
                placeWeb(at: CGPoint(x: x, y: y))
            }
        }

        viewModel?.setItemCounts(crystals: crystalCount, junk: junkCount + balloonCount)
    }

    /// The current stage number (forwarded from the view model for difficulty scaling).
    private var stage: Int {
        viewModel?.stage ?? 1
    }

    /// Stage-by-stage spawn tuning: start gentle, then ramp to the standard cap.
    private func itemCounts(for stage: Int) -> (crystals: Int, junk: Int, balloons: Int) {
        switch stage {
        case 1:  return (2, 4, 1)
        case 2:  return (2, 5, 1)
        case 3:  return (3, 6, 1)
        case 4:  return (3, 7, 1)
        case 5:  return (3, 8, 2)
        case 6:  return (4, 9, 2)
        case 7:  return (4, 10, 2)
        case 8:  return (5, 11, 2)
        case 9:  return (5, 12, 3)
        default: return (5, 13, 3)
        }
    }

    private func placeEmoji(type: EmojiType, at position: CGPoint) {
        let texture = emojiTexture(for: type)

        let sprite = SKSpriteNode(texture: texture)
        sprite.name                  = type.nodeName
        sprite.position              = position
        sprite.size                  = texture.size()

        // Keep scene lighting, but disable long projected light shadows.
        sprite.lightingBitMask = LightCategory.scene
        sprite.shadowCastBitMask = 0
        sprite.shadowedBitMask = 0
        if type.isCrystal {
            sprite.shadowedBitMask = LightCategory.scene
            configureCrystalAppearance(sprite)
            sprite.blendMode = .alpha
        }

        // Small local drop shadow to add depth without expensive long cast shadows.
        let dropShadow = SKSpriteNode(texture: texture, color: .black, size: texture.size())
        dropShadow.name = "emojiDropShadow"
        dropShadow.colorBlendFactor = 1.0
        dropShadow.alpha = 0.20
        dropShadow.position = CGPoint(x: 4, y: -4)
        dropShadow.zPosition = -1
        dropShadow.xScale = 0.95
        dropShadow.yScale = 0.85
        sprite.addChild(dropShadow)

        let body = SKPhysicsBody(circleOfRadius: type.radius)
        body.density           = type.density
        body.restitution       = type.restitution
        body.friction          = type.friction
        body.linearDamping     = type.isBalloon ? 2.0 : 0.8
        body.angularDamping    = type.isBalloon ? 0.6 : 0.7
        body.allowsRotation    = !type.isBalloon  // keep balloons upright
        body.affectedByGravity = !type.isBalloon  // balloons ignore gravity
        body.categoryBitMask   = type.physicsCategory
        body.collisionBitMask  = PhysicsCategory.allEmoji | PhysicsCategory.wall

        // All emoji report contact with webs; crystals also with walls (for haptics)
        if type.isCrystal {
            body.contactTestBitMask = PhysicsCategory.wall | PhysicsCategory.web
        } else {
            body.contactTestBitMask = PhysicsCategory.web | PhysicsCategory.wall
        }

        sprite.physicsBody = body
        sprite.zPosition = 2
        addChild(sprite)
    }

    private func spawnAmbientBackgroundItems() {
        children.filter {
            $0.name == "ambientCrystal" || $0.name == "ambientEmoji"
        }
        .forEach { node in
            node.removeAllActions()
            node.removeFromParent()
        }

        let jarW = jarMaxX - jarMinX
        let cx = frame.midX
        let baseYMin = jarBottomY + 130
        let baseYMax = min(jarTopY - 120, jarBottomY + 360)

        let ambientPool = EmojiType.allCases.filter { !$0.isCrystal && !$0.isBalloon }
        for _ in 0..<4 {
            guard let randomType = ambientPool.randomElement() else { continue }
            let x = CGFloat.random(in: (cx - jarW * 0.22)...(cx + jarW * 0.22))
            let y = CGFloat.random(in: baseYMin...baseYMax)
            placeAmbientEmoji(type: randomType, at: CGPoint(x: x, y: y))
        }
    }

    private func placeAmbientEmoji(type: EmojiType, at position: CGPoint) {
        let texture = emojiTexture(for: type)
        let sprite = SKSpriteNode(texture: texture)
        sprite.name = type.isCrystal ? "ambientCrystal" : "ambientEmoji"
        sprite.position = position
        sprite.size = texture.size()
        sprite.alpha = 0.78
        sprite.zPosition = 1

        sprite.lightingBitMask = LightCategory.scene
        sprite.shadowCastBitMask = 0
        sprite.shadowedBitMask = 0
        if type.isCrystal {
            sprite.shadowedBitMask = LightCategory.scene
            configureCrystalAppearance(sprite)
        }

        let body = SKPhysicsBody(circleOfRadius: type.radius)
        body.density = max(type.density * 0.8, 0.5)
        body.restitution = type.restitution
        body.friction = type.friction
        body.linearDamping = 0.9
        body.angularDamping = 0.7
        body.allowsRotation = true
        body.affectedByGravity = true
        body.categoryBitMask = PhysicsCategory.ambient
        body.collisionBitMask = PhysicsCategory.ambient | PhysicsCategory.ambientWall
        body.contactTestBitMask = 0
        sprite.physicsBody = body

        addChild(sprite)
    }

    private func configureCrystalAppearance(_ sprite: SKSpriteNode) {
        let crystalColor = CrystalColorVariant.weightedRandom()
        let facetSeed = Float.random(in: 0.05...0.98)

        let rotationUniform = SKUniform(name: "u_rotation", float: 0.0)
        let lightDirUniform = SKUniform(name: "u_light_dir", vectorFloat2: vector_float2(0.0, 1.0))

        let shader = SKShader(source: crystalGlowShaderSource)
        shader.uniforms = [
            SKUniform(name: "u_glow_color", vectorFloat4: crystalColor.glowVector),
            SKUniform(name: "u_core_color", vectorFloat4: crystalColor.coreVector),
            SKUniform(name: "u_facet_seed", float: facetSeed),
            rotationUniform,
            lightDirUniform
        ]

        sprite.shader = shader
        sprite.color = crystalColor.coreColor
        sprite.colorBlendFactor = 0.20
        sprite.userData = sprite.userData ?? NSMutableDictionary()
        sprite.userData?["uRotation"] = rotationUniform
        sprite.userData?["uLightDir"] = lightDirUniform
        sprite.userData?["glintPhase"] = CGFloat.random(in: 0 ... (.pi * 2))
        sprite.userData?["glintRadius"] = max(5.0, sprite.size.width * 0.24)
        sprite.userData?["glintPulse"] = CGFloat.random(in: 0.0...1.0)
        sprite.userData?["spawnOrder"] = crystalSpawnIndex
        crystalSpawnIndex += 1

        addGlint(to: sprite)
    }

    private func addGlint(to crystal: SKSpriteNode) {
        let glint: SKSpriteNode
        if let texture = glintTexture {
            glint = SKSpriteNode(texture: texture)
        } else {
            let texture = makeCircleTexture(radius: 1.6)
            glintTexture = texture
            glint = SKSpriteNode(texture: texture)
        }

        glint.name = "crystalGlint"
        glint.blendMode = .add
        glint.color = .white
        glint.colorBlendFactor = 1.0
        glint.alpha = 0.45
        glint.zPosition = 3
        glint.setScale(0.58)
        crystal.addChild(glint)
    }

    private func updateCrystalLightingAndGlints(currentTime: TimeInterval) {
        guard let light = primaryLight else { return }
        let time = CGFloat(currentTime)

        for case let crystal as SKSpriteNode in children where crystal.name == "crystal" || crystal.name == "ambientCrystal" {
            if let rotationUniform = crystal.userData?["uRotation"] as? SKUniform {
                rotationUniform.floatValue = Float(crystal.zRotation)
            }

            if let lightDirUniform = crystal.userData?["uLightDir"] as? SKUniform {
                let dx = Float(light.position.x - crystal.position.x)
                let dy = Float(light.position.y - crystal.position.y)
                let len = max(sqrt(dx * dx + dy * dy), 0.0001)
                lightDirUniform.vectorFloat2Value = vector_float2(dx / len, dy / len)
            }

            guard let glint = crystal.childNode(withName: "crystalGlint") as? SKSpriteNode else { continue }
            let phase = (crystal.userData?["glintPhase"] as? CGFloat) ?? 0
            let radius = (crystal.userData?["glintRadius"] as? CGFloat) ?? 6
            let pulse = (crystal.userData?["glintPulse"] as? CGFloat) ?? 0
            let angle = crystal.zRotation + phase

            glint.position = CGPoint(
                x: cos(angle) * radius,
                y: sin(angle) * (radius * 0.74) + radius * 0.24
            )

            let sparkle = 0.32 + 0.16 * sin(time * 5.0 + pulse * 7.0)
            glint.alpha = sparkle
            glint.setScale(0.48 + sparkle * 0.12)
        }
    }

    // MARK: - Sticky Web

    private func placeWeb(at position: CGPoint) {
        let webRadius: CGFloat = 50

        // Visual: 🕸️ emoji with a semi-transparent radial glow behind it
        let webNode = SKNode()
        webNode.name = "web"
        webNode.position = position
        webNode.zPosition = 1

        // Radial glow background
        let glow = SKShapeNode(circleOfRadius: webRadius)
        glow.fillColor = SKColor(white: 1.0, alpha: 0.06)
        glow.strokeColor = SKColor(white: 1.0, alpha: 0.15)
        glow.lineWidth = 1.5
        glow.glowWidth = 4
        glow.name = "webGlow"
        webNode.addChild(glow)

        // Emoji label
        let label = SKLabelNode(text: "🕸️")
        label.fontSize = 56
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.alpha = 0.85
        webNode.addChild(label)

        // Sensor physics body — detects overlap but does not collide
        let body = SKPhysicsBody(circleOfRadius: webRadius)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.web
        body.collisionBitMask = 0  // sensor only
        body.contactTestBitMask = PhysicsCategory.allEmoji
        webNode.physicsBody = body

        // Subtle idle animation
        let pulse = SKAction.sequence([
            .scale(to: 1.06, duration: 1.8),
            .scale(to: 0.94, duration: 1.8)
        ])
        webNode.run(.repeatForever(pulse))

        addChild(webNode)
    }

    /// Capture a node into a web: kill velocity, disable gravity, drift toward web center.
    private func captureInWeb(_ node: SKNode, web: SKNode) {
        guard stuckNodes[node] == nil else { return }  // already stuck
        guard let pb = node.physicsBody else { return }

        stuckNodes[node] = web

        // Drastically reduce velocity
        pb.velocity = CGVector(
            dx: pb.velocity.dx * 0.1,
            dy: pb.velocity.dy * 0.1
        )
        pb.angularVelocity *= 0.1
        pb.affectedByGravity = false
        pb.linearDamping = 8.0  // heavy drag to keep it stuck

        // Drift node toward web center to look "anchored"
        let drift = SKAction.move(to: web.position, duration: 0.6)
        drift.timingMode = .easeOut
        node.run(drift, withKey: "webDrift")

        // Visual feedback for crystals: add a color overlay to signal they're stuck
        if node.name == "crystal", let sprite = node as? SKSpriteNode {
            let tint = SKAction.colorize(with: .purple, colorBlendFactor: 0.4, duration: 0.3)
            sprite.run(tint, withKey: "stuckTint")
        }
    }

    /// Release all stuck nodes from webs — called on shake.
    private func releaseAllFromWebs() {
        for (node, _) in stuckNodes {
            guard let pb = node.physicsBody else { continue }

            node.removeAction(forKey: "webDrift")

            // Re-enable gravity (unless it's a balloon)
            let isBalloon = node.name == "balloon"
            pb.affectedByGravity = !isBalloon
            pb.linearDamping = isBalloon ? 2.0 : 0.8

            // Small random pop impulse
            let ix = CGFloat.random(in: -30...30)
            let iy = CGFloat.random(in: 20...60)
            pb.applyImpulse(CGVector(dx: ix, dy: iy))

            // Remove stuck tint from crystals
            if node.name == "crystal", let sprite = node as? SKSpriteNode {
                sprite.removeAction(forKey: "stuckTint")
                let restore = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.25)
                sprite.run(restore)
            }

            // Small sparkle at the release point
            sparkleEffect(at: node.position)
        }

        stuckNodes.removeAll()

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    // MARK: - CoreMotion (tilt)

    private func startMotion() {
        #if os(iOS)
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }

            // --- Shake detection (user acceleration, not gravity) ---
            let ua = motion.userAcceleration
            let accelMagnitude = sqrt(ua.x * ua.x + ua.y * ua.y + ua.z * ua.z)
            let now = CACurrentMediaTime()
            if accelMagnitude > self.shakeAccelerationThreshold,
               now - self.lastShakeTime > 0.6,
               !self.stuckNodes.isEmpty {
                self.lastShakeTime = now
                self.releaseAllFromWebs()
            }

            // --- Tilt-based gravity ---
            let gx = CGFloat(motion.gravity.x)
            let gy = CGFloat(motion.gravity.y)
            let projectedMagnitude = hypot(gx, gy)

            // Gentle flat-phone fallback — only kick in when phone is nearly horizontal
            let flatThreshold: CGFloat = 0.15
            let flatness = max(0, min(1, (flatThreshold - projectedMagnitude) / flatThreshold))
            let blendedX = gx * (1 - flatness)
            let blendedY = (gy * (1 - flatness)) + (-0.65 * flatness)

            // Amplify upward tilts for satisfying "throw" gestures
            let verticalScale: CGFloat = blendedY > 0 ? 1.4 : 0.9

            let targetGravity = CGVector(
                dx: blendedX * self.gravityStrength,
                dy: blendedY * self.gravityStrength * verticalScale
            )

            // Responsive smoothing — fast follow on big changes, gentle on small ones
            let current = self.physicsWorld.gravity
            let delta = hypot(targetGravity.dx - current.dx, targetGravity.dy - current.dy)
            let smoothing = min(max(delta / 20.0, 0.35), 0.8)

            self.physicsWorld.gravity = CGVector(
                dx: current.dx + (targetGravity.dx - current.dx) * smoothing,
                dy: current.dy + (targetGravity.dy - current.dy) * smoothing
            )

            // --- Bokeh parallax tilt (very gentle, smoothed) ---
            let bokehSmoothing: CGFloat = 0.12
            self.bokehTiltX += (gx - self.bokehTiltX) * bokehSmoothing
            self.bokehTiltY += (gy - self.bokehTiltY) * bokehSmoothing
        }
        #endif
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        // Bokeh parallax — shift layers opposite to tilt, increasing with depth.
        // Runs always (menu, playing, game over) for a living background.
        updateBokehParallax()

        // Drive the morph animation when active (even during isTransitioningShape).
        if isMorphing {
            updateMorph(currentTime: currentTime)
            return
        }
        guard isGameplayActive, !stageWon, !gameOver, !isTransitioningShape else { return }
        updateCrystalLightingAndGlints(currentTime: currentTime)

        // Timer ran out — game over
        if let vm = viewModel, vm.timeRemaining <= 0 {
            gameOver = true
            vm.gameEnded()
            showGameOverEffect()
            return
        }

        // Apply upward force to balloons (negative gravity effect)
        enumerateChildNodes(withName: "//balloon") { child, _ in
            if self.stuckNodes[child] == nil {
                child.physicsBody?.applyForce(CGVector(dx: 0, dy: self.balloonLiftForce))
            }
        }

        // Collect all dynamic emoji nodes from the main scene layer.
        let allEmoji: [SKNode] = children.filter {
            $0.name == "crystal" || $0.name == "junk" || $0.name == "balloon"
        }

        // Exit boost — when an item clears the jar top, give it a satisfying fling
        for child in allEmoji {
            guard let pb = child.physicsBody, pb.isDynamic else { continue }

            let scenePos = child.position

            let id = ObjectIdentifier(child)
            if scenePos.y > jarTopY + 10, !boostedNodes.contains(id) {
                boostedNodes.insert(id)
                // Amplify existing velocity direction for a "whoosh" effect
                let vx = pb.velocity.dx
                let vy = pb.velocity.dy
                let speed = hypot(vx, vy)
                if speed > 5 {
                    let boost: CGFloat = 1.6
                    pb.velocity = CGVector(dx: vx * boost, dy: vy * boost)
                }
                // Brief spin for visual flair
                pb.angularVelocity += CGFloat.random(in: -8...8)
            }
        }

        // Keep stuck nodes anchored — dampen any residual velocity each frame
        for (node, web) in stuckNodes {
            guard let pb = node.physicsBody else { continue }
            pb.velocity = CGVector(dx: pb.velocity.dx * 0.3, dy: pb.velocity.dy * 0.3)
            pb.angularVelocity *= 0.3

            // Web stretching visual: scale the web glow based on distance between node and web center
            let dist = hypot(node.position.x - web.position.x,
                             node.position.y - web.position.y)
            let stretch = 1.0 + min(dist / 100.0, 0.3)  // subtle scale increase
            if let glow = web.childNode(withName: "webGlow") as? SKShapeNode {
                glow.setScale(stretch)
            }
        }

        var removedJunk = 0
        var removedCrystals = 0
        var removedBalloons = 0

        for child in allEmoji {
            guard child.physicsBody != nil else { continue }

            let scenePos = child.position

            // Remove items that have left the visible screen. A small margin
            // prevents visual popping while ensuring off-screen items are freed
            // quickly and cannot drift back when the user tilts the device.
            let margin: CGFloat = 20
            let outOfBounds =
                scenePos.y < frame.minY - margin ||
                scenePos.y > frame.maxY + margin ||
                scenePos.x < frame.minX - margin ||
                scenePos.x > frame.maxX + margin

            if outOfBounds {
                if child.name == "junk" {
                    removedJunk += 1
                } else if child.name == "crystal" {
                    removedCrystals += 1
                } else if child.name == "balloon" {
                    removedBalloons += 1
                }
                stuckNodes.removeValue(forKey: child)
                child.removeFromParent()
            }
        }

        if removedJunk > 0 || removedBalloons > 0 {
            viewModel?.junkRemoved(removedJunk + removedBalloons)

            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        }

        // Losing crystals is allowed but costly — game over only when ALL crystals are gone
        if removedCrystals > 0 {
            viewModel?.crystalsLost(removedCrystals)

            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            #endif

            // Check if all crystals are gone from the scene entirely.
            let remainingCrystals = children.filter { $0.name == "crystal" }
            if remainingCrystals.isEmpty {
                gameOver = true
                viewModel?.gameEnded()
                showGameOverEffect()

                #if os(iOS)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                #endif
                return
            }
        }

        // Check if all crystals have floated outside the jar (even if still on screen).
        // If no crystal is inside the jar, the player has lost them all.
        let allCrystalNodes = children.filter { $0.name == "crystal" }
        if !allCrystalNodes.isEmpty {
            let insideJar = allCrystalNodes.filter { isInsideJar($0.position) }
            if insideJar.isEmpty {
                gameOver = true
                viewModel?.crystalsInJar = 0
                viewModel?.gameEnded()
                showGameOverEffect()

                #if os(iOS)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                #endif
                return
            }
        }

        checkWinCondition()
    }

    // MARK: - Jar Containment

    /// Returns true when the given scene-space position is inside the jar's closed boundary.
    /// Uses a closed copy of the jar path for accurate point-in-polygon testing.
    private func isInsideJar(_ position: CGPoint) -> Bool {
        guard let openPath = jarPath else { return false }
        // Close the path to form a polygon (the jar mouth seals the top).
        let closedPath = CGMutablePath()
        closedPath.addPath(openPath)
        closedPath.closeSubpath()
        return closedPath.contains(position)
    }

    /// Counts crystals whose center is geometrically inside the jar.
    private func crystalsInsideJar() -> [SKNode] {
        return children.filter { $0.name == "crystal" && isInsideJar($0.position) }
    }

    // MARK: - Win / Game Over

    private func checkWinCondition() {
        let junkNodes = children.filter { $0.name == "junk" || $0.name == "balloon" }

        // Stage clear: all junk and balloons gone, at least some crystals inside the jar
        if junkNodes.isEmpty {
            // Update crystalsInJar to reflect only gems actually inside the jar
            let inJar = crystalsInsideJar()
            viewModel?.crystalsInJar = inJar.count

            stageWon = true
            viewModel?.stageCleared()
            showWinEffect()
        }
    }

    private func showWinEffect() {
        let crystalNodes = children.filter { $0.name == "crystal" }
        let isPerfectStage = viewModel?.wasPerfectStage ?? false
        let perfectBonus = viewModel?.lastPerfectBonus ?? 0

        // Victory banner
        let banner = SKLabelNode(text: isPerfectStage ? "Perfect Level!" : "Stage Clear!")
        banner.name       = "banner"
        banner.fontName   = "SFProRounded-Heavy"
        banner.fontSize   = 44
        banner.fontColor  = isPerfectStage
            ? SKColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 1)
            : SKColor(red: 0.3, green: 0.95, blue: 1.0, alpha: 1)
        banner.position   = CGPoint(
            x: frame.midX,
            y: frame.midY + (isPerfectStage ? 176 : 150)
        )
        banner.zPosition  = 20
        banner.alpha      = 0
        banner.setScale(0.5)
        addChild(banner)

        banner.run(.group([
            .fadeIn(withDuration: 0.4),
            .scale(to: 1.0, duration: 0.4)
        ]))

        if isPerfectStage {
            let perfectLabel = SKLabelNode(text: "No gems lost")
            perfectLabel.name = "banner"
            perfectLabel.fontName = "SFProRounded-Bold"
            perfectLabel.fontSize = 24
            perfectLabel.fontColor = SKColor(red: 1.0, green: 0.94, blue: 0.68, alpha: 1)
            perfectLabel.position = CGPoint(x: frame.midX, y: frame.midY + 116)
            perfectLabel.zPosition = 20
            perfectLabel.alpha = 0
            perfectLabel.setScale(0.85)
            addChild(perfectLabel)

            perfectLabel.run(.sequence([
                .wait(forDuration: 0.2),
                .group([
                    .fadeIn(withDuration: 0.2),
                    .scale(to: 1.0, duration: 0.2)
                ]),
                .sequence([
                    .scale(to: 1.06, duration: 0.28),
                    .scale(to: 1.0, duration: 0.28)
                ])
            ]))

            let bonusLabel = SKLabelNode(text: "+\(perfectBonus) Perfect Bonus")
            bonusLabel.name = "banner"
            bonusLabel.fontName = "SFProRounded-Heavy"
            bonusLabel.fontSize = 28
            bonusLabel.fontColor = SKColor(red: 1.0, green: 0.86, blue: 0.2, alpha: 1)
            bonusLabel.position = CGPoint(x: frame.midX, y: frame.midY + 74)
            bonusLabel.zPosition = 21
            bonusLabel.alpha = 0
            bonusLabel.setScale(0.7)
            addChild(bonusLabel)

            bonusLabel.run(.sequence([
                .wait(forDuration: 0.3),
                .group([
                    .fadeIn(withDuration: 0.14),
                    .scale(to: 1.1, duration: 0.14)
                ]),
                .group([
                    .scale(to: 1.0, duration: 0.18),
                    .moveBy(x: 0, y: 16, duration: 0.18)
                ])
            ]))

            for index in 0..<10 {
                let delay = 0.08 + Double(index) * 0.05
                run(.sequence([
                    .wait(forDuration: delay),
                    .run { [weak self] in
                        guard let self else { return }
                        let burstPoint = CGPoint(
                            x: self.frame.midX + CGFloat.random(in: -100...100),
                            y: self.frame.midY + CGFloat.random(in: 40...190)
                        )
                        self.sparkleEffect(at: burstPoint)
                    }
                ]))
            }
        }

        for crystal in crystalNodes {
            sparkleEffect(at: crystal.position)
        }
        explodeRemainingCrystalsForScoring(crystalNodes)

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        // Wait for tally animation (~2s) + a brief pause, then advance
        let transitionDelay: TimeInterval = isPerfectStage ? 4.0 : 3.5
        run(.wait(forDuration: transitionDelay)) { [weak self] in
            self?.startNextStage()
        }
    }

    /// Consume all remaining crystals with a short explosion sequence so scoring feels earned.
    private func explodeRemainingCrystalsForScoring(_ crystalNodes: [SKNode]) {
        guard !crystalNodes.isEmpty else { return }

        let baseStagePoints = max(viewModel?.lastStageScore ?? 0, 0)
        let crystalCount = crystalNodes.count
        let basePerCrystal = crystalCount > 0 ? baseStagePoints / crystalCount : 0
        var remainder = crystalCount > 0 ? baseStagePoints % crystalCount : 0

        let orderedCrystals = crystalNodes.sorted { $0.position.y < $1.position.y }
        for (index, crystal) in orderedCrystals.enumerated() {
            let pointsForThisCrystal = basePerCrystal + (remainder > 0 ? 1 : 0)
            remainder = max(0, remainder - 1)
            let delay = 0.35 + Double(index) * 0.08
            runCrystalScoreExplosion(crystal, points: pointsForThisCrystal, delay: delay)
        }
    }

    private func runCrystalScoreExplosion(_ crystal: SKNode, points: Int, delay: TimeInterval) {
        crystal.run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self, weak crystal] in
                guard let self, let crystal, crystal.parent != nil else { return }

                crystal.removeAllActions()
                let point = crystal.position
                self.sparkleEffect(at: point)
                self.sparkleEffect(at: point)

                let scoreLabel = SKLabelNode(text: "+\(points)")
                scoreLabel.name = "banner"
                scoreLabel.fontName = "SFProRounded-Heavy"
                scoreLabel.fontSize = 28
                scoreLabel.fontColor = SKColor(red: 0.98, green: 0.92, blue: 0.35, alpha: 1.0)
                scoreLabel.position = CGPoint(x: point.x, y: point.y + 12)
                scoreLabel.zPosition = 24
                scoreLabel.alpha = 0
                self.addChild(scoreLabel)

                scoreLabel.run(.sequence([
                    .group([
                        .fadeIn(withDuration: 0.08),
                        .moveBy(x: 0, y: 26, duration: 0.32),
                        .scale(to: 1.08, duration: 0.12)
                    ]),
                    .group([
                        .fadeOut(withDuration: 0.22),
                        .moveBy(x: 0, y: 14, duration: 0.22)
                    ]),
                    .removeFromParent()
                ]))

                crystal.run(.sequence([
                    .group([
                        .fadeOut(withDuration: 0.14),
                        .scale(to: 1.5, duration: 0.14),
                        .rotate(byAngle: .pi, duration: 0.14)
                    ]),
                    .removeFromParent()
                ]))
            }
        ]))
    }

    private func showGameOverEffect() {
        let center = CGPoint(x: frame.midX, y: frame.midY + 120)

        let glow = SKLabelNode(text: "Game Over")
        glow.name       = "banner"
        glow.fontName   = "SFProRounded-Heavy"
        glow.fontSize   = 62
        glow.fontColor  = SKColor(red: 1.0, green: 0.26, blue: 0.22, alpha: 0.35)
        glow.position   = center
        glow.zPosition  = 19
        glow.alpha      = 0
        glow.setScale(0.5)
        addChild(glow)

        let shadow = SKLabelNode(text: "Game Over")
        shadow.name       = "banner"
        shadow.fontName   = "SFProRounded-Heavy"
        shadow.fontSize   = 60
        shadow.fontColor  = SKColor(white: 0.0, alpha: 0.55)
        shadow.position   = CGPoint(x: center.x, y: center.y - 4)
        shadow.zPosition  = 19.5
        shadow.alpha      = 0
        shadow.setScale(0.5)
        addChild(shadow)

        let banner = SKLabelNode(text: "Game Over")
        banner.name       = "banner"
        banner.fontName   = "SFProRounded-Heavy"
        banner.fontSize   = 60
        banner.fontColor  = SKColor(red: 1, green: 0.3, blue: 0.25, alpha: 1)
        banner.position   = center
        banner.zPosition  = 20
        banner.alpha      = 0
        banner.setScale(0.5)
        addChild(banner)

        let reveal = SKAction.group([
            .fadeIn(withDuration: 0.4),
            .scale(to: 1.0, duration: 0.4)
        ])
        glow.run(reveal)
        shadow.run(reveal)
        banner.run(reveal)

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }

    // MARK: - Dirty Jar Explosion Animation

    /// Plays a dramatic dirt splatter animation covering the entire jar, then calls completion.
    /// Returns the horizontal half-width of the jar interior at a given Y coordinate,
    /// accounting for the bottle shape (wide body narrowing into a neck).
    /// Returns 0 if `y` is outside the jar vertically.
    private func jarHalfWidthAt(y: CGFloat) -> CGFloat {
        guard let geometry = currentGeometry else { return 0 }
        return currentVesselShape.halfWidthAt(y: y, geometry: geometry)
    }

    /// Generates a random point guaranteed to be inside the jar silhouette.
    private func randomPointInsideJar(rng: inout DirtRNG, insetFraction: CGFloat = 0.08) -> CGPoint {
        let cx = (jarMinX + jarMaxX) / 2
        let y = rng.nextCGFloat(in: jarBottomY + 10 ... jarTopY - 10)
        let halfW = jarHalfWidthAt(y: y)
        let inset = halfW * insetFraction
        let safeHalf = max(halfW - inset, 0)
        let x = cx + rng.nextCGFloat(in: -safeHalf ... safeHalf)
        return CGPoint(x: x, y: y)
    }

    /// Clamps a point so it stays inside the jar silhouette.
    private func clampInsideJar(_ point: CGPoint, insetFraction: CGFloat = 0.08) -> CGPoint {
        let cx = (jarMinX + jarMaxX) / 2
        let y = min(max(point.y, jarBottomY + 6), jarTopY - 6)
        let halfW = jarHalfWidthAt(y: y)
        let inset = halfW * insetFraction
        let safeHalf = max(halfW - inset, 0)
        let x = min(max(point.x, cx - safeHalf), cx + safeHalf)
        return CGPoint(x: x, y: y)
    }

    func playDirtyJarAnimation(completion: @escaping () -> Void) {
        let jarH = jarTopY - jarBottomY
        let cx = (jarMinX + jarMaxX) / 2

        // Remove existing banners so the dirt animation is the focus
        children.filter { $0.name == "banner" }.forEach { $0.removeFromParent() }

        // Container for all dirt explosion nodes so we can manage them easily
        let dirtContainer = SKNode()
        dirtContainer.name = "dirtExplosion"
        dirtContainer.zPosition = 15
        addChild(dirtContainer)

        var rng = DirtRNG(seed: 31415)

        // --- Phase 1: Large dirt splatters burst outward from center ---
        let burstCenter = CGPoint(x: cx, y: jarBottomY + jarH * 0.4)
        let splatterCount = 18
        for i in 0..<splatterCount {
            let w = rng.nextCGFloat(in: 40...100)
            let h = rng.nextCGFloat(in: 30...80)
            let blotch = makeSmudgeBlotch(size: CGSize(width: w, height: h), rng: &rng)
            blotch.position = burstCenter
            blotch.zPosition = 15
            blotch.alpha = 0
            blotch.setScale(0.2)
            blotch.zRotation = rng.nextCGFloat(in: -.pi ... .pi)
            dirtContainer.addChild(blotch)

            // Generate a random target inside the jar
            let target = randomPointInsideJar(rng: &rng, insetFraction: 0.12)

            let delay = Double(i) * 0.04
            let targetAlpha = rng.nextCGFloat(in: 0.45...0.85)

            blotch.run(.sequence([
                .wait(forDuration: delay),
                .group([
                    .move(to: target, duration: 0.35),
                    .scale(to: rng.nextCGFloat(in: 0.8...1.4), duration: 0.35),
                    .fadeAlpha(to: targetAlpha, duration: 0.25)
                ])
            ]))
        }

        // --- Phase 2: Smear streaks dripping down (stay inside jar) ---
        let streakCount = 10
        for i in 0..<streakCount {
            let length = rng.nextCGFloat(in: 50...120)
            let thickness = rng.nextCGFloat(in: 12...28)
            let smear = makeSmudgeBlotch(
                size: CGSize(width: thickness, height: length),
                rng: &rng
            )
            let startPt = randomPointInsideJar(rng: &rng, insetFraction: 0.15)
            smear.position = startPt
            smear.zPosition = 15
            smear.alpha = 0
            dirtContainer.addChild(smear)

            let delay = 0.5 + Double(i) * 0.06
            // Drip downward, but clamp so it doesn't exit the jar
            let dripDist = rng.nextCGFloat(in: 30...80)
            let dripTarget = clampInsideJar(
                CGPoint(x: startPt.x, y: startPt.y - dripDist),
                insetFraction: 0.10
            )

            smear.run(.sequence([
                .wait(forDuration: delay),
                .group([
                    .fadeAlpha(to: rng.nextCGFloat(in: 0.4...0.7), duration: 0.3),
                    .move(to: dripTarget, duration: 0.8)
                ])
            ]))
        }

        // --- Phase 3: Fine grime spots inside jar ---
        let spotCount = 25
        for i in 0..<spotCount {
            let r = rng.nextCGFloat(in: 4...14)
            let spot = makeGrimeSpot(radius: r, rng: &rng)
            let pt = randomPointInsideJar(rng: &rng, insetFraction: 0.06)
            spot.position = pt
            spot.zPosition = 15
            spot.alpha = 0
            dirtContainer.addChild(spot)

            let delay = 0.3 + Double(i) * 0.03
            spot.run(.sequence([
                .wait(forDuration: delay),
                .group([
                    .fadeAlpha(to: rng.nextCGFloat(in: 0.5...0.9), duration: 0.2),
                    .scale(to: rng.nextCGFloat(in: 1.0...1.6), duration: 0.25)
                ])
            ]))
        }

        // --- Phase 4: Foggy overlay clipped to jar shape ---
        if let path = jarPath {
            let fogNode = SKShapeNode(path: path)
            fogNode.fillColor = SKColor(red: 0.28, green: 0.22, blue: 0.15, alpha: 1.0)
            fogNode.strokeColor = .clear
            fogNode.zPosition = 14
            fogNode.alpha = 0
            dirtContainer.addChild(fogNode)

            fogNode.run(.sequence([
                .wait(forDuration: 0.6),
                .fadeAlpha(to: 0.55, duration: 1.0)
            ]))
        }

        // --- Haptic feedback for the splatter ---
        #if os(iOS)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        #endif

        // --- After animation settles, call completion ---
        run(.sequence([
            .wait(forDuration: 2.5),
            .run { completion() }
        ]))
    }

    /// Remove the dirt explosion overlay nodes (called when transitioning away).
    func removeDirtExplosion() {
        children.filter { $0.name == "dirtExplosion" }.forEach { node in
            node.removeAllActions()
            node.removeFromParent()
        }
    }

    // MARK: - Stage Transition

    private func startNextStage() {
        // Remove all emoji, web, and banner nodes from scene
        children.filter {
            $0.name == "crystal" || $0.name == "junk" || $0.name == "balloon" ||
            $0.name == "banner" || $0.name == "web"
        }
        .forEach { node in
            node.removeAllActions()
            node.removeFromParent()
        }

        stuckNodes.removeAll()
        boostedNodes.removeAll()
        crystalSpawnIndex = 0

        let oldStage = stage
        viewModel?.nextStage()
        let newStage = stage
        stageWon = false

        // Check if the vessel shape changes at this stage boundary.
        if VesselShapeRegistry.shapeChanges(from: oldStage, to: newStage) {
            let newShape = VesselShapeRegistry.shape(forStage: newStage)
            isTransitioningShape = true
            beginVesselMorph(to: newShape)
        } else {
            fillJar()
        }
    }

    // MARK: - Vessel Morph

    private func beginVesselMorph(to newShape: VesselShape) {
        guard let oldGeometry = currentGeometry else { return }

        let newGeometry = newShape.buildGeometry(
            frameWidth: frame.width,
            frameHeight: frame.height
        )

        morphInterpolator = VesselMorphInterpolator(
            fromShape: currentVesselShape,
            toShape: newShape,
            fromGeometry: oldGeometry,
            toGeometry: newGeometry
        )

        // Cache references to visual nodes that need per-frame path updates.
        cacheMorphVisualNodeReferences()

        // Disable rasterization during animation for smooth per-frame updates.
        jarEffectNode?.shouldRasterize = false
        if let glowNode = jarEffectNode?
            .childNode(withName: "jarVisualRoot")?
            .childNode(withName: "jarGlowEffectsNode") as? SKEffectNode {
            glowNode.shouldRasterize = false
        }

        // Remove dirt overlays and reflection emitter — rebuilt after morph.
        for node in dirtNodes { node.removeFromParent() }
        dirtNodes.removeAll()
        childNode(withName: "jarReflectionEmitter")?.removeFromParent()

        isMorphing = true
        morphProgress = 0
        morphStartTime = 0
        morphFrameCounter = 0
        lastPhysicsUpdateFrame = 0
    }

    private func cacheMorphVisualNodeReferences() {
        guard let visualRoot = jarEffectNode?.childNode(withName: "jarVisualRoot") else { return }

        morphInnerFillNode = visualRoot.childNode(withName: "jarInnerFill") as? SKShapeNode
        morphGlassFillNode = visualRoot.childNode(withName: "jarGlass") as? SKShapeNode
        morphOutlineNode = visualRoot.childNode(withName: "jarOutline") as? SKShapeNode
        morphHighlightNode = visualRoot.childNode(withName: "jarHighlight") as? SKShapeNode

        if let glowNode = visualRoot.childNode(withName: "jarGlowEffectsNode") {
            morphOuterGlowNode = glowNode.childNode(withName: "jarOuterGlow") as? SKShapeNode
            let rimNodes = glowNode.children
                .filter { $0.name == "jarInnerRimLight" }
                .compactMap { $0 as? SKShapeNode }
            morphLeftRimNode = rimNodes.first
            morphRightRimNode = rimNodes.count > 1 ? rimNodes[1] : nil
        }

        morphBackWallMask = (childNode(withName: "jarBackWallCrop") as? SKCropNode)?
            .maskNode as? SKShapeNode
    }

    private func updateMorph(currentTime: TimeInterval) {
        guard let interpolator = morphInterpolator else { return }

        if morphStartTime == 0 { morphStartTime = currentTime }

        let elapsed = currentTime - morphStartTime
        let rawT = CGFloat(elapsed / morphDuration)

        // Ease-in-out cubic for smooth glass-reshaping feel.
        let t = min(1.0, easeInOutCubic(max(0, rawT)))
        morphProgress = t

        let geometry = interpolator.interpolatedGeometry(at: t)

        // Update visual layers.
        updateVisualLayersForMorph(geometry: geometry, interpolator: interpolator, t: t)

        // Update physics bodies (throttled).
        updatePhysicsForMorph(path: geometry.path)

        // Sync legacy jar variables.
        jarMinX = geometry.minX
        jarMaxX = geometry.maxX
        jarBottomY = geometry.bottomY
        jarTopY = geometry.topY
        jarPath = geometry.path

        if rawT >= 1.0 {
            finalizeMorph()
        }
    }

    private func easeInOutCubic(_ t: CGFloat) -> CGFloat {
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            let f = 2 * t - 2
            return 0.5 * f * f * f + 1
        }
    }

    private func updateVisualLayersForMorph(
        geometry: VesselGeometry,
        interpolator: VesselMorphInterpolator,
        t: CGFloat
    ) {
        let path = geometry.path

        // Shape nodes that follow the main vessel path.
        morphInnerFillNode?.path = path
        morphGlassFillNode?.path = path
        morphOutlineNode?.path = path
        morphOuterGlowNode?.path = path

        // Back wall mask needs a closed version of the path.
        let closedPath = CGMutablePath()
        closedPath.addPath(path)
        closedPath.closeSubpath()
        morphBackWallMask?.path = closedPath

        // Reposition the back wall sprite inside its crop node.
        if let cropNode = childNode(withName: "jarBackWallCrop") as? SKCropNode,
           let backWall = cropNode.children.first as? SKSpriteNode {
            backWall.size = CGSize(width: geometry.bodyWidth + 20, height: geometry.height + 20)
            backWall.position = CGPoint(
                x: geometry.centerX,
                y: geometry.bottomY + geometry.height / 2
            )
        }

        // Inner rim paths.
        let rimOffset: CGFloat = 8.0
        if let rimPath = interpolator.interpolatedLeftRimPath(at: t, geometry: geometry, offset: rimOffset) {
            morphLeftRimNode?.path = rimPath
        }
        if let rimPath = interpolator.interpolatedRightRimPath(at: t, geometry: geometry, offset: rimOffset) {
            morphRightRimNode?.path = rimPath
        }

        // Left highlight path.
        let hlOffset: CGFloat = 3.0
        if let hlPath = interpolator.interpolatedLeftHighlightPath(at: t, geometry: geometry, offset: hlOffset) {
            morphHighlightNode?.path = hlPath
        }

        // Reposition AO spots.
        if let glowNode = jarEffectNode?.childNode(withName: "jarVisualRoot")?
            .childNode(withName: "jarGlowEffectsNode") {
            if let leftAO = glowNode.childNode(withName: "jarAmbientOcclusionLeft") as? SKSpriteNode {
                let aoSize = CGSize(width: geometry.bodyCornerRadius * 1.9, height: geometry.bodyCornerRadius * 1.6)
                leftAO.size = aoSize
                leftAO.position = CGPoint(
                    x: geometry.minX + geometry.bodyCornerRadius + 14,
                    y: geometry.bottomY + geometry.bodyCornerRadius + 8
                )
            }
            if let rightAO = glowNode.childNode(withName: "jarAmbientOcclusionRight") as? SKSpriteNode {
                let aoSize = CGSize(width: geometry.bodyCornerRadius * 1.9, height: geometry.bodyCornerRadius * 1.6)
                rightAO.size = aoSize
                rightAO.position = CGPoint(
                    x: geometry.maxX - geometry.bodyCornerRadius - 14,
                    y: geometry.bottomY + geometry.bodyCornerRadius + 8
                )
            }
        }
    }

    private func updatePhysicsForMorph(path: CGMutablePath) {
        morphFrameCounter += 1

        // Throttle physics body recreation to every 4 frames (~15 Hz at 60 fps).
        guard morphFrameCounter - lastPhysicsUpdateFrame >= 4 else { return }
        lastPhysicsUpdateFrame = morphFrameCounter

        if let wallNode = childNode(withName: "wall") {
            let body = SKPhysicsBody(edgeChainFrom: path)
            body.isDynamic = false
            body.friction = 0.40
            body.restitution = 0.30
            body.categoryBitMask = PhysicsCategory.wall
            body.collisionBitMask = PhysicsCategory.allEmoji
            body.contactTestBitMask = PhysicsCategory.allEmoji
            wallNode.physicsBody = body
        }

        if let ambientNode = childNode(withName: "ambientWall") {
            let closedPath = CGMutablePath()
            closedPath.addPath(path)
            closedPath.closeSubpath()
            let ambientBody = SKPhysicsBody(edgeLoopFrom: closedPath)
            ambientBody.isDynamic = false
            ambientBody.friction = 0.35
            ambientBody.restitution = 0.35
            ambientBody.categoryBitMask = PhysicsCategory.ambientWall
            ambientBody.collisionBitMask = PhysicsCategory.ambient
            ambientBody.contactTestBitMask = 0
            ambientNode.physicsBody = ambientBody
        }
    }

    private func finalizeMorph() {
        guard let interpolator = morphInterpolator else { return }

        isMorphing = false
        morphProgress = 0
        morphFrameCounter = 0
        lastPhysicsUpdateFrame = 0

        // Rebuild with the canonical shape for pixel-perfect bezier curves.
        let newShape = interpolator.toShape
        teardownJar()
        buildJar(shape: newShape)

        // Re-enable rasterization.
        jarEffectNode?.shouldRasterize = shouldEnableEffects
        if let glowNode = jarEffectNode?
            .childNode(withName: "jarVisualRoot")?
            .childNode(withName: "jarGlowEffectsNode") as? SKEffectNode {
            glowNode.shouldRasterize = shouldEnableEffects
        }

        // Clean up morph state.
        morphInterpolator = nil
        morphOutlineNode = nil
        morphInnerFillNode = nil
        morphGlassFillNode = nil
        morphOuterGlowNode = nil
        morphLeftRimNode = nil
        morphRightRimNode = nil
        morphHighlightNode = nil
        morphBackWallMask = nil

        isTransitioningShape = false
        fillJar()
    }

    // MARK: - Particle Effects

    private func sparkleEffect(at point: CGPoint) {
        let gemColors: [SKColor] = [
            SKColor(red: 0.2, green: 0.9, blue: 1.0, alpha: 0.9),   // cyan
            SKColor(red: 0.8, green: 0.3, blue: 1.0, alpha: 0.9),   // magenta
            SKColor(red: 0.5, green: 0.9, blue: 1.0, alpha: 0.9),   // light cyan
            SKColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9),   // white sparkle
        ]
        for _ in 0..<8 {
            let r = CGFloat.random(in: 2...6)
            let particle = SKShapeNode(circleOfRadius: r)
            particle.fillColor   = gemColors.randomElement()!
            particle.strokeColor = .clear
            particle.position    = point
            particle.zPosition   = 10
            addChild(particle)

            let angle = CGFloat.random(in: 0 ... .pi * 2)
            let speed = CGFloat.random(in: 30...80)
            particle.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * speed,
                            y: sin(angle) * speed,
                            duration: 0.6),
                    .sequence([.scale(to: 1.5, duration: 0.2),
                               .scale(to: 0.0, duration: 0.4)]),
                    .fadeOut(withDuration: 0.6)
                ]),
                .removeFromParent()
            ]))
        }
    }
}

// MARK: - Contact Delegate (collision haptics + impact flash)
extension GameScene: SKPhysicsContactDelegate {

    func didBegin(_ contact: SKPhysicsContact) {
        guard isGameplayActive else { return }

        let a = contact.bodyA.categoryBitMask
        let b = contact.bodyB.categoryBitMask

        // --- Web capture logic ---
        let webInvolved = (a == PhysicsCategory.web || b == PhysicsCategory.web)
        if webInvolved {
            let emojiNode: SKNode?
            let webNode: SKNode?

            if a == PhysicsCategory.web {
                webNode = contact.bodyA.node
                emojiNode = contact.bodyB.node
            } else {
                webNode = contact.bodyB.node
                emojiNode = contact.bodyA.node
            }

            if let emoji = emojiNode, let web = webNode {
                captureInWeb(emoji, web: web)
            }
            return
        }

        let impulse = contact.collisionImpulse
        let now = CACurrentMediaTime()

        // --- Crystal-wall haptics (.heavy) + impact flash ---
        let crystalHitWall = (a == PhysicsCategory.crystal && b == PhysicsCategory.wall) ||
                             (a == PhysicsCategory.wall && b == PhysicsCategory.crystal)

        if crystalHitWall {
            #if os(iOS)
            if impulse > 3.0, now - lastHapticTime > 0.15 {
                lastHapticTime = now
                let intensity = min(CGFloat(impulse) / 12.0, 1.0)
                crystalImpactGenerator.impactOccurred(intensity: intensity)
                crystalImpactGenerator.prepare()
            }
            #endif
        }

        // --- Junk-wall haptics (.light) + impact flash ---
        let junkHitWall = (a == PhysicsCategory.junk && b == PhysicsCategory.wall) ||
                          (a == PhysicsCategory.wall && b == PhysicsCategory.junk)

        if junkHitWall {
            #if os(iOS)
            if impulse > 2.0, now - lastHapticTime > 0.12 {
                lastHapticTime = now
                let intensity = min(CGFloat(impulse) / 10.0, 1.0)
                wallImpactGenerator.impactOccurred(intensity: intensity)
                wallImpactGenerator.prepare()
            }
            #endif
        }

        // --- Squash & stretch on wall impact (balloons only) + impact flash ---
        let balloonHitWall = (a == PhysicsCategory.balloon && b == PhysicsCategory.wall) ||
                             (a == PhysicsCategory.wall && b == PhysicsCategory.balloon)

        if balloonHitWall {
            guard impulse > 2.0 else { return }

            let node: SKNode?
            if a == PhysicsCategory.balloon {
                node = contact.bodyA.node
            } else {
                node = contact.bodyB.node
            }
            guard let node else { return }

            let intensity = min(CGFloat(impulse) / 15.0, 0.35)
            let squashBig: CGFloat = 1.0 + intensity
            let squashSmall: CGFloat = 1.0 - intensity * 0.6

            let vx = abs(node.physicsBody?.velocity.dx ?? 0)
            let vy = abs(node.physicsBody?.velocity.dy ?? 0)
            let isHorizontal = vx > vy

            let action: SKAction
            if isHorizontal {
                action = .sequence([
                    .scaleX(to: squashSmall, y: squashBig, duration: 0.06),
                    .scaleX(to: 1.0, y: 1.0, duration: 0.15)
                ])
            } else {
                action = .sequence([
                    .scaleX(to: squashBig, y: squashSmall, duration: 0.06),
                    .scaleX(to: 1.0, y: 1.0, duration: 0.15)
                ])
            }
            node.run(action, withKey: "squash")

            #if os(iOS)
            if impulse > 3.0, now - lastHapticTime > 0.15 {
                lastHapticTime = now
                wallImpactGenerator.impactOccurred(intensity: min(CGFloat(impulse) / 12.0, 1.0))
            }
            #endif
        }
    }
}
