import Adapty
import AdaptyUI
import SwiftUI

struct PaywallView: View {
    @Environment(EntitlementManager.self) private var entitlementManager

    var body: some View {
        Group {
            if let paywallConfiguration = entitlementManager.paywallConfiguration {
                AdaptyPaywallView(
                    paywallConfiguration: paywallConfiguration,
                    didStartPurchase: { _ in
                        entitlementManager.startPurchase()
                    },
                    didFinishPurchase: { _, result in
                        entitlementManager.finishPurchase(result)
                    },
                    didFailPurchase: { _, _ in
                        entitlementManager.failPurchase()
                    },
                    didStartRestore: {
                        entitlementManager.startPurchase()
                    },
                    didFinishRestore: { profile in
                        entitlementManager.finishRestore(profile)
                    },
                    didFailRestore: { _ in
                        entitlementManager.failRestore()
                    },
                    didFailRendering: { _ in
                        entitlementManager.failRendering()
                    }
                )
            } else {
                fallbackView
            }
        }
        .background(mainScreenBackground.ignoresSafeArea())
        .task {
            await entitlementManager.loadPaywallConfiguration()
        }
    }

    private var fallbackView: some View {
        VStack(spacing: 14) {
            Image("headerlogo4")
                .resizable()
                .scaledToFit()
                .frame(height: 55)

            if let message = entitlementManager.purchaseErrorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color.red.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button("Try Again") {
                    Task {
                        await entitlementManager.loadPaywallConfiguration()
                    }
                }
                .buttonStyle(PaywallRetryButtonStyle())
            } else {
                ProgressView("Loading subscription options...")
                    .font(.footnote)
                    .foregroundStyle(Color.wineMutedText.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct PaywallRetryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.wineAccent.opacity(configuration.isPressed ? 0.88 : 1))
            .clipShape(.rect(cornerRadius: 14))
    }
}

#Preview {
    PaywallView()
        .environment(EntitlementManager())
}
