import Foundation
import Observation

@MainActor
@Observable
final class EntitlementManager {
    var hasActiveEntitlement = false
    var isLoading = true

    func configure() async {
        isLoading = false
    }

    func refreshEntitlement() async {
        isLoading = false
    }

    func restorePurchases() async throws {
        hasActiveEntitlement = true
        isLoading = false
    }

    func activatePlaceholderEntitlement() {
        hasActiveEntitlement = true
        isLoading = false
    }
}
