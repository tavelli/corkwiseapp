import SwiftUI

struct ResultsSoftPaywallCardView: View {
    let premiumAction: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            crownDivider

            VStack(spacing: 8) {
                Text("results.softPaywall.title")
                    .font(.system(.title3, design: .serif))
                    .bold()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.wineText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("results.softPaywall.subtitle")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.wineMutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: premiumAction) {
                Text("results.softPaywall.premiumButton")
                    .font(.headline)
                    .bold()
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(Color.wineAccent)
                    .clipShape(.capsule)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.resultCardBackground)
        .clipShape(.rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.wineBorder.opacity(0.8), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 12, y: 6)
    }

    private var crownDivider: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(crownDividerGradient)
                .frame(height: 1)

            Image(systemName: "crown.fill")
                .font(.headline)
                .foregroundStyle(Color(red: 0.83, green: 0.55, blue: 0.18))
                .frame(width: 38, height: 38)
                .background(Color.resultCardBackground)
                .clipShape(.circle)
                .overlay {
                    Circle()
                        .stroke(Color(red: 0.88, green: 0.62, blue: 0.25).opacity(0.8), lineWidth: 1)
                }

            Rectangle()
                .fill(crownDividerGradient)
                .frame(height: 1)
        }
        .padding(.horizontal, 14)
    }

    private var crownDividerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.wineBorder.opacity(0),
                Color(red: 0.88, green: 0.62, blue: 0.25).opacity(0.85),
                Color.wineBorder.opacity(0),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

#Preview {
    ZStack {
        mainScreenBackground
            .ignoresSafeArea()

        ResultsSoftPaywallCardView(premiumAction: {})
        .padding()
    }
}
