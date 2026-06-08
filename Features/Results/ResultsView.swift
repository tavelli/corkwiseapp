import SwiftData
import SwiftUI

struct ResultsView: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementManager.self) private var entitlementManager

    let result: WineScanResult
    let purchaseMode: PurchaseMode
    let categoryPreference: WineCategoryPreference
    let viewedAt: Date
    var hidesFeedbackOnOpen = false

    @State private var isShowingPaywall = false

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

    private var showsSoftPaywall: Bool {
        entitlementManager.hasActiveEntitlement == false
    }

    var body: some View {
        ResultsContentView(
            result: result,
            purchaseMode: purchaseMode,
            hidesFeedbackOnOpen: hidesFeedbackOnOpen,
            showsSoftPaywall: showsSoftPaywall,
            showRetryAction: showScanEntry,
            showPremiumAction: showPaywall
        )
        .navigationTitle(pageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationSubtitleIfAvailable(navigationSubtitle)
        .background(mainScreenBackground.ignoresSafeArea())
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(preferences: nil, source: "results_soft_paywall")
                .presentationDetents([.height(500)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(red: 0.09, green: 0.02, blue: 0.03))
        }
        .onChange(of: entitlementManager.hasActiveEntitlement) { _, hasActiveEntitlement in
            if hasActiveEntitlement {
                isShowingPaywall = false
            }
        }
    }

    private func showPaywall() {
        Task {
            let didLoadPaywall = await entitlementManager.loadPaywall(preferences: nil)
            if didLoadPaywall {
                isShowingPaywall = true
            }
        }
    }

    private func showScanEntry() {
        appState.resetMainNavigation()
    }
}

extension View {
    @ViewBuilder
    func navigationSubtitleIfAvailable(_ subtitle: String) -> some View {
        if #available(iOS 26.0, *) {
            self.navigationSubtitle(subtitle)
        } else {
            self
        }
    }
}

struct ResultsContentView: View {
    @Environment(\.modelContext) private var modelContext

    let result: WineScanResult
    let purchaseMode: PurchaseMode
    var hidesFeedbackOnOpen = false
    var scriptedScrollSequence: ResultsScriptedScrollSequence? = nil
    var showsSoftPaywall = false
    var showRetryAction: () -> Void = {}
    var showPremiumAction: () -> Void = {}

    @State private var hasRunScriptedScrollSequence = false
    @State private var hasTrackedSoftPaywallShown = false

    var body: some View {
        GeometryReader { geometry in
            let layout = ResultsLayoutMetrics(availableWidth: geometry.size.width)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                        if let topRecommendation = result.recommendations.first {
                            BestPickHeroView(
                                recommendation: topRecommendation,
                                purchaseMode: purchaseMode,
                                currencyCode: result.currencyCode,
                                restaurantName: result.restaurantName,
                                textMaxWidth: layout.readableTextMaxWidth
                            )
                            .frame(maxWidth: layout.featureContentMaxWidth)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }

                        if snapshotText.isEmpty == false {
                            MenuSnapshotView(
                                text: snapshotText,
                                pricingContextSummary: result.pricingContextSummary,
                                textMaxWidth: layout.readableTextMaxWidth
                            )
                                .id(ResultsScrollTarget.summary)
                                .frame(maxWidth: layout.featureContentMaxWidth)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }

                        if remainingRecommendations.isEmpty == false {
                            LazyVGrid(columns: layout.recommendationColumns, alignment: .leading, spacing: layout.cardSpacing) {
                                ForEach(Array(remainingRecommendations.enumerated()), id: \.element.id) { index, recommendation in
                                    RecommendationCardView.categoryCard(
                                        recommendation: recommendation,
                                        purchaseMode: purchaseMode,
                                        currencyCode: result.currencyCode,
                                        categoryLabel: String(localized: .resultsCategoryHighlyRecommend),
                                        icon: .star
                                    )
                                    .id(ResultsScrollTarget.highlyRecommendCard(index: index))
                                }
                            }
                        }

                        if result.categoryRecommendations.isEmpty == false {
                            CategoryHighlightsView(
                                sections: result.categoryRecommendations,
                                purchaseMode: purchaseMode,
                                currencyCode: result.currencyCode,
                                columns: layout.recommendationColumns,
                                spacing: layout.cardSpacing
                            )
                        }

                        if result.notes.isEmpty == false {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(.resultsNotesTitle)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.wineText)

                                ForEach(result.notes, id: \.self) { note in
                                    Label {
                                        Text(note)
                                            .foregroundStyle(Color.wineMutedText)
                                    } icon: {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundStyle(Color.wineMutedText)
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

                        if hidesFeedbackOnOpen == false, let analysisId = result.analysisId {
                            ResultsFeedbackCardView(
                                analysisId: analysisId,
                                retryAction: showRetryAction,
                                requestVisibility: {
                                    withAnimation(.easeInOut(duration: 0.24)) {
                                        proxy.scrollTo(ResultsScrollTarget.feedback, anchor: .bottom)
                                    }
                                },
                                onFeedbackSubmitted: markFeedbackSubmitted
                            )
                            .id(ResultsScrollTarget.feedback)
                        }

                        if showsSoftPaywall {
                            ResultsSoftPaywallCardView(
                                theme: .paywallSheet,
                                source: "results",
                                premiumAction: showPremiumAction
                            )
                            .onScrollVisibilityChange(threshold: 0.5) { isVisible in
                                guard isVisible, hasTrackedSoftPaywallShown == false else { return }
                                hasTrackedSoftPaywallShown = true
                                AnalyticsService.shared.trackSoftPaywallShown(source: "results")
                            }
                        }

                        #if DEBUG
                        if let debugInfo = result.debugInfo {
                            DebugScanInfoView(debugInfo: debugInfo)
                        }
                        #endif
                    }
                    .frame(maxWidth: layout.contentMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, layout.horizontalPadding)
                    .padding(.vertical, 20)
                }
                .scrollDismissesKeyboard(.interactively)
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
    }

    private var remainingRecommendations: [WineRecommendation] {
        Array(result.recommendations.dropFirst())
    }

    private var snapshotText: String {
        result.summary.headline.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func markFeedbackSubmitted() {
        guard let analysisId = result.analysisId else {
            return
        }

        let descriptor = FetchDescriptor<WineScan>(
            predicate: #Predicate { scan in
                scan.analysisId == analysisId
            }
        )

        guard let scan = try? modelContext.fetch(descriptor).first else { return }
        guard scan.hasSubmittedFeedback == false else { return }

        scan.hasSubmittedFeedback = true
        try? modelContext.save()
    }
}

struct ResultsLayoutMetrics {
    let availableWidth: CGFloat

