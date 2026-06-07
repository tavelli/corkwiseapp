import Foundation
import PostHog

final class AnalyticsService {
    static let shared = AnalyticsService()

    enum ScanInputType: String {
        case image
        case images
        case menuURL = "menu_url"
        case pdf
    }

    private enum Event: String {
        case appOpened = "app_opened"
        case onboardingCompleted = "onboarding_completed"
        case scanStarted = "scan_started"
        case scanCompleted = "scan_completed"
        case scanFailed = "scan_failed"
        case paywallShown = "paywall_shown"
        case softPaywallShown = "soft_paywall_shown"
        case softPaywallCTATapped = "soft_paywall_cta_tapped"
        case purchaseCompleted = "purchase_completed"
        case purchaseFailed = "purchase_failed"
        case purchaseCancelled = "purchase_cancelled"
        case restoreCompleted = "restore_completed"
        case restoreFailed = "restore_failed"
        case feedbackSubmitted = "feedback_submitted"
    }

    private let allowedPropertyKeys: Set<String> = [
        "app_version",
        "build_channel",
        "build_number",
        "bundle_id",
        "category_preference",
        "error_type",
        "has_active_entitlement",
        "has_free_scan_allowance",
        "has_retry_credit",
        "purchase_mode",
        "rating",
        "retry_granted",
        "source",
        "scan_input_type",
        "attachment_count",
    ]

    nonisolated private static let blockedPropertyKeyFragments = [
        "comment",
        "image",
        "email",
        "token",
    ]

    private var isConfigured = false
    private var hasTrackedAppOpened = false

    private init() {}

    func configure() async {
        guard isConfigured == false else { return }
        #if DEBUG
        guard Self.isDebugAnalyticsEnabled else { return }
        #endif
        guard
            let projectToken = AppConfiguration.shared.postHogProjectToken,
            let host = AppConfiguration.shared.postHogHost
        else {
            return
        }

        let config = PostHogConfig(projectToken: projectToken, host: host.absoluteString)
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        config.captureElementInteractions = false
        config.sessionReplay = false
        config.surveys = false
        #if DEBUG
        config.debug = true
        #endif
        config.setBeforeSend { event in
            Self.containsBlockedProperty(in: event.properties) ? nil : event
        }

        PostHogSDK.shared.setup(config)
        isConfigured = true

        do {
            let sharedProperties = sharedProperties(buildChannel: await BuildChannel.current())
            let appUserID = try AppIdentityService.shared.appUserID()
            PostHogSDK.shared.register(sharedProperties)
            PostHogSDK.shared.identify(
                appUserID,
                userProperties: sharedProperties
            )
        } catch {
            #if DEBUG
            print("AnalyticsService failed to identify PostHog user: \(error)")
            #endif
        }

        trackAppOpened()
    }

    func trackOnboardingCompleted() {
        capture(.onboardingCompleted)
    }

    func trackScanStarted(
        inputType: ScanInputType,
        attachmentCount: Int? = nil,
        purchaseMode: PurchaseMode,
        categoryPreference: WineCategoryPreference
    ) {
        capture(
            .scanStarted,
            properties: [
                "scan_input_type": inputType.rawValue,
                "attachment_count": attachmentCount,
                "purchase_mode": purchaseMode.rawValue,
                "category_preference": categoryPreference.rawValue,
            ]
        )
    }

    func trackScanCompleted(
        inputType: ScanInputType,
        attachmentCount: Int? = nil,
        purchaseMode: PurchaseMode,
        categoryPreference: WineCategoryPreference
    ) {
        capture(
            .scanCompleted,
            properties: [
                "scan_input_type": inputType.rawValue,
                "attachment_count": attachmentCount,
                "purchase_mode": purchaseMode.rawValue,
                "category_preference": categoryPreference.rawValue,
            ]
        )
    }

    func trackScanFailed(
        inputType: ScanInputType,
        attachmentCount: Int? = nil,
        purchaseMode: PurchaseMode,
        categoryPreference: WineCategoryPreference,
        error: Error
    ) {
        capture(
            .scanFailed,
            properties: [
                "scan_input_type": inputType.rawValue,
                "attachment_count": attachmentCount,
                "purchase_mode": purchaseMode.rawValue,
                "category_preference": categoryPreference.rawValue,
                "error_type": Self.errorType(for: error),
            ]
        )
    }

    func trackPaywallShown(
        source: String,
        hasActiveEntitlement: Bool,
        hasFreeScanAllowance: Bool,
        hasRetryCredit: Bool
    ) {
        var properties = entitlementProperties(
            hasActiveEntitlement: hasActiveEntitlement,
            hasFreeScanAllowance: hasFreeScanAllowance,
            hasRetryCredit: hasRetryCredit
        )
        properties["source"] = source
        capture(.paywallShown, properties: properties)
    }

