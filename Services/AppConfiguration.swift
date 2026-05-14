import Foundation

struct AppConfiguration {
    static let shared = AppConfiguration()

    private let productionSupabaseBaseURL: URL?
    private let localSupabaseBaseURL: URL?
    private let supabaseAnonKey: String?
    private let adaptyPublicSDKKey: String?
    private let adaptyAccessLevelID: String
    private let adaptyPlacementID: String
    private let environment: ProcessInfo

    init(bundle: Bundle = .main, environment: ProcessInfo = .processInfo) {
        self.environment = environment
        productionSupabaseBaseURL = Self.urlValue(for: "CorkWiseSupabaseBaseURL", in: bundle)
        localSupabaseBaseURL = Self.urlValue(for: "CorkWiseLocalSupabaseBaseURL", in: bundle)
        supabaseAnonKey = Self.stringValue(for: "CorkWiseSupabaseAnonKey", in: bundle)
            ?? Self.stringValue(for: "CorkWiseSupabasePublishableKey", in: bundle)
        adaptyPublicSDKKey = Self.stringValue(for: "CorkWiseAdaptyPublicSDKKey", in: bundle)
        adaptyAccessLevelID = Self.stringValue(for: "CorkWiseAdaptyAccessLevelID", in: bundle) ?? "premium"
        adaptyPlacementID = Self.stringValue(for: "CorkWiseAdaptyPlacementID", in: bundle) ?? "onboarding"
    }

    var supabaseBaseURL: URL? {
        let environmentValues = Self.normalizedEnvironment(environment.environment)
        Self.logEnvironmentValue(
            environmentValues["CORKWISE_USE_LOCAL_SUPABASE"],
            key: "CORKWISE_USE_LOCAL_SUPABASE"
        )
        Self.logEnvironmentValue(
            environmentValues["CORKWISE_SUPABASE_BASE_URL_OVERRIDE"],
            key: "CORKWISE_SUPABASE_BASE_URL_OVERRIDE"
        )

        if let overrideURL = Self.urlValue(for: environmentValues["CORKWISE_SUPABASE_BASE_URL_OVERRIDE"]) {
            Self.logSelectedURL(overrideURL, source: "env override")
            return overrideURL
        }

        if Self.boolValue(for: environmentValues["CORKWISE_USE_LOCAL_SUPABASE"]) {
            let selectedURL = localSupabaseBaseURL ?? productionSupabaseBaseURL
            Self.logSelectedURL(selectedURL, source: "local flag")
            return selectedURL
        }

        Self.logSelectedURL(productionSupabaseBaseURL, source: "plist")
        return productionSupabaseBaseURL
    }

    var analysisEndpoint: URL? {
        supabaseBaseURL?.appending(path: "functions").appending(path: "v1").appending(path: "analyze-wine-menu")
    }

    var authEndpoint: URL? {
        supabaseBaseURL?.appending(path: "auth").appending(path: "v1")
    }

    var supabaseAPIKey: String? {
        let environmentValues = Self.normalizedEnvironment(environment.environment)
        if let overrideKey = Self.stringValue(for: environmentValues["CORKWISE_SUPABASE_API_KEY_OVERRIDE"]) {
            return overrideKey
        }

        return supabaseAnonKey
    }

    var authStorageKey: String {
        let baseValue = supabaseBaseURL?.absoluteString ?? "unconfigured"
        let normalizedValue = baseValue
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "_" }
        return "corkwise.supabase.auth.\(String(normalizedValue))"
    }

    var adaptySDKKey: String? {
        adaptyPublicSDKKey
    }

    var paidAccessLevelID: String {
        adaptyAccessLevelID
    }

    var adaptyPaywallPlacementID: String {
        adaptyPlacementID
    }
}

private extension AppConfiguration {
    static func urlValue(for key: String, in bundle: Bundle) -> URL? {
        guard let rawValue = bundle.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        return urlValue(for: rawValue)
    }

    static func stringValue(for key: String, in bundle: Bundle) -> String? {
        guard let rawValue = bundle.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        return stringValue(for: rawValue)
    }

    static func stringValue(for rawValue: String?) -> String? {
        guard let rawValue else { return nil }

        let trimmedValue = rawValue
            .removingInvisibleFormatCharacters()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else { return nil }
        return trimmedValue
    }

    static func urlValue(for rawValue: String?) -> URL? {
        guard let rawValue else { return nil }
        let trimmedValue = rawValue
            .removingInvisibleFormatCharacters()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else { return nil }
        return URL(string: trimmedValue)
    }

    static func boolValue(for rawValue: String?) -> Bool {
        guard let rawValue else { return false }

        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes":
            return true
        default:
            return false
        }
    }

    static func normalizedEnvironment(_ environment: [String: String]) -> [String: String] {
        environment.reduce(into: [:]) { result, entry in
            result[entry.key.removingInvisibleFormatCharacters()] = entry.value.removingInvisibleFormatCharacters()
        }
    }

    static func logSelectedURL(_ url: URL?, source: String) {
        #if DEBUG
        let displayValue = url?.absoluteString ?? "nil"
        print("AppConfiguration using Supabase URL (\(source)): \(displayValue)")
        #endif
    }

    static func logEnvironmentValue(_ value: String?, key: String) {
        #if DEBUG
        print("AppConfiguration env \(key): \(value ?? "nil")")
        #endif
    }
}

private extension String {
    func removingInvisibleFormatCharacters() -> String {
        String(unicodeScalars.filter { $0.properties.generalCategory != .format })
    }
}
