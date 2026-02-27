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
        .background(Color(red: 0.07, green: 0.07, blue: 0.14))
    }
}

// MARK: - HUD

struct GameHUD: View {
    @ObservedObject var viewModel: GameViewModel

    private var timerColor: Color {
        viewModel.timeRemaining <= 10 ? .red : .white
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left: compact stats row
            HStack(spacing: 14) {
                compactStat(icon: "🏁", value: viewModel.stage)
                compactStat(icon: "🪙", value: viewModel.coinsInJar,
                            color: Color(red: 1, green: 0.84, blue: 0.1))
                compactStat(icon: "🗑️", value: viewModel.junkRemaining)
            }

            Spacer()

            // Right: prominent timer
            Text("\(viewModel.timeRemaining)")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(timerColor)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.3), value: viewModel.timeRemaining)
        }
        .padding(.leading, 20)
        .padding(.trailing, 24)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func compactStat(icon: String, value: Int,
                             color: Color? = nil) -> some View {
        HStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 14))
            Text("\(value)")
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(color ?? .primary)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.3), value: value)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
