import Adapty
import Foundation
import Observation

@MainActor
@Observable
final class EntitlementManager {
    var hasActiveEntitlement = false
    var hasFreeScanAllowance = false
    var hasRetryCredit = false
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
        hasActiveEntitlement || hasFreeScanAllowance || hasRetryCredit
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
            try await Self.updateProfile(with: await Self.profileCustomAttributes(for: nil))
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
            hasRetryCredit = access.hasRetryCredit
            freeScansUsed = access.freeScansUsed
            freeScanLimit = access.freeScanLimit
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func refreshAccessForScanAttempt(preferences: UserWinePreferences? = nil) async -> Bool {
        let didRefresh = await refreshScanAccess()
        if hasActiveEntitlement == false {
            await loadPaywallIfNeeded(preferences: preferences)
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
                hasRetryCredit = false
            }
        } catch {
            hasActiveEntitlement = false
        }
    }

    @discardableResult
    func loadPaywall(preferences: UserWinePreferences? = nil) async -> Bool {
        guard isConfigured else { return false }

        let customAttributes = await Self.profileCustomAttributes(for: preferences)
        if paywall != nil, loadedPaywallCustomAttributes == customAttributes {
            return true
        }

        purchaseErrorMessage = nil
        
        do {
            try await Self.updateProfile(with: customAttributes)

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
            return true
        } catch {
            paywall = nil
            loadedPaywallCustomAttributes = nil
            Self.logPaywallError(error, context: "load paywall \(AppConfiguration.shared.adaptyPaywallPlacementID)")
            #if DEBUG
            purchaseErrorMessage = String(localized: .paywallErrorLoadFailedDebug(AppConfiguration.shared.adaptyPaywallPlacementID, Self.debugDescription(for: error)))
            #else
            purchaseErrorMessage = String(localized: .paywallErrorLoadFailed)
            #endif
            return false
        }
    }

    private func loadPaywallIfNeeded(preferences: UserWinePreferences? = nil) async {
        guard hasActiveEntitlement == false else { return }

        await loadPaywall(preferences: preferences)
    }

    func logPaywallShownIfNeeded(source: String) async {
        guard let paywall else { return }
        guard let adaptyPaywall = paywall.adaptyPaywall else { return }
        guard loggedPaywallInstanceIdentities.contains(paywall.id) == false else { return }

        do {
            try await Adapty.logShowPaywall(adaptyPaywall)
            loggedPaywallInstanceIdentities.insert(paywall.id)
            AnalyticsService.shared.trackPaywallShown(
                source: source,
                hasActiveEntitlement: hasActiveEntitlement,
                hasFreeScanAllowance: hasFreeScanAllowance,
                hasRetryCredit: hasRetryCredit
            )
        } catch {
            Self.logPaywallError(error, context: "log shown paywall \(paywall.id)")
        }
    }

    func purchaseSelectedPaywallProduct(source: String) async {
        guard let paywall else { return }

        AnalyticsService.shared.trackPaywallCTATapped(
            source: source,
            productPeriod: Self.productPeriod(for: paywall.product)
        )
        startPurchase()

        do {
            let result = try await Adapty.makePurchase(product: paywall.product)
            finishPurchase(result)
        } catch {
            Self.logPaywallError(error, context: "purchase \(paywall.product.vendorProductId)")
            AnalyticsService.shared.trackPurchaseFailed(error: error)
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
            hasRetryCredit = false
        }

        if hasActiveEntitlement {
            purchaseStatusMessage = String(localized: .paywallStatusPurchasesRestored)
        } else {
            purchaseErrorMessage = String(localized: .paywallErrorNoActiveSubscription)
        }
        AnalyticsService.shared.trackRestoreCompleted(hasActiveEntitlement: hasActiveEntitlement)
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
                hasRetryCredit = false
            }
            if hasActiveEntitlement {
                AnalyticsService.shared.trackPurchaseCompleted(hasActiveEntitlement: true)
            } else {
                AnalyticsService.shared.trackPurchaseFailed()
            }
            if hasActiveEntitlement == false {
                Task {
                    await refreshEntitlement()
                }
            }
        case .pending:
            purchaseStatusMessage = String(localized: .paywallStatusPurchasePending)
        case .userCancelled:
            AnalyticsService.shared.trackPurchaseCancelled()
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
            hasRetryCredit = false
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

    private static func productPeriod(for product: any AdaptyPaywallProduct) -> String {
        guard let subscriptionPeriod = product.subscriptionPeriod else {
            return "non_subscription"
        }

        switch (subscriptionPeriod.unit, subscriptionPeriod.numberOfUnits) {
        case (.week, 1):
            return "weekly"
        case (.month, 1):
            return "monthly"
        case (.year, 1):
            return "yearly"
        case (.day, _), (.week, _), (.month, _), (.year, _), (.unknown, _):
            return "unknown"
        }
    }

    private static func profileCustomAttributes(for preferences: UserWinePreferences?) async -> [String: String] {
        var customAttributes = [
            "BUILD_CONFIG": await BuildChannel.current(),
        ]

        if let preferences {
            customAttributes["ONBOARDING_CHOICE_STYLE"] = preferences.choiceStyleValue.rawValue
            customAttributes["ONBOARDING_PURCHASE_PREFERENCE"] = preferences.usualPurchasePreferenceValue.rawValue
        }

        return customAttributes
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
    private static let fallbackEyebrowText = String(localized: .paywallFallbackEyebrow)
    private static let fallbackHeadlineText = String(localized: .paywallFallbackHeadline)
    private static let fallbackSubheadlineText = String(localized: .paywallFallbackSubheadline)
    private static let fallbackCTAText = String(localized: .paywallFallbackCta)
    private static let fallbackBenefitText = String(localized: .paywallFullWineListAnalysis)

    let eyebrowText: String
    let headlineText: String
    let subheadlineText: String
    let ctaText: String
    let benefitText: String
    let productTitleText: String?
    let productDescriptionText: String?

    init(dictionary: [String: Any]?) {
        eyebrowText = Self.stringValue(
            forKey: "eyebrow_text",
            in: dictionary,
            fallback: Self.fallbackEyebrowText
        )
        headlineText = Self.stringValue(
            forKey: "headline_text",
            in: dictionary,
            fallback: Self.fallbackHeadlineText
        )
        subheadlineText = Self.stringValue(
            forKey: "subheadline_text",
            in: dictionary,
            fallback: Self.fallbackSubheadlineText
        )
        ctaText = Self.stringValue(
            forKey: "cta_text",
            in: dictionary,
            fallback: Self.fallbackCTAText
        )
        benefitText = Self.stringValue(
            forKey: "benefit_text",
            in: dictionary,
            fallback: Self.fallbackBenefitText
        )
        productTitleText = Self.stringValue(forKey: "product_title_text", in: dictionary)
        productDescriptionText = Self.stringValue(forKey: "product_description_text", in: dictionary)
    }

    private static func stringValue(forKey key: String, in dictionary: [String: Any]?, fallback: String) -> String {
        guard let trimmedValue = stringValue(forKey: key, in: dictionary) else { return fallback }
        return trimmedValue
    }

    private static func stringValue(forKey key: String, in dictionary: [String: Any]?) -> String? {
        guard let value = dictionary?[key] as? String else { return nil }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

private enum CustomPaywallError: LocalizedError {
    case noProducts

    var errorDescription: String? {
        "Adapty paywall returned no products."
    }
}
