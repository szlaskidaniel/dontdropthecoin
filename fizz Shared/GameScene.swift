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

    /// Density — coins are heavy, junk is light.
    var density: CGFloat {
        switch self {
        case .coinBag:   return 12.0
        case .coin:      return 10.0
        case .apple:     return 1.0
        case .teddy:     return 0.8
        case .shoe:      return 1.2
        case .balloon:   return 0.3
        }
    }

    /// Friction — coins have high friction, junk has low friction.
    var friction: CGFloat {
        switch self {
        case .coinBag, .coin: return 0.9
        case .apple:          return 0.2
        case .teddy:          return 0.15
        case .shoe:           return 0.25
        case .balloon:        return 0.1
        }
    }

    var restitution: CGFloat {
        switch self {
        case .coinBag:   return 0.10
        case .coin:      return 0.15
        case .apple:     return 0.45
        case .teddy:     return 0.50
        case .shoe:      return 0.40
        case .balloon:   return 0.60
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

    private let gravityStrength: CGFloat = 28.0
    private let balloonLiftForce: CGFloat = 12.0

    /// Jar geometry (set once in buildJar).
    private var jarMinX: CGFloat = 0
    private var jarMaxX: CGFloat = 0
    private var jarBottomY: CGFloat = 0
    private var jarTopY: CGFloat = 0

    private var stageWon = false
    private var gameOver = false
    private var lastHapticTime: TimeInterval = 0

    // MARK: - Factory

    class func newGameScene() -> GameScene {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .aspectFit
        return scene
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.07, green: 0.07, blue: 0.14, alpha: 1)
        physicsWorld.gravity = CGVector(dx: 0, dy: -gravityStrength)
        physicsWorld.speed = 1.0
        physicsWorld.contactDelegate = self

        #if os(iOS)
        coinImpactGenerator.prepare()
        #endif

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

        // Build the jar physics as an edge-chain (open top, bottle shape)
        let jarPath = CGMutablePath()
        // Left side: straight neck → shoulder → body → floor → body → shoulder → straight neck (right)
        jarPath.move(to:    CGPoint(x: neckMinX, y: jarTopY))       // left opening edge
        jarPath.addLine(to: CGPoint(x: neckMinX, y: shoulderY))    // left neck straight down
        jarPath.addLine(to: CGPoint(x: jarMinX,  y: shoulderY))    // left shoulder outward
        jarPath.addLine(to: CGPoint(x: jarMinX,  y: by))           // left wall down
        jarPath.addLine(to: CGPoint(x: jarMaxX,  y: by))           // floor
        jarPath.addLine(to: CGPoint(x: jarMaxX,  y: shoulderY))    // right wall up
        jarPath.addLine(to: CGPoint(x: neckMaxX, y: shoulderY))    // right shoulder inward
        jarPath.addLine(to: CGPoint(x: neckMaxX, y: jarTopY))      // right neck straight up

        let jarNode = SKNode()
        jarNode.name = "wall"
        let body = SKPhysicsBody(edgeChainFrom: jarPath)
        body.isDynamic          = false
        body.friction           = 0.70
        body.restitution        = 0.25
        body.categoryBitMask    = PhysicsCategory.wall
        body.collisionBitMask   = PhysicsCategory.allEmoji
        body.contactTestBitMask = PhysicsCategory.coin
        jarNode.physicsBody = body
        addChild(jarNode)

        // Visual outline
        let outline = SKShapeNode(path: jarPath)
        outline.name        = "jarOutline"
        outline.strokeColor = SKColor(white: 1, alpha: 0.22)
        outline.lineWidth   = 4
        outline.lineCap     = .round
        outline.fillColor   = SKColor(white: 1, alpha: 0.03)
        outline.glowWidth   = 1.5
        outline.zPosition   = -1
        addChild(outline)
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

        viewModel?.setItemCounts(coins: coinCount, junk: junkCount + balloonCount)
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
        body.linearDamping     = type.isBalloon ? 2.0 : 0.12
        body.angularDamping    = 0.60
        body.allowsRotation    = !type.isBalloon  // keep balloons upright
        body.affectedByGravity = !type.isBalloon  // balloons ignore gravity
        body.categoryBitMask   = type.physicsCategory
        body.collisionBitMask  = PhysicsCategory.allEmoji | PhysicsCategory.wall

        // Coins report contact with walls (for haptics)
        if type.isCoin {
            body.contactTestBitMask = PhysicsCategory.wall
        } else {
            body.contactTestBitMask = 0
        }

        label.physicsBody = body
        addChild(label)
    }

    // MARK: - CoreMotion (tilt)

    private func startMotion() {
        #if os(iOS)
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 1.0 / 60.0
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            self.physicsWorld.gravity = CGVector(
                dx: CGFloat(data.acceleration.x) * self.gravityStrength,
                dy: CGFloat(data.acceleration.y) * self.gravityStrength
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
            child.physicsBody?.applyForce(CGVector(dx: 0, dy: balloonLiftForce))
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
        banner.fontName   = "AvenirNext-Bold"
        banner.fontSize   = 44
        banner.fontColor  = SKColor(red: 1, green: 0.85, blue: 0.1, alpha: 1)
        banner.position   = CGPoint(x: frame.midX, y: frame.midY + 120)
        banner.zPosition  = 20
        banner.alpha      = 0
        banner.setScale(0.5)
        addChild(banner)

        banner.run(.group([
            .fadeIn(withDuration: 0.4),
            .scale(to: 1.0, duration: 0.4)
        ]))

        for coin in coinNodes {
            sparkleEffect(at: coin.position)
        }

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        // Transition to next stage after a delay
        run(.wait(forDuration: 2.0)) { [weak self] in
            self?.startNextStage()
        }
    }

    private func showGameOverEffect() {
        let banner = SKLabelNode(text: "Game Over")
        banner.name       = "banner"
        banner.fontName   = "AvenirNext-Bold"
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
        // Remove all emoji nodes and banners
        children.filter { $0.name == "coin" || $0.name == "junk" || $0.name == "balloon" || $0.name == "banner" }
            .forEach { node in
                node.removeAllActions()
                node.removeFromParent()
            }

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

        let coinHitWall = (a == PhysicsCategory.coin && b == PhysicsCategory.wall) ||
                          (a == PhysicsCategory.wall && b == PhysicsCategory.coin)

        if coinHitWall {
            let impulse = contact.collisionImpulse
            let now = CACurrentMediaTime()
            #if os(iOS)
            // Only fire haptic for meaningful impacts, with a cooldown
            if impulse > 3.0, now - lastHapticTime > 0.15 {
                lastHapticTime = now
                let intensity = min(CGFloat(impulse) / 12.0, 1.0)
                coinImpactGenerator.impactOccurred(intensity: intensity)
                coinImpactGenerator.prepare()
            }
            #endif
        }
    }
}


