import SwiftUI

struct PaywallView: View {
    @Environment(EntitlementManager.self) private var entitlementManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 22) {
                titleBlock
                productBlock
                featureList
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            footer
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(mainScreenBackground.ignoresSafeArea())
        .task {
            await entitlementManager.loadPaywallProducts()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image("headerlogo4")
                .resizable()
                .scaledToFit()
                .frame(height: 55)

            Text("Unlock smarter wine picks.")
                .font(.subheadline)
                .foregroundStyle(Color.wineText.opacity(0.6))
                .padding(.top, 6)
                .padding(.bottom, 38)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order wine with more confidence.")
                .font(.title2)
                .bold()
                .foregroundStyle(Color.wineText)

            Text("Scan a restaurant wine list and get ranked recommendations based on value, producer quality, your taste, and whether you're ordering by the glass or bottle.")
                .font(.subheadline)
                .lineSpacing(3)
                .foregroundStyle(Color.wineMutedText.opacity(0.92))
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaywallFeatureRow(
                title: "Ranked picks for the whole list",
                subtitle: "See what stands out before you order.",
                systemImage: "sparkles"
            )
            PaywallFeatureRow(
                title: "Value-aware recommendations",
                subtitle: "Balances markup, producer quality, age, and list context.",
                systemImage: "chart.line.uptrend.xyaxis"
            )
            PaywallFeatureRow(
                title: "Restore purchases supported",
                subtitle: "Your access follows your Apple ID.",
                systemImage: "arrow.clockwise"
            )
        }
    }

    @ViewBuilder
    private var productBlock: some View {
        if let purchaseDisplay = entitlementManager.purchaseDisplay {
            VStack(alignment: .leading, spacing: 6) {
                Text(purchaseDisplay.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.wineText)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(purchaseDisplay.price)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.wineText)

                    if let period = purchaseDisplay.period {
                        Text(period)
                            .font(.footnote)
                            .foregroundStyle(Color.wineMutedText.opacity(0.9))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.94))
            .clipShape(.rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.wineBorder.opacity(0.9), lineWidth: 1)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if let message = entitlementManager.purchaseErrorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color.red.opacity(0.82))
                    .multilineTextAlignment(.center)
            } else if let message = entitlementManager.purchaseStatusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color.wineMutedText.opacity(0.9))
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await entitlementManager.purchasePrimaryProduct()
                }
            } label: {
                if entitlementManager.isPurchaseInProgress {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(primaryButtonTitle)
                }
            }
            .buttonStyle(PaywallPrimaryButtonStyle())
            .disabled(entitlementManager.isPurchaseInProgress)

            Button("Restore Purchases") {
                Task {
                    do {
                        try await entitlementManager.restorePurchases()
                    } catch {
                        entitlementManager.purchaseErrorMessage = "Couldn't restore purchases. Please try again."
                    }
                }
            }
            .buttonStyle(PaywallSecondaryButtonStyle())
            .disabled(entitlementManager.isPurchaseInProgress)
        }
        .padding(.top, 24)
    }

    private var primaryButtonTitle: String {
        if let price = entitlementManager.purchaseDisplay?.price {
            return "Continue - \(price)"
        }

        return "Continue"
    }
}

private struct PaywallFeatureRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.wineAccent)
                .frame(width: 30, height: 30)
                .background(Color.wineSoftPeach.opacity(0.38))
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.wineText)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.wineMutedText.opacity(0.9))
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.94))
        .clipShape(.rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.wineBorder.opacity(0.9), lineWidth: 1)
        }
    }
}

private struct PaywallPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.wineAccent.opacity(configuration.isPressed ? 0.88 : 1))
            .clipShape(.rect(cornerRadius: 14))
    }
}

private struct PaywallSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.wineText)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.wineOptionBackground.opacity(configuration.isPressed ? 0.92 : 1))
            .clipShape(.rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.wineBorder, lineWidth: 1)
            }
    }
}

#Preview {
    PaywallView()
        .environment(EntitlementManager())
}
