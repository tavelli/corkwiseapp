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
                        PaywallView()
                    case .main:
                        MainView(preferences: preferenceRecords.first)
                    }
                }
            }
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .results(let result, let purchaseMode, let viewedAt):
                    ResultsView(result: result, purchaseMode: purchaseMode, viewedAt: viewedAt)
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
