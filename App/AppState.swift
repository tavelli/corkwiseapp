import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var navigationPath: [AppDestination] = []
    var activeScanPresentation: ScanPresentation?

    func showScanProgress(purchaseMode: PurchaseMode, viewedAt: Date = .now) -> UUID {
        let presentation = ScanPresentation(purchaseMode: purchaseMode, viewedAt: viewedAt)
        activeScanPresentation = presentation
        navigationPath.append(.scanProgress(presentation.id))
        return presentation.id
    }

    func completeScanProgress(id: UUID, result: WineScanResult) {
        guard activeScanPresentation?.id == id else { return }
        activeScanPresentation?.result = result
    }

    func dismissScanProgress(id: UUID) {
        guard activeScanPresentation?.id == id else { return }

        if navigationPath.last == .scanProgress(id) {
            navigationPath.removeLast()
        }

        activeScanPresentation = nil
    }

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

@MainActor
@Observable
final class ScanPresentation {
    let id: UUID
    let purchaseMode: PurchaseMode
    let viewedAt: Date
    var result: WineScanResult?

    init(id: UUID = UUID(), purchaseMode: PurchaseMode, viewedAt: Date) {
        self.id = id
        self.purchaseMode = purchaseMode
        self.viewedAt = viewedAt
    }
}
