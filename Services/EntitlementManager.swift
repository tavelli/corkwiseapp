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
    private var loadedPaywallCustomAttributes: [String: String]?

    func configure() async {
        isLoading = true
        defer { isLoading = false }

        if isConfigured {
            await refreshEntitlement(updatesLoadingState: false)
            await loadPaywallConfigurationIfNeeded()
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
            await refreshEntitlement(updatesLoadingState: false)
            await loadPaywallConfigurationIfNeeded()
        } catch {
            isConfigured = false
            hasActiveEntitlement = false
            Self.logPaywallError(error, context: "configure")
            #if DEBUG
            purchaseErrorMessage = String(localized: .paywallErrorSetupFailed(Self.debugDescription(for: error)))
            #else
            purchaseErrorMessage = String(localized: .paywallErrorUnavailable)
            #endif
        }
    }

    func refreshEntitlement() async {
        await refreshEntitlement(updatesLoadingState: true)
    }

    private func refreshEntitlement(updatesLoadingState: Bool) async {
        if updatesLoadingState {
            isLoading = true
        }
        defer {
            if updatesLoadingState {
                isLoading = false
            }
        }

        guard isConfigured else {
            return
        }

        do {
            let profile = try await Adapty.getProfile()
            hasActiveEntitlement = Self.hasActiveEntitlement(in: profile)
        } catch {
            hasActiveEntitlement = false
        }
    }

    func loadPaywallConfiguration(preferences: UserWinePreferences? = nil) async {
        guard isConfigured else { return }

        let customAttributes = Self.paywallCustomAttributes(for: preferences)
        if paywallConfiguration != nil, loadedPaywallCustomAttributes == customAttributes {
            return
        }

        purchaseErrorMessage = nil

        do {
            if let customAttributes {
                try await Self.updateProfile(with: customAttributes)
            }

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
            loadedPaywallCustomAttributes = customAttributes
        } catch {
            paywallConfiguration = nil
            loadedPaywallCustomAttributes = nil
            Self.logPaywallError(error, context: "load paywall \(AppConfiguration.shared.adaptyPaywallPlacementID)")
            #if DEBUG
            purchaseErrorMessage = String(localized: .paywallErrorLoadFailedDebug(AppConfiguration.shared.adaptyPaywallPlacementID, Self.debugDescription(for: error)))
            #else
            purchaseErrorMessage = String(localized: .paywallErrorLoadFailed)
            #endif
        }
    }

    private func loadPaywallConfigurationIfNeeded() async {
        guard hasActiveEntitlement == false else { return }

        await loadPaywallConfiguration()
    }

    func restorePurchases() async throws {
        isPurchaseInProgress = true
        purchaseErrorMessage = nil
        purchaseStatusMessage = nil
        defer { isPurchaseInProgress = false }

        let profile = try await Adapty.restorePurchases()
        hasActiveEntitlement = Self.hasActiveEntitlement(in: profile)

        if hasActiveEntitlement {
            purchaseStatusMessage = String(localized: .paywallStatusPurchasesRestored)
        } else {
            purchaseErrorMessage = String(localized: .paywallErrorNoActiveSubscription)
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
            purchaseStatusMessage = String(localized: .paywallStatusPurchasePending)
        case .userCancelled:
            break
        }
    }

    func failPurchase() {
        isPurchaseInProgress = false
        purchaseErrorMessage = String(localized: .paywallErrorPurchaseFailed)
    }

    func finishRestore(_ profile: AdaptyProfile) {
        isPurchaseInProgress = false
        hasActiveEntitlement = Self.hasActiveEntitlement(in: profile)

        if hasActiveEntitlement {
            purchaseStatusMessage = String(localized: .paywallStatusPurchasesRestored)
        } else {
            purchaseErrorMessage = String(localized: .paywallErrorNoActiveSubscription)
        }
    }

    func failRestore() {
        isPurchaseInProgress = false
        purchaseErrorMessage = String(localized: .paywallErrorRestoreFailed)
    }

    func failRendering() {
        purchaseErrorMessage = String(localized: .paywallErrorRenderFailed)
    }

    private static func hasActiveEntitlement(in profile: AdaptyProfile) -> Bool {
        profile.accessLevels[AppConfiguration.shared.paidAccessLevelID]?.isActive == true
    }

    private static func paywallCustomAttributes(for preferences: UserWinePreferences?) -> [String: String]? {
        guard let preferences else { return nil }

        return [
            "ONBOARDING_CHOICE_STYLE": preferences.choiceStyleValue.rawValue,
            "ONBOARDING_PURCHASE_PREFERENCE": preferences.usualPurchasePreferenceValue.rawValue,
        ]
    }

    private static func updateProfile(with customAttributes: [String: String]) async throws {
        let builder = AdaptyProfileParameters.Builder()
        for (key, value) in customAttributes {
            try builder.with(customAttribute: value, forKey: key)
        }

        try await Adapty.updateProfile(params: builder.build())
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
