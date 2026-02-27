//
//  GameViewModel.swift
//  fizz Shared
//

import Foundation
import Combine

class GameViewModel: ObservableObject {

    @Published var stage: Int = 1
    @Published var coinsInJar: Int = 0
    @Published var junkRemaining: Int = 0
    @Published var stageComplete: Bool = false
    @Published var isGameOver: Bool = false
    @Published var timeRemaining: Int = 120

    private let earlyStageDuration = 120
    private let laterStageDuration = 60
    private var timer: Timer?

    private var currentStageDuration: Int {
        stage <= 5 ? earlyStageDuration : laterStageDuration
    }

    func setItemCounts(coins: Int, junk: Int) {
        coinsInJar = coins
        junkRemaining = junk
        stageComplete = false
        startTimer()
    }

    func junkRemoved(_ count: Int) {
        junkRemaining = max(0, junkRemaining - count)
    }

    func coinsLost(_ count: Int) {
        coinsInJar = max(0, coinsInJar - count)
    }

    func stageCleared() {
        stageComplete = true
        stopTimer()
    }

    func nextStage() {
        stage += 1
        stageComplete = false
    }

    func gameEnded() {
        isGameOver = true
        stopTimer()
    }

    func reset() {
        stage = 1
        coinsInJar = 0
        junkRemaining = 0
        stageComplete = false
        isGameOver = false
        timeRemaining = currentStageDuration
        stopTimer()
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timeRemaining = currentStageDuration
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.timeRemaining -= 1
            if self.timeRemaining <= 0 {
                self.timeRemaining = 0
                self.stopTimer()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
