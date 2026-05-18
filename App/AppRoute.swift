import Foundation

enum AppRoute {
    case onboarding
    case main
}

enum AppDestination: Hashable {
    case results(WineScanResult, PurchaseMode, WineCategoryPreference, Date)
    case scanProgress(UUID)
    case preferences
    case allScans
}
