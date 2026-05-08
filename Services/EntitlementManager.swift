import Adapty
import AdaptyUI
import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class EntitlementManager {
    var hasActiveEntitlement = false
    var isLoading = true
    var isConfigured = false
    var paywallConfiguration: AdaptyUI.PaywallConfiguration?
    var isPurchaseInProgress = false
    var purchaseStatusMessage: String?
    var purchaseErrorMessage: String?
    private var hasActivatedAdaptyUI = false

    func configure() async {
        isLoading = true
        defer { isLoading = false }

        if isConfigured {
            await refreshEntitlement()
            await loadPaywallConfiguration()
            return
        }

        guard let sdkKey = AppConfiguration.shared.adaptySDKKey else {
            isConfigured = false
            hasActiveEntitlement = false
            return
        }

        do {
            let appUserID = try AppIdentityService.shared.appUserID()
            let configurationBuilder = AdaptyConfiguration
                .builder(withAPIKey: sdkKey)
                .with(customerUserId: appUserID, withAppAccountToken: UUID(uuidString: appUserID))

            let configuration = configurationBuilder.build()
            try await Adapty.activate(with: configuration)
            if hasActivatedAdaptyUI == false {
                try await AdaptyUI.activate()
                hasActivatedAdaptyUI = true
            }
            isConfigured = true
            await refreshEntitlement()
            await loadPaywallConfiguration()
        } catch {
            isConfigured = false
            hasActiveEntitlement = false
            Self.logPaywallError(error, context: "configure")
            #if DEBUG
            purchaseErrorMessage = "Paywall setup failed: \(Self.debugDescription(for: error))"
            #else
            purchaseErrorMessage = "Paywall is unavailable right now. Please try again later."
            #endif
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

    func loadPaywallConfiguration() async {
        guard isConfigured else { return }
        guard paywallConfiguration == nil else { return }

        purchaseErrorMessage = nil

        do {
            let placementID = AppConfiguration.shared.adaptyPaywallPlacementID
            let paywall = try await Adapty.getPaywall(
                placementId: placementID
            )
            #if DEBUG
            print("Adapty paywall:", paywall)
            print("Adapty vendor product IDs:", paywall.vendorProductIds)
            do {
                let storeKitProducts = try await Product.products(for: paywall.vendorProductIds)
                print("Direct StoreKit products:", storeKitProducts.map(\.id))
            } catch {
                print("Direct StoreKit error:", error)
            }
            #endif
            paywallConfiguration = try await AdaptyUI.getPaywallConfiguration(
                forPaywall: paywall
            )
        } catch {
            paywallConfiguration = nil
            Self.logPaywallError(error, context: "load paywall \(AppConfiguration.shared.adaptyPaywallPlacementID)")
            #if DEBUG
            purchaseErrorMessage = "Couldn't load paywall \(AppConfiguration.shared.adaptyPaywallPlacementID): \(Self.debugDescription(for: error))"
            #else
            purchaseErrorMessage = "Couldn't load the paywall. Please try again."
            #endif
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

    func startPurchase() {
        isPurchaseInProgress = true
        purchaseErrorMessage = nil
        purchaseStatusMessage = nil
    }

    func finishPurchase(_ result: AdaptyPurchaseResult) {
        isPurchaseInProgress = false

        switch result {
        case .success(let profile, _):
            hasActiveEntitlement = Self.hasActiveEntitlement(in: profile)
            if hasActiveEntitlement == false {
                Task {
                    await refreshEntitlement()
                }
            }
        case .pending:
            purchaseStatusMessage = "Purchase pending approval."
        case .userCancelled:
            break
        }
    }

    func failPurchase() {
        isPurchaseInProgress = false
        purchaseErrorMessage = "Purchase couldn't be completed. Please try again."
    }

    func finishRestore(_ profile: AdaptyProfile) {
        isPurchaseInProgress = false
        hasActiveEntitlement = Self.hasActiveEntitlement(in: profile)

        if hasActiveEntitlement {
            purchaseStatusMessage = "Purchases restored."
        } else {
            purchaseErrorMessage = "No active subscription was found for this Apple ID."
        }
    }

    func failRestore() {
        isPurchaseInProgress = false
        purchaseErrorMessage = "Couldn't restore purchases. Please try again."
    }

    func failRendering() {
        purchaseErrorMessage = "Couldn't render the paywall. Please try again."
    }

    private static func hasActiveEntitlement(in profile: AdaptyProfile) -> Bool {
        profile.accessLevels[AppConfiguration.shared.paidAccessLevelID]?.isActive == true
    }

    private static func debugDescription(for error: Error) -> String {
        let debugDescription = String(reflecting: error)
        if debugDescription.isEmpty == false {
            return debugDescription
        }

        let nsError = error as NSError
        if nsError.localizedDescription.isEmpty == false {
            return nsError.localizedDescription
        }

        return String(describing: error)
    }

    private static func logPaywallError(_ error: Error, context: String) {
        #if DEBUG
        let nsError = error as NSError
        print(
            """
            Adapty paywall error (\(context)):
            domain: \(nsError.domain)
            code: \(nsError.code)
            debug: \(String(reflecting: error))
            description: \(nsError.localizedDescription)
            underlying: \(nsError.userInfo)
            """
        )
        #endif
    }
}
