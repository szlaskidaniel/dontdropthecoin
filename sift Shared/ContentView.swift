//
//  ContentView.swift
//  fizz Shared
//

import SwiftUI
import SpriteKit
import Combine
#if os(iOS)
import UIKit
import CoreMotion
#endif

// MARK: - Root View

struct ContentView: View {

    @StateObject private var viewModel = GameViewModel()

    /// Kept in @State so the scene is created once and survives re-renders.
    @State private var scene: GameScene = GameScene.newGameScene()

    var body: some View {
        ZStack(alignment: .top) {
            // ── Game canvas ──────────────────────────────────────────
            SpriteView(
                scene: scene,
                options: [.shouldCullNonVisibleNodes, .allowsTransparency]
            )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .onAppear {
                    scene.viewModel = viewModel
                    // Request 120Hz ProMotion refresh rate
                    if let skView = scene.view {
                        let maxFPS = skView.window?.windowScene?.screen.maximumFramesPerSecond ?? 60
                        skView.preferredFramesPerSecond = min(120, maxFPS)
                        skView.ignoresSiblingOrder = true
                        skView.showsFPS = false
                    }
                }

            // ── HUD overlay (only while playing) ─────────────────────
            if viewModel.gameState == .playing {
                GameHUD(viewModel: viewModel)
            }

           

            // ── Main Menu overlay ────────────────────────────────────
            if viewModel.gameState == .menu {
                MainMenuOverlay(viewModel: viewModel) {
                    SoundEffects.shared.playMenuClick()
                    if viewModel.startGame() {
                        scene.updateDirtOverlays()
                        scene.beginGame()
                    }
                    // If startGame() returns false, viewModel switches to .dailyLimitReached
                }
                .transition(.opacity)
            }

            // ── Game Over overlay ────────────────────────────────────
            if viewModel.gameState == .gameOver {
                GameOverOverlay(viewModel: viewModel) {
                    SoundEffects.shared.playMenuClick()
                    if viewModel.startGame() {
                        scene.updateDirtOverlays()
                        scene.beginGame()
                    }
                }
                .transition(.opacity)
            }

            // ── Daily Limit Reached overlay ─────────────────────────
            if viewModel.gameState == .dailyLimitReached {
                DailyLimitOverlay(
                    viewModel: viewModel,
                    scene: scene,
                    playDirtAnimation: viewModel.shouldPlayDailyLimitAnimation
                ) {
                    // After cleaning jar, update scene dirt overlays
                    scene.updateDirtOverlays()
                }
                .transition(.opacity)
            }
        }
        .background(Color(red: 0.10, green: 0.03, blue: 0.14))
        .animation(.easeInOut(duration: 0.35), value: viewModel.gameState)
        .onChange(of: viewModel.gameState) { _, newState in
            if newState == .menu {
                scene.clearTransientStatusText()
            }
        }
    }
}

// MARK: - HUD

