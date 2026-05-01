import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var navigationPath: [AppDestination] = []

    func showResults(_ result: WineScanResult, purchaseMode: PurchaseMode) {
        navigationPath.append(.results(result, purchaseMode))
    }

    func resetMainNavigation() {
        navigationPath.removeAll()
    }
}
