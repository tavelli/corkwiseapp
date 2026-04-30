import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var navigationPath: [AppDestination] = []

    func showResults(_ result: WineScanResult) {
        navigationPath.append(.results(result))
    }

    func resetMainNavigation() {
        navigationPath.removeAll()
    }
}
