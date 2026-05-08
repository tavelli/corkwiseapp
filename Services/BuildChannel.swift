import Foundation

enum BuildChannel {
    static var current: String {
        #if DEBUG
        return "debug"
        #else
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            return "release_unknown"
        }

        if receiptURL.lastPathComponent == "sandboxReceipt",
           FileManager.default.fileExists(atPath: receiptURL.path) {
            return "testflight"
        }

        return "appstore"
        #endif
    }
}
