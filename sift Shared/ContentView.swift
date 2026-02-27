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

            // ── HUD overlay ──────────────────────────────────────────
            GameHUD(viewModel: viewModel)

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
        }
        .background(Color(red: 0.10, green: 0.03, blue: 0.14))
    }
}

// MARK: - HUD

struct GameHUD: View {
    @ObservedObject var viewModel: GameViewModel

    private var timerColor: Color {
        viewModel.timeRemaining <= 10 ? .red : .white
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                // Left: stage
                HStack(spacing: 4) {
                    Text("🏁")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                    Text("\(viewModel.stage)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.3), value: viewModel.stage)
                }
                .frame(minWidth: 50, alignment: .leading)

                Spacer()

                // Center: total score
                Text("\(viewModel.totalScore)")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(red: 0.3, green: 0.9, blue: 1.0))
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.15), value: viewModel.totalScore)

                Spacer()

                // Right: timer
                Text("\(viewModel.timeRemaining)")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(timerColor)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: viewModel.timeRemaining)
            }
            .padding(.leading, 20)
            .padding(.trailing, 24)
            .padding(.vertical, 8)

            // Progress bar — junk removal percentage
            GeometryReader { geo in
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
                            width: geo.size.width * viewModel.junkProgress,
                            height: 6
                        )
                        .cornerRadius(3)
                        .animation(.spring(duration: 0.3), value: viewModel.junkProgress)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
