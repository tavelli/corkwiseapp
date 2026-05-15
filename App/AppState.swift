import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var navigationPath: [AppDestination] = []
    var activeScanPresentation: ScanPresentation?

    func showScanProgress(
        purchaseMode: PurchaseMode,
        categoryPreference: WineCategoryPreference,
        viewedAt: Date = .now,
        cancellationHandler: (() -> Void)? = nil
    ) -> UUID {
        let presentation = ScanPresentation(
            purchaseMode: purchaseMode,
            categoryPreference: categoryPreference,
            viewedAt: viewedAt,
            cancellationHandler: cancellationHandler
        )
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

    func cancelScanProgress(id: UUID) {
        guard activeScanPresentation?.id == id else { return }
        activeScanPresentation?.cancellationHandler?()
        dismissScanProgress(id: id)
    }

    func showResults(
        _ result: WineScanResult,
        purchaseMode: PurchaseMode,
        categoryPreference: WineCategoryPreference,
        viewedAt: Date = .now
    ) {
        navigationPath.append(.results(result, purchaseMode, categoryPreference, viewedAt))
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
    let categoryPreference: WineCategoryPreference
    let viewedAt: Date
    let cancellationHandler: (() -> Void)?
    var result: WineScanResult?

    init(
        id: UUID = UUID(),
        purchaseMode: PurchaseMode,
        categoryPreference: WineCategoryPreference,
        viewedAt: Date,
        cancellationHandler: (() -> Void)? = nil
    ) {
        self.id = id
        self.purchaseMode = purchaseMode
        self.categoryPreference = categoryPreference
        self.viewedAt = viewedAt
        self.cancellationHandler = cancellationHandler
    }
}
