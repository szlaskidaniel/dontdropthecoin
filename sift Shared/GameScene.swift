//
//  GameScene.swift
//  fizz Shared
//

import SpriteKit
import CoreImage
import simd
import AVFoundation
import Combine

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
    case crystal, apple, teddy, shoe, banana, book, gift, duck, donut, puzzle, balloon, poop, bomb

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
        case .poop:           return "💩"
        case .bomb:           return "💣"
        }
    }

    var isCrystal: Bool { self == .crystal }
    var isJunk: Bool { !isCrystal && !isBalloon }
    var isBalloon: Bool { self == .balloon }
    var isPoop: Bool { self == .poop }
    var isBomb: Bool { self == .bomb }

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
        if isPoop { return "poop" }
        if isBomb { return "bomb" }
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
        case .poop:           return 0.7
        case .bomb:           return 1.2
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
        case .poop:                     return 0.30
        case .bomb:                     return 0.20
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
        case .poop:           return 0.35
        case .bomb:           return 0.30
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
        case .poop:           return 20
        case .bomb:           return 20
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .teddy, .shoe: return 42
        case .gift, .duck:  return 40
        case .puzzle:       return 38
        case .balloon:      return 72
        case .poop:         return 40
        case .bomb:         return 40
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

    weak var viewModel: GameViewModel? {
        didSet { observeMusicMute() }
    }

    private var bgMusicPlayer: AVAudioPlayer?
    private var musicMuteObserver: AnyCancellable?

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
    /// True while items are popping in at the start of a stage. Locks tilt gravity and interaction.
    private var isSpawning = false

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

    // MARK: Sticky Poop
    /// Pairs of nodes glued together by poop. The poop node is always the first element.
    private var poopGluedPairs: [(poop: SKNode, other: SKNode, joint: SKPhysicsJointSpring, stretchLine: SKShapeNode)] = []

    // MARK: Fragile Bomb
    /// Tracks wall strike counts per bomb node. Explodes on the 3rd hard strike.
    private var bombStrikeCounts: [SKNode: Int] = [:]
    /// Timestamp of the last registered strike per bomb — enforces a cooldown between strikes.
    private var bombLastStrikeTime: [SKNode: TimeInterval] = [:]
    /// Number of hard wall strikes before detonation.
    private let bombMaxStrikes: Int = 3
    /// Minimum collision impulse to register as a "hard" strike against glass.
    private let bombStrikeImpulseThreshold: CGFloat = 6.0
    /// Minimum seconds between registered strikes on the same bomb.
    private let bombStrikeCooldown: TimeInterval = 0.5
    /// Programmatic hiss sound engine for bomb fuse.
    private var bombHissPlayer: AVAudioPlayer?
    /// Programmatic boom sound for detonation.
    private var bombBoomPlayer: AVAudioPlayer?
    /// Tracks whether a bomb hiss is currently ramping.
    private var bombHissActive: Bool = false

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
            $0.name == "ambientCrystal" || $0.name == "ambientEmoji" ||
            $0.name == "poop" || $0.name == "bomb"
        }
        .forEach { node in
            node.removeAllActions()
            node.removeFromParent()
        }

        stuckNodes.removeAll()
        boostedNodes.removeAll()
        removeAllPoopGlue()
        bombStrikeCounts.removeAll()
        bombLastStrikeTime.removeAll()
        stopBombHiss()
        crystalSpawnIndex = 0
        stageWon = false
        gameOver = false
        isSpawning = false
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
            if viewModel?.isMusicMuted != true {
                player.play()
            }
            bgMusicPlayer = player
        } catch {
            print("Background music failed to load: \(error)")
        }
    }

    private func stopBackgroundMusic() {
        bgMusicPlayer?.stop()
        bgMusicPlayer = nil
    }

    private func applyMusicMuteState(_ muted: Bool) {
        guard let player = bgMusicPlayer else { return }
        if muted {
            player.pause()
        } else {
            if !player.isPlaying {
                player.play()
            }
        }
    }

    private func observeMusicMute() {
        musicMuteObserver?.cancel()
        guard let vm = viewModel else { return }
        // Apply current state immediately
        applyMusicMuteState(vm.isMusicMuted)
        // Observe future changes
        musicMuteObserver = vm.$isMusicMuted
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] muted in
                self?.applyMusicMuteState(muted)
            }
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
    /// Stains and smudges can appear anywhere inside the vessel.
    /// Uses `randomPointInsideJar` to respect the vessel's curved silhouette.
    private func addStainBatch(playIndex: Int, rng: inout DirtRNG) {
        // --- Smudge blotches scattered anywhere (3-5 per play) ---
        let smudgeCount = 3 + rng.nextInt(bound: 3)
        for _ in 0..<smudgeCount {
            let pos = randomPointInsideJar(rng: &rng, insetFraction: 0.12)
            let w = rng.nextCGFloat(in: 18...44)
            let h = rng.nextCGFloat(in: 14...32)

            let smudge = makeSmudgeBlotch(size: CGSize(width: w, height: h), rng: &rng)
            smudge.position = pos
            smudge.zPosition = 7
            smudge.zRotation = rng.nextCGFloat(in: -0.8...0.8)
            smudge.alpha = min(0.22 + CGFloat(playIndex) * 0.08, 0.56)
            smudge.name = "dirtStain"
            addChild(smudge)
            dirtNodes.append(smudge)
        }

        // --- Grime spots scattered anywhere (2-4 per play) ---
        let spotCount = 2 + rng.nextInt(bound: 3)
        for _ in 0..<spotCount {
            let pos = randomPointInsideJar(rng: &rng, insetFraction: 0.12)
            let r = rng.nextCGFloat(in: 4...10)

            let spot = makeGrimeSpot(radius: r, rng: &rng)
            spot.position = pos
            spot.zPosition = 7
            spot.alpha = min(0.24 + CGFloat(playIndex) * 0.07, 0.55)
            spot.name = "dirtStain"
            addChild(spot)
            dirtNodes.append(spot)
        }

        // --- Occasional larger smear anywhere (40% chance) ---
        if rng.nextInt(bound: 10) < 4 {
            let pos = randomPointInsideJar(rng: &rng, insetFraction: 0.15)
            let w = rng.nextCGFloat(in: 28...52)
            let h = rng.nextCGFloat(in: 10...22)

            let smear = makeSmudgeBlotch(size: CGSize(width: w, height: h), rng: &rng)
            smear.position = pos
            smear.zPosition = 7
            smear.zRotation = rng.nextCGFloat(in: -1.0...1.0)
            smear.alpha = min(0.18 + CGFloat(playIndex) * 0.06, 0.45)
            smear.name = "dirtStain"
            addChild(smear)
            dirtNodes.append(smear)
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
        let cx = frame.midX

        // Lock tilt, gravity, and interaction while items pop in.
        isSpawning = true
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)

        // Build a shuffled list of all item types so positions are fully random
        var items: [EmojiType] = []
        items += Array(repeating: EmojiType.crystal, count: crystalCount)
        for _ in 0..<junkCount { items.append(.randomJunk(forStage: stage)) }
        items += Array(repeating: EmojiType.balloon, count: balloonCount)

        // Special items: poop spawns from stage 4+, bomb from stage 6+
        // Each has a chance-based spawn (not guaranteed every stage)
        if stage >= 4 && Int.random(in: 0..<3) < 2 {  // ~67% chance
            items.append(.poop)
        }
        if stage >= 1 && Int.random(in: 0..<4) < 2 {  // ~50% chance
            items.append(.bomb)
        }
        // Second poop at high stages
        if stage >= 8 && Int.random(in: 0..<3) < 1 {  // ~33% chance
            items.append(.poop)
        }
        // Second bomb at very high stages
        if stage >= 12 && Int.random(in: 0..<3) < 1 {  // ~33% chance
            items.append(.bomb)
        }

        items.shuffle()

        // Place all items at non-overlapping positions inside the vessel silhouette.
        // Each position is checked against all previously placed items so physics
        // bodies never overlap and push each other apart on spawn.
        let spawnYMin = jarBottomY + 40
        let spawnYMax = min(jarTopY - 40, jarBottomY + 300)
        let stagger: TimeInterval = 0.09
        let spacing: CGFloat = 4  // minimum gap between physics circles

        var placedPositions: [(CGPoint, CGFloat)] = []  // (position, radius)

        for (index, type) in items.enumerated() {
            let position = nonOverlappingSpawnPosition(
                type: type,
                placed: placedPositions,
                cx: cx,
                yMin: spawnYMin,
                yMax: spawnYMax,
                spacing: spacing
            )
            placedPositions.append((position, type.radius))
            placeEmoji(type: type, at: position, spawnDelay: Double(index) * stagger)
        }

        // Spawn a single sticky web stuck to a wall — only from stage 10 onward.
        // The web has a 60 % chance of appearing each stage.
        if stage >= 10 && Int.random(in: 0..<5) < 3 {
            // Pick a Y in the lower-to-mid portion of the jar (never near the top)
            let webY = CGFloat.random(in: jarBottomY + 60 ... jarBottomY + (jarTopY - jarBottomY) * 0.55)
            let halfW = jarHalfWidthAt(y: webY)
            // Stick to left or right wall with a small inset so the web overlaps the border
            let wallInset: CGFloat = 12
            let side: CGFloat = Bool.random() ? 1 : -1
            let webX = cx + side * max(halfW - wallInset, 0)
            placeWeb(at: CGPoint(x: webX, y: webY), wallSide: side)
        }

        let specialCount = items.filter { $0.isPoop || $0.isBomb }.count
        viewModel?.setItemCounts(crystals: crystalCount, junk: junkCount + balloonCount + specialCount)

        // After all items have popped in, show a brief "GO!" banner then unlock gameplay.
        let popDuration: TimeInterval = 0.45
        let totalSpawnTime = Double(items.count - 1) * stagger + popDuration
        run(.sequence([
            .wait(forDuration: totalSpawnTime + 0.1),
            .run { [weak self] in self?.showGoBanner() }
        ]))
    }

    /// Displays a brief "GO!" text that scales up, holds, then fades out, unlocking gameplay.
    private func showGoBanner() {
        let label = SKLabelNode(text: "GO!")
        label.name = "banner"
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 64
        label.fontColor = .white
        label.position = CGPoint(x: frame.midX, y: frame.midY + 40)
        label.zPosition = 20
        label.setScale(0)
        label.alpha = 0
        addChild(label)

        label.run(.sequence([
            .group([
                .fadeAlpha(to: 1.0, duration: 0.12),
                .scale(to: 1.1, duration: 0.15)
            ]),
            .scale(to: 1.0, duration: 0.08),
            .wait(forDuration: 0.3),
            .group([
                .fadeOut(withDuration: 0.2),
                .scale(to: 1.4, duration: 0.2)
            ]),
            .run { [weak self] in
                guard let self else { return }
                self.isSpawning = false
                self.physicsWorld.gravity = CGVector(dx: 0, dy: -self.gravityStrength)
            },
            .removeFromParent()
        ]))
    }

    /// Finds a spawn position inside the jar that doesn't overlap any already-placed item.
    private func nonOverlappingSpawnPosition(
        type: EmojiType,
        placed: [(CGPoint, CGFloat)],
        cx: CGFloat,
        yMin: CGFloat,
        yMax: CGFloat,
        spacing: CGFloat
    ) -> CGPoint {
        let maxAttempts = 60
        for _ in 0..<maxAttempts {
            let y = CGFloat.random(in: yMin...yMax)
            let halfW = jarHalfWidthAt(y: y)
            let inset = type.radius + 6
            let safeHalf = max(halfW - inset, 0)
            let x = cx + CGFloat.random(in: -safeHalf...safeHalf)
            let candidate = CGPoint(x: x, y: y)

            let overlaps = placed.contains { pos, radius in
                let minDist = radius + type.radius + spacing
                let dx = candidate.x - pos.x
                let dy = candidate.y - pos.y
                return dx * dx + dy * dy < minDist * minDist
            }
            if !overlaps { return candidate }
        }
        // Fallback: pick a valid position even if it overlaps (rare, many items in small jar)
        let y = CGFloat.random(in: yMin...yMax)
        let halfW = jarHalfWidthAt(y: y)
        let inset = type.radius + 6
        let safeHalf = max(halfW - inset, 0)
        let x = cx + CGFloat.random(in: -safeHalf...safeHalf)
        return CGPoint(x: x, y: y)
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

    private func placeEmoji(type: EmojiType, at position: CGPoint, spawnDelay: TimeInterval = 0) {
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

        if type.isBomb {
            configureBombFuse(sprite)
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

        // All emoji report contact with webs and walls.
        // Poop also reports contact with other emoji (for gluing).
        // Bomb reports contact with everything except balloon (soft, doesn't count as a strike).
        if type.isPoop {
            body.contactTestBitMask = PhysicsCategory.wall | PhysicsCategory.web | PhysicsCategory.crystal | PhysicsCategory.junk | PhysicsCategory.balloon
        } else if type.isBomb {
            body.contactTestBitMask = PhysicsCategory.wall | PhysicsCategory.web | PhysicsCategory.crystal | PhysicsCategory.junk
        } else {
            body.contactTestBitMask = PhysicsCategory.wall | PhysicsCategory.web
        }

        sprite.physicsBody = body
        sprite.zPosition = 2

        // Pop-in spawn animation: start invisible and with physics disabled,
        // then pop in with a smooth elastic scale after a staggered delay.
        if spawnDelay > 0 {
            sprite.setScale(0)
            sprite.alpha = 0
            body.isDynamic = false

            let popDuration: TimeInterval = 0.45
            let popAction = SKAction.customAction(withDuration: popDuration) { node, elapsed in
                let t = CGFloat(elapsed / popDuration)
                // Damped elastic ease-out: gentle overshoot then settles smoothly
                let scale = 1.0 - pow(2.72, -5.0 * t) * cos(t * .pi * 2.0)
                node.setScale(scale)
                // Smooth fade in over the first 25% of the animation
                node.alpha = min(t / 0.25, 1.0)
            }

            sprite.run(.sequence([
                .wait(forDuration: spawnDelay),
                popAction,
                .scale(to: 1.0, duration: 0), // ensure final scale is exactly 1
                .run { body.isDynamic = true }
            ]))
        }

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

        let ambientPool = EmojiType.allCases.filter { !$0.isCrystal && !$0.isBalloon && !$0.isPoop && !$0.isBomb }
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

    /// Place a spider web stuck to the jar wall.
    /// `wallSide` is -1 for left wall, +1 for right wall.
    private func placeWeb(at position: CGPoint, wallSide: CGFloat = 1) {
        let webRadius: CGFloat = 50

        let webNode = SKNode()
        webNode.name = "web"
        webNode.position = position
        webNode.zPosition = 1

        // --- Soft radial halo (two-layer glow for a friendly, ethereal look) ---

        // Outer soft halo — large, very faint, gives a warm glow aura
        let outerHalo = SKShapeNode(circleOfRadius: webRadius * 1.4)
        outerHalo.fillColor = SKColor(red: 0.85, green: 0.80, blue: 1.0, alpha: 0.04)
        outerHalo.strokeColor = .clear
        outerHalo.lineWidth = 0
        outerHalo.glowWidth = 12
        outerHalo.name = "webOuterHalo"
        outerHalo.alpha = 0.7
        webNode.addChild(outerHalo)

        // Inner glow — subtle, tinted with a slight lavender
        let glow = SKShapeNode(circleOfRadius: webRadius)
        glow.fillColor = SKColor(red: 0.90, green: 0.85, blue: 1.0, alpha: 0.06)
        glow.strokeColor = SKColor(red: 0.80, green: 0.75, blue: 1.0, alpha: 0.12)
        glow.lineWidth = 1.0
        glow.glowWidth = 6
        glow.name = "webGlow"
        webNode.addChild(glow)

        // Emoji label — flip horizontally if on the right wall so the web faces inward
        let label = SKLabelNode(text: "🕸️")
        label.fontSize = 52
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.alpha = 0.75
        label.xScale = wallSide < 0 ? 1.0 : -1.0  // mirror for right wall
        webNode.addChild(label)

        // Sensor physics body — detects overlap but does not collide
        let body = SKPhysicsBody(circleOfRadius: webRadius)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.web
        body.collisionBitMask = 0  // sensor only
        body.contactTestBitMask = PhysicsCategory.allEmoji
        webNode.physicsBody = body

        // Gentle breathing animation (slower and subtler than before)
        let pulse = SKAction.sequence([
            .scale(to: 1.04, duration: 2.4),
            .scale(to: 0.97, duration: 2.4)
        ])
        webNode.run(.repeatForever(pulse))

        // Outer halo fades in and out gently, offset from the main pulse
        let haloFade = SKAction.sequence([
            .fadeAlpha(to: 0.9, duration: 3.0),
            .fadeAlpha(to: 0.5, duration: 3.0)
        ])
        outerHalo.run(.repeatForever(haloFade))

        addChild(webNode)
    }

    /// Capture a node into a web: kill velocity, disable gravity, drift toward web center.
    /// The drift target is clamped inside the jar so items never clip through the walls.
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

        // Drift node toward web center, but clamped safely inside the jar
        let safeTarget = clampInsideJar(web.position, insetFraction: 0.12)
        let drift = SKAction.move(to: safeTarget, duration: 0.6)
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
            let hasStuckItems = !self.stuckNodes.isEmpty || !self.poopGluedPairs.isEmpty
            if accelMagnitude > self.shakeAccelerationThreshold,
               now - self.lastShakeTime > 0.6,
               hasStuckItems {
                self.lastShakeTime = now
                if !self.stuckNodes.isEmpty { self.releaseAllFromWebs() }
                if !self.poopGluedPairs.isEmpty { self.releaseAllPoopGlue() }
            }

            // --- Tilt-based gravity (locked during spawn animation) ---
            guard !self.isSpawning else { return }
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
        guard isGameplayActive, !stageWon, !gameOver, !isTransitioningShape, !isSpawning else { return }
        updateCrystalLightingAndGlints(currentTime: currentTime)
        updatePoopStretchLines()

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
            $0.name == "crystal" || $0.name == "junk" || $0.name == "balloon" ||
            $0.name == "poop" || $0.name == "bomb"
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

            // Safety: clamp stuck node inside the jar so it never escapes through the wall
            let clamped = clampInsideJar(node.position, insetFraction: 0.06)
            if clamped != node.position {
                node.position = clamped
            }

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
                if child.name == "junk" || child.name == "poop" || child.name == "bomb" {
                    removedJunk += 1
                } else if child.name == "crystal" {
                    removedCrystals += 1
                } else if child.name == "balloon" {
                    removedBalloons += 1
                }
                stuckNodes.removeValue(forKey: child)
                removePoopGlueFor(node: child)
                bombStrikeCounts.removeValue(forKey: child)
                bombLastStrikeTime.removeValue(forKey: child)
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

        // Update crystalsInJar live so the HUD reflects the current count.
        // Crystals outside the jar are NOT lost — the player can tilt them back in.
        let inJarNow = crystalsInsideJar()
        viewModel?.crystalsInJar = inJarNow.count

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
        let junkNodes = children.filter { $0.name == "junk" || $0.name == "balloon" || $0.name == "poop" || $0.name == "bomb" }

        // Stage clear: all junk and balloons gone
        if junkNodes.isEmpty {
            // Count all surviving crystals — both inside the jar and still on screen.
            let allSurviving = children.filter { $0.name == "crystal" }
            viewModel?.crystalsInJar = allSurviving.count

            stageWon = true
            viewModel?.stageCleared()
            showWinEffect()
        }
    }

    private func showWinEffect() {
        let crystalNodes = children.filter { $0.name == "crystal" }
        let isPerfectStage = viewModel?.wasPerfectStage ?? false

        // Victory banner
        
         //  .font(.system(size: 15, weight: .semibold, design: .rounded))
           // .textCase(.uppercase)
           // .tracking(1.0)
        
        let banner = SKLabelNode(text: isPerfectStage ? "PERFECT LEVEL!" : "STAGE CLEAR!")
        banner.name       = "banner"
        banner.fontName   = "AvenirNextCondensed-Heavy"
        banner.fontSize   = 44
        banner.fontColor  = isPerfectStage
            ? SKColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 1)
            : SKColor(red: 0.3, green: 0.95, blue: 1.0, alpha: 1)
        banner.position   = CGPoint(
            x: frame.midX,
            y: frame.midY + (isPerfectStage ? 196 : 170) // 176:150
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
            let perfectLabel = SKLabelNode(text: "NO GEMS LOST")
            perfectLabel.name = "banner"
            perfectLabel.fontName = "AvenirNextCondensed-DemiBold"
            perfectLabel.fontSize = 26
            perfectLabel.fontColor = SKColor(red: 1.0, green: 0.94, blue: 0.68, alpha: 1)
            perfectLabel.position = CGPoint(x: frame.midX, y: frame.midY + 160) //116
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
                scoreLabel.fontName = "AvenirNextCondensed-Heavy"
                scoreLabel.fontSize = 30
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

        let glow = SKLabelNode(text: "GAME OVER")
        glow.name       = "banner"
        glow.fontName   = "AvenirNextCondensed-Heavy"
        glow.fontSize   = 66
        glow.fontColor  = SKColor(red: 1.0, green: 0.26, blue: 0.22, alpha: 0.35)
        glow.position   = center
        glow.zPosition  = 19
        glow.alpha      = 0
        glow.setScale(0.5)
        addChild(glow)

        let shadow = SKLabelNode(text: "GAME OVER")
        shadow.name       = "banner"
        shadow.fontName   = "AvenirNextCondensed-Heavy"
        shadow.fontSize   = 64
        shadow.fontColor  = SKColor(white: 0.0, alpha: 0.55)
        shadow.position   = CGPoint(x: center.x, y: center.y - 4)
        shadow.zPosition  = 19.5
        shadow.alpha      = 0
        shadow.setScale(0.5)
        addChild(shadow)

        let banner = SKLabelNode(text: "GAME OVER")
        banner.name       = "banner"
        banner.fontName   = "AvenirNextCondensed-Heavy"
        banner.fontSize   = 64
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
            $0.name == "banner" || $0.name == "web" ||
            $0.name == "poop" || $0.name == "bomb"
        }
        .forEach { node in
            node.removeAllActions()
            node.removeFromParent()
        }

        stuckNodes.removeAll()
        boostedNodes.removeAll()
        removeAllPoopGlue()
        bombStrikeCounts.removeAll()
        bombLastStrikeTime.removeAll()
        stopBombHiss()
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

        // Finalize slightly before t=1.0 — the canonical rebuild is visually
        // identical at t≈0.97 but avoids floating-point jitter artifacts
        // that appear in the last few interpolated frames.
        if rawT >= 0.97 {
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

    // MARK: - Sticky Poop

    /// Glues a poop node to another emoji node using a spring joint and a visual stretch line.
    private func gluePoopTo(_ poopNode: SKNode, other: SKNode) {
        // Don't glue if poop is already glued to something
        guard !poopGluedPairs.contains(where: { $0.poop === poopNode }) else { return }
        // Don't glue to another poop
        guard other.name != "poop" else { return }
        // Don't glue if the other node is already glued to a poop
        guard !poopGluedPairs.contains(where: { $0.other === other }) else { return }

        guard let poopBody = poopNode.physicsBody, let otherBody = other.physicsBody else { return }
        guard poopBody.isDynamic, otherBody.isDynamic else { return }

        // Create a spring joint to bind them together
        let anchorA = poopNode.position
        let anchorB = other.position
        let joint = SKPhysicsJointSpring.joint(
            withBodyA: poopBody,
            bodyB: otherBody,
            anchorA: anchorA,
            anchorB: anchorB
        )
        joint.frequency = 8.0    // stiff spring
        joint.damping = 0.8      // some damping to avoid oscillation
        physicsWorld.add(joint)

        // Increase mass so the combined piece feels heavy
        poopBody.linearDamping = 1.5
        otherBody.linearDamping = 1.5

        // Create a stretch line between the two nodes
        let stretchLine = SKShapeNode()
        stretchLine.strokeColor = SKColor(red: 0.55, green: 0.35, blue: 0.15, alpha: 0.6)
        stretchLine.lineWidth = 3.0
        stretchLine.lineCap = .round
        stretchLine.zPosition = 3
        stretchLine.name = "poopStretch"
        addChild(stretchLine)

        poopGluedPairs.append((poop: poopNode, other: other, joint: joint, stretchLine: stretchLine))

        // Haptic feedback
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
    }

    /// Updates the visual stretch lines between poop-glued pairs each frame.
    private func updatePoopStretchLines() {
        for pair in poopGluedPairs {
            let from = pair.poop.position
            let to = pair.other.position
            let path = CGMutablePath()
            // Draw a slightly curved line for a "gooey" look
            let midX = (from.x + to.x) / 2
            let midY = (from.y + to.y) / 2
            let dist = hypot(to.x - from.x, to.y - from.y)
            let sag = min(dist * 0.15, 12)  // sag increases with distance
            path.move(to: from)
            path.addQuadCurve(to: to, control: CGPoint(x: midX, y: midY - sag))
            pair.stretchLine.path = path

            // Thicken/thin based on stretch distance for organic feel
            let thickness = max(1.5, 4.0 - dist * 0.02)
            pair.stretchLine.lineWidth = thickness
        }
    }

    /// Remove glue for a specific node (when it leaves the screen).
    private func removePoopGlueFor(node: SKNode) {
        poopGluedPairs.removeAll { pair in
            if pair.poop === node || pair.other === node {
                physicsWorld.remove(pair.joint)
                pair.stretchLine.removeFromParent()
                // Restore damping on the surviving node
                if pair.poop === node {
                    pair.other.physicsBody?.linearDamping = 0.8
                } else {
                    pair.poop.physicsBody?.linearDamping = 0.8
                }
                return true
            }
            return false
        }
    }

    /// Remove all poop glue joints and visual lines.
    private func removeAllPoopGlue() {
        for pair in poopGluedPairs {
            physicsWorld.remove(pair.joint)
            pair.stretchLine.removeFromParent()
        }
        poopGluedPairs.removeAll()
    }

    /// Release all poop glue — called on vigorous shake.
    private func releaseAllPoopGlue() {
        for pair in poopGluedPairs {
            physicsWorld.remove(pair.joint)
            pair.stretchLine.removeFromParent()

            // Restore normal damping
            pair.poop.physicsBody?.linearDamping = 0.8
            pair.other.physicsBody?.linearDamping = 0.8

            // Pop impulse to separate them
            let dx = pair.other.position.x - pair.poop.position.x
            let dy = pair.other.position.y - pair.poop.position.y
            let dist = max(hypot(dx, dy), 1)
            let pushStrength: CGFloat = 40
            pair.poop.physicsBody?.applyImpulse(CGVector(dx: -dx / dist * pushStrength, dy: -dy / dist * pushStrength))
            pair.other.physicsBody?.applyImpulse(CGVector(dx: dx / dist * pushStrength, dy: dy / dist * pushStrength))

            // Brown dust particle effect at the separation point
            let midPoint = CGPoint(
                x: (pair.poop.position.x + pair.other.position.x) / 2,
                y: (pair.poop.position.y + pair.other.position.y) / 2
            )
            brownDustEffect(at: midPoint)
        }

        poopGluedPairs.removeAll()

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// Brown dust particle effect — shown when poop is shaken free.
    private func brownDustEffect(at point: CGPoint) {
        let dustColors: [SKColor] = [
            SKColor(red: 0.55, green: 0.35, blue: 0.15, alpha: 0.8),
            SKColor(red: 0.45, green: 0.28, blue: 0.12, alpha: 0.7),
            SKColor(red: 0.65, green: 0.42, blue: 0.20, alpha: 0.6),
            SKColor(red: 0.40, green: 0.25, blue: 0.10, alpha: 0.5),
        ]
        for _ in 0..<12 {
            let r = CGFloat.random(in: 3...7)
            let particle = SKShapeNode(circleOfRadius: r)
            particle.fillColor = dustColors.randomElement()!
            particle.strokeColor = .clear
            particle.position = point
            particle.zPosition = 10
            addChild(particle)

            let angle = CGFloat.random(in: 0 ... .pi * 2)
            let speed = CGFloat.random(in: 20...60)
            particle.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * speed,
                            y: sin(angle) * speed,
                            duration: 0.5),
                    .sequence([.scale(to: 1.3, duration: 0.15),
                               .scale(to: 0.0, duration: 0.35)]),
                    .fadeOut(withDuration: 0.5)
                ]),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Fragile Bomb

    /// Attaches a fuse spark emitter to a newly spawned bomb.
    private func configureBombFuse(_ bombNode: SKNode) {
        guard let sprite = bombNode as? SKSpriteNode else { return }

        // Inner glow node — starts invisible, revealed on first strike
        let glowNode = SKShapeNode(circleOfRadius: sprite.size.width * 0.35)
        glowNode.name = "bombGlow"
        glowNode.fillColor = SKColor(red: 1.0, green: 0.15, blue: 0.05, alpha: 0.0)
        glowNode.strokeColor = .clear
        glowNode.glowWidth = 8
        glowNode.zPosition = -1
        glowNode.blendMode = .add
        sprite.addChild(glowNode)

        // Fuse spark emitter — positioned at the top of the bomb
        let fuseEmitter = SKEmitterNode()
        fuseEmitter.name = "bombFuse"
        fuseEmitter.particleTexture = makeCircleTexture(radius: 2)
        fuseEmitter.particleBirthRate = 0   // starts dormant, activated on strike 1
        fuseEmitter.numParticlesToEmit = 0
        fuseEmitter.particleLifetime = 0.4
        fuseEmitter.particleLifetimeRange = 0.2
        fuseEmitter.particleSpeed = 20
        fuseEmitter.particleSpeedRange = 15
        fuseEmitter.emissionAngle = .pi / 2       // upward
        fuseEmitter.emissionAngleRange = .pi / 3  // spread
        fuseEmitter.particleScale = 0.6
        fuseEmitter.particleScaleRange = 0.4
        fuseEmitter.particleScaleSpeed = -0.8
        fuseEmitter.particleAlpha = 0.9
        fuseEmitter.particleAlphaSpeed = -1.8
        fuseEmitter.particleColor = SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)
        fuseEmitter.particleColorBlendFactor = 1.0
        fuseEmitter.particleBlendMode = .add
        // Position at the top of the emoji
        fuseEmitter.position = CGPoint(x: 0, y: sprite.size.height * 0.32)
        fuseEmitter.zPosition = 2
        sprite.addChild(fuseEmitter)

        // Smoke puff emitter — dormant, thickens with each strike (stays local to bomb)
        let smokeEmitter = SKEmitterNode()
        smokeEmitter.name = "bombSmoke"
        smokeEmitter.particleTexture = makeCircleTexture(radius: 4)
        smokeEmitter.particleBirthRate = 0   // dormant
        smokeEmitter.numParticlesToEmit = 0
        smokeEmitter.particleLifetime = 0.8
        smokeEmitter.particleLifetimeRange = 0.3
        smokeEmitter.particleSpeed = 8
        smokeEmitter.particleSpeedRange = 4
        smokeEmitter.emissionAngle = .pi / 2
        smokeEmitter.emissionAngleRange = .pi / 5
        smokeEmitter.particleScale = 0.3
        smokeEmitter.particleScaleRange = 0.2
        smokeEmitter.particleScaleSpeed = 0.6
        smokeEmitter.particleAlpha = 0.3
        smokeEmitter.particleAlphaSpeed = -0.5
        smokeEmitter.particleColor = SKColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        smokeEmitter.particleColorBlendFactor = 1.0
        smokeEmitter.position = CGPoint(x: 0, y: sprite.size.height * 0.36)
        smokeEmitter.zPosition = 1
        sprite.addChild(smokeEmitter)

        // Smoke TRAIL emitter — particles stay in scene space so they trail behind the bomb
        let trailEmitter = SKEmitterNode()
        trailEmitter.name = "bombTrail"
        trailEmitter.particleTexture = makeCircleTexture(radius: 6)
        trailEmitter.particleBirthRate = 0   // dormant until first strike
        trailEmitter.numParticlesToEmit = 0
        trailEmitter.particleLifetime = 1.2
        trailEmitter.particleLifetimeRange = 0.4
        trailEmitter.particleSpeed = 5
        trailEmitter.particleSpeedRange = 3
        trailEmitter.emissionAngle = .pi / 2        // upward drift
        trailEmitter.emissionAngleRange = .pi / 2   // wide spread for natural look
        trailEmitter.particleScale = 0.2
        trailEmitter.particleScaleRange = 0.15
        trailEmitter.particleScaleSpeed = 0.8        // particles grow as they age (expanding smoke)
        trailEmitter.particleAlpha = 0.25
        trailEmitter.particleAlphaRange = 0.1
        trailEmitter.particleAlphaSpeed = -0.22       // slow fade for lingering trail
        trailEmitter.particleColor = SKColor(red: 0.35, green: 0.33, blue: 0.30, alpha: 1.0)
        trailEmitter.particleColorBlendFactor = 1.0
        trailEmitter.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                SKColor(red: 0.45, green: 0.42, blue: 0.38, alpha: 1.0),  // warm grey at birth
                SKColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1.0),  // neutral grey mid-life
                SKColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 0.0)   // dark, faded out
            ],
            times: [0.0, 0.5, 1.0]
        )
        trailEmitter.particleBlendMode = .alpha
        trailEmitter.position = CGPoint(x: 0, y: sprite.size.height * 0.36)
        trailEmitter.zPosition = -1
        // KEY: targetNode = scene makes particles stay in world space, creating trailing effect
        trailEmitter.targetNode = self
        sprite.addChild(trailEmitter)
    }

    /// Register a hard wall strike on a bomb. Returns true if the bomb should detonate.
    private func registerBombWallHit(_ bombNode: SKNode, impulse: CGFloat) -> Bool {
        guard impulse >= bombStrikeImpulseThreshold else { return false }

        // Enforce cooldown — ignore rapid-fire collisions from the same bounce
        let now = CACurrentMediaTime()
        if let lastStrike = bombLastStrikeTime[bombNode],
           now - lastStrike < bombStrikeCooldown {
            return false
        }
        bombLastStrikeTime[bombNode] = now

        let current = bombStrikeCounts[bombNode, default: 0]
        let newCount = current + 1
        bombStrikeCounts[bombNode] = newCount

        // Escalating haptics per strike
        #if os(iOS)
        switch newCount {
        case 1:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case 2:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        default:
            break // explosion haptic is handled in explodeBomb
        }
        #endif

        // Visual evolution per strike
        applyBombStrikeVisuals(bombNode, strike: newCount)

        // Start or intensify fuse hiss sound
        updateBombHissSound(strike: newCount)

        return newCount >= bombMaxStrikes
    }

    /// Progressive visual evolution — each strike adds more urgency.
    private func applyBombStrikeVisuals(_ bombNode: SKNode, strike: Int) {
        guard let sprite = bombNode as? SKSpriteNode else { return }
        let glow = sprite.childNode(withName: "bombGlow") as? SKShapeNode
        let fuse = sprite.childNode(withName: "bombFuse") as? SKEmitterNode
        let smoke = sprite.childNode(withName: "bombSmoke") as? SKEmitterNode
        let trail = sprite.childNode(withName: "bombTrail") as? SKEmitterNode

        // Clean previous actions
        sprite.removeAction(forKey: "bombFlash")
        sprite.removeAction(forKey: "bombShake")

        switch strike {
        case 1:
            // --- STRIKE 1: WARNING ---
            // Faint pulsing red inner glow fades in
            glow?.run(.sequence([
                .customAction(withDuration: 0) { node, _ in
                    (node as? SKShapeNode)?.fillColor = SKColor(red: 1.0, green: 0.15, blue: 0.05, alpha: 0.12)
                },
                .repeatForever(.sequence([
                    .fadeAlpha(to: 0.6, duration: 0.8),
                    .fadeAlpha(to: 0.2, duration: 0.8)
                ]))
            ]), withKey: "bombGlowPulse")

            // Fuse sparks begin — small, gentle
            fuse?.particleBirthRate = 8
            fuse?.particleSpeed = 20

            // Thin smoke starts
            smoke?.particleBirthRate = 2
            smoke?.particleScale = 0.3

            // Smoke trail begins — light wisps trailing behind the bomb
            trail?.particleBirthRate = 6
            trail?.particleScale = 0.2
            trail?.particleLifetime = 1.0
            trail?.particleAlpha = 0.18

        case 2:
            // --- STRIKE 2: DANGER ---
            // Glow intensifies and pulses faster
            glow?.removeAction(forKey: "bombGlowPulse")
            glow?.run(.sequence([
                .customAction(withDuration: 0) { node, _ in
                    (node as? SKShapeNode)?.fillColor = SKColor(red: 1.0, green: 0.1, blue: 0.05, alpha: 0.25)
                    (node as? SKShapeNode)?.glowWidth = 14
                },
                .repeatForever(.sequence([
                    .fadeAlpha(to: 0.85, duration: 0.35),
                    .fadeAlpha(to: 0.35, duration: 0.35)
                ]))
            ]), withKey: "bombGlowPulse")

            // Red flash on the bomb body
            let flash = SKAction.sequence([
                .colorize(with: SKColor(red: 1.0, green: 0.15, blue: 0.0, alpha: 1.0), colorBlendFactor: 0.35, duration: 0.25),
                .colorize(withColorBlendFactor: 0.05, duration: 0.25)
            ])
            sprite.run(.repeatForever(flash), withKey: "bombFlash")

            // Body vibration — rapid small jitter
            let shake = SKAction.sequence([
                .moveBy(x: -1.5, y: 0, duration: 0.02),
                .moveBy(x: 3.0, y: 0, duration: 0.02),
                .moveBy(x: -3.0, y: 0, duration: 0.02),
                .moveBy(x: 1.5, y: 0, duration: 0.02),
            ])
            sprite.run(.repeatForever(shake), withKey: "bombShake")

            // Fuse sparks intensify — brighter, more
            fuse?.particleBirthRate = 25
            fuse?.particleSpeed = 35
            fuse?.particleColor = SKColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1.0)

            // Smoke thickens substantially
            smoke?.particleBirthRate = 8
            smoke?.particleScale = 0.5

            // Smoke trail thickens — denser, larger puffs, linger longer
            trail?.particleBirthRate = 14
            trail?.particleScale = 0.35
            trail?.particleLifetime = 1.4
            trail?.particleAlpha = 0.3
            trail?.particleScaleSpeed = 1.0
            smoke?.particleLifetime = 1.0
            smoke?.particleAlpha = 0.5

        default:
            break // strike 3 triggers detonation, handled externally
        }
    }

    /// Generates and plays a programmatic hiss/fuse sound that increases in pitch per strike.
    private func updateBombHissSound(strike: Int) {
        // Generate a short burst of filtered noise as a hiss sound
        let sampleRate: Double = 44100
        let duration: Double = strike >= 2 ? 2.0 : 1.5
        let sampleCount = Int(sampleRate * duration)

        // Base frequency rises with strike count
        let baseFreq: Double = strike == 1 ? 2000 : 4000
        let amplitude: Double = strike == 1 ? 0.08 : 0.15

        var samples = [Float](repeating: 0, count: sampleCount)
        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            // Mix white noise with a high-frequency sine to create a hiss
            let noise = Float.random(in: -1...1)
            let tone = Float(sin(2.0 * .pi * baseFreq * t) * 0.3)
            let envelope = Float(min(t * 8.0, 1.0) * max(1.0 - t / duration, 0.0)) // fade in/out
            samples[i] = (noise * 0.7 + tone) * Float(amplitude) * envelope
        }

        // Create WAV data in memory
        let dataSize = sampleCount * 2  // 16-bit samples
        let fileSize = 44 + dataSize
        var wavData = Data(capacity: fileSize)

        // WAV header
        func appendUInt32LE(_ value: UInt32) { wavData.append(contentsOf: withUnsafeBytes(of: value.littleEndian) { Array($0) }) }
        func appendUInt16LE(_ value: UInt16) { wavData.append(contentsOf: withUnsafeBytes(of: value.littleEndian) { Array($0) }) }

        wavData.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        appendUInt32LE(UInt32(fileSize - 8))
        wavData.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
        wavData.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        appendUInt32LE(16)                                      // chunk size
        appendUInt16LE(1)                                       // PCM
        appendUInt16LE(1)                                       // mono
        appendUInt32LE(UInt32(sampleRate))                       // sample rate
        appendUInt32LE(UInt32(sampleRate) * 2)                  // byte rate
        appendUInt16LE(2)                                       // block align
        appendUInt16LE(16)                                      // bits per sample
        wavData.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        appendUInt32LE(UInt32(dataSize))

        for sample in samples {
            let clamped = max(-1, min(1, sample))
            let intSample = Int16(clamped * Float(Int16.max))
            appendUInt16LE(UInt16(bitPattern: intSample))
        }

        // Play via AVAudioPlayer
        do {
            bombHissPlayer?.stop()
            let player = try AVAudioPlayer(data: wavData)
            player.volume = 0.5
            player.prepareToPlay()
            player.play()
            bombHissPlayer = player
            bombHissActive = true
        } catch {
            // Silently fail — sound is non-critical
        }
    }

    /// Stop bomb hiss if playing.
    private func stopBombHiss() {
        bombHissPlayer?.stop()
        bombHissPlayer = nil
        bombHissActive = false
    }

    /// Synthesizes and plays a deep, punchy explosion boom sound.
    private func playBombBoomSound() {
        let sampleRate: Double = 44100
        let duration: Double = 0.8
        let sampleCount = Int(sampleRate * duration)

        var samples = [Float](repeating: 0, count: sampleCount)
        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate

            // Sharp attack envelope: instant rise, fast exponential decay
            let attack = min(t * 200.0, 1.0)  // ~5ms attack
            let decay = exp(-t * 6.0)           // fast exponential decay
            let envelope = Float(attack * decay)

            // Layer 1: Deep sub-bass thump (40-60 Hz, pitch drops over time)
            let subFreq = 60.0 - t * 30.0  // sweeps from 60 Hz down to ~36 Hz
            let sub = Float(sin(2.0 * .pi * subFreq * t)) * 0.9

            // Layer 2: Mid-frequency body punch (120 Hz, faster decay)
            let midDecay = Float(exp(-t * 10.0))
            let mid = Float(sin(2.0 * .pi * 120.0 * t)) * 0.5 * midDecay

            // Layer 3: High-frequency crack/snap (noise burst, very fast decay)
            let crackDecay = Float(exp(-t * 30.0))
            let crack = Float.random(in: -1...1) * 0.6 * crackDecay

            // Layer 4: Rumble tail (low noise, slow decay for sustained boom feel)
            let rumbleDecay = Float(exp(-t * 3.5))
            let rumble = Float.random(in: -1...1) * 0.15 * rumbleDecay

            samples[i] = (sub + mid + crack + rumble) * envelope * 0.85
        }

        // Soft-clip to prevent harsh digital distortion
        for i in 0..<sampleCount {
            let x = samples[i]
            samples[i] = x / (1.0 + abs(x)) * 1.4  // warm saturation
        }

        // Build WAV in memory
        let dataSize = sampleCount * 2
        let fileSize = 44 + dataSize
        var wavData = Data(capacity: fileSize)

        func appendUInt32LE(_ value: UInt32) { wavData.append(contentsOf: withUnsafeBytes(of: value.littleEndian) { Array($0) }) }
        func appendUInt16LE(_ value: UInt16) { wavData.append(contentsOf: withUnsafeBytes(of: value.littleEndian) { Array($0) }) }

        wavData.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        appendUInt32LE(UInt32(fileSize - 8))
        wavData.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
        wavData.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        appendUInt32LE(16)
        appendUInt16LE(1)                                       // PCM
        appendUInt16LE(1)                                       // mono
        appendUInt32LE(UInt32(sampleRate))
        appendUInt32LE(UInt32(sampleRate) * 2)
        appendUInt16LE(2)
        appendUInt16LE(16)
        wavData.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        appendUInt32LE(UInt32(dataSize))

        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let intSample = Int16(clamped * Float(Int16.max))
            appendUInt16LE(UInt16(bitPattern: intSample))
        }

        do {
            bombBoomPlayer?.stop()
            let player = try AVAudioPlayer(data: wavData)
            player.volume = 0.9
            player.prepareToPlay()
            player.play()
            bombBoomPlayer = player
        } catch {
            // Non-critical
        }
    }

    /// Explodes a bomb — 0.5s freeze-frame for drama, then massive force impulse.
    private func explodeBomb(_ bombNode: SKNode) {
        let center = bombNode.position

        // Remove bomb from tracking
        bombStrikeCounts.removeValue(forKey: bombNode)
        bombLastStrikeTime.removeValue(forKey: bombNode)
        removePoopGlueFor(node: bombNode)
        stopBombHiss()

        // --- Strike 3 slow-motion buildup: smooth ramp for dramatic tension ---
        let savedSpeed = physicsWorld.speed

        // Slow physics to 10% for a brief dramatic moment (no hard freeze)
        physicsWorld.speed = savedSpeed * 0.1

        // Stop all bomb visual actions and flash white
        bombNode.removeAllActions()
        if let sprite = bombNode as? SKSpriteNode {
            sprite.colorBlendFactor = 0.7
            sprite.color = .white
        }

        // Growing glow overlay on the bomb during slow-mo
        let slowMoGlow = SKShapeNode(circleOfRadius: 15)
        slowMoGlow.fillColor = SKColor(red: 1.0, green: 1.0, blue: 0.9, alpha: 0.4)
        slowMoGlow.strokeColor = .clear
        slowMoGlow.position = center
        slowMoGlow.zPosition = 20
        slowMoGlow.blendMode = .add
        slowMoGlow.setScale(1.0)
        addChild(slowMoGlow)

        // Animate the glow expanding during slow-mo
        slowMoGlow.run(.sequence([
            .group([
                .scale(to: 2.5, duration: 0.3),
                .fadeAlpha(to: 0.8, duration: 0.3)
            ])
        ]))

        // Heavy "boom" haptic at start of slow-mo
        #if os(iOS)
        let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
        heavyImpact.prepare()
        heavyImpact.impactOccurred(intensity: 1.0)
        #endif

        // After brief slow-mo, ramp back to full speed and detonate
        run(.sequence([
            .wait(forDuration: 0.3),
            .run { [weak self] in
                guard let self else { return }
                slowMoGlow.removeFromParent()
                self.physicsWorld.speed = savedSpeed

                // BOOM sound + visual explosion + glass fog
                self.playBombBoomSound()
                self.showBombExplosionEffect(at: center)
                self.showBombFogEffect(at: center)

                // --- Force impulse — devastate everything in range ---
                let blastRadius: CGFloat = 280
                let maxForce: CGFloat = 320

                let allItems: [SKNode] = self.children.filter {
                    $0.name == "crystal" || $0.name == "junk" || $0.name == "balloon" ||
                    $0.name == "poop" || $0.name == "bomb"
                }

                for item in allItems where item !== bombNode {
                    guard let pb = item.physicsBody, pb.isDynamic else { continue }
                    let dx = item.position.x - center.x
                    let dy = item.position.y - center.y
                    let dist = max(hypot(dx, dy), 1)

                    if dist < blastRadius {
                        // Cubic falloff — devastating up close, still strong at range
                        let falloff = 1.0 - (dist / blastRadius)
                        let force = maxForce * falloff * falloff * falloff
                        let nx = dx / dist
                        let ny = dy / dist
                        // Massive impulse + strong upward bias to launch items out of the jar
                        pb.applyImpulse(CGVector(
                            dx: nx * force * 1.2,
                            dy: ny * force + force * 0.5
                        ))
                        pb.angularVelocity += CGFloat.random(in: -25...25)

                        // Temporarily zero out damping so items fly freely
                        pb.linearDamping = 0.1

                        // Release from web if stuck
                        if self.stuckNodes[item] != nil {
                            item.removeAction(forKey: "webDrift")
                            let isBalloon = item.name == "balloon"
                            pb.affectedByGravity = !isBalloon
                            self.stuckNodes.removeValue(forKey: item)
                        }

                        // Break poop glue on affected items
                        self.removePoopGlueFor(node: item)

                        // Restore normal damping after items have scattered
                        let isBalloon = item.name == "balloon"
                        let restoreDamping = isBalloon ? 2.0 : 0.8
                        item.run(.sequence([
                            .wait(forDuration: 0.6),
                            .run { pb.linearDamping = CGFloat(restoreDamping) }
                        ]))
                    }
                }

                // Remove the bomb node
                bombNode.removeAllActions()
                bombNode.removeFromParent()

                // Update junk count (bomb counts as removed junk)
                self.viewModel?.junkRemoved(1)

                // --- Haptic rumble sequence: makes the phone shake like an actual explosion ---
                #if os(iOS)
                // Initial slam
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)

                // Rapid staccato rumble — 6 heavy taps over 0.4s
                for i in 0..<6 {
                    let delay = 0.06 + Double(i) * 0.07
                    let intensity = max(1.0 - Double(i) * 0.12, 0.4)
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: intensity)
                    }
                }

                // Final deep thud after rumble settles
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
                #endif
            }
        ]))
    }

    /// Massive explosion visual effect for bomb detonation.
    private func showBombExplosionEffect(at point: CGPoint) {
        // --- Primary blast flash (large, bright) ---
        let flash = SKShapeNode(circleOfRadius: 80)
        flash.fillColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.95)
        flash.strokeColor = .clear
        flash.position = point
        flash.zPosition = 18
        flash.blendMode = .add
        addChild(flash)
        flash.run(.sequence([
            .group([
                .scale(to: 3.5, duration: 0.2),
                .fadeOut(withDuration: 0.2)
            ]),
            .removeFromParent()
        ]))

        // --- Secondary shockwave ring ---
        let ring = SKShapeNode(circleOfRadius: 20)
        ring.fillColor = .clear
        ring.strokeColor = SKColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 0.7)
        ring.lineWidth = 4
        ring.glowWidth = 6
        ring.position = point
        ring.zPosition = 17
        ring.blendMode = .add
        addChild(ring)
        ring.run(.sequence([
            .group([
                .scale(to: 8.0, duration: 0.35),
                .fadeOut(withDuration: 0.35)
            ]),
            .removeFromParent()
        ]))

        // --- Dense smoke cloud (24 particles) ---
        let smokeColors: [SKColor] = [
            SKColor(red: 0.20, green: 0.18, blue: 0.15, alpha: 0.85),
            SKColor(red: 0.30, green: 0.28, blue: 0.25, alpha: 0.75),
            SKColor(red: 0.40, green: 0.38, blue: 0.35, alpha: 0.65),
            SKColor(red: 0.18, green: 0.15, blue: 0.12, alpha: 0.90),
        ]
        for _ in 0..<24 {
            let r = CGFloat.random(in: 10...28)
            let smoke = SKShapeNode(circleOfRadius: r)
            smoke.fillColor = smokeColors.randomElement()!
            smoke.strokeColor = .clear
            smoke.position = CGPoint(
                x: point.x + CGFloat.random(in: -10...10),
                y: point.y + CGFloat.random(in: -10...10)
            )
            smoke.zPosition = 14
            addChild(smoke)

            let angle = CGFloat.random(in: 0 ... .pi * 2)
            let speed = CGFloat.random(in: 50...140)
            let growScale = CGFloat.random(in: 3.0...6.0)
            smoke.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * speed,
                            y: sin(angle) * speed + 40,  // smoke rises
                            duration: 0.9),
                    .scale(to: growScale, duration: 0.9),
                    .fadeOut(withDuration: 0.9)
                ]),
                .removeFromParent()
            ]))
        }

        // --- Ember/spark shower (16 particles) ---
        let emberColors: [SKColor] = [
            SKColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 0.95),
            SKColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 0.95),
            SKColor(red: 1.0, green: 0.4, blue: 0.1, alpha: 0.90),
        ]
        for _ in 0..<16 {
            let ember = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.5...5))
            ember.fillColor = emberColors.randomElement()!
            ember.strokeColor = .clear
            ember.position = point
            ember.zPosition = 19
            ember.blendMode = .add
            addChild(ember)

            let angle = CGFloat.random(in: 0 ... .pi * 2)
            let speed = CGFloat.random(in: 80...200)
            ember.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * speed,
                            y: sin(angle) * speed,
                            duration: 0.5),
                    .fadeOut(withDuration: 0.5),
                    .scale(to: 0, duration: 0.5)
                ]),
                .removeFromParent()
            ]))
        }

        // --- Debris chunks (dark fragments flung outward) ---
        for _ in 0..<6 {
            let chunkSize = CGFloat.random(in: 4...10)
            let chunk = SKShapeNode(rectOf: CGSize(width: chunkSize, height: chunkSize * 0.6), cornerRadius: 1)
            chunk.fillColor = SKColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 0.8)
            chunk.strokeColor = .clear
            chunk.position = point
            chunk.zPosition = 13
            addChild(chunk)

            let angle = CGFloat.random(in: 0 ... .pi * 2)
            let speed = CGFloat.random(in: 60...160)
            let spin = CGFloat.random(in: -20...20)
            chunk.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * speed,
                            y: sin(angle) * speed - 20,  // debris falls
                            duration: 0.8),
                    .rotate(byAngle: spin, duration: 0.8),
                    .fadeOut(withDuration: 0.8)
                ]),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Bomb Fog / Glass Smudge Effect

    /// Generates a single soft cloud puff texture — a radial gradient circle with feathered edges.
    private func generateCloudPuffTexture(radius: CGFloat) -> SKTexture {
        let size = CGSize(width: radius * 2, height: radius * 2)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let center = CGPoint(x: radius, y: radius)

            // Multi-stop radial gradient: dark sooty center, soft feathered edge
            let colors = [
                UIColor(white: 0.38, alpha: 0.75).cgColor,
                UIColor(white: 0.34, alpha: 0.55).cgColor,
                UIColor(white: 0.30, alpha: 0.30).cgColor,
                UIColor(white: 0.26, alpha: 0.10).cgColor,
                UIColor(white: 0.22, alpha: 0.0).cgColor,
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.2, 0.45, 0.75, 1.0]

            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                          colors: colors, locations: locations) {
                cg.drawRadialGradient(gradient,
                                      startCenter: center, startRadius: 0,
                                      endCenter: center, endRadius: radius,
                                      options: [])
            }
        }
        return SKTexture(image: image)
    }

    /// Shows a cloudy fog effect clipped to the jar after a bomb explosion.
    /// Spawns multiple individual cloud puffs that drift independently for a natural smoke look.
    private func showBombFogEffect(at explosionPoint: CGPoint) {
        guard let path = jarPath else { return }

        // Create a closed jar path for masking
        let closedPath = CGMutablePath()
        closedPath.addPath(path)
        closedPath.closeSubpath()

        // Crop node keeps all fog inside the jar
        let cropMask = SKShapeNode(path: closedPath)
        cropMask.fillColor = .white
        cropMask.strokeColor = .clear

        let fogCrop = SKCropNode()
        fogCrop.name = "bombFogCrop"
        fogCrop.zPosition = 12
        fogCrop.maskNode = cropMask
        addChild(fogCrop)

        // Pre-generate a few puff textures at different sizes for variety
        let smallPuff  = generateCloudPuffTexture(radius: 120)
        let mediumPuff = generateCloudPuffTexture(radius: 200)
        let largePuff  = generateCloudPuffTexture(radius: 280)
        let puffTextures = [smallPuff, smallPuff, mediumPuff, mediumPuff, mediumPuff, largePuff]

        // Track puff count so the last one to finish removes the crop node
        let puffCount = Int.random(in: 28...40)
        var removedCount = 0

        for i in 0..<puffCount {
            let tex = puffTextures[i % puffTextures.count]
            let puffRadius = CGFloat.random(in: 140...320)
            let puffSize = CGSize(width: puffRadius * 2, height: puffRadius * 2)

            let puff = SKSpriteNode(texture: tex, size: puffSize)
            puff.name = "fogPuff"
            puff.blendMode = .alpha
            puff.zPosition = CGFloat.random(in: 11...13)

            // Scatter puffs around the explosion — tighter cluster near center, some further out
            let spawnAngle = CGFloat.random(in: 0...CGFloat.pi * 2)
            let spawnDist = CGFloat.random(in: 0...200) * CGFloat.random(in: 0.3...1.0) // bias toward center
            let startX = explosionPoint.x + cos(spawnAngle) * spawnDist
            let startY = explosionPoint.y + sin(spawnAngle) * spawnDist
            puff.position = CGPoint(x: startX, y: startY)

            // Randomize initial scale and rotation for variety
            let initScale = CGFloat.random(in: 0.3...0.7)
            puff.setScale(initScale)
            puff.zRotation = CGFloat.random(in: 0...CGFloat.pi * 2)
            puff.alpha = 0.0

            fogCrop.addChild(puff)

            // Each puff has its own drift direction, speed, and timing
            let driftAngle = CGFloat.random(in: 0...CGFloat.pi * 2)
            let driftSpeed = CGFloat.random(in: 15...50)
            let driftX = cos(driftAngle) * driftSpeed
            let driftY = sin(driftAngle) * driftSpeed + CGFloat.random(in: 8...25) // upward bias
            let growTo = initScale * CGFloat.random(in: 1.8...3.0)
            let spinAmount = CGFloat.random(in: -0.4...0.4)

            // Stagger appearance: inner puffs appear first, outer ones slightly later
            let appearDelay = Double(spawnDist / 200.0) * 0.15 + Double.random(in: 0...0.1)
            let fadeInDuration = Double.random(in: 0.1...0.25)
            let peakAlpha = CGFloat.random(in: 0.45...0.75)
            let holdDuration = Double.random(in: 0.6...1.2)
            let fadeOutDuration = Double.random(in: 2.5...4.0)

            let totalPuffCount = puffCount  // capture for closure
            puff.run(.sequence([
                .wait(forDuration: appearDelay),
                // Fade in while starting to grow
                .group([
                    .fadeAlpha(to: peakAlpha, duration: fadeInDuration),
                    .scale(to: initScale * 1.2, duration: fadeInDuration),
                ]),
                // Hold — subtle drift and slow rotation
                .group([
                    .wait(forDuration: holdDuration),
                    .moveBy(x: driftX * 0.2, y: driftY * 0.2, duration: holdDuration),
                    .rotate(byAngle: spinAmount * 0.3, duration: holdDuration),
                ]),
                // Dissipate — drift outward, expand, fade, rotate
                .group([
                    .fadeOut(withDuration: fadeOutDuration),
                    .moveBy(x: driftX, y: driftY, duration: fadeOutDuration),
                    .scale(to: growTo, duration: fadeOutDuration),
                    .rotate(byAngle: spinAmount, duration: fadeOutDuration),
                ]),
                // Cleanup
                .run { [weak fogCrop] in
                    puff.removeFromParent()
                    removedCount += 1
                    if removedCount >= totalPuffCount {
                        fogCrop?.removeFromParent()
                    }
                }
            ]))
        }
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
        guard isGameplayActive, !isSpawning else { return }

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

        // --- Sticky Poop: glue to any other emoji on contact ---
        let nodeA = contact.bodyA.node
        let nodeB = contact.bodyB.node
        if let nA = nodeA, let nB = nodeB {
            if nA.name == "poop" && (nB.name == "crystal" || nB.name == "junk" || nB.name == "balloon" || nB.name == "bomb") {
                gluePoopTo(nA, other: nB)
            } else if nB.name == "poop" && (nA.name == "crystal" || nA.name == "junk" || nA.name == "balloon" || nA.name == "bomb") {
                gluePoopTo(nB, other: nA)
            }
        }

        // --- Fragile Bomb: track hard impacts (walls + items, NOT balloons) ---
        let hardCategories: UInt32 = PhysicsCategory.wall | PhysicsCategory.crystal | PhysicsCategory.junk
        let bombHitHard = (nodeA?.name == "bomb" && (b & hardCategories) != 0) ||
                          (nodeB?.name == "bomb" && (a & hardCategories) != 0)
        // Also count bomb-on-bomb and bomb-on-poop collisions
        let bombHitItem: Bool = {
            if nodeA?.name == "bomb", let other = nodeB?.name {
                return other == "poop" || (other == "bomb" && nodeB !== nodeA)
            }
            if nodeB?.name == "bomb", let other = nodeA?.name {
                return other == "poop" || (other == "bomb" && nodeA !== nodeB)
            }
            return false
        }()
        if bombHitHard || bombHitItem {
            let bombNode = (nodeA?.name == "bomb") ? nodeA! : nodeB!
            if registerBombWallHit(bombNode, impulse: impulse) {
                explodeBomb(bombNode)
                return
            }
            // If a second bomb was also involved, register the hit on it too
            if bombHitItem, nodeA?.name == "bomb", nodeB?.name == "bomb",
               let otherBomb = nodeB, otherBomb !== bombNode {
                if registerBombWallHit(otherBomb, impulse: impulse) {
                    explodeBomb(otherBomb)
                    return
                }
            }
        }

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