struct GameHUD: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var showExitConfirmation = false

    private let hudAccent = Color(red: 0.30, green: 0.86, blue: 1.00)
    private let hudTextPrimary = Color.white.opacity(0.95)
    private let hudTextSecondary = Color.white.opacity(0.72)

    private var timerColor: Color {
        if viewModel.timeRemaining <= 10 {
            return Color(red: 1.0, green: 0.34, blue: 0.28)
        } else if viewModel.timeRemaining <= 30 {
            return Color(red: 1.0, green: 0.82, blue: 0.30)
        } else {
            return hudAccent
        }
    }

    private var isScoreExpanded: Bool {
        viewModel.stageComplete || viewModel.isTallying
    }

    private var scoreFontSize: CGFloat {
        isScoreExpanded ? 40 : 24
    }

    private var scoreHorizontalPadding: CGFloat {
        isScoreExpanded ? 30 : 18
    }

    private var scoreVerticalPadding: CGFloat {
        isScoreExpanded ? 10 : 5
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 10) {
                HStack {
                    Button {
                        SoundEffects.shared.playMenuClick()
                        showExitConfirmation = true
                    } label: {
                        Image(systemName: "house.fill")
                            .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(hudTextPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(.ultraThinMaterial.opacity(0.6))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                                )
                        )
                        .padding(10)
                        .contentShape(Rectangle())
                    }
                    .padding(.leading, 4)

                    Spacer(minLength: 12)

                    // Right: timer
                    HStack(spacing: 4) {
                        Text("Time")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .textCase(.uppercase)
                            .tracking(1.1)
                            .foregroundStyle(hudTextSecondary)
                        Text("\(viewModel.timeRemaining)")
                            .font(.system(size: 33, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(timerColor)
                            .contentTransition(.numericText())
                            .animation(.spring(duration: 0.3), value: viewModel.timeRemaining)
                            .frame(width: 72, alignment: .trailing)
                    }
                    .frame(width: 130, alignment: .trailing)
                    .padding(.trailing, 2)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)

                // Progress bar — junk removal percentage
                GeometryReader { progressGeo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.20, green: 0.78, blue: 1.00),
                                        Color(red: 0.28, green: 0.92, blue: 0.74)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: progressGeo.size.width * viewModel.junkProgress,
                                height: 6
                            )
                            .cornerRadius(3)
                            .animation(.spring(duration: 0.3), value: viewModel.junkProgress)
                    }
                }
                .frame(height: 6)

                // Score row with Round (left) and score (right)
                HStack {
                    HStack(spacing: 6) {
                        Text("Round")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .textCase(.uppercase)
                            .tracking(1.0)
                            .foregroundStyle(hudTextSecondary)
                        Text("\(viewModel.stage)")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(hudTextPrimary)
                            .contentTransition(.numericText())
                            .animation(.spring(duration: 0.3), value: viewModel.stage)
                    }

                    Spacer(minLength: 10)

                    Text("\(viewModel.totalScore)")
                        .font(.system(size: scoreFontSize, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [hudAccent, Color.white.opacity(0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.15), value: viewModel.totalScore)
                        .padding(.horizontal, scoreHorizontalPadding)
                        .padding(.vertical, scoreVerticalPadding)
                        .background {
                            Capsule(style: .continuous)
                                .fill(.ultraThinMaterial.opacity(isScoreExpanded ? 0.65 : 0.45))
                                .overlay {
                                    Capsule(style: .continuous)
                                        .stroke(Color.white.opacity(isScoreExpanded ? 0.24 : 0.14), lineWidth: 0.8)
                                }
                        }
                        .scaleEffect(isScoreExpanded ? 1.0 : 0.86)
                        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: isScoreExpanded)
                }
            }
            .padding(.top, 10)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .top)
            .background {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.52)

                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.02),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .overlay {
                    Rectangle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
                }
                .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea(edges: .top)
        .confirmationDialog(
            "Leave Current Game?",
            isPresented: $showExitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Return to Home Screen", role: .destructive) {
                SoundEffects.shared.playMenuClick()
                viewModel.returnToMenuFromGameplay()
            }
            Button("Cancel", role: .cancel) {
                SoundEffects.shared.playMenuClick()
            }
        } message: {
            Text("Your current round progress will be lost.")
        }
    }
}

// MARK: - Main Menu

struct MainMenuOverlay: View {
    @ObservedObject var viewModel: GameViewModel
    var onStart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                MenuGemView()

                Text("Sift")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.30, green: 0.86, blue: 1.00),
                                Color(red: 0.80, green: 0.30, blue: 1.00)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                if viewModel.highScore > 0 {
                    VStack(spacing: 4) {
                        Text("Best Score")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(1.5)

                        Text("\(viewModel.highScore)")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color(red: 0.30, green: 0.86, blue: 1.00))
                    }
                    .padding(.top, 8)
                }

                Spacer()

                Button(action: onStart) {
                    Text("START")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.30, green: 0.86, blue: 1.00),
                                            Color(red: 0.20, green: 0.60, blue: 0.90)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
                .padding(.horizontal, 50)

                Text("Tilt to clear the clutter.\nKeep only 💎 crystals!")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 8)

                // Energy indicator
                EnergyIndicator()
                    .padding(.top, 6)

                // Mute music toggle
                Button {
                    SoundEffects.shared.playMenuClick()
                    viewModel.isMusicMuted.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isMusicMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(viewModel.isMusicMuted ? "Music Off" : "Music On")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.3))
                    )
                }
                .padding(.top, 4)

                Spacer()
                    .frame(height: 60)
            }
        }
    }
}

