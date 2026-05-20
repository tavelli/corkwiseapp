import Adapty
import SwiftUI

struct PaywallView: View {
    @Environment(EntitlementManager.self) private var entitlementManager
    @Environment(\.dismiss) private var dismiss

    let preferences: UserWinePreferences?

    var body: some View {
        Group {
            if let paywall = entitlementManager.paywall {
                CustomPaywallContent(
                    paywall: paywall,
                    isPurchaseInProgress: entitlementManager.isPurchaseInProgress,
                    statusMessage: entitlementManager.purchaseStatusMessage,
                    errorMessage: entitlementManager.purchaseErrorMessage,
                    purchaseAction: {
                        Task {
                            await entitlementManager.purchaseSelectedPaywallProduct()
                        }
                    },
                    restoreAction: {
                        Task {
                            do {
                                try await entitlementManager.restorePurchases()
                            } catch {
                                entitlementManager.failRestore()
                            }
                        }
                    }
                )
                .task(id: paywall.id) {
                    await entitlementManager.logPaywallShownIfNeeded()
                }
            } else {
                PaywallFallbackView(
                    errorMessage: entitlementManager.purchaseErrorMessage,
                    retryAction: {
                        Task {
                            await entitlementManager.loadPaywall(preferences: preferences)
                        }
                    }
                )
            }
        }
        .background(PaywallBackground().ignoresSafeArea())
        .task {
            await entitlementManager.loadPaywall(preferences: preferences)
        }
        .onChange(of: entitlementManager.hasActiveEntitlement) { _, hasActiveEntitlement in
            if hasActiveEntitlement {
                dismiss()
            }
        }
    }
}

private struct CustomPaywallContent: View {
    let paywall: CustomPaywall
    let isPurchaseInProgress: Bool
    let statusMessage: String?
    let errorMessage: String?
    let purchaseAction: () -> Void
    let restoreAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 28)

            VStack(spacing: 12) {
                Text("CORKWISE PREMIUM")
                    .font(.caption.bold())
                    .tracking(2.4)
                    .foregroundStyle(Color(red: 0.86, green: 0.68, blue: 0.38))

                Text("Know what’s worth ordering")
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.98, green: 0.93, blue: 0.86))
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)

                Text("Expert guidance for every wine list.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.90, green: 0.82, blue: 0.74))
                    .padding(.horizontal, 12)
            }

            ProductSelectionCard(product: paywall.displayProduct)
                .padding(.top, 28)

            VStack(spacing: 24) {
                Button(action: purchaseAction) {
                    HStack(spacing: 8) {
                        if isPurchaseInProgress {
                            ProgressView()
                                .tint(Color(red: 0.16, green: 0.10, blue: 0.08))
                        }

                        Text(paywall.remoteConfig.ctaText)
                            .font(.headline)
                            .bold()
                    }
                    .foregroundStyle(Color(red: 0.16, green: 0.10, blue: 0.08))
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.76, blue: 0.42),
                                Color(red: 0.82, green: 0.60, blue: 0.30),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(isPurchaseInProgress)
                .opacity(isPurchaseInProgress ? 0.78 : 1)

                PaywallFooterLinks(
                    isPurchaseInProgress: isPurchaseInProgress,
                    restoreAction: restoreAction
                )
            }
            .padding(.top, 30)

            PaywallMessageView(statusMessage: statusMessage, errorMessage: errorMessage)
                .padding(.top, 16)

            Spacer(minLength: 22)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ProductSelectionCard: View {
    let product: CustomPaywallProduct

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "crown")
                .font(.title2)
                .foregroundStyle(Color(red: 0.91, green: 0.70, blue: 0.42))
                .frame(width: 66, height: 66)
                .background(Color(red: 0.20, green: 0.08, blue: 0.10).opacity(0.64))
                .clipShape(.circle)
                .overlay(
                    Circle()
                        .stroke(Color(red: 0.76, green: 0.55, blue: 0.32), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(productTitle)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(Color(red: 0.98, green: 0.92, blue: 0.84))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(productPrice)
                    .font(.title3)
                    .foregroundStyle(Color(red: 0.91, green: 0.76, blue: 0.54))

                Text(product.localizedDescription.isEmpty ? "Premium guidance for every list" : product.localizedDescription)
                    .font(.footnote)
                    .foregroundStyle(Color(red: 0.75, green: 0.66, blue: 0.62))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.18, green: 0.06, blue: 0.08).opacity(0.52))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(red: 0.92, green: 0.68, blue: 0.38), lineWidth: 1.4)
        )
        .shadow(color: Color(red: 0.90, green: 0.60, blue: 0.28).opacity(0.22), radius: 14, y: 3)
    }

    private var productTitle: String {
        if product.adaptyProductType.localizedCaseInsensitiveContains("annual") ||
            product.adaptyProductType.localizedCaseInsensitiveContains("year") ||
            product.subscriptionPeriod?.unit == .year {
            return "Annual"
        }

        return product.localizedTitle.isEmpty ? "Premium" : product.localizedTitle
    }

    private var productPrice: String {
        guard let localizedPrice = product.localizedPrice, localizedPrice.isEmpty == false else {
            return product.localizedTitle
        }

        guard let subscriptionPeriod = product.subscriptionPeriod else {
            return localizedPrice
        }

        return "\(localizedPrice)/\(subscriptionUnitLabel(for: subscriptionPeriod))"
    }

    private func subscriptionUnitLabel(for subscriptionPeriod: AdaptySubscriptionPeriod) -> String {
        switch subscriptionPeriod.unit {
        case .day:
            subscriptionPeriod.numberOfUnits == 1 ? "day" : "\(subscriptionPeriod.numberOfUnits) days"
        case .week:
            subscriptionPeriod.numberOfUnits == 1 ? "week" : "\(subscriptionPeriod.numberOfUnits) weeks"
        case .month:
            subscriptionPeriod.numberOfUnits == 1 ? "month" : "\(subscriptionPeriod.numberOfUnits) months"
        case .year:
            subscriptionPeriod.numberOfUnits == 1 ? "year" : "\(subscriptionPeriod.numberOfUnits) years"
        case .unknown:
            "period"
        }
    }
}

