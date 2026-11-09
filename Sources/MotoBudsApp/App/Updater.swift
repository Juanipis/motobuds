import Foundation
import Sparkle
import SwiftUI

/// Wraps Sparkle's `SPUStandardUpdaterController` so SwiftUI can drive it.
/// The controller hosts the singleton updater; the published flags below
/// let SwiftUI views enable/disable the "Check for Updates…" button while
/// a check is in flight.
@MainActor
final class Updater: NSObject, ObservableObject {

    @Published var canCheck: Bool = true

    let controller: SPUStandardUpdaterController
    private let proxy = UpdaterDelegateProxy()

    override init() {
        self.controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: proxy,
            userDriverDelegate: nil
        )
        super.init()
        proxy.owner = self
        controller.updater.automaticallyChecksForUpdates = true
        controller.updater.automaticallyDownloadsUpdates  = false
        controller.updater.updateCheckInterval = 60 * 60 * 24    // once a day
    }

    func checkNow() {
        controller.checkForUpdates(nil)
    }
}

/// Sparkle's delegate API is `@objc`-typed and synchronous; we route it to
/// the @MainActor `Updater` through a thin proxy so we don't fight strict
/// concurrency with every callback.
final class UpdaterDelegateProxy: NSObject, SPUUpdaterDelegate {
    weak var owner: Updater?

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        Task { @MainActor in self.owner?.canCheck = true }
    }

    func updaterWillCheck(forUpdates updater: SPUUpdater) {
        Task { @MainActor in self.owner?.canCheck = false }
    }
}