private struct MenuGemView: View {
    @State private var shimmerX: CGFloat = -1.3
    @StateObject private var tilt = DeviceTiltObserver()

    var body: some View {
        let gemGlyph = Text("💎")
            .font(.system(size: 82))

        gemGlyph
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(1.0),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: geo.size.width * 0.52)
                    .rotationEffect(.degrees(20 + Double(tilt.x) * 10))
                    .offset(x: shimmerX * geo.size.width)
                }
                .mask(gemGlyph)
                .blendMode(.screen)
            }
            .rotation3DEffect(.degrees(-Double(tilt.y) * 10), axis: (x: 1, y: 0, z: 0))
            .rotation3DEffect(.degrees(Double(tilt.x) * 12), axis: (x: 0, y: 1, z: 0))
            .offset(x: tilt.x * 10, y: -tilt.y * 8)
            .shadow(
                color: Color(red: 0.35, green: 0.9, blue: 1.0).opacity(0.52),
                radius: 16,
                x: tilt.x * 12,
                y: 10 - (tilt.y * 12)
            )
            .scaleEffect(1.0 + (abs(tilt.x) + abs(tilt.y)) * 0.06)
            .task {
                tilt.start()
                await runShimmerLoop()
            }
            .onDisappear {
                tilt.stop()
            }
    }

    @MainActor
    private func runShimmerLoop() async {
        while !Task.isCancelled {
            shimmerX = -1.3
            withAnimation(.linear(duration: 2.8)) {
                shimmerX = 1.45
            }

            try? await Task.sleep(nanoseconds: 2_800_000_000)
            try? await Task.sleep(nanoseconds: 1_600_000_000)
        }
    }
}

private final class DeviceTiltObserver: ObservableObject {
    @Published var x: CGFloat = 0
    @Published var y: CGFloat = 0

    #if os(iOS)
    private let motionManager = CMMotionManager()
    #endif

    func start() {
        #if os(iOS)
        guard motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let gravity = motion?.gravity else { return }
            let rawX = CGFloat(gravity.x) * 1.9
            let rawY = CGFloat(-gravity.y) * 1.9
            let targetX = max(-1.0, min(1.0, rawX))
            let targetY = max(-1.0, min(1.0, rawY))
            let smoothing: CGFloat = 0.28
            self.x = (self.x * (1 - smoothing)) + (targetX * smoothing)
            self.y = (self.y * (1 - smoothing)) + (targetY * smoothing)
        }
        #endif
    }

    func stop() {
        #if os(iOS)
        motionManager.stopDeviceMotionUpdates()
        #endif
        x = 0
        y = 0
    }
}

// MARK: - Energy Indicator

struct EnergyIndicator: View {
    @ObservedObject private var energy = EnergyManager.shared
    @State private var showInfo = false

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<EnergyManager.maxPlays, id: \.self) { index in
                    Circle()
                        .fill(index < energy.playsRemaining
                              ? Color(red: 0.30, green: 0.86, blue: 1.00)
                              : Color.white.opacity(0.15))
                        .frame(width: 10, height: 10)
                }
            }

            Button {
                SoundEffects.shared.playMenuClick()
                showInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.3))
        )
        .sheet(isPresented: $showInfo) {
            EnergyInfoSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Energy Info Sheet

private struct EnergyInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.03, blue: 0.14)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("🫙")
                    .font(.system(size: 56))
                    .padding(.top, 24)

                Text("Daily Plays")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 14) {
                    InfoRow(icon: "sparkles", text: "You get 5 free plays each day.")
                    InfoRow(icon: "aqi.medium", text: "The jar gets dusty with each game. After 5 plays, it's too dirty to sift.")
                    InfoRow(icon: "play.rectangle.fill", text: "Watch an ad to clean the jar and keep playing for free.")
                    InfoRow(icon: "crown.fill", text: "Or unlock permanently — one purchase removes dust forever!")
                }
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    SoundEffects.shared.playMenuClick()
                    dismiss()
                } label: {
                    Text("Got it")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule(style: .continuous)
                                .fill(.ultraThinMaterial.opacity(0.4))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                                )
                        )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(red: 0.30, green: 0.86, blue: 1.00))
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Game Over

