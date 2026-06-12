import Foundation
import Observation

@MainActor
@Observable
final class AnalyticsPreferences {
    var isPostHogAnalyticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isPostHogAnalyticsEnabled, forKey: Self.postHogAnalyticsEnabledKey)
            AnalyticsService.shared.setPostHogAnalyticsEnabled(isPostHogAnalyticsEnabled)
        }
    }

    init(defaults: UserDefaults = .standard) {
        if defaults.object(forKey: Self.postHogAnalyticsEnabledKey) == nil {
            isPostHogAnalyticsEnabled = true
        } else {
            isPostHogAnalyticsEnabled = defaults.bool(forKey: Self.postHogAnalyticsEnabledKey)
        }
    }

    nonisolated static var isPostHogAnalyticsEnabled: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: postHogAnalyticsEnabledKey) != nil else { return true }
        return defaults.bool(forKey: postHogAnalyticsEnabledKey)
    }

    nonisolated private static let postHogAnalyticsEnabledKey = "postHogAnalyticsEnabled"
}
