import SwiftUI

struct CategoryHighlightsView: View {
    let sections: [RecommendationCategorySection]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(displaySections, id: \.key) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.secondary)
                            Text(section.displayTitle)
                                .font(.title3)
                                .bold()
                        }

                        ForEach(section.recommendations) { recommendation in
                            RecommendationCardView(recommendation: recommendation)
                        }
                    }
                }
            }
        }
    }

    private var displaySections: [DisplayCategorySection] {
        let canonicalKeys = [
            "best_value",
            "best_splurge",
            "safest_choice",
            "most_interesting_pick",
        ]

        let mappedSections = sections.map { section in
            DisplayCategorySection(
                key: section.key,
                displayTitle: Self.displayTitle(for: section),
                recommendations: Array(section.recommendations.prefix(2))
            )
        }

        let canonicalMatches = canonicalKeys.compactMap { key in
            mappedSections.first { $0.key == key }
        }

        let fallbackSections = mappedSections.filter { section in
            canonicalKeys.contains(section.key) == false
        }

        return canonicalMatches + fallbackSections
    }

    private static func displayTitle(for section: RecommendationCategorySection) -> String {
        switch section.key {
        case "best_value":
            return "Best Value"
        case "best_splurge":
            return "Best Splurge"
        case "safest_choice":
            return "Safest Choice"
        case "most_interesting_pick":
            return "Most Interesting Pick"
        default:
            return section.title
        }
    }
}

private struct DisplayCategorySection: Hashable {
    let key: String
    let displayTitle: String
    let recommendations: [WineRecommendation]
}
