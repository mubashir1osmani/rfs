import Foundation
import Security

enum CredentialStoreError: LocalizedError {
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .keychainFailure(status):
            "Nori couldn’t update the secure credential (\(status))."
        }
    }
}

enum CredentialStore {
    private static let account = "backend-access-token"
    private static let service = Bundle.main.bundleIdentifier ?? "com.nori.assistant"

    static func appToken() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func setAppToken(_ token: String) throws {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else {
            let status = SecItemDelete(baseQuery as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw CredentialStoreError.keychainFailure(status)
            }
            return
        }

        let attributes: [String: Any] = [kSecValueData as String: Data(cleanToken.utf8)]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw CredentialStoreError.keychainFailure(updateStatus) }

        var newItem = baseQuery
        newItem.merge(attributes) { _, replacement in replacement }
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(newItem as CFDictionary, nil)
        guard status == errSecSuccess else { throw CredentialStoreError.keychainFailure(status) }
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
