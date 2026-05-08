import Adapty
import Foundation
import Observation

@MainActor
@Observable
final class EntitlementManager {
    var hasActiveEntitlement = false
    var isLoading = true
    var isConfigured = false
    var purchaseDisplay: PurchaseDisplay?
    var isPurchaseInProgress = false
    var purchaseStatusMessage: String?
    var purchaseErrorMessage: String?

    private var products: [any AdaptyPaywallProduct] = []

    func configure() async {
        isLoading = true
        defer { isLoading = false }

        guard let sdkKey = AppConfiguration.shared.adaptySDKKey else {
            isConfigured = false
            hasActiveEntitlement = false
            return
        }

        do {
            let appUserID = try AppIdentityService.shared.appUserID()
            let configuration = AdaptyConfiguration
                .builder(withAPIKey: sdkKey)
                .with(customerUserId: appUserID, withAppAccountToken: UUID(uuidString: appUserID))
                .build()
            try await Adapty.activate(with: configuration)
            isConfigured = true
            await refreshEntitlement()
            await loadPaywallProducts()
        } catch {
            isConfigured = false
            hasActiveEntitlement = false
            purchaseErrorMessage = "Purchases are unavailable right now. Please try again later."
        }
    }

    func refreshEntitlement() async {
        guard isConfigured else {
            isLoading = false
            return
        }

        do {
            let profile = try await Adapty.getProfile()
            hasActiveEntitlement = Self.hasActiveEntitlement(in: profile)
        } catch {
            hasActiveEntitlement = false
        }

        isLoading = false
    }

    func loadPaywallProducts() async {
        guard isConfigured else { return }

        purchaseErrorMessage = nil

        do {
            let paywall = try await Adapty.getPaywall(
                placementId: AppConfiguration.shared.adaptyPaywallPlacementID
            )
            products = try await Adapty.getPaywallProducts(paywall: paywall)
            purchaseDisplay = products.first.map(PurchaseDisplay.init(product:))

            if products.isEmpty {
                purchaseErrorMessage = "No subscription products are available yet."
            }
        } catch {
            products = []
            purchaseDisplay = nil
            purchaseErrorMessage = "Couldn't load subscription options. Please try again."
        }
    }

    func restorePurchases() async throws {
        isPurchaseInProgress = true
        purchaseErrorMessage = nil
        purchaseStatusMessage = nil
        defer { isPurchaseInProgress = false }

        let profile = try await Adapty.restorePurchases()
        hasActiveEntitlement = Self.hasActiveEntitlement(in: profile)

        if hasActiveEntitlement {
            purchaseStatusMessage = "Purchases restored."
        } else {
            purchaseErrorMessage = "No active subscription was found for this Apple ID."
        }
    }

    func purchasePrimaryProduct() async {
        guard let product = products.first else {
            await loadPaywallProducts()
            guard products.isEmpty == false else { return }
            return await purchasePrimaryProduct()
        }

        isPurchaseInProgress = true
        purchaseErrorMessage = nil
        purchaseStatusMessage = nil
        defer { isPurchaseInProgress = false }

        do {
            let result = try await Adapty.makePurchase(product: product)

            switch result {
            case .success(let profile, _):
                hasActiveEntitlement = Self.hasActiveEntitlement(in: profile)
                if hasActiveEntitlement == false {
                    await refreshEntitlement()
                }
            case .pending:
                purchaseStatusMessage = "Purchase pending approval."
            case .userCancelled:
                break
            }
        } catch {
            purchaseErrorMessage = "Purchase couldn't be completed. Please try again."
        }
    }

    private static func hasActiveEntitlement(in profile: AdaptyProfile) -> Bool {
        profile.accessLevels[AppConfiguration.shared.paidAccessLevelID]?.isActive == true
    }
}

struct PurchaseDisplay {
    let title: String
    let price: String
    let period: String?

    init(product: any AdaptyPaywallProduct) {
        title = product.localizedTitle.isEmpty ? "CorkWise Premium" : product.localizedTitle
        price = product.localizedPrice ?? "\(product.price)"
        period = product.localizedSubscriptionPeriod
    }
}
