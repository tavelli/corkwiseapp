import SwiftUI

struct PaywallView: View {
    @Environment(EntitlementManager.self) private var entitlementManager

    var body: some View {
        VStack(alignment: .leading) {
            Spacer()

            Text("Order wine with more confidence.")
                .font(.largeTitle)
                .bold()

            Text("Scan a restaurant wine list and get ranked recommendations based on value, producer quality, your taste, and whether you're ordering by the glass or bottle.")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading) {
                Label("No free trial", systemImage: "checkmark.seal")
                Label("No free scan", systemImage: "checkmark.seal")
                Label("Restore purchases supported", systemImage: "checkmark.seal")
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(.rect(cornerRadius: 24))

            Text("Placeholder gate until Adapty is integrated.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Continue") {
                entitlementManager.activatePlaceholderEntitlement()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Restore Purchases") {
                Task {
                    try? await entitlementManager.restorePurchases()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.paywallBackgroundTop, .paywallBackgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

#Preview {
    PaywallView()
        .environment(EntitlementManager())
}
