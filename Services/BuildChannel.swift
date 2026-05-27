import Foundation
import StoreKit

enum BuildChannel {
    static func current() async -> String {
        #if DEBUG
        return "debug"
        #else
        do {
            let appTransaction = try await AppTransaction.shared.payloadValue
            switch appTransaction.environment {
            case .sandbox:
                return "testflight"
            case .production:
                return "appstore"
            default:
                return "release_unknown"
            }
        } catch {
            return "release_unknown"
        }
        #endif
    }
}
