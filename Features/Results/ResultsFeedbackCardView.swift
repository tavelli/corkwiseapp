import StoreKit
import SwiftUI

struct ResultsFeedbackCardView: View {
    @Environment(EntitlementManager.self) private var entitlementManager
    @Environment(\.requestReview) private var requestReview

    let analysisId: String
    let retryAction: () -> Void
    let requestVisibility: () -> Void
    let onFeedbackSubmitted: () -> Void

    @State private var state: FeedbackState = .initial
    @State private var comment = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var negativeFeedbackId: String?
    @State private var hasRequestedReview = false
    @FocusState private var isCommentFocused: Bool

    private let feedbackService = FeedbackService()

    init(
        analysisId: String,
        retryAction: @escaping () -> Void,
        requestVisibility: @escaping () -> Void = {},
        onFeedbackSubmitted: @escaping () -> Void = {},
        initialState: FeedbackState = .initial,
        initialNegativeFeedbackId: String? = nil
    ) {
        self.analysisId = analysisId
        self.retryAction = retryAction
        self.requestVisibility = requestVisibility
        self.onFeedbackSubmitted = onFeedbackSubmitted
        _state = State(initialValue: initialState)
        _negativeFeedbackId = State(initialValue: initialNegativeFeedbackId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch state {
            case .initial:
                initialContent
            case .comment:
                commentContent
            case .positiveThanks:
                VStack(alignment: .leading, spacing: 12) {
                    Text(.resultsFeedbackPositiveThanksTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.wineText)

                    Text(.resultsFeedbackPositiveThanksMessage)
                        .font(.subheadline)
                        .foregroundStyle(Color.wineMutedText)
                    
                }
            case .feedbackThanks:
                Text(.resultsFeedbackThanksMessage)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.wineOptionBackground.opacity(0.62))
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.wineBorder.opacity(0.55), lineWidth: 1)
        }
        .onChange(of: isCommentFocused) { _, isFocused in
            guard isFocused else { return }
            revealAfterKeyboardBeginsPresenting()
        }
        .onChange(of: state) { _, newState in
            guard newState == .positiveThanks, hasRequestedReview == false else { return }
            hasRequestedReview = true
            requestReview()
        }
    }

    private var initialContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(.resultsFeedbackQuestion)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.wineText)

            HStack(spacing: 10) {
                ratingButton(.resultsFeedbackYesButton, icon: .thumbsUp) {
                    submitPositiveFeedback()
                }

                ratingButton(.resultsFeedbackNoButton, icon: .thumbsDown) {
                    submitInitialNegativeFeedback()
                }
            }
        }
    }

    private var commentContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.resultsFeedbackCommentTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.wineText)

            TextField(String(localized: .resultsFeedbackCommentPlaceholder), text: $comment, axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(Color.wineText)
                .lineLimit(3...5)
                .frame(minHeight: 82, alignment: .topLeading)
                .padding(8)
                .focused($isCommentFocused)
                .background(Color.resultCardBackground.opacity(0.8))
                .clipShape(.rect(cornerRadius: 12))

            prominentFeedbackButton(.resultsFeedbackSendButton) {
                submitNegativeFeedbackComment()
            }
        }
    }

    private var retryOfferContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text(.resultsFeedbackRetryOfferTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.wineText)

                Text(.resultsFeedbackRetryOfferMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color.wineMutedText)
                
            }
        }
    }

    private func ratingButton(
        _ title: LocalizedStringResource,
        icon: PhosphorIcon,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            } icon: {
                Image(phosphor: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }
            .foregroundStyle(Color.wineText)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
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

    private func quietButton(_ title: LocalizedStringResource, action: @escaping () -> Void) -> some View {
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

    private func prominentFeedbackButton(_ title: LocalizedStringResource, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.resultHeroIvory)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(
                    LinearGradient(
                        colors: [Color.resultHeroTop, Color.resultHeroBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(.rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.resultHeroIvory.opacity(0.28), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
        .opacity(isSubmitting ? 0.72 : 1)
    }

    private func submitPositiveFeedback() {
        errorMessage = nil
        onFeedbackSubmitted()

        withAnimation(.easeInOut(duration: 0.18)) {
            state = .positiveThanks
        }

        Task {
            if (try? await feedbackService.submitFeedback(
                analysisId: analysisId,
                rating: .useful,
                comment: nil
            )) != nil {
                await MainActor.run {
                    AnalyticsService.shared.trackFeedbackSubmitted(
                        rating: .useful,
                        source: "result_end_card"
                    )
                }
            }
        }
    }

    private func submitInitialNegativeFeedback() {
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let response = try await feedbackService.submitFeedback(
                    analysisId: analysisId,
                    rating: .notUseful,
                    comment: nil
                )

                await MainActor.run {
                    AnalyticsService.shared.trackFeedbackSubmitted(
                        rating: .notUseful,
                        source: "result_end_card_initial",
                        retryGranted: response.retryGranted
                    )
                    onFeedbackSubmitted()
                    negativeFeedbackId = response.feedbackId
                    isSubmitting = false
                    withAnimation(.easeInOut(duration: 0.18)) {
                        state = .comment
                    }
                    revealAfterExpansion()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = String(localized: .resultsFeedbackSubmitError)
                }
            }
        }
    }

    private func submitNegativeFeedbackComment() {
        guard let negativeFeedbackId else {
            errorMessage = String(localized: .resultsFeedbackSubmitError)
            return
        }

        isSubmitting = true
        errorMessage = nil

        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                let response = try await feedbackService.submitFeedback(
                    feedbackId: negativeFeedbackId,
                    analysisId: analysisId,
                    rating: .notUseful,
                    comment: trimmedComment.isEmpty ? nil : trimmedComment
                )

                await MainActor.run {
                    AnalyticsService.shared.trackFeedbackSubmitted(
                        rating: .notUseful,
                        source: "result_end_card_comment",
                        retryGranted: response.retryGranted
                    )
                    isSubmitting = false
                    withAnimation(.easeInOut(duration: 0.18)) {
                        state = response.retryGranted ? .retryOffer : .feedbackThanks
                    }
                }

                if response.retryGranted {
                    await entitlementManager.refreshScanAccess()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = String(localized: .resultsFeedbackSubmitError)
                }
            }
        }
    }

    private func revealAfterExpansion() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            requestVisibility()
        }
    }

    private func revealAfterKeyboardBeginsPresenting() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            requestVisibility()
        }
    }

    enum FeedbackState: Equatable {
        case initial
        case comment
        case positiveThanks
        case feedbackThanks
        case retryOffer
    }
}

