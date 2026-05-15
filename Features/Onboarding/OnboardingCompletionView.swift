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
                Text("Your first\nanalysis is\n\(Text("complimentary.").italic())")
                    .font(.system(size: headlineFontSize, weight: .regular, design: .serif))
                    .lineSpacing(2)
                    .foregroundStyle(Color.wineText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)

                Text("Try Corkwise on a real wine list and see for yourself.")
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
                Text("Analyze a Wine List")
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