    func trackSoftPaywallShown(source: String) {
        capture(.softPaywallShown, properties: ["source": source])
    }

    func trackSoftPaywallCTATapped(source: String) {
        capture(.softPaywallCTATapped, properties: ["source": source])
    }

    func trackPurchaseCompleted(hasActiveEntitlement: Bool) {
        capture(.purchaseCompleted, properties: ["has_active_entitlement": hasActiveEntitlement])
    }

    func trackPurchaseFailed(error: Error? = nil) {
        capture(.purchaseFailed, properties: ["error_type": error.map(Self.errorType(for:)) ?? "unknown"])
    }

    func trackPurchaseCancelled() {
        capture(.purchaseCancelled)
    }

    func trackRestoreCompleted(hasActiveEntitlement: Bool) {
        capture(.restoreCompleted, properties: ["has_active_entitlement": hasActiveEntitlement])
    }

    func trackRestoreFailed(error: Error? = nil) {
        capture(.restoreFailed, properties: ["error_type": error.map(Self.errorType(for:)) ?? "unknown"])
    }

    func trackFeedbackSubmitted(
        rating: AnalysisFeedbackRequest.Rating,
        source: String,
        retryGranted: Bool? = nil
    ) {
        capture(
            .feedbackSubmitted,
            properties: [
                "rating": rating.rawValue,
                "source": source,
                "retry_granted": retryGranted,
            ]
        )
    }

    private func trackAppOpened() {
        guard hasTrackedAppOpened == false else { return }
        hasTrackedAppOpened = true
        capture(.appOpened)
    }

    private func capture(_ event: Event, properties: [String: Any?] = [:]) {
        guard isConfigured else { return }

        let sanitizedProperties = properties.reduce(into: [String: Any]()) { result, entry in
            guard allowedPropertyKeys.contains(entry.key), let value = entry.value else { return }
            if let stringValue = value as? String {
                result[entry.key] = stringValue
            } else if let intValue = value as? Int {
                result[entry.key] = intValue
            } else if let boolValue = value as? Bool {
                result[entry.key] = boolValue
            }
        }

        PostHogSDK.shared.capture(event.rawValue, properties: sanitizedProperties)
    }

    private func sharedProperties(buildChannel: String) -> [String: Any] {
        let bundle = Bundle.main
        return [
            "app_version": bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build_number": bundle.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            "bundle_id": bundle.bundleIdentifier ?? "unknown",
            "build_channel": buildChannel,
        ]
    }

    private func entitlementProperties(
        hasActiveEntitlement: Bool,
        hasFreeScanAllowance: Bool,
        hasRetryCredit: Bool
    ) -> [String: Any?] {
        [
            "has_active_entitlement": hasActiveEntitlement,
            "has_free_scan_allowance": hasFreeScanAllowance,
            "has_retry_credit": hasRetryCredit,
        ]
    }

    nonisolated private static func containsBlockedProperty(in properties: [String: Any]) -> Bool {
        properties.contains { key, value in
            isBlockedPropertyKey(key) || containsBlockedNestedProperty(in: value)
        }
    }

    nonisolated private static func containsBlockedNestedProperty(in value: Any) -> Bool {
        if let dictionary = value as? [String: Any] {
            return containsBlockedProperty(in: dictionary)
        }

        if let array = value as? [Any] {
            return array.contains { containsBlockedNestedProperty(in: $0) }
        }

        return false
    }

    nonisolated private static func isBlockedPropertyKey(_ key: String) -> Bool {
        let normalizedKey = key
            .replacingOccurrences(of: "-", with: "_")
            .lowercased()

        if normalizedKey == "text" || normalizedKey.hasSuffix("_text") {
            return true
        }

        if normalizedKey == "url" || normalizedKey.hasSuffix("_url") || normalizedKey == "menuurl" {
            return true
        }

        return Self.blockedPropertyKeyFragments.contains { normalizedKey.contains($0) }
    }

    nonisolated private static func errorType(for error: Error) -> String {
        if let serviceError = error as? WineAnalysisServiceError {
            switch serviceError {
            case .backendNotConfigured:
                return "backend_not_configured"
            case .authorizationFailed:
                return "authorization_failed"
            case .entitlementRequired:
                return "entitlement_required"
            case .invalidInput:
                return "invalid_input"
            case .invalidResponse:
                return "invalid_response"
            case .requestFailed:
                return "request_failed"
            case .serverError(let response):
                return response.error
            }
        }

        if error is CancellationError {
            return "cancelled"
        }

        return String(describing: type(of: error))
    }

    #if DEBUG
    nonisolated private static var isDebugAnalyticsEnabled: Bool {
        let rawValue = ProcessInfo.processInfo.environment["CORKWISE_ANALYTICS_ENABLED"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return rawValue == "1" || rawValue == "true" || rawValue == "yes"
    }
    #endif
}
