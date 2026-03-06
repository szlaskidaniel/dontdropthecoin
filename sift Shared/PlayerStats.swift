//
//  PlayerStats.swift
//  sift Shared
//

import Foundation
import Combine

/// Tracks lifetime player statistics, persisted to UserDefaults.
class PlayerStats: ObservableObject {

    static let shared = PlayerStats()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Key: String {
        case totalSessions     = "stats_totalSessions"
        case totalDiamonds     = "stats_totalDiamonds"
        case sortedApples      = "stats_sorted_apple"
        case sortedTeddies     = "stats_sorted_teddy"
        case sortedShoes       = "stats_sorted_shoe"
        case sortedRocks       = "stats_sorted_rock"
        case sortedGifts       = "stats_sorted_gift"
        case sortedPaperclips  = "stats_sorted_paperclip"
        case sortedDonuts      = "stats_sorted_donut"
        case sortedBolts       = "stats_sorted_bolt"
        case sortedBalloons    = "stats_sorted_balloon"
        case sortedPoops       = "stats_sorted_poop"
        case sortedBombs       = "stats_sorted_bomb"
        case lostDiamonds      = "stats_lostDiamonds"
    }

    // MARK: - Published Properties

    @Published var totalSessions: Int
    @Published var totalDiamonds: Int
    @Published var lostDiamonds: Int

    @Published var sortedApples: Int
    @Published var sortedTeddies: Int
    @Published var sortedShoes: Int
    @Published var sortedRocks: Int
    @Published var sortedGifts: Int
    @Published var sortedPaperclips: Int
    @Published var sortedDonuts: Int
    @Published var sortedBolts: Int
    @Published var sortedBalloons: Int
    @Published var sortedPoops: Int
    @Published var sortedBombs: Int

    // MARK: - Session Accumulators (not persisted until game ends)

    private var sessionApples = 0
    private var sessionTeddies = 0
    private var sessionShoes = 0
    private var sessionRocks = 0
    private var sessionGifts = 0
    private var sessionPaperclips = 0
    private var sessionDonuts = 0
    private var sessionBolts = 0
    private var sessionBalloons = 0
    private var sessionPoops = 0
    private var sessionBombs = 0
    private var sessionDiamonds = 0
    private var sessionLostDiamonds = 0

    // MARK: - Init

    private init() {
        totalSessions    = defaults.integer(forKey: Key.totalSessions.rawValue)
        totalDiamonds    = defaults.integer(forKey: Key.totalDiamonds.rawValue)
        lostDiamonds     = defaults.integer(forKey: Key.lostDiamonds.rawValue)
        sortedApples     = defaults.integer(forKey: Key.sortedApples.rawValue)
        sortedTeddies    = defaults.integer(forKey: Key.sortedTeddies.rawValue)
        sortedShoes      = defaults.integer(forKey: Key.sortedShoes.rawValue)
        sortedRocks      = defaults.integer(forKey: Key.sortedRocks.rawValue)
        sortedGifts      = defaults.integer(forKey: Key.sortedGifts.rawValue)
        sortedPaperclips = defaults.integer(forKey: Key.sortedPaperclips.rawValue)
        sortedDonuts     = defaults.integer(forKey: Key.sortedDonuts.rawValue)
        sortedBolts      = defaults.integer(forKey: Key.sortedBolts.rawValue)
        sortedBalloons   = defaults.integer(forKey: Key.sortedBalloons.rawValue)
        sortedPoops      = defaults.integer(forKey: Key.sortedPoops.rawValue)
        sortedBombs      = defaults.integer(forKey: Key.sortedBombs.rawValue)
    }

    // MARK: - Session Tracking

    /// Call when a junk/special item exits the jar during gameplay.
    func recordSortedItem(_ type: EmojiType) {
        switch type {
        case .apple:     sessionApples += 1
        case .teddy:     sessionTeddies += 1
        case .shoe:      sessionShoes += 1
        case .rock:      sessionRocks += 1
        case .gift:      sessionGifts += 1
        case .paperclip: sessionPaperclips += 1
        case .donut:     sessionDonuts += 1
        case .bolt:      sessionBolts += 1
        case .balloon:   sessionBalloons += 1
        case .poop:      sessionPoops += 1
        case .bomb:      sessionBombs += 1
        case .crystal:   sessionLostDiamonds += 1
        }
    }

