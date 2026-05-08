import Foundation
import Security

enum AppIdentityServiceError: Error {
    case invalidStoredIdentifier
    case keychainReadFailed(OSStatus)
    case keychainWriteFailed(OSStatus)
}

struct AppIdentityService {
    static let shared = AppIdentityService()

    private let service = "com.getcorkwise.CorkWise.appIdentity"
    private let account = "keychainAppUserID"

    func appUserID() throws -> String {
        if let storedIdentifier = try storedAppUserID() {
            return storedIdentifier
        }

        let identifier = UUID().uuidString
        try storeAppUserID(identifier)
        return identifier
    }

    private func storedAppUserID() throws -> String? {
        var query = baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw AppIdentityServiceError.keychainReadFailed(status)
        }

        guard
            let data = item as? Data,
            let identifier = String(data: data, encoding: .utf8),
            UUID(uuidString: identifier) != nil
        else {
            throw AppIdentityServiceError.invalidStoredIdentifier
        }

        return identifier
    }

    private func storeAppUserID(_ identifier: String) throws {
        var query = baseQuery()
        query[kSecValueData as String] = Data(identifier.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            var attributes = [String: Any]()
            attributes[kSecValueData as String] = Data(identifier.utf8)
            let updateStatus = SecItemUpdate(baseQuery() as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw AppIdentityServiceError.keychainWriteFailed(updateStatus)
            }
            return
        }

        guard status == errSecSuccess else {
            throw AppIdentityServiceError.keychainWriteFailed(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
