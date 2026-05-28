import SwiftUI

struct ScanFailureView: View {
    let title: String
    let message: String
    let buttonTitle: String
    let buttonAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title3)
                    .bold()
                    .foregroundStyle(Color.wineText)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.wineText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(buttonTitle, action: buttonAction)
                .buttonStyle(ScanFailureRetryButtonStyle())
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
    }
}

private struct ScanFailureRetryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .bold()
            .foregroundStyle(Color.resultHeroIvory)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(configuration.isPressed ? Color.wineDeep : Color.wineAccent)
            .clipShape(.capsule)
            .shadow(
                color: Color.wineDeep.opacity(configuration.isPressed ? 0.12 : 0.22),
                radius: configuration.isPressed ? 5 : 10,
                x: 0,
                y: configuration.isPressed ? 2 : 5
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
