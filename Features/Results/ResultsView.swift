import SwiftUI

struct ResultsView: View {
    let result: WineScanResult
    let purchaseMode: PurchaseMode
    let viewedAt: Date

    private var pageTitle: String {
        let restaurantName = result.restaurantName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = if let restaurantName, restaurantName.isEmpty == false {
            restaurantName
        } else {
            "Wine List"
        }
        let formattedDate = viewedAt.formatted(date: .abbreviated, time: .omitted)

        return "\(displayName) - \(formattedDate) "
    }

    var body: some View {
        ResultsContentView(result: result, purchaseMode: purchaseMode)
            .navigationTitle(pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .background(mainScreenBackground.ignoresSafeArea())
    }
}

struct ResultsContentView: View {
    let result: WineScanResult
    let purchaseMode: PurchaseMode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let topRecommendation = result.recommendations.first {
                    BestPickHeroView(
                        recommendation: topRecommendation,
                        purchaseMode: purchaseMode,
                        restaurantName: result.restaurantName
                    )
                }

                if snapshotText.isEmpty == false {
                    MenuSnapshotView(text: snapshotText)
                }

                if remainingRecommendations.isEmpty == false {
                    VStack(alignment: .leading, spacing: 16) {
                        ResultSectionHeader(
                            title: "Other Great Picks",
                            systemImage: "star.circle.fill",
                            style: .ribbon
                        )

                        ForEach(remainingRecommendations) { recommendation in
                            RecommendationCardView(recommendation: recommendation, purchaseMode: purchaseMode)
                        }
                    }
                }

                if result.categoryRecommendations.isEmpty == false {
                    CategoryHighlightsView(sections: result.categoryRecommendations, purchaseMode: purchaseMode)
                }

                if result.notes.isEmpty == false {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes")
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .foregroundStyle(Color.wineText)

                        ForEach(result.notes, id: \.self) { note in
                            Label {
                                Text(note)
                                    .foregroundStyle(Color.wineMutedText)
                            } icon: {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(Color.resultScoreTint)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color.resultCardBackground)
                    .clipShape(.rect(cornerRadius: 22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.wineBorder.opacity(0.8), lineWidth: 1)
                    }
                }

                #if DEBUG
                if let debugInfo = result.debugInfo {
                    DebugScanInfoView(debugInfo: debugInfo)
                }
                #endif
            }
            .padding(20)
        }
    }

    private var remainingRecommendations: [WineRecommendation] {
        Array(result.recommendations.dropFirst())
    }

    private var snapshotText: String {
        result.summary.headline.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    ResultsView(
        result: WineScanResult.sample(
            for: .glass,
            preferences: UserWinePreferences(
                preferredStyles: [WineStylePreference.crispRefreshing.rawValue],
                choiceStyle: ChoiceStyle.bestValue.rawValue,
                usualPurchasePreference: UsualPurchasePreference.glass.rawValue,
                hasCompletedOnboarding: true
            )
        ),
        purchaseMode: .glass,
        viewedAt: .now
    )
}

#if DEBUG
private struct DebugScanInfoView: View {
    let debugInfo: ScanDebugInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Debug")
                .font(.title3)
                .bold()

            Text("Model: \(debugInfo.model)")
                .font(.subheadline)

            Text("API Time: \(debugInfo.apiDurationMilliseconds) ms")
                .font(.subheadline)

            if let usage = debugInfo.usage {
                Text("Tokens: \(usage.promptTokenCount) in / \(usage.candidatesTokenCount) out / \(usage.totalTokenCount) total")
                    .font(.subheadline)
            }

            if let totalCostUsd = debugInfo.totalCostUsd {
                Text("Cost: \(formattedCost(totalCostUsd))")
                    .font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.resultCardBackground)
        .clipShape(.rect(cornerRadius: 22))
    }

    private func formattedCost(_ value: Double) -> String {
        if value < 0.000001 {
            return String(format: "$%.8f", value)
        }

        return String(format: "$%.6f", value)
    }
}
#endif

private struct MenuSnapshotView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.wineAccent)
                    .frame(width: 18, height: 18)

                Text("MENU SNAPSHOT")
                    .font(.caption.weight(.bold))
                    .tracking(0.9)
                    .foregroundStyle(Color.wineAccent)
            }

            Text(text)
                .font(.subheadline)
                .lineSpacing(2)
                .foregroundStyle(Color.wineText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.resultCardBackground.opacity(0.92))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.wineBorder.opacity(0.85), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 12, y: 6)
    }
}

struct ResultSectionHeader: View {
    enum Style {
        case plain
        case ribbon
    }

    let title: String
    let systemImage: String
    var style: Style = .plain

    var body: some View {
        switch style {
        case .plain:
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.resultScoreTint)
                    .frame(width: 28, height: 28)
                    .background(Color.resultScoreTint.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 10))

                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(Color.wineText)
            }
        case .ribbon:
            HStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.resultCardBackground)
                    Circle()
                        .stroke(Color.wineAccent.opacity(0.75), lineWidth: 1.2)

                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.wineAccent)
                }
                .frame(width: 38, height: 38)
                .zIndex(1)

                HStack(spacing: 0) {
                    Text(title.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(0.9)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.leading, 18)
                        .padding(.trailing, 22)
                        .frame(height: 26)
                        .background(Color.wineAccent)
                        .overlay(alignment: .trailing) {
                            RibbonNotch()
                                .fill(Color.wineAccent)
                                .frame(width: 16, height: 26)
                                .offset(x: 14)
                        }

                    ZStack(alignment: .trailing) {
                        Rectangle()
                            .fill(Color.wineAccent.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .frame(height: 1.2)

                        Circle()
                            .fill(Color.wineAccent)
                            .frame(width: 6, height: 6)
                            .offset(x: 3)
                    }
                }
                .offset(x: -8)
            }
        }
    }
}

private struct RibbonNotch: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 0.45, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}
