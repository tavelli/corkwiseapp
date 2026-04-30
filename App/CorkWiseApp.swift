import SwiftData
import SwiftUI

@main
struct CorkWiseApp: App {
    @State private var appState = AppState()
    @State private var entitlementManager = EntitlementManager()

    private var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserWinePreferences.self,
            WineScan.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environment(appState)
                .environment(entitlementManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
