//
//  GameViewModel.swift
//  fizz Shared
//

import Foundation
import Combine

class GameViewModel: ObservableObject {

    @Published var stage: Int = 1
    @Published var crystalsInJar: Int = 0
    @Published var junkRemaining: Int = 0
    @Published var stageComplete: Bool = false
    @Published var isGameOver: Bool = false
    @Published var timeRemaining: Int = 120

    /// Total junk count at the start of the current stage (set once per stage).
    @Published var totalJunkAtStart: Int = 0
    /// Total crystals at the start of the current stage (set once per stage).
    @Published var totalCrystalsAtStart: Int = 0

    /// Fraction of junk removed so far (0.0 ... 1.0).
    var junkProgress: Double {
        guard totalJunkAtStart > 0 else { return 0 }
        let removed = totalJunkAtStart - junkRemaining
        return min(1.0, Double(removed) / Double(totalJunkAtStart))
    }

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
    /// Points awarded per tick during the score tally animation.
    private var tallyPointsPerTick: Int = 0

    private var currentStageDuration: Int {
        stage <= 5 ? earlyStageDuration : laterStageDuration
    }

    func setItemCounts(crystals: Int, junk: Int) {
        crystalsInJar = crystals
        totalCrystalsAtStart = crystals
        junkRemaining = junk
        totalJunkAtStart = junk
        stageComplete = false
        startTimer()
    }

    func junkRemoved(_ count: Int) {
        junkRemaining = max(0, junkRemaining - count)
    }

    func crystalsLost(_ count: Int) {
        crystalsInJar = max(0, crystalsInJar - count)
    }

    func stageCleared() {
        stopTimer()

        // Stage multiplier: later stages are worth more
        let stageMultiplier = 1.0 + Double(stage - 1) * 0.15
        let safeTotalCrystals = max(totalCrystalsAtStart, 1)
        let crystalPreservation = Double(crystalsInJar) / Double(safeTotalCrystals)
        // Strong nonlinear weighting so preserving gems always dominates the score.
        let preservationWeight = pow(crystalPreservation, 3.0)

        // Base points are heavily driven by gems preserved.
        let crystalBasePoints = Double(totalCrystalsAtStart * 1200)
        let basePoints = Int((crystalBasePoints * preservationWeight * stageMultiplier).rounded())
        lastMultiplier = stageMultiplier * preservationWeight
        lastStageScore = basePoints
        totalScore += basePoints

        // Time bonus is secondary, but always visibly tallied per remaining second.
        // It is still strongly scaled by preserved gems, so gem preservation dominates.
        let perSecondTimeBonus = max(1, Int((Double(totalCrystalsAtStart * 20) * preservationWeight * stageMultiplier).rounded()))
        tallyPointsPerTick = perSecondTimeBonus

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
        crystalsInJar = 0
        junkRemaining = 0
        stageComplete = false
        isGameOver = false
        totalScore = 0
        lastStageScore = 0
        lastMultiplier = 1.0
        totalJunkAtStart = 0
        totalCrystalsAtStart = 0
        tallyPointsPerTick = 0
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
