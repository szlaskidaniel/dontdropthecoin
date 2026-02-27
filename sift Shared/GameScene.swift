//
//  GameScene.swift
//  fizz Shared
//

import SpriteKit

#if os(iOS)
import CoreMotion
import UIKit
#endif

// MARK: - Physics Categories

private struct PhysicsCategory {
    static let wall:     UInt32 = 1 << 0
    static let coin:     UInt32 = 1 << 1
    static let junk:     UInt32 = 1 << 2
    static let balloon:  UInt32 = 1 << 3
    static let web:      UInt32 = 1 << 4
    static let allEmoji: UInt32 = coin | junk | balloon
}

// MARK: - Emoji Type

enum EmojiType: CaseIterable {
    case coinBag, coin, apple, teddy, shoe, balloon

    var character: String {
        switch self {
        case .coinBag:   return "💰"
        case .coin:      return "🪙"
        case .apple:     return "🍎"
        case .teddy:     return "🧸"
        case .shoe:      return "👟"
        case .balloon:   return "🎈"
        }
    }

    var isCoin: Bool { self == .coin || self == .coinBag }
    var isJunk: Bool { self == .apple || self == .teddy || self == .shoe }
    var isBalloon: Bool { self == .balloon }

    var physicsCategory: UInt32 {
        switch self {
        case .coin, .coinBag: return PhysicsCategory.coin
        case .balloon:        return PhysicsCategory.balloon
        default:              return PhysicsCategory.junk
        }
    }

    var nodeName: String {
        if isCoin { return "coin" }
        if isBalloon { return "balloon" }
        return "junk"
    }

    /// Density — coins are noticeably heavier, junk is light and throwable.
    var density: CGFloat {
        switch self {
        case .coinBag:   return 5.0
        case .coin:      return 4.0
        case .apple:     return 0.6
        case .teddy:     return 0.5
        case .shoe:      return 0.7
        case .balloon:   return 0.15
        }
    }

    /// Friction — coins grip surfaces, junk slides easily.
    var friction: CGFloat {
        switch self {
        case .coinBag, .coin: return 0.7
        case .apple:          return 0.15
        case .teddy:          return 0.10
        case .shoe:           return 0.20
        case .balloon:        return 0.05
        }
    }

    /// Bounciness — junk bounces around for fun, coins stay put.
    var restitution: CGFloat {
        switch self {
        case .coinBag:   return 0.15
        case .coin:      return 0.20
        case .apple:     return 0.55
        case .teddy:     return 0.60
        case .shoe:      return 0.50
        case .balloon:   return 0.70
        }
    }

    /// Radius for the physics body circle.
    var radius: CGFloat {
        switch self {
        case .coinBag:   return 20
        case .coin:      return 18
        case .apple:     return 16
        case .teddy:     return 24
        case .shoe:      return 22
        case .balloon:   return 40
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .teddy, .shoe: return 42
        case .balloon:      return 72
        default:            return 36
        }
    }

    /// Random junk type (apple, teddy, shoe).
    static func randomJunk() -> EmojiType {
        let pool: [EmojiType] = [.apple, .teddy, .shoe]
        return pool.randomElement()!
    }

    /// Random coin type.
    static func randomCoin() -> EmojiType {
        let pool: [EmojiType] = [.coin, .coin, .coin, .coinBag]
        return pool.randomElement()!
    }
}

// MARK: - GameScene

class GameScene: SKScene {

    // MARK: Properties

    weak var viewModel: GameViewModel?

    #if os(iOS)
    private let motionManager = CMMotionManager()
    private let coinImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    #endif

    private let gravityStrength: CGFloat = 14.0
    private let balloonLiftForce: CGFloat = 6.0

    /// Jar geometry (set once in buildJar).
    private var jarMinX: CGFloat = 0
    private var jarMaxX: CGFloat = 0
    private var jarBottomY: CGFloat = 0
    private var jarTopY: CGFloat = 0
    private var jarPath: CGMutablePath?



    private var stageWon = false
    private var gameOver = false
    private var lastHapticTime: TimeInterval = 0

    /// Track which nodes have already received their exit boost so we only apply it once.
    private var boostedNodes: Set<ObjectIdentifier> = []

