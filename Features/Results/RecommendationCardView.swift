import SwiftUI

struct RecommendationCardView: View {
    let recommendation: WineRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                    Text(recommendation.wineName)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(Color.wineText)
                }
            }

            RecommendationMetricRow(
                menuPrice: recommendation.menuPrice,
                estimatedRetailLow: recommendation.estimatedRetailLow,
                estimatedRetailHigh: recommendation.estimatedRetailHigh,
                estimatedMarkupDisplay: recommendation.estimatedMarkupDisplay,
                estimatedMarkupLow: recommendation.estimatedMarkupLow,
                estimatedMarkupHigh: recommendation.estimatedMarkupHigh
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Why I like it")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.wineAccent)
                Text(recommendation.why)
                    .font(.subheadline)
                    .foregroundStyle(Color.wineText)
                    .lineSpacing(2)
            }
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
}

private struct RecommendationMetricRow: View {
    let menuPrice: Double?
    let estimatedRetailLow: Double?
    let estimatedRetailHigh: Double?
    let estimatedMarkupDisplay: String?
    let estimatedMarkupLow: Double?
    let estimatedMarkupHigh: Double?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(metrics, id: \.title) { metric in
                MetricItem(title: metric.title, value: metric.value)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }

    private var metrics: [Metric] {
        [
            formattedMenuPrice.map { Metric(title: "Menu", value: $0) },
            formattedRetailBottle.map { Metric(title: "Retail Bottle", value: $0) },
            normalizedMarkupDisplay.map { Metric(title: "Markup", value: $0) },
        ].compactMap { $0 }
    }

    private var formattedMenuPrice: String? {
        guard let menuPrice else { return nil }
        return currency(menuPrice)
    }

    private var formattedRetailBottle: String? {
        switch (estimatedRetailLow, estimatedRetailHigh) {
        case let (low?, high?):
            if abs(low - high) < 0.05 {
                return currency(low)
            }
            return "\(currency(low))–\(currency(high))"
        case let (low?, nil):
            return currency(low)
        case let (nil, high?):
            return currency(high)
        default:
            return nil
        }
    }

    private var normalizedMarkupDisplay: String? {
        if let estimatedMarkupLow, let estimatedMarkupHigh {
            let low = estimatedMarkupLow.formatted(.number.precision(.fractionLength(1)))
            let high = estimatedMarkupHigh.formatted(.number.precision(.fractionLength(1)))

            if abs(estimatedMarkupLow - estimatedMarkupHigh) < 0.05 {
                return "\(low)x"
            }

            return "\(low)x–\(high)x"
        }

        if let estimatedMarkupLow {
            let low = estimatedMarkupLow.formatted(.number.precision(.fractionLength(1)))
            return "\(low)x"
        }

        return estimatedMarkupDisplay?
            .replacingOccurrences(of: "-", with: "–")
            .replacingOccurrences(of: "%", with: "x")
    }

    private func currency(_ value: Double) -> String {
        let roundedValue = value.rounded()
        let isWholeNumber = abs(value - roundedValue) < 0.05
        let precision = isWholeNumber ? 0 : 1
        return value.formatted(.currency(code: "USD").precision(.fractionLength(precision)))
    }
}

private struct Metric: Hashable {
    let title: String
    let value: String
}

private struct MetricItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.wineText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title.uppercased())
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .layoutPriority(1)
    }
}
