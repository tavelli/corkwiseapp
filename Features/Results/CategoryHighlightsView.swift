import SwiftUI

struct CategoryHighlightsView: View {
    let sections: [RecommendationCategorySection]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(displaySections, id: \.key) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        ResultSectionHeader(
                            title: section.displayTitle,
                            systemImage: section.systemImage,
                            style: .ribbon
                        )

                        ForEach(section.recommendations) { recommendation in
                            RecommendationCardView(recommendation: recommendation)
                        }
                    }
                    .padding(.top, 14)
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
                systemImage: Self.systemImage(for: section.key),
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

    private static func systemImage(for key: String) -> String {
        switch key {
        case "best_value":
            return "tag.fill"
        case "best_splurge":
            return "crown.fill"
        case "safest_choice":
            return "checkmark.shield.fill"
        case "most_interesting_pick":
            return "sparkles"
        default:
            return "star.circle.fill"
        }
    }
}

private struct DisplayCategorySection: Hashable {
    let key: String
    let displayTitle: String
    let systemImage: String
    let recommendations: [WineRecommendation]
}
