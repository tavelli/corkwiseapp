import SwiftUI

struct ResultsView: View {
    let result: WineScanResult
    let purchaseMode: PurchaseMode
    let categoryPreference: WineCategoryPreference
    let viewedAt: Date

    private var pageTitle: String {
        let restaurantName = result.restaurantName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = if let restaurantName, restaurantName.isEmpty == false {
            restaurantName
        } else {
            String(localized: .commonWineList)
        }

        return "\(displayName)"
    }

    private var navigationSubtitle: String {
        "\(purchaseMode.title) • \(categoryPreference.title)"
    }

    var body: some View {
        ResultsContentView(result: result, purchaseMode: purchaseMode)
            .navigationTitle(pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationSubtitle(navigationSubtitle)
            .background(mainScreenBackground.ignoresSafeArea())
    }
}

struct ResultsContentView: View {
    let result: WineScanResult
    let purchaseMode: PurchaseMode
    var scriptedScrollSequence: ResultsScriptedScrollSequence? = nil

    @State private var hasRunScriptedScrollSequence = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let topRecommendation = result.recommendations.first {
                        BestPickHeroView(
                            recommendation: topRecommendation,
                            purchaseMode: purchaseMode,
                            currencyCode: result.currencyCode,
                            restaurantName: result.restaurantName
                        )
                    }

                    if snapshotText.isEmpty == false {
                        MenuSnapshotView(text: snapshotText)
                            .id(ResultsScrollTarget.summary)
                    }

                    if remainingRecommendations.isEmpty == false {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(Array(remainingRecommendations.enumerated()), id: \.element.id) { index, recommendation in
                                RecommendationCardView(
                                    recommendation: recommendation,
                                    purchaseMode: purchaseMode,
                                    currencyCode: result.currencyCode,
                                    categoryLabel: String(localized: .resultsCategoryHighlyRecommend),
                                    categorySystemImage: "star.fill"
                                )
                                .id(ResultsScrollTarget.highlyRecommendCard(index: index))
                            }
                        }
                    }

                    if result.categoryRecommendations.isEmpty == false {
                        CategoryHighlightsView(
                            sections: result.categoryRecommendations,
                            purchaseMode: purchaseMode,
                            currencyCode: result.currencyCode
                        )
                    }

                    if result.notes.isEmpty == false {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(.resultsNotesTitle)
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
            .task(id: scriptedScrollSequence?.isEnabled ?? false) {
                guard
                    let scriptedScrollSequence,
                    scriptedScrollSequence.isEnabled,
                    hasRunScriptedScrollSequence == false
                else {
                    return
                }

                hasRunScriptedScrollSequence = true
                await scriptedScrollSequence.run(using: proxy)
            }
        }
    }

    private var remainingRecommendations: [WineRecommendation] {
        Array(result.recommendations.dropFirst())
    }

    private var snapshotText: String {
        result.summary.headline.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ResultsScriptedScrollSequence: Equatable {
    var isEnabled: Bool

    static let demoRecording = ResultsScriptedScrollSequence(isEnabled: true)

    @MainActor
    func run(using proxy: ScrollViewProxy) async {
        let steps: [(delay: Duration, target: ResultsScrollTarget, anchor: UnitPoint, duration: TimeInterval)] = [
            (.seconds(3), .summary, .top, 1.05),
            (.seconds(3), .highlyRecommendCard(index: 1), .top, 1.15),
            (.seconds(3), .category(key: "worth_the_splurge"), .top, 1.05),
            (.seconds(3), .category(key: "hidden_gem"), .top, 1.05),
//            (.seconds(3), .category(key: "overpriced_here"), .top, 1.05),
        ]

        for step in steps {
            try? await Task.sleep(for: step.delay)
            guard Task.isCancelled == false else { return }

            withAnimation(.timingCurve(0.18, 0.82, 0.22, 1, duration: step.duration)) {
                proxy.scrollTo(step.target, anchor: step.anchor)
            }
        }
    }
}

enum ResultsScrollTarget: Hashable {
    case summary
    case highlyRecommendCard(index: Int)
    case category(key: String)
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
        categoryPreference: .reds,
        viewedAt: .now
    )
}

#if DEBUG
private struct DebugScanInfoView: View {
    let debugInfo: ScanDebugInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.resultsDebugTitle)
                .font(.title3)
                .bold()

            Text(.resultsDebugModel(debugInfo.model))
                .font(.subheadline)

            Text(.resultsDebugApiTime(debugInfo.apiDurationMilliseconds))
                .font(.subheadline)

            if let usage = debugInfo.usage {
                Text(.resultsDebugTokens(usage.promptTokenCount, usage.candidatesTokenCount, usage.totalTokenCount))
                    .font(.subheadline)
            }

            if let totalCostUsd = debugInfo.totalCostUsd {
                Text(.resultsDebugCost(formattedCost(totalCostUsd)))
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
                Image(systemName: "wineglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.wineAccent)
                    .frame(width: 18, height: 18)

                Text(.resultsSnapshotTitle)
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
