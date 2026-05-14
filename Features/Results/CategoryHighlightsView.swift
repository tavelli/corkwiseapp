import SwiftUI

struct CategoryHighlightsView: View {
    let sections: [RecommendationCategorySection]
    let purchaseMode: PurchaseMode
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(displaySections, id: \.key) { section in
                ForEach(section.recommendations) { recommendation in
                    RecommendationCardView(
                        recommendation: recommendation,
                        purchaseMode: purchaseMode,
                        currencyCode: currencyCode,
                        categoryLabel: section.displayTitle,
                        categorySystemImage: section.systemImage
                    )
                }
            }
        }
    }

    private var displaySections: [DisplayCategorySection] {
        let canonicalKeys = [
            "best_value",
            "worth_the_splurge",
            "crowd_pleaser",
            "hidden_gem",
            "overpriced_here",
            "try_something_new",
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

        return canonicalMatches
    }

    private static func displayTitle(for section: RecommendationCategorySection) -> String {
        switch section.key {
        case "best_value":
            return String(localized: "Best Value")
        case "worth_the_splurge":
            return String(localized: "Worth the Splurge")
        case "crowd_pleaser":
            return String(localized: "Crowd Pleaser")
        case "hidden_gem":
            return String(localized: "Hidden Gem")
        case "overpriced_here":
            return String(localized: "Overpriced Here")
        case "try_something_new":
            return String(localized: "Try Something New")
        default:
            return section.title
        }
    }

    private static func systemImage(for key: String) -> String {
        switch key {
        case "best_value":
            return "tag.fill"
        case "worth_the_splurge":
            return "crown.fill"
        case "crowd_pleaser":
            return "checkmark.shield.fill"
        case "hidden_gem":
            return "sparkles"
        case "overpriced_here":
            return "exclamationmark.triangle.fill"
        case "try_something_new":
            return "sparkles.square.filled.on.square"
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
