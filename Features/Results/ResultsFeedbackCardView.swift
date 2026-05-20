import SwiftUI

struct ResultsFeedbackCardView: View {
    @Environment(EntitlementManager.self) private var entitlementManager

    let analysisId: String
    let retryAction: () -> Void

    @State private var state: FeedbackState = .initial
    @State private var comment = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var negativeFeedbackId: String?

    private let feedbackService = FeedbackService()

    init(
        analysisId: String,
        retryAction: @escaping () -> Void,
        initialState: FeedbackState = .initial,
        initialNegativeFeedbackId: String? = nil
    ) {
        self.analysisId = analysisId
        self.retryAction = retryAction
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.wineOptionBackground.opacity(0.62))
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.wineBorder.opacity(0.55), lineWidth: 1)
        }
    }

    private var initialContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Was this guidance useful?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.wineText)

            HStack(spacing: 10) {
                ratingButton("Yes", systemImage: "hand.thumbsup") {
                    submitPositiveFeedback()
                }

                ratingButton("Not really", systemImage: "hand.thumbsdown") {
                    submitInitialNegativeFeedback()
                }
            }
        }
    }

    private var commentContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What could have been better?")
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
                        Text("Was anything inaccurate, missing, or unclear?")
                            .font(.subheadline)
                            .foregroundStyle(Color.wineMutedText.opacity(0.78))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }

            HStack(spacing: 10) {
                quietButton("Send feedback") {
                    submitNegativeFeedbackComment()
                }

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

    private func ratingButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            } icon: {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
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

    private func submitPositiveFeedback() {
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let response = try await feedbackService.submitFeedback(
                    analysisId: analysisId,
                    rating: .useful,
                    comment: nil
                )

                await MainActor.run {
                    isSubmitting = false
                    withAnimation(.easeInOut(duration: 0.18)) {
                        if response.retryGranted {
                            state = .retryOffer
                        } else {
                            state = .positiveThanks
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
                    negativeFeedbackId = response.feedbackId
                    isSubmitting = false
                    withAnimation(.easeInOut(duration: 0.18)) {
                        state = .comment
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Couldn't send feedback. Please try again."
                }
            }
        }
    }

    private func submitNegativeFeedbackComment() {
        guard let negativeFeedbackId else {
            errorMessage = "Couldn't send feedback. Please try again."
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
                    errorMessage = "Couldn't send feedback. Please try again."
                }
            }
        }
    }

    enum FeedbackState {
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
