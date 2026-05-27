import SwiftUI

struct OnboardingCompletionView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var headlineFontSize = 42
    @ScaledMetric(relativeTo: .subheadline) private var subheadlineFontSize = 14
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image("headerlogo4")
                .resizable()
                .scaledToFit()
                .frame(height: 48)
                .padding(.top, 28)

            Spacer(minLength: 20)

            VStack(spacing: 14) {
                (
                    Text(.onboardingCompletionHeadlinePrefix)
                    + Text("\n")
                    + Text(.onboardingCompletionHeadlineMiddle)
                    + Text("\n")
                    + Text(.onboardingCompletionHeadlineEmphasis).italic()
                )
                    .font(.system(size: headlineFontSize, weight: .regular, design: .serif))
                    .lineSpacing(2)
                    .foregroundStyle(Color.wineText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)

                Text(.onboardingCompletionSubtitle)
                    .font(.system(size: subheadlineFontSize, weight: .medium))
                    .foregroundStyle(Color.wineMutedText.opacity(0.94))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(4)
                    .frame(maxWidth: .infinity)
            }
            .offset(y: -24)

            Spacer(minLength: 20)

            Button(action: onContinue) {
                Text(.onboardingCompletionCta)
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
        .background(mainScreenBackground.ignoresSafeArea())
    }
}

#Preview {
    OnboardingCompletionView {}
}
