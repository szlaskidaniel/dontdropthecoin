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

    // Scoring
    @Published var totalScore: Int = 0
    @Published var lastStageScore: Int = 0
    @Published var lastMultiplier: Double = 1.0
    /// True while the time→score tally animation is running.
    @Published var isTallying: Bool = false

    private let earlyStageDuration = 120
    private let laterStageDuration = 60
    private var timer: Timer?
    private var tallyTimer: Timer?
    /// Points awarded per tick of the tally (time remaining × this value).
    private var tallyPointsPerTick: Int = 0

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
        stopTimer()

        // Stage multiplier: later stages are worth more
        let stageMultiplier = 1.0 + Double(stage - 1) * 0.15

        // Base points: coins saved × 100 × stage multiplier — awarded immediately
        let basePoints = Int(Double(coinsInJar * 100) * stageMultiplier)
        lastMultiplier = stageMultiplier
        lastStageScore = basePoints
        totalScore += basePoints

        // Time bonus: each remaining second is worth (5 × stageMultiplier) points,
        // awarded one tick at a time so the player sees the timer drain to zero.
        tallyPointsPerTick = max(1, Int(5.0 * stageMultiplier))

        stageComplete = true

        if timeRemaining > 0 {
            startTally()
        }
    }

    // MARK: - Score Tally Animation

    /// Drains `timeRemaining` to 0, awarding points each tick.
    private func startTally() {
        stopTally()
        isTallying = true

        // Tick interval adapts so the tally always takes ~2 seconds total
        let ticks = timeRemaining
        let interval = min(2.0 / Double(max(ticks, 1)), 0.05)

        tallyTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
                self.totalScore += self.tallyPointsPerTick
                self.lastStageScore += self.tallyPointsPerTick
            }
            if self.timeRemaining <= 0 {
                self.stopTally()
            }
        }
    }

    private func stopTally() {
        tallyTimer?.invalidate()
        tallyTimer = nil
        isTallying = false
    }

    func nextStage() {
        stopTally()
        stage += 1
        stageComplete = false
    }

    func gameEnded() {
        isGameOver = true
        stopTimer()
    }

    func reset() {
        stopTally()
        stage = 1
        coinsInJar = 0
        junkRemaining = 0
        stageComplete = false
        isGameOver = false
        totalScore = 0
        lastStageScore = 0
        lastMultiplier = 1.0
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