private struct PaywallFooterLinks: View {
    let isPurchaseInProgress: Bool
    let restoreAction: () -> Void

    private static let privacyPolicyURL = URL(string: "https://getcorkwise.com/privacy")
    private static let termsOfServiceURL = URL(string: "https://getcorkwise.com/terms")
    private let linkColor = Color(red: 0.86, green: 0.76, blue: 0.66)

    var body: some View {
        HStack(spacing: 12) {
            Button("Restore Purchases", action: restoreAction)
                .disabled(isPurchaseInProgress)

            if let privacyPolicyURL = Self.privacyPolicyURL {
                footerSeparator

                Link("Privacy", destination: privacyPolicyURL)
            }

            if let termsOfServiceURL = Self.termsOfServiceURL {
                footerSeparator

                Link("Terms", destination: termsOfServiceURL)
            }
        }
        .font(.footnote)
        .foregroundStyle(linkColor)
    }

    private var footerSeparator: some View {
        Text("•")
            .foregroundStyle(linkColor.opacity(0.7))
            .accessibilityHidden(true)
    }
}

private struct PaywallMessageView: View {
    let statusMessage: String?
    let errorMessage: String?

    var body: some View {
        VStack(spacing: 6) {
            if let statusMessage {
                Text(statusMessage)
                    .foregroundStyle(Color(red: 0.86, green: 0.76, blue: 0.66))
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(Color(red: 1.0, green: 0.48, blue: 0.44))
            }
        }
        .font(.footnote)
        .multilineTextAlignment(.center)
    }
}

private struct PaywallFallbackView: View {
    let errorMessage: String?
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image("headerlogo4")
                .resizable()
                .scaledToFit()
                .frame(height: 55)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color(red: 1.0, green: 0.48, blue: 0.44))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button(String(localized: .paywallTryAgain), action: retryAction)
                    .buttonStyle(PaywallRetryButtonStyle())
            } else {
                ProgressView(String(localized: .paywallLoadingSubscriptionOptions))
                    .font(.footnote)
                    .foregroundStyle(Color(red: 0.90, green: 0.82, blue: 0.74))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct PaywallBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.34, green: 0.05, blue: 0.12),
                Color(red: 0.16, green: 0.04, blue: 0.07),
                Color(red: 0.09, green: 0.02, blue: 0.03),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct PaywallRetryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .foregroundStyle(Color.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.wineAccent.opacity(configuration.isPressed ? 0.88 : 1))
            .clipShape(.rect(cornerRadius: 14))
    }
}

#Preview {
    PaywallView(preferences: nil)
        .environment(EntitlementManager())
}

#Preview("Loaded") {
    let entitlementManager = EntitlementManager()
    entitlementManager.paywall = .previewLoaded

    return PaywallView(preferences: nil)
        .environment(entitlementManager)
}

#if DEBUG
extension CustomPaywall {
    static let previewLoaded = CustomPaywall(
        id: "preview-annual-paywall",
        displayProduct: CustomPaywallProduct(
            vendorProductId: "corkwise.premium.annual.preview",
            localizedTitle: "Annual",
            localizedDescription: "A smarter way to choose the bottle",
            localizedPrice: "$99/year",
            adaptyProductType: "annual",
            subscriptionPeriod: nil
        ),
        remoteConfig: .init(dictionary: ["cta_text": "Get Premium"])
    )
}
#endif