#Preview {
    ZStack {
        mainScreenBackground
            .ignoresSafeArea()

        ResultsFeedbackCardView(
            analysisId: UUID().uuidString,
            retryAction: {}
        )
        .padding()
    }
    .environment(EntitlementManager())
}

#Preview("Comment Open") {
    ZStack {
        mainScreenBackground
            .ignoresSafeArea()

        ResultsFeedbackCardView(
            analysisId: UUID().uuidString,
            retryAction: {},
            initialState: .comment,
            initialNegativeFeedbackId: UUID().uuidString
        )
        .padding()
    }
    .environment(EntitlementManager())
}
#Preview("Positive Feedback Submitted") {
    ZStack {
        mainScreenBackground
            .ignoresSafeArea()

        ResultsFeedbackCardView(
            analysisId: UUID().uuidString,
            retryAction: {},
            initialState: .positiveThanks
        )
        .padding()
    }
    .environment(EntitlementManager())
}

#Preview("Feedback Submitted") {
    ZStack {
        mainScreenBackground
            .ignoresSafeArea()

        ResultsFeedbackCardView(
            analysisId: UUID().uuidString,
            retryAction: {},
            initialState: .feedbackThanks
        )
        .padding()
    }
    .environment(EntitlementManager())
}

#Preview("Retry Granted") {
    ZStack {
        mainScreenBackground
            .ignoresSafeArea()

        ResultsFeedbackCardView(
            analysisId: UUID().uuidString,
            retryAction: {},
            initialState: .retryOffer
        )
        .padding()
    }
    .environment(EntitlementManager())
}
