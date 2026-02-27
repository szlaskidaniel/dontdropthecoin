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
    @Published var timeRemaining: Int = 60

    private let stageDuration = 60
    private var timer: Timer?

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
        timeRemaining = stageDuration
        stopTimer()
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timeRemaining = stageDuration
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
