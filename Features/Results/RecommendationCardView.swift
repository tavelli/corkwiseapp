import SwiftUI

struct RecommendationCardView: View {
    let recommendation: WineRecommendation
    let purchaseMode: PurchaseMode
    let currencyCode: String
    var categoryLabel: String?
    var categorySystemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: categoryLabel == nil ? 14 : 16) {
            if let categoryLabel, let categorySystemImage {
                HStack(spacing: 8) {
                    Image(systemName: categorySystemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.wineAccent)
                        .frame(width: 18, height: 18)

                    Text(categoryLabel.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(Color.wineAccent)
                }
            }

            HStack(alignment: .center, spacing: 14) {
                Text(recommendation.valueScore.formatted(.number.precision(.fractionLength(1))))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.resultScoreText)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(scoreBackground)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(recommendation.displayTitle)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(Color.wineText)

                    if let displayProducer = recommendation.displayProducer {
                        Text(displayProducer)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.wineMutedText)
                    }
                }
            }

            RecommendationMetricRow(
                menuPrice: recommendation.menuPrice,
                menuPriceUnit: recommendation.menuPriceUnit,
                estimatedRetail: recommendation.estimatedRetail,
                purchaseMode: purchaseMode,
                currencyCode: currencyCode
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(recommendation.why)
                    .font(.subheadline)
                    .foregroundStyle(Color.wineText)
                    .lineSpacing(2)
            }

            WineDataTagRow(tags: wineDataTags)
        }
        .padding(20)
        .background(Color.resultCardBackground)
        .clipShape(.rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.wineBorder.opacity(0.8), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 12, y: 6)
    }

    private var scoreBackground: Color {
        switch recommendation.valueScore {
        case 9.0...:
            return .resultScoreTopTier
        case 8.5..<9.0:
            return .resultScoreUpperMid
        case 8.0..<8.5:
            return .resultScoreMid
        default:
            return .resultScoreLow
        }
    }

    private var wineDataTags: [String] {
        [
            recommendation.varietal?.trimmedNonEmpty,
            recommendation.region?.trimmedNonEmpty,
            recommendation.vintage.map(String.init),
        ].compactMap { $0 }
    }
}

struct RecommendationMetricRow: View {
    enum Style {
        case standard
        case hero
    }

    let menuPrice: Double?
    let menuPriceUnit: PurchaseMode?
    let estimatedRetail: Double?
    let purchaseMode: PurchaseMode
    let currencyCode: String
    var style: Style = .standard

    var body: some View {
        HStack(spacing: 0) {
            ForEach(metrics, id: \.title) { metric in
                MetricItem(title: metric.title, value: metric.value, style: style)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        .clipShape(.rect(cornerRadius: style == .hero ? 16 : 0))
    }

    private var metrics: [Metric] {
        [
            formattedMenuPrice.map { Metric(title: String(localized: .resultsMetricMenu), value: $0) },
            formattedRetailBottle.map { Metric(title: String(localized: .resultsMetricRetailBottle), value: $0) },
            formattedMarkup.map { Metric(title: String(localized: .resultsMetricMarkup), value: $0) },
        ].compactMap { $0 }
    }

    private var formattedMenuPrice: String? {
        guard let menuPrice else { return nil }
        return currency(menuPrice)
    }

    private var formattedRetailBottle: String? {
        guard let estimatedRetail else { return nil }
        return "~\(currency(estimatedRetail))"
    }

    private var formattedMarkup: String? {
        guard
            let menuPrice,
            let estimatedRetail,
            menuPrice > 0,
            estimatedRetail > 0
        else {
            return nil
        }

        let effectiveMenuPriceUnit = menuPriceUnit ?? purchaseMode
        let costBasis = effectiveMenuPriceUnit == .glass ? estimatedRetail / 5 : estimatedRetail
        guard costBasis > 0 else { return nil }

        let markup = menuPrice / costBasis
        let formattedMarkup = markup.formatted(.number.precision(.fractionLength(1)))
        return "~\(formattedMarkup)x"
    }

    private func currency(_ value: Double) -> String {
        let roundedValue = value.rounded()
        let isWholeNumber = abs(value - roundedValue) < 0.05
        let precision = isWholeNumber ? 0 : 1
        return value.formatted(.currency(code: currencyCode).precision(.fractionLength(precision)))
    }

    private var backgroundColor: Color {
        switch style {
        case .standard:
            return .clear
        case .hero:
            return Color.white.opacity(0.0)
        }
    }
}

private struct Metric: Hashable {
    let title: String
    let value: String
}

private struct MetricItem: View {
    let title: String
    let value: String
    let style: RecommendationMetricRow.Style

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(size: valueFontSize, weight: .semibold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title.uppercased())
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(titleColor)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .layoutPriority(1)
    }

    private var valueColor: Color {
        switch style {
        case .standard:
            return .wineText
        case .hero:
            return Color.white.opacity(0.96)
        }
    }

    private var valueFontSize: CGFloat {
        switch style {
        case .standard:
            return 18
        case .hero:
            return 20
        }
    }

    private var titleColor: Color {
        switch style {
        case .standard:
            return .secondary
        case .hero:
            return Color.resultHeroIvory.opacity(0.82)
        }
    }
}

struct WineDataTagRow: View {
    enum Style {
        case standard
        case hero
    }

    let tags: [String]
    var style: Style = .standard

    var body: some View {
        if tags.isEmpty == false {
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(foregroundColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(backgroundColor)
                        .clipShape(.capsule)
                }
            }
            .padding(.top, 2)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .standard:
            return .wineText
        case .hero:
            return Color.white.opacity(0.94)
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .standard:
            return Color.wineSoftPeach.opacity(0.18)
        case .hero:
            return Color.resultHeroIvory.opacity(0.16)
        }
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat) {
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let rows = rows(for: subviews, proposal: proposal)
        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var y = bounds.minY

        for row in rows(for: subviews, proposal: ProposedViewSize(width: bounds.width, height: proposal.height)) {
            var x = bounds.minX

            for item in row.items {
                item.subview.place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }

            y += row.height + spacing
        }
    }

    private func rows(for subviews: Subviews, proposal: ProposedViewSize) -> [FlowRow] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [FlowRow] = []
        var currentItems: [FlowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width

            if nextWidth > maxWidth, currentItems.isEmpty == false {
                rows.append(FlowRow(items: currentItems, width: currentWidth, height: currentHeight))
                currentItems = [FlowItem(subview: subview, size: size)]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentItems.append(FlowItem(subview: subview, size: size))
                currentWidth = nextWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if currentItems.isEmpty == false {
            rows.append(FlowRow(items: currentItems, width: currentWidth, height: currentHeight))
        }

        return rows
    }
}

private struct FlowRow {
    let items: [FlowItem]
    let width: CGFloat
    let height: CGFloat
}

private struct FlowItem {
    let subview: LayoutSubview
    let size: CGSize
}

extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

extension WineRecommendation {
    var displayProducer: String? {
        guard let producer = producer?.trimmedNonEmpty else { return nil }
        return displayTitle.localizedCaseInsensitiveContains(producer) ? nil : producer
    }
}
