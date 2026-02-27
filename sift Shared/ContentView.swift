//
//  ContentView.swift
//  fizz Shared
//

import SwiftUI
import SpriteKit

// MARK: - Root View

struct ContentView: View {

    @StateObject private var viewModel = GameViewModel()

    /// Kept in @State so the scene is created once and survives re-renders.
    @State private var scene: GameScene = GameScene.newGameScene()

    var body: some View {
        ZStack(alignment: .top) {
            // ── Game canvas ──────────────────────────────────────────
            SpriteView(scene: scene)
                .ignoresSafeArea()
                .onAppear {
                    scene.viewModel = viewModel
                }

            // ── HUD overlay ──────────────────────────────────────────
            GameHUD(viewModel: viewModel)

            // ── Stage clear banner ───────────────────────────────────
            if viewModel.stageComplete {
                VStack(spacing: 16) {
                    Spacer()
                    Text("Tilt to remove the junk!\nKeep only 🪙 coins.")
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
                        .font(.system(size: 14))
                    Text("\(viewModel.stage)")
                        .font(.system(.callout, design: .rounded, weight: .heavy))
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
                    .foregroundStyle(Color(red: 1, green: 0.84, blue: 0.1))
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

                    Capsule()
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
