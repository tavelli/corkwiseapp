import SwiftUI

struct CategoryHighlightsView: View {
    let sections: [RecommendationCategorySection]
    let purchaseMode: PurchaseMode
    let currencyCode: String
    var columns: [GridItem] = [GridItem(.flexible(), spacing: 16, alignment: .top)]
    var spacing: CGFloat = 16

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
            ForEach(displaySections, id: \.key) { section in
                ForEach(section.recommendations) { recommendation in
                    RecommendationCardView.categoryCard(
                        recommendation: recommendation,
                        purchaseMode: purchaseMode,
                        currencyCode: currencyCode,
                        categoryLabel: section.displayTitle,
                        icon: section.icon
                    )
                    .id(ResultsScrollTarget.category(key: section.key))
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
                icon: Self.icon(for: section.key),
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
            return String(localized: .resultsCategoryBestValue)
        case "worth_the_splurge":
            return String(localized: .resultsCategoryWorthTheSplurge)
        case "crowd_pleaser":
            return String(localized: .resultsCategoryCrowdPleaser)
        case "hidden_gem":
            return String(localized: .resultsCategoryHiddenGem)
        case "overpriced_here":
            return String(localized: .resultsCategoryOverpricedHere)
        case "try_something_new":
            return String(localized: .resultsCategoryTrySomethingNew)
        default:
            return section.title
        }
    }

    private static func icon(for key: String) -> PhosphorIcon {
        switch key {
        case "best_value":
            return .chartBar
        case "worth_the_splurge":
            return .medal
        case "crowd_pleaser":
            return .sealCheck
        case "hidden_gem":
            return .listMagnifyingGlass
        case "overpriced_here":
            return .warningCircle
        case "try_something_new":
            return .arrowsSplit
        default:
            return .star
        }
    }
}

private struct DisplayCategorySection: Hashable {
    let key: String
    let displayTitle: String
    let icon: PhosphorIcon
    let recommendations: [WineRecommendation]
}
