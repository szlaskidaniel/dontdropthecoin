//
//  EnergyManager.swift
//  sift Shared
//

import Foundation
import Combine

/// Manages the daily play-count energy system.
/// Players get 3 free plays per calendar day. The count resets at midnight (local time).
/// "Cleaning the jar" (via IAP or rewarded ad) resets the counter immediately.
final class EnergyManager: ObservableObject {

    static let shared = EnergyManager()

    /// Maximum free plays per calendar day.
    static let maxPlays = 3

    // MARK: - Published State

    /// Number of plays used today.
    @Published private(set) var playsUsedToday: Int = 0

    /// Whether the player has reached the daily limit.
    var isLimitReached: Bool {
        playsUsedToday >= Self.maxPlays
    }

    /// Remaining plays today.
    var playsRemaining: Int {
        max(0, Self.maxPlays - playsUsedToday)
    }

    /// The dirt/smudge level of the jar (0.0 = clean, 1.0 = fully dirty).
    /// Increases linearly with each play: 0 plays → 0.0, 3 plays → 1.0.
    var dirtLevel: Double {
        min(1.0, Double(playsUsedToday) / Double(Self.maxPlays))
    }

    // MARK: - UserDefaults Keys

    private let playsKey = "energy_playsUsedToday"
    private let dateKey = "energy_lastPlayDate"

    // MARK: - Init

    private init() {
        refreshIfNewDay()
    }

    // MARK: - Public API

    /// Consume one play. Returns `true` if the play was allowed, `false` if limit reached.
    @discardableResult
    func consumePlay() -> Bool {
        refreshIfNewDay()
        guard !isLimitReached else { return false }
        playsUsedToday += 1
        persist()
        return true
    }

    /// Reset the energy counter (e.g. after IAP "Clean the Jar" or rewarded ad).
    func cleanJar() {
        playsUsedToday = 0
        persist()
    }

    /// Call on app foreground / scene activation to auto-reset if a new day has started.
    func refreshIfNewDay() {
        let today = Calendar.current.startOfDay(for: Date())
        if let storedDate = UserDefaults.standard.object(forKey: dateKey) as? Date {
            let storedDay = Calendar.current.startOfDay(for: storedDate)
            if today > storedDay {
                // New day — reset
                playsUsedToday = 0
                persist()
                return
            }
        }
        // Same day — load stored count
        playsUsedToday = UserDefaults.standard.integer(forKey: playsKey)
    }

    // MARK: - Persistence

    private func persist() {
        UserDefaults.standard.set(playsUsedToday, forKey: playsKey)
        UserDefaults.standard.set(Date(), forKey: dateKey)
    }
}