struct GameOverOverlay: View {
    @ObservedObject var viewModel: GameViewModel
    var onPlayAgain: () -> Void

    private var isNewHighScore: Bool {
        viewModel.totalScore >= viewModel.highScore && viewModel.totalScore > 0
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Text("Game Over")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 1, green: 0.3, blue: 0.25))

                Text("Round \(viewModel.stage)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                VStack(spacing: 6) {
                    Text("Score")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(1.5)

                    Text("\(viewModel.totalScore)")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color(red: 0.30, green: 0.86, blue: 1.00))
                }

                if isNewHighScore {
                    Text("New Best!")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 1.00, green: 0.85, blue: 0.25))
                }

                Spacer()

                Button(action: onPlayAgain) {
                    Text("PLAY AGAIN")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.30, green: 0.86, blue: 1.00),
                                            Color(red: 0.20, green: 0.60, blue: 0.90)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
                .padding(.horizontal, 50)

                Button {
                    SoundEffects.shared.playMenuClick()
                    viewModel.gameState = .menu
                } label: {
                    Text("Back to Main Menu")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.top, 8)

                Spacer()
                    .frame(height: 60)
            }
        }
    }
}

// MARK: - Daily Limit Reached

struct DailyLimitOverlay: View {
    @ObservedObject var viewModel: GameViewModel
    let scene: GameScene
    /// When true, plays the dirt splatter animation before revealing the UI.
    let playDirtAnimation: Bool
    /// Called after the jar is cleaned so the scene can update dirt overlays.
    var onClean: () -> Void

    /// Controls whether the overlay content is visible (delayed when animating).
    @State private var showContent = false
    /// Background opacity — animated when dirt animation plays.
    @State private var bgOpacity: Double = 0.80

    var body: some View {
        ZStack {
            Color.black.opacity(bgOpacity)
                .ignoresSafeArea()

            if showContent {
                VStack(spacing: 24) {
                    Spacer()

                    // Dirty jar icon
                    Text("🫙")
                        .font(.system(size: 80))

                    Text("Daily Limit Reached")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.90, green: 0.70, blue: 0.35),
                                    Color(red: 0.85, green: 0.55, blue: 0.25)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .multilineTextAlignment(.center)

                    Text("Your jar is too dirty to sift.\nCome back tomorrow or clean it now!")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.horizontal, 30)

                    Spacer()

                    // "Clean the Jar" IAP button
                    Button {
                        SoundEffects.shared.playMenuClick()
                        // TODO: Trigger StoreKit IAP purchase flow
                        // For now, immediately clean (placeholder)
                        scene.removeDirtExplosion()
                        viewModel.cleanJar()
                        onClean()
                    } label: {
                        HStack(spacing: 8) {
                            Text("Clean the Jar")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                            Text("$0.99")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .tracking(1)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.30, green: 0.86, blue: 1.00),
                                            Color(red: 0.20, green: 0.60, blue: 0.90)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                    }
                    .padding(.horizontal, 40)

                    // "Watch Ad to Clean" button
                    Button {
                        SoundEffects.shared.playMenuClick()
                        // TODO: Trigger rewarded ad flow
                        // For now, immediately clean (placeholder)
                        scene.removeDirtExplosion()
                        viewModel.cleanJar()
                        onClean()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Watch Ad to Clean")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule(style: .continuous)
                                .fill(.ultraThinMaterial.opacity(0.5))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, 40)

                    // Back to menu
                    Button {
                        SoundEffects.shared.playMenuClick()
                        scene.removeDirtExplosion()
                        viewModel.gameState = .menu
                    } label: {
                        Text("Back to Menu")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .padding(.top, 8)

                    Spacer()
                        .frame(height: 50)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onAppear {
            if playDirtAnimation {
                // Consume immediately so the animation is one-shot per trigger.
                viewModel.consumeDailyLimitAnimation()
                // Start with lighter dim so the dirt animation is visible on the jar
                bgOpacity = 0.35
                // Play SpriteKit dirt explosion, then reveal UI
                scene.playDirtyJarAnimation {
                    withAnimation(.easeIn(duration: 0.5)) {
                        bgOpacity = 0.80
                    }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        showContent = true
                    }
                }
            } else {
                // No animation — show immediately
                showContent = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
