//
//  SoundEffects.swift
//  fizz Shared
//

import Foundation
import AVFoundation
import CoreGraphics
import QuartzCore

final class SoundEffects: NSObject, AVAudioPlayerDelegate {

    private enum SoundKey: Hashable {
        case menuClick
        case crystalTap      // crystal-on-crystal: delicate gem clink
        case crystalGlass    // crystal-on-wall: soft glassy thud
        case roundCleared
        case gameOver
        case scoreCounter
    }

    static let shared = SoundEffects()

    /// Dedicated serial queue so AVAudioPlayer.play() never blocks the main/render thread.
    private let audioQueue = DispatchQueue(label: "com.sift.soundEffects", qos: .userInteractive)

    private let menuClickData: Data
    private let crystalTapData: Data
    private let crystalGlassData: Data
    private let roundClearedData: Data
    private let gameOverData: Data
    private let scoreCounterData: Data

    private var playerPools: [SoundKey: [AVAudioPlayer]] = [:]
    private var scoreCounterLoopPlayer: AVAudioPlayer?
    private var lastMenuClickTime: CFTimeInterval = 0
    private var lastCrystalTapTime: CFTimeInterval = 0
    private var lastCrystalGlassTime: CFTimeInterval = 0

    private override init() {
        menuClickData = SoundEffects.makeMenuClickWAV()
        crystalTapData = SoundEffects.makeCrystalTapWAV()
        crystalGlassData = SoundEffects.makeCrystalGlassWAV()
        roundClearedData = SoundEffects.loadBundleWAV(named: "lvl_completed")
        gameOverData = SoundEffects.loadBundleWAV(named: "game_over")
        scoreCounterData = SoundEffects.makeScoreCounterWAV()
        super.init()
        configurePlayerPools()
    }

    // MARK: - AVAudioPlayerDelegate

