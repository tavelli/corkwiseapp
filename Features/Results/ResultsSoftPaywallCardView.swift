import SwiftUI

struct ResultsSoftPaywallCardView: View {
    enum Theme {
        case standard
        case paywallSheet

        var titleColor: Color {
            switch self {
            case .standard:
                Color.wineText
            case .paywallSheet:
                Color(red: 0.98, green: 0.93, blue: 0.86)
            }
        }

        var subtitleColor: Color {
            switch self {
            case .standard:
                Color.wineMutedText
            case .paywallSheet:
                Color(red: 0.90, green: 0.82, blue: 0.74)
            }
        }

        var buttonTextColor: Color {
            switch self {
            case .standard:
                Color.white
            case .paywallSheet:
                Color(red: 0.16, green: 0.10, blue: 0.08)
            }
        }

        var buttonBackground: LinearGradient {
            switch self {
            case .standard:
                LinearGradient(
                    colors: [Color.wineAccent, Color.wineAccent],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .paywallSheet:
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.76, blue: 0.42),
                        Color(red: 0.82, green: 0.60, blue: 0.30),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }

        var cardBackground: LinearGradient {
            switch self {
            case .standard:
                LinearGradient(
                    colors: [Color.resultCardBackground, Color.resultCardBackground],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .paywallSheet:
                LinearGradient(
                    colors: [
                        Color(red: 0.34, green: 0.05, blue: 0.12),
                        Color(red: 0.16, green: 0.04, blue: 0.07),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }

        var crownBackground: Color {
            switch self {
            case .standard:
                Color.resultCardBackground
            case .paywallSheet:
                Color(red: 0.20, green: 0.08, blue: 0.10).opacity(0.64)
            }
        }

        var borderColor: Color {
            switch self {
            case .standard:
                Color.wineBorder.opacity(0.8)
            case .paywallSheet:
                Color(red: 0.92, green: 0.68, blue: 0.38).opacity(0.88)
            }
        }

        var shadowColor: Color {
            switch self {
            case .standard:
                Color.black.opacity(0.04)
            case .paywallSheet:
                Color(red: 0.90, green: 0.60, blue: 0.28).opacity(0.20)
            }
        }
    }

    let theme: Theme
    let premiumAction: () -> Void

    init(theme: Theme = .standard, premiumAction: @escaping () -> Void) {
        self.theme = theme
        self.premiumAction = premiumAction
    }

    var body: some View {
        VStack(spacing: 14) {
            crownDivider

            VStack(spacing: 8) {
                Text(.resultsSoftPaywallTitle)
                    .font(.system(.title3, design: .serif))
                    .bold()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.titleColor)
                    .fixedSize(horizontal: false, vertical: true)

                Text(.resultsSoftPaywallSubtitle)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.subtitleColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: premiumAction) {
                Text(.resultsSoftPaywallPremiumButton)
                    .font(.headline)
                    .bold()
                    .foregroundStyle(theme.buttonTextColor)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(theme.buttonBackground)
                    .clipShape(.capsule)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(theme.cardBackground)
        .clipShape(.rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(theme.borderColor, lineWidth: 1)
        }
        .shadow(color: theme.shadowColor, radius: 12, y: 6)
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
                .background(theme.crownBackground)
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

        VStack(spacing: 20) {
            ResultsSoftPaywallCardView(premiumAction: {})

            ResultsSoftPaywallCardView(theme: .paywallSheet, premiumAction: {})
        }
        .padding()
    }
}