    // MARK: Sticky Web
    /// Nodes currently stuck in a web zone, keyed by the node. Value is the web node they are stuck in.
    private var stuckNodes: [SKNode: SKNode] = [:]
    private let shakeAccelerationThreshold: Double = 2.5
    private var lastShakeTime: TimeInterval = 0

    // MARK: - Factory

    class func newGameScene() -> GameScene {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .aspectFit
        return scene
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.gravity = CGVector(dx: 0, dy: -gravityStrength)
        physicsWorld.speed = 1.0
        physicsWorld.contactDelegate = self

        #if os(iOS)
        coinImpactGenerator.prepare()
        #endif

        // Radial gradient background (deep navy → dark purple)
        let bgNode = SKSpriteNode(texture: makeRadialGradientTexture(
            size: self.size,
            innerColor: SKColor(red: 0.06, green: 0.06, blue: 0.18, alpha: 1),
            outerColor: SKColor(red: 0.10, green: 0.03, blue: 0.14, alpha: 1)
        ))
        bgNode.position  = CGPoint(x: frame.midX, y: frame.midY)
        bgNode.zPosition = -10
        bgNode.name      = "background"
        addChild(bgNode)

        buildJar()

        fillJar()
        startMotion()
    }

    override func willMove(from view: SKView) {
        #if os(iOS)
        motionManager.stopDeviceMotionUpdates()
        #endif
    }

    // MARK: - Jar Construction

