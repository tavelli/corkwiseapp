import SwiftUI

struct RecommendationCardView: View {
    let recommendation: WineRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(scoreTint.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Text(recommendation.valueScore.formatted(.number.precision(.fractionLength(1))))
                        .bold()
                        .foregroundStyle(scoreTint)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(recommendation.wineName)
                        .font(.title3)
                        .bold()
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
                    .font(.headline)
                Text(recommendation.why)
                    .foregroundStyle(.primary)
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: 24))
    }

    private var scoreTint: Color {
        switch recommendation.valueScore {
        case 9...:
            return .green
        case 7..<9:
            return .orange
        default:
            return .secondary
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
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], alignment: .leading, spacing: 12) {
            if let menuPriceValue = formattedMenuPrice {
                MetricBlock(title: "Menu", value: menuPriceValue)
            }
            if let estimatedRetailValue = formattedRetailBottle {
                MetricBlock(title: "Retail Bottle", value: estimatedRetailValue)
            }
            if let estimatedMarkupValue = normalizedMarkupDisplay {
                MetricBlock(title: "Est. Markup", value: estimatedMarkupValue)
            }
        }
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
            return "~\(currency(low))-\(currency(high))"
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

            return "~\(low)x-\(high)x"
        }

        if let estimatedMarkupLow {
            let low = estimatedMarkupLow.formatted(.number.precision(.fractionLength(1)))
            return "\(low)x"
        }

        return estimatedMarkupDisplay?
            .replacingOccurrences(of: "%", with: "x")
    }

    private func currency(_ value: Double) -> String {
        let roundedValue = value.rounded()
        let isWholeNumber = abs(value - roundedValue) < 0.05
        let precision = isWholeNumber ? 0 : 1
        return value.formatted(.currency(code: "USD").precision(.fractionLength(precision)))
    }
}

private struct MetricBlock: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
    }
}
