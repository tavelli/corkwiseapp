import SwiftData
import SwiftUI

struct AllScansView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \WineScan.createdAt, order: .reverse) private var scans: [WineScan]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if scans.isEmpty {
                    Text(.historyEmptyAll)
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
        .navigationTitle(String(localized: .historyAllTitle))
        .navigationBarTitleDisplayMode(.inline)
        .background(mainScreenBackground.ignoresSafeArea())
    }

    private func openScan(_ scan: WineScan) {
        guard let data = scan.resultJSON.data(using: .utf8) else { return }
        let decoder = JSONDecoder()

        guard let result = try? decoder.decode(WineScanResult.self, from: data) else { return }
        appState.showResults(
            result,
            purchaseMode: scan.purchaseModeValue,
            categoryPreference: scan.categoryPreferenceValue,
            viewedAt: scan.createdAt
        )
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserWinePreferences.self, WineScan.self, configurations: configuration)
    let context = ModelContext(container)
    let preferences = UserWinePreferences(
        preferredStyles: [WineStylePreference.crispRefreshing.rawValue],
        favoriteVarietals: [
            WineVarietal.prosecco.rawValue,
            WineVarietal.pinotNoir.rawValue,
        ],
        choiceStyle: ChoiceStyle.bestValue.rawValue,
        usualPurchasePreference: UsualPurchasePreference.bottle.rawValue,
        hasCompletedOnboarding: true
    )
    context.insert(preferences)

    let sampleResult = WineScanResult.sample(for: .glass, preferences: preferences)
    let sampleData = try! JSONEncoder().encode(sampleResult)
    let sampleJSON = String(data: sampleData, encoding: .utf8)!

    context.insert(
        WineScan(
            createdAt: .now.addingTimeInterval(-3_600),
            restaurantName: "Max's",
            purchaseMode: PurchaseMode.glass.rawValue,
            summaryHeadline: sampleResult.summary.headline,
            resultJSON: sampleJSON
        )
    )

    context.insert(
        WineScan(
            createdAt: .now.addingTimeInterval(-9_400),
            restaurantName: "June Wine Bar",
            purchaseMode: PurchaseMode.bottle.rawValue,
            bottleContext: BottleContext.forGroup.rawValue,
            summaryHeadline: sampleResult.summary.headline,
            resultJSON: sampleJSON
        )
    )

    context.insert(
        WineScan(
            createdAt: .now.addingTimeInterval(-18_800),
            restaurantName: nil,
            purchaseMode: PurchaseMode.glass.rawValue,
            summaryHeadline: sampleResult.summary.headline,
            resultJSON: sampleJSON
        )
    )

    try! context.save()

    return AllScansView()
        .environment(AppState())
        .modelContainer(container)
}