    /// Call when crystals are saved (still in jar at stage clear).
    func recordDiamondsSaved(_ count: Int) {
        sessionDiamonds += count
    }

    /// Reset session accumulators at the start of a new game.
    func beginSession() {
        sessionApples = 0
        sessionTeddies = 0
        sessionShoes = 0
        sessionRocks = 0
        sessionGifts = 0
        sessionPaperclips = 0
        sessionDonuts = 0
        sessionBolts = 0
        sessionBalloons = 0
        sessionPoops = 0
        sessionBombs = 0
        sessionDiamonds = 0
        sessionLostDiamonds = 0
    }

    /// Flush session accumulators to lifetime totals and persist.
    func endSession() {
        totalSessions += 1
        totalDiamonds += sessionDiamonds
        lostDiamonds  += sessionLostDiamonds

        sortedApples     += sessionApples
        sortedTeddies    += sessionTeddies
        sortedShoes      += sessionShoes
        sortedRocks      += sessionRocks
        sortedGifts      += sessionGifts
        sortedPaperclips += sessionPaperclips
        sortedDonuts     += sessionDonuts
        sortedBolts      += sessionBolts
        sortedBalloons   += sessionBalloons
        sortedPoops      += sessionPoops
        sortedBombs      += sessionBombs

        persist()
    }

    // MARK: - Persistence

    private func persist() {
        defaults.set(totalSessions,    forKey: Key.totalSessions.rawValue)
        defaults.set(totalDiamonds,    forKey: Key.totalDiamonds.rawValue)
        defaults.set(lostDiamonds,     forKey: Key.lostDiamonds.rawValue)
        defaults.set(sortedApples,     forKey: Key.sortedApples.rawValue)
        defaults.set(sortedTeddies,    forKey: Key.sortedTeddies.rawValue)
        defaults.set(sortedShoes,      forKey: Key.sortedShoes.rawValue)
        defaults.set(sortedRocks,      forKey: Key.sortedRocks.rawValue)
        defaults.set(sortedGifts,      forKey: Key.sortedGifts.rawValue)
        defaults.set(sortedPaperclips, forKey: Key.sortedPaperclips.rawValue)
        defaults.set(sortedDonuts,     forKey: Key.sortedDonuts.rawValue)
        defaults.set(sortedBolts,      forKey: Key.sortedBolts.rawValue)
        defaults.set(sortedBalloons,   forKey: Key.sortedBalloons.rawValue)
        defaults.set(sortedPoops,      forKey: Key.sortedPoops.rawValue)
        defaults.set(sortedBombs,      forKey: Key.sortedBombs.rawValue)
    }

    /// All item stats as an ordered list for display, excluding zeros.
    var leaderboard: [(emoji: String, name: String, count: Int)] {
        let all: [(String, String, Int)] = [
            ("👟", "Shoes", sortedShoes),
            ("🍎", "Apples", sortedApples),
            ("🧸", "Teddies", sortedTeddies),
            ("🪨", "Rocks", sortedRocks),
            ("🎁", "Gifts", sortedGifts),
            ("📎", "Paperclips", sortedPaperclips),
            ("🍩", "Donuts", sortedDonuts),
            ("🔩", "Bolts", sortedBolts),
            ("🎈", "Balloons", sortedBalloons),
            ("💩", "Poops", sortedPoops),
            ("💣", "Bombs", sortedBombs),
        ]
        return all
            .filter { $0.2 > 0 }
            .sorted { $0.2 > $1.2 }
            .map { (emoji: $0.0, name: $0.1, count: $0.2) }
    }

    /// True when there are any stats to show.
    var hasStats: Bool {
        totalSessions > 0
    }
}
