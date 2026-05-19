import SwiftUI

struct ResultsView: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementManager.self) private var entitlementManager

    let result: WineScanResult
    let purchaseMode: PurchaseMode
    let categoryPreference: WineCategoryPreference
    let viewedAt: Date

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
            showsSoftPaywall: showsSoftPaywall,
            showRetryAction: showScanEntry,
            showPremiumAction: showPaywall
        )
        .navigationTitle(pageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationSubtitle(navigationSubtitle)
        .background(mainScreenBackground.ignoresSafeArea())
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(preferences: nil)
                .presentationDetents([.height(500)])
                .presentationDragIndicator(.visible)
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

struct ResultsContentView: View {
    let result: WineScanResult
    let purchaseMode: PurchaseMode
    var scriptedScrollSequence: ResultsScriptedScrollSequence? = nil
    var showsSoftPaywall = false
    var showRetryAction: () -> Void = {}
    var showPremiumAction: () -> Void = {}

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

                    if result.analysisId != nil {
                        ResultsFeedbackCardView(
                            result: result,
                            retryAction: showRetryAction
                        )
                    }
                    
                    if showsSoftPaywall {
                        ResultsSoftPaywallCardView(premiumAction: showPremiumAction)
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
}

private struct ResultsFeedbackCardView: View {
    @Environment(EntitlementManager.self) private var entitlementManager

    let result: WineScanResult
    let retryAction: () -> Void

    @State private var state: FeedbackState = .initial
    @State private var comment = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let feedbackService = FeedbackService()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch state {
            case .initial:
                initialContent
            case .comment:
                commentContent
            case .positiveThanks:
                Text("Thanks - glad it helped.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.wineMutedText)
            case .feedbackThanks:
                Text("Thanks - feedback helps improve CorkWise.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.wineMutedText)
            case .retryOffer:
                retryOfferContent
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.wineMutedText)
            }
        }
        .padding(16)
        .background(Color.wineOptionBackground.opacity(0.62))
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.wineBorder.opacity(0.55), lineWidth: 1)
        }
    }

    private var initialContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Was this result useful?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.wineText)

            HStack(spacing: 10) {
                quietButton("Yes") {
                    submit(rating: .useful, comment: nil)
                }

                quietButton("Not really") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        state = .comment
                        errorMessage = nil
                    }
                }
            }
        }
    }

    private var commentContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What felt off?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.wineText)

            TextEditor(text: $comment)
                .font(.subheadline)
                .foregroundStyle(Color.wineText)
                .frame(minHeight: 82)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color.resultCardBackground.opacity(0.8))
                .clipShape(.rect(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    if comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Missing wines, wrong prices, weak picks, or something else?")
                            .font(.subheadline)
                            .foregroundStyle(Color.wineMutedText.opacity(0.78))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }

            HStack(spacing: 10) {
                quietButton("Send feedback") {
                    submit(
                        rating: .notUseful,
                        comment: comment.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
                .disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Skip") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        state = .feedbackThanks
                        errorMessage = nil
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.wineMutedText)
                .disabled(isSubmitting)
            }
        }
    }

    private var retryOfferContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Want another try?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.wineText)

                Text("Thanks for the feedback. You can run one more complimentary analysis.")
                    .font(.subheadline)
                    .foregroundStyle(Color.wineMutedText)
            }

            HStack(spacing: 10) {
                quietButton("Try again") {
                    Task {
                        await entitlementManager.refreshScanAccess()
                        retryAction()
                    }
                }

                Button("Maybe later") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        state = .feedbackThanks
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.wineMutedText)
            }
        }
    }

    private func quietButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.wineText)
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background(Color.resultCardBackground.opacity(0.78))
                .clipShape(.rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.wineBorder.opacity(0.7), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
    }

    private func submit(rating: AnalysisFeedbackRequest.Rating, comment: String?) {
        guard let analysisId = result.analysisId else { return }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let response = try await feedbackService.submitFeedback(
                    analysisId: analysisId,
                    rating: rating,
                    comment: comment
                )

                await MainActor.run {
                    isSubmitting = false
                    withAnimation(.easeInOut(duration: 0.18)) {
                        if response.retryGranted {
                            state = .retryOffer
                        } else {
                            state = rating == .useful ? .positiveThanks : .feedbackThanks
                        }
                    }
                }

                if response.retryGranted {
                    await entitlementManager.refreshScanAccess()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Couldn't send feedback. Please try again."
                }
            }
        }
    }

    private enum FeedbackState {
        case initial
        case comment
        case positiveThanks
        case feedbackThanks
        case retryOffer
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
        categoryPreference: .reds,
        viewedAt: .now
    )
    .environment(AppState())
    .environment(EntitlementManager())
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
