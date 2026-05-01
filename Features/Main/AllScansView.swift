import SwiftData
import SwiftUI

struct AllScansView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \WineScan.createdAt, order: .reverse) private var scans: [WineScan]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if scans.isEmpty {
                    Text("No scans yet. Your scan history will appear here once you analyze a wine list.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.9))
                        .clipShape(.rect(cornerRadius: 20))
                } else {
                    ForEach(scans) { scan in
                        ScanHistoryCard(scan: scan) {
                            openScan(scan)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("All Scans")
        .navigationBarTitleDisplayMode(.inline)
        .background(mainScreenBackground.ignoresSafeArea())
    }

    private func openScan(_ scan: WineScan) {
        guard let data = scan.resultJSON.data(using: .utf8) else { return }
        let decoder = JSONDecoder()

        guard let result = try? decoder.decode(WineScanResult.self, from: data) else { return }
        appState.showResults(result, purchaseMode: scan.purchaseModeValue, viewedAt: scan.createdAt)
    }
}

#Preview {
    AllScansView()
        .environment(AppState())
        .modelContainer(for: [UserWinePreferences.self, WineScan.self], inMemory: true)
}
