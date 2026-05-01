import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var navigationPath: [AppDestination] = []

    func showResults(_ result: WineScanResult, purchaseMode: PurchaseMode, viewedAt: Date = .now) {
        navigationPath.append(.results(result, purchaseMode, viewedAt))
    }

    func showPreferences() {
        navigationPath.append(.preferences)
    }

    func showAllScans() {
        navigationPath.append(.allScans)
    }

    func resetMainNavigation() {
        navigationPath.removeAll()
    }
}
