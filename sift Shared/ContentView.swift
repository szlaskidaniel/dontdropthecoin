//
//  ContentView.swift
//  fizz Shared
//

import SwiftUI
import SpriteKit
#if os(iOS)
import UIKit
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

            // ── Stage clear banner ───────────────────────────────────
            if viewModel.stageComplete {
                VStack(spacing: 16) {
                    Spacer()
                    Text("Tilt to remove the junk!\nKeep only 💎 crystals.")
                        .font(.system(.callout, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 40)
                }
                .transition(.opacity)
            }

            // ── Main Menu overlay ────────────────────────────────────
            if viewModel.gameState == .menu {
                MainMenuOverlay(viewModel: viewModel) {
                    viewModel.startGame()
                    scene.beginGame()
                }
                .transition(.opacity)
            }

            // ── Game Over overlay ────────────────────────────────────
            if viewModel.gameState == .gameOver {
                GameOverOverlay(viewModel: viewModel) {
                    viewModel.startGame()
                    scene.beginGame()
                }
                .transition(.opacity)
            }
        }
        .background(Color(red: 0.10, green: 0.03, blue: 0.14))
        .animation(.easeInOut(duration: 0.35), value: viewModel.gameState)
    }
}

// MARK: - HUD

struct GameHUD: View {
    @ObservedObject var viewModel: GameViewModel

    private var timerColor: Color {
        viewModel.timeRemaining <= 10 ? .red : .white
    }

    private var isScoreExpanded: Bool {
        viewModel.stageComplete || viewModel.isTallying
    }

    private var scoreFontSize: CGFloat {
        isScoreExpanded ? 52 : 24
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
                    // Left: round
                    HStack(spacing: 6) {
                        Text("Round")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("\(viewModel.stage)")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.spring(duration: 0.3), value: viewModel.stage)
                    }
                    .padding(.leading, 12)
                    .padding(.top, 4)

                    Spacer(minLength: 12)

                    // Right: timer
                    HStack(spacing: 4) {
                        Text("Time")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("\(viewModel.timeRemaining)")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(timerColor)
                            .contentTransition(.numericText())
                            .animation(.spring(duration: 0.3), value: viewModel.timeRemaining)
                            .frame(width: 72, alignment: .trailing)
                    }
                    .frame(width: 130, alignment: .trailing)
                    .padding(.trailing, 4)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)

                // Progress bar — junk removal percentage
                GeometryReader { progressGeo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.3, green: 0.8, blue: 0.4),
                                        Color(red: 0.2, green: 0.9, blue: 0.5)
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

                // Current score under progress bar
                Text("\(viewModel.totalScore)")
                    .font(.system(size: scoreFontSize, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(red: 0.30, green: 0.86, blue: 1.00))
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
                    .frame(maxWidth: .infinity, alignment: .center)
                    .animation(.spring(response: 0.45, dampingFraction: 0.82), value: isScoreExpanded)
            }
            .padding(.top, geo.safeAreaInsets.top + 10)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .top)
            .background {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.46)

                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02),
                            Color.white.opacity(0.05)
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

                Text("💎")
                    .font(.system(size: 72))

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

                Text("Tilt to remove the junk.\nKeep only 💎 crystals!")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 8)

                Spacer()
                    .frame(height: 60)
            }
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

                Spacer()
                    .frame(height: 60)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
