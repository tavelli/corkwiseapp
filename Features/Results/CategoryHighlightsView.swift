import SwiftUI

struct CategoryHighlightsView: View {
    let highlights: [CategoryHighlight]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Other Categories")
                .font(.title3)
                .bold()

            VStack(alignment: .leading, spacing: 10) {
                ForEach(displayHighlights, id: \.key) { highlight in
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(highlight.displayTitle)
                                .font(.headline)
                            Text("Recommendation #\(highlight.wineRank)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(.rect(cornerRadius: 20))
                }
            }
        }
    }

    private var displayHighlights: [DisplayHighlight] {
        let canonicalKeys = [
            "best_value",
            "best_splurge",
            "safest_choice",
            "most_interesting_pick",
        ]

        let mappedHighlights = highlights.map { highlight in
            DisplayHighlight(
                key: highlight.key,
                displayTitle: Self.displayTitle(for: highlight),
                wineRank: highlight.wineRank
            )
        }

        let canonicalMatches = canonicalKeys.compactMap { key in
            mappedHighlights.first { $0.key == key }
        }

        let fallbackHighlights = mappedHighlights.filter { highlight in
            canonicalKeys.contains(highlight.key) == false
        }

        return canonicalMatches + fallbackHighlights
    }

    private static func displayTitle(for highlight: CategoryHighlight) -> String {
        switch highlight.key {
        case "best_overall":
            return "Best Overall"
        case "best_value":
            return "Best Value"
        case "best_splurge":
            return "Best Splurge"
        case "safest_choice":
            return "Safest Choice"
        case "most_interesting_pick":
            return "Most Interesting Pick"
        default:
            return highlight.title
        }
    }
}

private struct DisplayHighlight: Hashable {
    let key: String
    let displayTitle: String
    let wineRank: Int
}