    private func buildJar() {
        let bodyW   = frame.width * 0.78
        let neckW   = bodyW * 0.38         // narrow neck opening
        let h       = frame.height * 0.55
        let neckH   = h * 0.36             // neck height (top portion)
        let cx      = frame.midX
        let by      = frame.minY + 70

        jarMinX    = cx - bodyW / 2
        jarMaxX    = cx + bodyW / 2
        jarBottomY = by
        jarTopY    = by + h

        let shoulderY = jarTopY - neckH    // where neck begins to narrow
        let neckMinX  = cx - neckW / 2
        let neckMaxX  = cx + neckW / 2

        // Corner radius for the bottom of the body
        let bodyCornerR: CGFloat = 28

        // Build the jar as a smooth bottle-shaped edge-chain (open top).
        // The shoulder is a smooth S-curve from the narrow neck to the wide body,
        // NOT a horizontal shelf. This gives a proper bottle/jar silhouette.
        let path = CGMutablePath()

        // Start at left neck opening
        path.move(to: CGPoint(x: neckMinX, y: jarTopY))

        // Left side: smooth S-curve from neck down to body
        // Control points pull the curve diagonally — first hugging the neck,
        // then sweeping out to the body width.
        path.addCurve(
            to: CGPoint(x: jarMinX, y: shoulderY - 30),
            control1: CGPoint(x: neckMinX, y: shoulderY + 20),
            control2: CGPoint(x: jarMinX, y: shoulderY + 10)
        )

        // Left body wall straight down to bottom-left corner
        path.addLine(to: CGPoint(x: jarMinX, y: by + bodyCornerR))

        // Bottom-left rounded corner
        path.addQuadCurve(
            to: CGPoint(x: jarMinX + bodyCornerR, y: by),
            control: CGPoint(x: jarMinX, y: by)
        )

        // Floor
        path.addLine(to: CGPoint(x: jarMaxX - bodyCornerR, y: by))

        // Bottom-right rounded corner
        path.addQuadCurve(
            to: CGPoint(x: jarMaxX, y: by + bodyCornerR),
            control: CGPoint(x: jarMaxX, y: by)
        )

        // Right body wall straight up to shoulder region
        path.addLine(to: CGPoint(x: jarMaxX, y: shoulderY - 30))

        // Right side: smooth S-curve from body up to neck
        path.addCurve(
            to: CGPoint(x: neckMaxX, y: jarTopY),
            control1: CGPoint(x: jarMaxX, y: shoulderY + 10),
            control2: CGPoint(x: neckMaxX, y: shoulderY + 20)
        )

        jarPath = path

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

        // --- Layer 1: Inner fill (depth tint) ---
        let innerFill = SKShapeNode(path: path)
        innerFill.name        = "jarLayer"
        innerFill.strokeColor = .clear
        innerFill.fillColor   = SKColor(red: 0.4, green: 0.5, blue: 0.8, alpha: 0.04)
        innerFill.lineJoin    = .round
        innerFill.zPosition   = -3
        addChild(innerFill)

        // --- Layer 2: Main glass outline ---
        let outline = SKShapeNode(path: path)
        outline.name        = "jarLayer"
        outline.strokeColor = SKColor(white: 1, alpha: 0.18)
        outline.lineWidth   = 3.5
        outline.lineCap     = .round
        outline.lineJoin    = .round
        outline.fillColor   = SKColor(white: 1, alpha: 0.025)
        outline.glowWidth   = 2.0
        outline.zPosition   = -1
        addChild(outline)

        // --- Layer 3: Left-side highlight (light reflection) ---
        let hlPath = CGMutablePath()
        let hlOff: CGFloat = 3  // inset from the main outline
        hlPath.move(to: CGPoint(x: neckMinX + hlOff, y: jarTopY))
        hlPath.addCurve(
            to: CGPoint(x: jarMinX + hlOff, y: shoulderY - 30),
            control1: CGPoint(x: neckMinX + hlOff, y: shoulderY + 20),
            control2: CGPoint(x: jarMinX + hlOff, y: shoulderY + 10)
        )
        hlPath.addLine(to: CGPoint(x: jarMinX + hlOff, y: by + bodyCornerR))

        let highlight = SKShapeNode(path: hlPath)
        highlight.name        = "jarLayer"
        highlight.strokeColor = SKColor(white: 1, alpha: 0.12)
        highlight.lineWidth   = 1.5
        highlight.lineCap     = .round
        highlight.lineJoin    = .round
        highlight.fillColor   = .clear
        highlight.glowWidth   = 0.8
        highlight.zPosition   = -0.5
        addChild(highlight)

        // Jar reflection shimmer particles
        addJarReflectionParticles()
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

        let center = CGPoint(x: CGFloat(w) / 2, y: CGFloat(h) * 0.55)
        let radius = max(CGFloat(w), CGFloat(h)) * 0.7

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

    // MARK: - Fill Jar

    private func fillJar() {
        let coinCount    = 5
        let junkCount    = 12
        let balloonCount = 3
        let jarW = jarMaxX - jarMinX
        let cx   = frame.midX

        // Spawn coins (heavy, settle at the bottom)
        for _ in 0..<coinCount {
            let x = CGFloat.random(in: (cx - jarW * 0.25)...(cx + jarW * 0.25))
            let y = CGFloat.random(in: jarBottomY + 40 ... jarBottomY + 140)
            placeEmoji(type: .randomCoin(), at: CGPoint(x: x, y: y))
        }

        // Spawn junk (light, scattered throughout)
        for _ in 0..<junkCount {
            let x = CGFloat.random(in: (cx - jarW * 0.30)...(cx + jarW * 0.30))
            let y = CGFloat.random(in: jarBottomY + 40 ... jarBottomY + 260)
            placeEmoji(type: .randomJunk(), at: CGPoint(x: x, y: y))
        }

        // Spawn balloons (float toward the top, block the neck)
        for _ in 0..<balloonCount {
            let x = CGFloat.random(in: (cx - jarW * 0.20)...(cx + jarW * 0.20))
            let y = CGFloat.random(in: jarBottomY + 180 ... jarBottomY + 300)
            placeEmoji(type: .balloon, at: CGPoint(x: x, y: y))
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

        viewModel?.setItemCounts(coins: coinCount, junk: junkCount + balloonCount)
    }

    /// The current stage number (forwarded from the view model for difficulty scaling).
    private var stage: Int {
        viewModel?.stage ?? 1
    }

    private func placeEmoji(type: EmojiType, at position: CGPoint) {
        let label = SKLabelNode(text: type.character)
        label.name                  = type.nodeName
        label.fontSize              = type.fontSize
        label.verticalAlignmentMode = .center
        label.position              = position
        label.zPosition             = 2

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

        // All emoji report contact with webs; coins also with walls (for haptics)
        if type.isCoin {
            body.contactTestBitMask = PhysicsCategory.wall | PhysicsCategory.web
        } else {
            body.contactTestBitMask = PhysicsCategory.web
        }

        label.physicsBody = body
        addChild(label)

        // Pulsing glow behind coin emojis
        if type.isCoin {
            let glowRadius = type.radius + 8
            let glow = SKShapeNode(circleOfRadius: glowRadius)
            glow.name        = "coinGlow"
            glow.fillColor   = SKColor(red: 1.0, green: 0.85, blue: 0.1, alpha: 0.15)
            glow.strokeColor = SKColor(red: 1.0, green: 0.85, blue: 0.1, alpha: 0.08)
            glow.lineWidth   = 2
            glow.glowWidth   = 6
            glow.zPosition   = -0.1
            glow.position    = .zero

            let pulse = SKAction.sequence([
                .group([
                    .scale(to: 1.15, duration: 0.8),
                    .fadeAlpha(to: 0.25, duration: 0.8)
                ]),
                .group([
                    .scale(to: 0.9, duration: 0.8),
                    .fadeAlpha(to: 0.10, duration: 0.8)
                ])
            ])
            glow.run(.repeatForever(pulse))
            label.addChild(glow)
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

        // Visual feedback for coins: add a color overlay to signal they're stuck
        if node.name == "coin", let label = node as? SKLabelNode {
            let tint = SKAction.colorize(with: .purple, colorBlendFactor: 0.4, duration: 0.3)
            label.run(tint, withKey: "stuckTint")
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

            // Remove stuck tint from coins
            if node.name == "coin", let label = node as? SKLabelNode {
                label.removeAction(forKey: "stuckTint")
                let restore = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.25)
                label.run(restore)
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
        }
        #endif
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        guard !stageWon, !gameOver else { return }

        // Timer ran out — game over
        if let vm = viewModel, vm.timeRemaining <= 0 {
            gameOver = true
            vm.gameEnded()
            showGameOverEffect()
            return
        }

        // Apply upward force to balloons (negative gravity effect)
        for child in children where child.name == "balloon" {
            if stuckNodes[child] == nil {  // only if not stuck in a web
                child.physicsBody?.applyForce(CGVector(dx: 0, dy: balloonLiftForce))
            }
        }

        // Exit boost — when an item clears the jar top, give it a satisfying fling
        for child in children {
            guard let pb = child.physicsBody, pb.isDynamic else { continue }
            guard child.name == "junk" || child.name == "balloon" || child.name == "coin" else { continue }

            let id = ObjectIdentifier(child)
            if child.position.y > jarTopY + 10, !boostedNodes.contains(id) {
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
        var removedCoins = 0
        var removedBalloons = 0

        for child in children {
            guard child.physicsBody != nil else { continue }
            guard child.name == "coin" || child.name == "junk" || child.name == "balloon" else { continue }

            // Remove items that have escaped the scene bounds (fell out of jar).
            let outOfBounds =
                child.position.y < frame.minY - 100 ||
                child.position.y > frame.maxY + 100 ||
                child.position.x < frame.minX - 100 ||
                child.position.x > frame.maxX + 100

            if outOfBounds {
                if child.name == "junk" {
                    removedJunk += 1
                } else if child.name == "coin" {
                    removedCoins += 1
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

        // Losing coins is allowed but costly — game over only when ALL coins are gone
        if removedCoins > 0 {
            viewModel?.coinsLost(removedCoins)

            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            #endif

            // Check if all coins are gone
            let remainingCoins = children.filter { $0.name == "coin" }
            if remainingCoins.isEmpty {
                gameOver = true
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

    // MARK: - Win / Game Over

    private func checkWinCondition() {
        let junkNodes = children.filter { $0.name == "junk" || $0.name == "balloon" }

        // Stage clear: all junk and balloons gone, coins still inside
        if junkNodes.isEmpty {
            stageWon = true
            viewModel?.stageCleared()
            showWinEffect()
        }
    }

    private func showWinEffect() {
        let coinNodes = children.filter { $0.name == "coin" }
        for coin in coinNodes {
            coin.run(.repeatForever(.sequence([
                .scale(to: 1.3, duration: 0.3),
                .scale(to: 1.0, duration: 0.3),
            ])))
        }

        // Victory banner
        let banner = SKLabelNode(text: "Stage Clear!")
        banner.name       = "banner"
        banner.fontName   = "SFProRounded-Heavy"
        banner.fontSize   = 44
        banner.fontColor  = SKColor(red: 1, green: 0.85, blue: 0.1, alpha: 1)
        banner.position   = CGPoint(x: frame.midX, y: frame.midY + 150)
        banner.zPosition  = 20
        banner.alpha      = 0
        banner.setScale(0.5)
        addChild(banner)

        banner.run(.group([
            .fadeIn(withDuration: 0.4),
            .scale(to: 1.0, duration: 0.4)
        ]))

        // Multiplier label
        if let vm = viewModel {
            let multiplierText = String(format: "×%.1f", vm.lastMultiplier)
            let multLabel = SKLabelNode(text: multiplierText)
            multLabel.name       = "banner"
            multLabel.fontName   = "SFProRounded-Bold"
            multLabel.fontSize   = 22
            multLabel.fontColor  = SKColor(white: 1, alpha: 0.7)
            multLabel.position   = CGPoint(x: frame.midX, y: frame.midY + 110)
            multLabel.zPosition  = 20
            multLabel.alpha      = 0
            addChild(multLabel)

            multLabel.run(.sequence([
                .wait(forDuration: 0.3),
                .fadeIn(withDuration: 0.3)
            ]))
        }

        for coin in coinNodes {
            sparkleEffect(at: coin.position)
        }

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        // Wait for tally animation (~2s) + a brief pause, then advance
        run(.wait(forDuration: 3.5)) { [weak self] in
            self?.startNextStage()
        }
    }

    private func showGameOverEffect() {
        let banner = SKLabelNode(text: "Game Over")
        banner.name       = "banner"
        banner.fontName   = "SFProRounded-Heavy"
        banner.fontSize   = 48
        banner.fontColor  = SKColor(red: 1, green: 0.3, blue: 0.25, alpha: 1)
        banner.position   = CGPoint(x: frame.midX, y: frame.midY + 120)
        banner.zPosition  = 20
        banner.alpha      = 0
        banner.setScale(0.5)
        addChild(banner)

        banner.run(.group([
            .fadeIn(withDuration: 0.4),
            .scale(to: 1.0, duration: 0.4)
        ]))

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }

    // MARK: - Stage Transition

    private func startNextStage() {
        // Remove all emoji, web, and banner nodes
        children.filter {
            $0.name == "coin" || $0.name == "junk" || $0.name == "balloon" ||
            $0.name == "banner" || $0.name == "web"
        }
        .forEach { node in
            node.removeAllActions()
            node.removeFromParent()
        }

        stuckNodes.removeAll()
        boostedNodes.removeAll()
        viewModel?.nextStage()
        stageWon = false
        fillJar()
    }

    // MARK: - Particle Effects

    private func sparkleEffect(at point: CGPoint) {
        for _ in 0..<8 {
            let r = CGFloat.random(in: 2...6)
            let particle = SKShapeNode(circleOfRadius: r)
            particle.fillColor   = SKColor(red: 1, green: 0.9, blue: 0.2, alpha: 0.9)
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

// MARK: - Contact Delegate (coin-wall haptics)
extension GameScene: SKPhysicsContactDelegate {

    func didBegin(_ contact: SKPhysicsContact) {
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

        // --- Coin-wall haptics (.heavy) ---
        let coinHitWall = (a == PhysicsCategory.coin && b == PhysicsCategory.wall) ||
                          (a == PhysicsCategory.wall && b == PhysicsCategory.coin)

        if coinHitWall {
            let impulse = contact.collisionImpulse
            let now = CACurrentMediaTime()
            #if os(iOS)
            if impulse > 3.0, now - lastHapticTime > 0.15 {
                lastHapticTime = now
                let intensity = min(CGFloat(impulse) / 12.0, 1.0)
                coinImpactGenerator.impactOccurred(intensity: intensity)
                coinImpactGenerator.prepare()
            }
            #endif
        }

        // --- Junk-wall haptics (.light) ---
        let junkHitWall = (a == PhysicsCategory.junk && b == PhysicsCategory.wall) ||
                          (a == PhysicsCategory.wall && b == PhysicsCategory.junk)

        if junkHitWall {
            #if os(iOS)
            let impulse = contact.collisionImpulse
            let now = CACurrentMediaTime()
            if impulse > 2.0, now - lastHapticTime > 0.12 {
                lastHapticTime = now
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            #endif
        }

        // --- Squash & stretch on wall impact (balloons only) ---
        let balloonHitWall = (a == PhysicsCategory.balloon && b == PhysicsCategory.wall) ||
                             (a == PhysicsCategory.wall && b == PhysicsCategory.balloon)

        if balloonHitWall {
            let impulse = contact.collisionImpulse
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
        }
    }
}


