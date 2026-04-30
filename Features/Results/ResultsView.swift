import SwiftUI

struct ResultsView: View {
    let result: WineScanResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ResultsHeaderView(
                    restaurantName: result.restaurantName,
                    purchaseMode: result.purchaseMode,
                    recommendationCount: result.recommendations.count
                )

                BestPickHeroView(summary: result.summary, restaurantName: result.restaurantName)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Ranked Recommendations")
                        .font(.title2)
                        .bold()

                    ForEach(result.recommendations) { recommendation in
                        RecommendationCardView(recommendation: recommendation)
                    }
                }

                if result.recommendations.isEmpty == false {
                    BestOverallHighlightsView(recommendations: Array(result.recommendations.prefix(bestOverallDisplayCount)))
                }

                if secondaryHighlights.isEmpty == false {
                    CategoryHighlightsView(highlights: secondaryHighlights)
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
            }
            .padding()
        }
        .navigationTitle(result.restaurantName ?? "Results")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }

    private var bestOverallDisplayCount: Int {
        min(max(result.recommendations.count, 2), 5)
    }

    private var secondaryHighlights: [CategoryHighlight] {
        result.categoryHighlights.filter { $0.key != "best_overall" }
    }
}

private struct ResultsHeaderView: View {
    let restaurantName: String?
    let purchaseMode: String
    let recommendationCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CorkWise Ranking")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack {
                ResultPill(title: purchaseMode.capitalized)
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

private struct BestOverallHighlightsView: View {
    let recommendations: [WineRecommendation]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Best Overall")
                .font(.title3)
                .bold()

            Text("Top picks from this scan.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(recommendations) { recommendation in
                HStack(alignment: .top, spacing: 12) {
                    Text("#\(recommendation.rank)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(recommendation.wineName)
                            .font(.headline)
                        Text(recommendation.why)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Text(recommendation.valueScore.formatted(.number.precision(.fractionLength(1))))
                        .font(.headline)
                        .foregroundStyle(.green)
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(.rect(cornerRadius: 20))
            }
        }
    }
}
