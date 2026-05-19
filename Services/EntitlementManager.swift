import Adapty
import Foundation
import Observation

@MainActor
@Observable
final class EntitlementManager {
    var hasActiveEntitlement = false
    var hasFreeScanAllowance = false
    var freeScansUsed = 0
    var freeScanLimit = 0
    var isLoading = true
    var isScanAccessLoading = false
    var isConfigured = false
    var paywall: CustomPaywall?
    var isPurchaseInProgress = false
    var purchaseStatusMessage: String?
    var purchaseErrorMessage: String?
    private var loadedPaywallCustomAttributes: [String: String]?
    private var loggedPaywallInstanceIdentities = Set<String>()
    private let scanAccessService = ScanAccessService()

    var canScanWithoutPurchase: Bool {
        hasActiveEntitlement || hasFreeScanAllowance
    }

    var requiresPurchaseForScan: Bool {
        isLoading == false &&
            isScanAccessLoading == false &&
            canScanWithoutPurchase == false
    }

    func configure() async {
        isLoading = true
        defer { isLoading = false }

        if isConfigured {
            await refreshEntitlement(updatesLoadingState: false)
            await refreshScanAccess()
            return
        }

        guard let sdkKey = AppConfiguration.shared.adaptySDKKey else {
            isConfigured = false
            hasActiveEntitlement = false
            await refreshScanAccess()
            return
        }

        do {
            let appUserID = try AppIdentityService.shared.appUserID()
            let configurationBuilder = AdaptyConfiguration
                .builder(withAPIKey: sdkKey)
                .with(customerUserId: appUserID, withAppAccountToken: UUID(uuidString: appUserID))

            let configuration = configurationBuilder.build()
            try await Adapty.activate(with: configuration)
            isConfigured = true
            await refreshEntitlement(updatesLoadingState: false)
            await refreshScanAccess()
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

    @discardableResult
    func refreshScanAccess() async -> Bool {
        isScanAccessLoading = true
        defer { isScanAccessLoading = false }

        do {
            let access = try await scanAccessService.scanAccess()
            hasActiveEntitlement = access.hasActiveEntitlement
            hasFreeScanAllowance = access.hasFreeScanAllowance
            freeScansUsed = access.freeScansUsed
            freeScanLimit = access.freeScanLimit
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func refreshAccessForScanAttempt() async -> Bool {
        let didRefresh = await refreshScanAccess()
        if requiresPurchaseForScan {
            await loadPaywallIfNeeded()
        }
        return didRefresh
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
            if hasActiveEntitlement {
                hasFreeScanAllowance = false
            }
        } catch {
            hasActiveEntitlement = false
        }
    }

    func loadPaywall(preferences: UserWinePreferences? = nil) async {
        guard isConfigured else { return }

        let customAttributes = Self.paywallCustomAttributes(for: preferences)
        if paywall != nil, loadedPaywallCustomAttributes == customAttributes {
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
            #endif
            let products = try await Adapty.getPaywallProducts(paywall: paywall)
            guard let selectedProduct = Self.selectedProduct(from: products) else {
                throw CustomPaywallError.noProducts
            }

            self.paywall = CustomPaywall(
                paywall: paywall,
                product: selectedProduct,
                remoteConfig: .init(dictionary: paywall.remoteConfig?.dictionary)
            )
            loadedPaywallCustomAttributes = customAttributes
        } catch {
            paywall = nil
            loadedPaywallCustomAttributes = nil
            Self.logPaywallError(error, context: "load paywall \(AppConfiguration.shared.adaptyPaywallPlacementID)")
            #if DEBUG
            purchaseErrorMessage = String(localized: .paywallErrorLoadFailedDebug(AppConfiguration.shared.adaptyPaywallPlacementID, Self.debugDescription(for: error)))
            #else
            purchaseErrorMessage = String(localized: .paywallErrorLoadFailed)
            #endif
        }
    }

    private func loadPaywallIfNeeded() async {
        guard hasActiveEntitlement == false else { return }

        await loadPaywall()
    }

    func logPaywallShownIfNeeded() async {
        guard let paywall else { return }
        guard let adaptyPaywall = paywall.adaptyPaywall else { return }
        guard loggedPaywallInstanceIdentities.contains(paywall.id) == false else { return }

        do {
            try await Adapty.logShowPaywall(adaptyPaywall)
            loggedPaywallInstanceIdentities.insert(paywall.id)
        } catch {
            Self.logPaywallError(error, context: "log shown paywall \(paywall.id)")
        }
    }

    func purchaseSelectedPaywallProduct() async {
        guard let paywall else { return }

        startPurchase()

        do {
            let result = try await Adapty.makePurchase(product: paywall.product)
            finishPurchase(result)
        } catch {
            Self.logPaywallError(error, context: "purchase \(paywall.product.vendorProductId)")
            failPurchase()
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
            hasFreeScanAllowance = false
        }

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
            if hasActiveEntitlement {
                hasFreeScanAllowance = false
            }
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
            hasFreeScanAllowance = false
        }

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

    private static func selectedProduct(from products: [any AdaptyPaywallProduct]) -> (any AdaptyPaywallProduct)? {
        products.first { product in
            product.adaptyProductType.localizedCaseInsensitiveContains("annual") ||
                product.adaptyProductType.localizedCaseInsensitiveContains("year") ||
                product.subscriptionPeriod?.unit == .year
        } ?? products.first
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

struct CustomPaywall {
    let id: String
    let adaptyPaywall: AdaptyPaywall?
    let product: any AdaptyPaywallProduct
    let remoteConfig: CustomPaywallRemoteConfig

    init(paywall: AdaptyPaywall, product: any AdaptyPaywallProduct, remoteConfig: CustomPaywallRemoteConfig) {
        id = paywall.instanceIdentity
        adaptyPaywall = paywall
        self.product = product
        self.remoteConfig = remoteConfig
    }

    init(id: String, product: any AdaptyPaywallProduct, remoteConfig: CustomPaywallRemoteConfig) {
        self.id = id
        adaptyPaywall = nil
        self.product = product
        self.remoteConfig = remoteConfig
    }
}

struct CustomPaywallRemoteConfig {
    private static let fallbackCTAText = "Join Corkwise"

    let ctaText: String

    init(dictionary: [String: Any]?) {
        if let ctaText = dictionary?["cta_text"] as? String {
            let trimmedCTAText = ctaText.trimmingCharacters(in: .whitespacesAndNewlines)
            self.ctaText = trimmedCTAText.isEmpty ? Self.fallbackCTAText : trimmedCTAText
        } else {
            ctaText = Self.fallbackCTAText
        }
    }
}

private enum CustomPaywallError: LocalizedError {
    case noProducts

    var errorDescription: String? {
        "Adapty paywall returned no products."
    }
}
