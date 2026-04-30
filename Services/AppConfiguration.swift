import Foundation

struct AppConfiguration {
    static let shared = AppConfiguration()

    private let productionSupabaseBaseURL: URL?
    private let localSupabaseBaseURL: URL?
    private let environment: ProcessInfo

    init(bundle: Bundle = .main, environment: ProcessInfo = .processInfo) {
        self.environment = environment
        productionSupabaseBaseURL = Self.urlValue(for: "CorkWiseSupabaseBaseURL", in: bundle)
        localSupabaseBaseURL = Self.urlValue(for: "CorkWiseLocalSupabaseBaseURL", in: bundle)
    }

    var supabaseBaseURL: URL? {
        if let overrideURL = Self.urlValue(for: environment.environment["CORKWISE_SUPABASE_BASE_URL_OVERRIDE"]) {
            Self.logSelectedURL(overrideURL, source: "env override")
            return overrideURL
        }

        if environment.environment["CORKWISE_USE_LOCAL_SUPABASE"] == "1" {
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
}

private extension AppConfiguration {
    static func urlValue(for key: String, in bundle: Bundle) -> URL? {
        guard let rawValue = bundle.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        return urlValue(for: rawValue)
    }

    static func urlValue(for rawValue: String?) -> URL? {
        guard let rawValue else { return nil }
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else { return nil }
        return URL(string: trimmedValue)
    }

    static func logSelectedURL(_ url: URL?, source: String) {
        #if DEBUG
        let displayValue = url?.absoluteString ?? "nil"
        print("AppConfiguration using Supabase URL (\(source)): \(displayValue)")
        #endif
    }
}
