//
//  GameViewModel.swift
//  sift Shared
//

import Foundation
import Combine

enum GameState {
    case menu
    case playing
    case gameOver
    case dailyLimitReached
}

class GameViewModel: ObservableObject {

    @Published var gameState: GameState = .menu
    @Published var stage: Int = 1
    @Published var crystalsInJar: Int = 0
    @Published var junkRemaining: Int = 0
    @Published var stageComplete: Bool = false
    @Published var isGameOver: Bool = false
    /// One-shot trigger for the dirt animation on Daily Limit screen.
    @Published var shouldPlayDailyLimitAnimation: Bool = false
    @Published var timeRemaining: Int = 120

    @Published var highScore: Int {
        didSet { UserDefaults.standard.set(highScore, forKey: "highScore") }
    }

    @Published var isMusicMuted: Bool {
        didSet { UserDefaults.standard.set(isMusicMuted, forKey: "isMusicMuted") }
    }

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
    @Published var wasPerfectStage: Bool = false
    @Published var lastPerfectBonus: Int = 0
    /// True while the time→score tally animation is running.
    @Published var isTallying: Bool = false

    private let baseStageDuration = 120
    private let unchangedStageCount = 3
    private let stageDurationReductionPerStage = 3
    private let minimumStageDuration = 30
    private var timer: Timer?
    private var tallyTimer: Timer?
    /// Points awarded per tick during the score tally animation.
    private var tallyPointsPerTick: Int = 0

    /// Reference to the shared energy manager for daily play tracking.
    let energy = EnergyManager.shared

    init() {
        self.highScore = UserDefaults.standard.integer(forKey: "highScore")
        self.isMusicMuted = UserDefaults.standard.bool(forKey: "isMusicMuted")
    }

    /// Attempt to start a game. Returns `true` if the game was started,
    /// or `false` if the daily limit was reached (shows limit screen instead).
    @discardableResult
    func startGame() -> Bool {
        energy.refreshIfNewDay()
        guard !energy.isLimitReached else {
            // Entered from START while already out of plays: do not replay dirt animation.
            shouldPlayDailyLimitAnimation = false
            gameState = .dailyLimitReached
            return false
        }
        energy.consumePlay()
        reset()
        gameState = .playing
        return true
    }

    /// Called when the user purchases "Clean the Jar" or watches a rewarded ad.
    func cleanJar() {
        energy.cleanJar()
        shouldPlayDailyLimitAnimation = false
        gameState = .menu
    }

    /// Show the daily limit screen (e.g. when user tries to play from game over).
    func showDailyLimit() {
        shouldPlayDailyLimitAnimation = false
        gameState = .dailyLimitReached
    }

    /// Consume the one-shot dirt animation trigger.
    func consumeDailyLimitAnimation() {
        shouldPlayDailyLimitAnimation = false
    }

    private var currentStageDuration: Int {
        guard stage > unchangedStageCount else { return baseStageDuration }
        let reductions = stage - unchangedStageCount
        let reducedDuration = baseStageDuration - (reductions * stageDurationReductionPerStage)
        return max(minimumStageDuration, reducedDuration)
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
        SoundEffects.shared.playRoundCleared()

        // Stage multiplier: later stages are worth more
        let stageMultiplier = 1.0 + Double(stage - 1) * 0.15
        let safeTotalCrystals = max(totalCrystalsAtStart, 1)
        let crystalPreservation = Double(crystalsInJar) / Double(safeTotalCrystals)
        // Strong nonlinear weighting so preserving gems always dominates the score.
        let preservationWeight = pow(crystalPreservation, 3.0)

        // Base points are heavily driven by gems preserved.
        let crystalBasePoints = Double(totalCrystalsAtStart * 1200)
        let basePoints = Int((crystalBasePoints * preservationWeight * stageMultiplier).rounded())
        let isPerfectStage = totalCrystalsAtStart > 0 && crystalsInJar == totalCrystalsAtStart
        let perfectBonus = isPerfectStage ? Int((Double(totalCrystalsAtStart * 450) * stageMultiplier).rounded()) : 0
        lastMultiplier = stageMultiplier * preservationWeight
        wasPerfectStage = isPerfectStage
        lastPerfectBonus = perfectBonus
        lastStageScore = basePoints + perfectBonus
        totalScore += basePoints + perfectBonus

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
        SoundEffects.shared.startScoreCounterLoop()

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
        SoundEffects.shared.stopScoreCounterLoop()
    }

    func nextStage() {
        stopTally()
        stage += 1
        stageComplete = false
        wasPerfectStage = false
        lastPerfectBonus = 0
    }

    func gameEnded() {
        isGameOver = true
        stopTimer()
        if totalScore > highScore {
            highScore = totalScore
        }
        // On the last free play, go straight to daily limit screen and play dirt animation once.
        if energy.isLimitReached {
            shouldPlayDailyLimitAnimation = true
            gameState = .dailyLimitReached
        } else {
            gameState = .gameOver
        }
    }

    func returnToMenuFromGameplay() {
        reset()
        gameState = .menu
    }

    func reset() {
        stopTally()
        stage = 1
        crystalsInJar = 0
        junkRemaining = 0
        stageComplete = false
        isGameOver = false
        shouldPlayDailyLimitAnimation = false
        totalScore = 0
        lastStageScore = 0
        lastMultiplier = 1.0
        wasPerfectStage = false
        lastPerfectBonus = 0
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