    var contentMaxWidth: CGFloat {
        usesWideLayout ? 1060 : .infinity
    }

    var featureContentMaxWidth: CGFloat {
        usesWideLayout ? 620 : .infinity
    }

    var horizontalPadding: CGFloat {
        usesWideLayout ? 28 : 20
    }

    var sectionSpacing: CGFloat {
        usesWideLayout ? 26 : 24
    }

    var cardSpacing: CGFloat {
        usesWideLayout ? 18 : 16
    }

    var readableTextMaxWidth: CGFloat? {
        usesWideLayout ? 760 : nil
    }

    var recommendationColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: cardSpacing, alignment: .top),
            count: usesWideLayout ? 2 : 1
        )
    }

    private var usesWideLayout: Bool {
        availableWidth >= 760
    }
}

struct ResultsScriptedScrollSequence: Equatable {
    var isEnabled: Bool

    static let demoRecording = ResultsScriptedScrollSequence(isEnabled: true)

    @MainActor
    func run(using proxy: ScrollViewProxy) async {
        let steps: [(delay: Duration, target: ResultsScrollTarget, anchor: UnitPoint, duration: TimeInterval)] = [
            (.seconds(3), .summary, .top, 4),
            (.seconds(5), .highlyRecommendCard(index: 1), .top, 3),
            (.seconds(5), .category(key: "worth_the_splurge"), .top, 3),
            (.seconds(5), .category(key: "hidden_gem"), .top, 3),
//           (.seconds(3), .category(key: "overpriced_here"), .top, 12),
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
    case feedback
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
    .environment(AppState())
    .environment(EntitlementManager())
}

#Preview("Results With Feedback Card") {
    ResultsView(
        result: WineScanResult.sampleWithFeedback(
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
    .environment(AppState())
    .environment(EntitlementManager())
}

private extension WineScanResult {
    static func sampleWithFeedback(
        for purchaseMode: PurchaseMode,
        preferences: UserWinePreferences
    ) -> WineScanResult {
        let sample = WineScanResult.sample(
            for: purchaseMode,
            preferences: preferences
        )

        return WineScanResult(
            analysisId: "00000000-0000-0000-0000-000000000001",
            modelVersion: sample.modelVersion,
            promptVersion: sample.promptVersion,
            freeScanUsed: sample.freeScanUsed,
            restaurantName: sample.restaurantName,
            currencyCode: sample.currencyCode,
            summary: sample.summary,
            pricingContextSummary: sample.pricingContextSummary,
            recommendations: sample.recommendations,
            categoryRecommendations: sample.categoryRecommendations,
            notes: sample.notes,
            debugInfo: sample.debugInfo
        )
    }
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
    let pricingContextSummary: PricingContextSummary?
    var textMaxWidth: CGFloat? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
//                Image(phosphor: .wine)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 18, height: 18)
//                    .foregroundStyle(Color.wineText)
//                    

                Text(.resultsSnapshotTitle)
                    .font(.caption.weight(.bold))
                    .tracking(0.9)
                    .foregroundStyle(Color.wineText)
            }

            Text(text)
                .font(.subheadline)
                .lineSpacing(2)
                .foregroundStyle(Color.wineText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: textMaxWidth ?? .infinity, alignment: .leading)

           //  WineDataTagRow(tags: medianMarkupTags)
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

    private var formattedMedianMarkup: String? {
        guard let medianEstimatedMarkup = pricingContextSummary?.medianEstimatedMarkup else {
            return nil
        }

        return medianEstimatedMarkup.formatted(.number.precision(.fractionLength(1)))
    }

    private var medianMarkupTags: [String] {
        guard let formattedMedianMarkup else {
            return []
        }

        return [String(localized: .resultsSnapshotMedianMarkup(formattedMedianMarkup))]
    }
}
