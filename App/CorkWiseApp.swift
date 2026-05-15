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
            rootView
                .environment(appState)
                .environment(entitlementManager)
        }
        .modelContainer(sharedModelContainer)
    }

    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
        if Self.isDemoRecordingEnabled {
            DemoRecordingView()
        } else {
            AppRouter()
        }
        #else
        AppRouter()
        #endif
    }

    #if DEBUG
    private static var isDemoRecordingEnabled: Bool {
        ProcessInfo.processInfo.environment["CORKWISE_DEMO_RECORDING"] == "1"
    }
    #endif
}
