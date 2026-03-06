//
//  RewardedAdManager.swift
//  sift Shared
//

import GoogleMobileAds
import Combine
import UIKit

/// Manages loading and presenting Google AdMob rewarded ads.
@MainActor
final class RewardedAdManager: NSObject, ObservableObject, FullScreenContentDelegate {

    static let shared = RewardedAdManager()

    /// Test rewarded ad unit ID from Google.
    private let adUnitID = "ca-app-pub-3940256099942544/1712485313"

    /// The loaded rewarded ad, ready to present.
    private var rewardedAd: RewardedAd?

    /// Callback to fire after the ad is dismissed, only if the user earned the reward.
    private var pendingRewardCallback: (() -> Void)?

    /// Whether an ad is loaded and ready to show.
    @Published private(set) var isAdReady = false

    /// Whether an ad is currently loading.
    @Published private(set) var isLoading = false

    private override init() {
        super.init()
        NSLog("[AdMob] RewardedAdManager initialized, preloading ad...")
        loadAd()
    }

    // MARK: - Public API

    /// Pre-load a rewarded ad so it's ready when the user taps "Watch Ad".
    func loadAd() {
        guard !isLoading else {
            NSLog("[AdMob] Already loading, skipping duplicate request")
            return
        }
        isLoading = true
        NSLog("[AdMob] Loading rewarded ad (unit: %@)...", adUnitID)

        Task {
            do {
                let ad = try await RewardedAd.load(
                    with: adUnitID,
                    request: Request()
                )
                self.rewardedAd = ad
                ad.fullScreenContentDelegate = self
                self.isAdReady = true
                self.isLoading = false
                NSLog("[AdMob] Rewarded ad loaded successfully")
            } catch {
                NSLog("[AdMob] Failed to load rewarded ad: %@", error.localizedDescription)
                self.rewardedAd = nil
                self.isAdReady = false
                self.isLoading = false
            }
        }
    }

    /// Present the rewarded ad from the given view controller.
    /// If the ad isn't loaded yet, loads one first and then presents it.
    /// Calls `onRewardEarned` when the user earns the reward.
    func showAd(from viewController: UIViewController, onRewardEarned: @escaping () -> Void) {
        NSLog("[AdMob] showAd called — isAdReady: %d, hasAd: %d", isAdReady ? 1 : 0, rewardedAd != nil ? 1 : 0)

        if let rewardedAd {
            presentAd(rewardedAd, from: viewController, onRewardEarned: onRewardEarned)
            return
        }

        // Ad not ready — load and present once ready
        NSLog("[AdMob] Ad not ready, loading on demand...")
        isLoading = true
        Task {
            do {
                let ad = try await RewardedAd.load(
                    with: adUnitID,
                    request: Request()
                )
                ad.fullScreenContentDelegate = self
                self.rewardedAd = ad
                self.isAdReady = true
                self.isLoading = false
                NSLog("[AdMob] On-demand ad loaded, presenting now")
                self.presentAd(ad, from: viewController, onRewardEarned: onRewardEarned)
            } catch {
                NSLog("[AdMob] On-demand ad failed to load: %@", error.localizedDescription)
                self.rewardedAd = nil
                self.isAdReady = false
                self.isLoading = false
            }
        }
    }

    private func presentAd(_ ad: RewardedAd, from viewController: UIViewController, onRewardEarned: @escaping () -> Void) {
        NSLog("[AdMob] Presenting rewarded ad...")
        pendingRewardCallback = nil
        ad.present(from: viewController) { [weak self] in
            NSLog("[AdMob] User earned reward")
            self?.pendingRewardCallback = onRewardEarned
        }
    }

    // MARK: - FullScreenContentDelegate

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        NSLog("[AdMob] Ad dismissed")
        Task { @MainActor in
            let callback = self.pendingRewardCallback
            self.pendingRewardCallback = nil
            self.rewardedAd = nil
            self.isAdReady = false
            callback?()
            self.loadAd()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        NSLog("[AdMob] Failed to present ad: %@", error.localizedDescription)
        Task { @MainActor in
            self.rewardedAd = nil
            self.isAdReady = false
            self.loadAd()
        }
    }
}
