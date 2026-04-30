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
                    Text("\(recommendation.rank)")
                        .bold()
                        .foregroundStyle(scoreTint)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(recommendation.wineName)
                        .font(.title3)
                        .bold()

                    Text("Value Score \(recommendation.valueScore.formatted(.number.precision(.fractionLength(1))))")
                        .font(.headline)
                        .foregroundStyle(scoreTint)
                }
            }

            RecommendationMetricRow(
                menuPriceDisplay: recommendation.menuPriceDisplay,
                estimatedRetailDisplay: recommendation.estimatedRetailDisplay,
                estimatedMarkupDisplay: recommendation.estimatedMarkupDisplay,
                estimatedMarkupLow: recommendation.estimatedMarkupLow,
                estimatedMarkupHigh: recommendation.estimatedMarkupHigh
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Why It Stands Out")
                    .font(.headline)
                Text(recommendation.why)
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Fit For You")
                    .font(.headline)
                Text(recommendation.fitForUser)
                    .foregroundStyle(.secondary)
            }

            WineTagStrip(tags: recommendation.styleTags + recommendation.categoryTags)
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
    let menuPriceDisplay: String?
    let estimatedRetailDisplay: String?
    let estimatedMarkupDisplay: String?
    let estimatedMarkupLow: Double?
    let estimatedMarkupHigh: Double?

    var body: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], alignment: .leading, spacing: 12) {
            if let menuPriceDisplay {
                MetricBlock(title: "Menu", value: normalizedCurrencyDisplay(menuPriceDisplay))
            }
            if let estimatedRetailDisplay {
                MetricBlock(title: "Est. Retail", value: normalizedCurrencyDisplay(estimatedRetailDisplay))
            }
            if let estimatedMarkupValue = normalizedMarkupDisplay {
                MetricBlock(title: "Est. Markup", value: estimatedMarkupValue)
            }
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

    private func normalizedCurrencyDisplay(_ value: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedValue.hasPrefix("$") || trimmedValue.hasPrefix("~$") {
            return trimmedValue
        }

        if trimmedValue.hasPrefix("~") {
            let remainder = trimmedValue.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
            return "~$\(remainder)"
        }

        return "$\(trimmedValue)"
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

private struct WineTagStrip: View {
    let tags: [String]

    var body: some View {
        if tags.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.tint.opacity(0.14))
                            .clipShape(.capsule)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}