    /// Re-prepare the player as soon as it finishes so the next play() starts instantly.
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        player.prepareToPlay()
    }

    func playMenuClick() {
        let now = CACurrentMediaTime()
        guard now - lastMenuClickTime > 0.05 else { return }
        lastMenuClickTime = now
        play(.menuClick, volume: 0.28, allowSteal: false)
    }

    /// Crystal-on-crystal: a delicate, bright gem clink.
    func playCrystalTap(impulse: CGFloat) {
        guard impulse > 1.8 else { return }

        let now = CACurrentMediaTime()
        guard now - lastCrystalTapTime > 0.10 else { return }
        lastCrystalTapTime = now

        let normalized = min(max(Float(impulse) / 14.0, 0.0), 1.0)
        let volume = 0.04 + (normalized * 0.10)
        play(.crystalTap, volume: volume, allowSteal: true)
    }

    /// Crystal-on-glass/wall: a soft, muted glassy settle.
    func playCrystalGlass(impulse: CGFloat) {
        guard impulse > 2.0 else { return }

        let now = CACurrentMediaTime()
        guard now - lastCrystalGlassTime > 0.10 else { return }
        lastCrystalGlassTime = now

        let normalized = min(max(Float(impulse) / 14.0, 0.0), 1.0)
        let volume = 0.05 + (normalized * 0.09)
        play(.crystalGlass, volume: volume, allowSteal: true)
    }

    func playRoundCleared() {
        play(.roundCleared, volume: 0.30, allowSteal: false)
    }

    func playGameOver() {
        play(.gameOver, volume: 0.40, allowSteal: false)
    }

    func startScoreCounterLoop() {
        audioQueue.async { [weak self] in
            guard let player = self?.scoreCounterLoopPlayer else { return }
            guard !player.isPlaying else { return }
            player.currentTime = 0
            player.volume = 0.14
            player.play()
        }
    }

    func stopScoreCounterLoop() {
        audioQueue.async { [weak self] in
            guard let player = self?.scoreCounterLoopPlayer else { return }
            guard player.isPlaying else { return }
            player.stop()
            player.currentTime = 0
            player.prepareToPlay()
        }
    }

    private func configurePlayerPools() {
        playerPools[.menuClick] = makePool(data: menuClickData, voices: 2)
        playerPools[.crystalTap] = makePool(data: crystalTapData, voices: 3)
        playerPools[.crystalGlass] = makePool(data: crystalGlassData, voices: 3)
        playerPools[.roundCleared] = makePool(data: roundClearedData, voices: 1)
        playerPools[.gameOver] = makePool(data: gameOverData, voices: 1)
        scoreCounterLoopPlayer = makeLoopingPlayer(data: scoreCounterData)
    }

    private func makePool(data: Data, voices: Int) -> [AVAudioPlayer] {
        var players: [AVAudioPlayer] = []
        players.reserveCapacity(voices)
        for _ in 0..<voices {
            guard let player = try? AVAudioPlayer(data: data) else { continue }
            player.numberOfLoops = 0
            player.delegate = self
            player.prepareToPlay()
            players.append(player)
        }
        return players
    }

    private func makeLoopingPlayer(data: Data) -> AVAudioPlayer? {
        guard let player = try? AVAudioPlayer(data: data) else { return nil }
        player.numberOfLoops = -1
        player.prepareToPlay()
        return player
    }

    private func play(_ key: SoundKey, volume: Float, allowSteal: Bool) {
        guard let pool = playerPools[key], !pool.isEmpty else { return }

        audioQueue.async {
            if let idleIndex = pool.firstIndex(where: { !$0.isPlaying }) {
                let player = pool[idleIndex]
                player.volume = volume
                player.currentTime = 0
                player.play()
                return
            }

            guard allowSteal else { return }
            let player = pool[0]
            player.stop()
            player.currentTime = 0
            player.volume = volume
            player.play()
        }
    }

    private static func makeMenuClickWAV() -> Data {
        let sampleRate = 44_100
        let duration = 0.06
        let sampleCount = Int(Double(sampleRate) * duration)

        var samples = [Float](repeating: 0, count: sampleCount)
        for i in 0..<sampleCount {
            let t = Double(i) / Double(sampleRate)
            // Soft attack so it doesn't pop, gentle decay
            let attack = min(t * 200.0, 1.0)
            let envelope = Float(attack * exp(-t * 34.0))
            // Lower, rounder tone — a gentle "pop"
            let primary = sin(2.0 * Double.pi * 780.0 * t)
            let warmth = 0.30 * sin(2.0 * Double.pi * 520.0 * t)
            let air = 0.12 * sin(2.0 * Double.pi * 1_400.0 * t)
            samples[i] = Float((primary + warmth + air) * 0.18) * envelope
        }

        return makeWAV(from: samples, sampleRate: sampleRate)
    }

    /// Crystal-on-crystal: very short, bright, delicate gem clink — like two small stones kissing.
    private static func makeCrystalTapWAV() -> Data {
        let sampleRate = 44_100
        let duration = 0.09
        let sampleCount = Int(Double(sampleRate) * duration)

        var samples = [Float](repeating: 0, count: sampleCount)
        for i in 0..<sampleCount {
            let t = Double(i) / Double(sampleRate)
            // Instant attack, very fast decay — a tiny "tick"
            let envelope = Float(exp(-t * 38.0))

            // High, thin partials — bright but quiet
            let ping = sin(2.0 * Double.pi * 3_800.0 * t)
            let harmonic = 0.30 * sin(2.0 * Double.pi * 5_200.0 * t)
            let sub = 0.15 * sin(2.0 * Double.pi * 2_400.0 * t)

            let signal = Float((ping + harmonic + sub) * 0.12)
            samples[i] = signal * envelope
        }

        return makeWAV(from: samples, sampleRate: sampleRate)
    }

    /// Crystal-on-glass: a softer, rounder thud with a subtle glassy ring — like a gem settling in a jar.
    private static func makeCrystalGlassWAV() -> Data {
        let sampleRate = 44_100
        let duration = 0.12
        let sampleCount = Int(Double(sampleRate) * duration)

        var samples = [Float](repeating: 0, count: sampleCount)
        for i in 0..<sampleCount {
            let t = Double(i) / Double(sampleRate)
            // Soft attack, moderate decay — muted and warm
            let attack = min(t * 120.0, 1.0)
            let envelope = Float(attack * exp(-t * 24.0))

            // Lower fundamental with a gentle glass overtone
            let thud = sin(2.0 * Double.pi * 1_200.0 * t)
            let glass = 0.20 * sin(2.0 * Double.pi * 2_800.0 * t)
            let warmth = 0.25 * sin(2.0 * Double.pi * 680.0 * t)

            let signal = Float((thud + glass + warmth) * 0.10)
            samples[i] = signal * envelope
        }

        return makeWAV(from: samples, sampleRate: sampleRate)
    }

    private static func loadBundleWAV(named name: String) -> Data {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("Missing sound file: \(name).wav")
            return Data()
        }
        return data
    }

    private static func makeScoreCounterWAV() -> Data {
        let sampleRate = 44_100
        let duration = 0.045
        let sampleCount = Int(Double(sampleRate) * duration)

        var samples = [Float](repeating: 0, count: sampleCount)
        for i in 0..<sampleCount {
            let t = Double(i) / Double(sampleRate)
            let attack = min(t * 180.0, 1.0)
            let decay = exp(-t * 55.0)
            let envelope = Float(attack * decay)

            let sweepFreq = 2_000.0 - (t / duration) * 700.0
            let tone = sin(2.0 * Double.pi * sweepFreq * t)
            let click = 0.35 * sin(2.0 * Double.pi * 2_850.0 * t)

            samples[i] = Float((tone + click) * 0.18) * envelope
        }

        return makeWAV(from: samples, sampleRate: sampleRate)
    }

    private static func makeWAV(from samples: [Float], sampleRate: Int) -> Data {
        let dataSize = samples.count * 2
        let fileSize = 44 + dataSize
        var wavData = Data(capacity: fileSize)

        func appendUInt32LE(_ value: UInt32) {
            wavData.append(contentsOf: withUnsafeBytes(of: value.littleEndian) { Array($0) })
        }

        func appendUInt16LE(_ value: UInt16) {
            wavData.append(contentsOf: withUnsafeBytes(of: value.littleEndian) { Array($0) })
        }

        wavData.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
        appendUInt32LE(UInt32(fileSize - 8))
        wavData.append(contentsOf: [0x57, 0x41, 0x56, 0x45])
        wavData.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
        appendUInt32LE(16)
        appendUInt16LE(1)
        appendUInt16LE(1)
        appendUInt32LE(UInt32(sampleRate))
        appendUInt32LE(UInt32(sampleRate) * 2)
        appendUInt16LE(2)
        appendUInt16LE(16)
        wavData.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
        appendUInt32LE(UInt32(dataSize))

        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let intSample = Int16(clamped * Float(Int16.max))
            appendUInt16LE(UInt16(bitPattern: intSample))
        }

        return wavData
    }
}
