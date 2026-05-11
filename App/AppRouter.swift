import SwiftData
import SwiftUI

struct AppRouter: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementManager.self) private var entitlementManager
    @Query(sort: \UserWinePreferences.createdAt) private var preferenceRecords: [UserWinePreferences]

    private var currentRoute: AppRoute {
        guard let preferences = preferenceRecords.first, preferences.hasCompletedOnboarding else {
            return .onboarding
        }

        if entitlementManager.isConfigured, entitlementManager.hasActiveEntitlement == false {
            return .paywall
        }

        return .main
    }

    var body: some View {
        @Bindable var bindableAppState = appState

        NavigationStack(path: $bindableAppState.navigationPath) {
            Group {
                if entitlementManager.isLoading {
                    ProgressView("Checking access…")
                } else {
                    switch currentRoute {
                    case .onboarding:
                        OnboardingView(existingPreferences: preferenceRecords.first)
                    case .paywall:
                        PaywallView(preferences: preferenceRecords.first)
                    case .main:
                        MainView(preferences: preferenceRecords.first)
                    }
                }
            }
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .results(let result, let purchaseMode, let viewedAt):
                    ResultsView(result: result, purchaseMode: purchaseMode, viewedAt: viewedAt)
                case .scanProgress(let id):
                    ScanProgressResultsView(scanID: id)
                case .preferences:
                    PreferencesView()
                case .allScans:
                    AllScansView()
                }
            }
        }
        .task {
            await entitlementManager.configure()
        }
    }
}

#Preview {
    AppRouter()
        .environment(AppState())
        .environment(EntitlementManager())
        .modelContainer(for: [UserWinePreferences.self, WineScan.self], inMemory: true)
}
