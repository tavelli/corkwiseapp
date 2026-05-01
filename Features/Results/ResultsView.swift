import SwiftUI

struct ResultsView: View {
    let result: WineScanResult
    let purchaseMode: PurchaseMode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ResultsHeaderView(
                    restaurantName: result.restaurantName,
                    purchaseMode: purchaseMode,
                    recommendationCount: result.recommendations.count
                )

                BestPickHeroView(summary: result.summary, restaurantName: result.restaurantName)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Best Overall Picks")
                        .font(.title2)
                        .bold()

                    ForEach(result.recommendations) { recommendation in
                        RecommendationCardView(recommendation: recommendation)
                    }
                }

                if result.categoryRecommendations.isEmpty == false {
                    CategoryHighlightsView(sections: result.categoryRecommendations)
                }

                if result.notes.isEmpty == false {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes")
                            .font(.title3)
                            .bold()

                        ForEach(result.notes, id: \.self) { note in
                            Label {
                                Text(note)
                                    .foregroundStyle(.secondary)
                            } icon: {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(.rect(cornerRadius: 24))
                }

                #if DEBUG
                if let debugInfo = result.debugInfo {
                    DebugScanInfoView(debugInfo: debugInfo)
                }
                #endif
            }
            .padding()
        }
        .navigationTitle(result.restaurantName ?? "Results")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }

}

#if DEBUG
private struct DebugScanInfoView: View {
    let debugInfo: ScanDebugInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Debug")
                .font(.title3)
                .bold()

            Text("Model: \(debugInfo.model)")
                .font(.subheadline)

            Text("API Time: \(debugInfo.apiDurationMilliseconds) ms")
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 24))
    }
}
#endif

private struct ResultsHeaderView: View {
    let restaurantName: String?
    let purchaseMode: PurchaseMode
    let recommendationCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CorkWise Ranking")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack {
                ResultPill(title: purchaseMode.title)
                ResultPill(title: "\(recommendationCount) Picks")
                if restaurantName != nil {
                    ResultPill(title: "Analyzed")
                }
            }
        }
    }
}

private struct ResultPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.footnote)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.thinMaterial)
            .clipShape(.capsule)
    }
}
