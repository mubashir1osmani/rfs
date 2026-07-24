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
    private static let service = Bundle.main.bundleIdentifier ?? "com.nori.assistant"

    static var openAIKey: String? { value(for: "openai-api-key") }

    static func setOpenAIKey(_ value: String) throws {
        try setValue(value, for: "openai-api-key")
    }

    static var googleCredentials: Data? { data(for: "google-oauth-credentials") }

    static func setGoogleCredentials(_ data: Data?) throws {
        try setData(data, for: "google-oauth-credentials")
    }

    private static func value(for account: String) -> String? {
        guard let data = data(for: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func data(for account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return data
    }

    private static func setValue(_ value: String, for account: String) throws {
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        try setData(cleanValue.isEmpty ? nil : Data(cleanValue.utf8), for: account)
    }

    private static func setData(_ data: Data?, for account: String) throws {
        let query = baseQuery(account: account)
        guard let data else {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw CredentialStoreError.keychainFailure(status)
            }
            return
        }

        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw CredentialStoreError.keychainFailure(updateStatus) }

        var newItem = query
        newItem.merge(attributes) { _, replacement in replacement }
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(newItem as CFDictionary, nil)
        guard status == errSecSuccess else { throw CredentialStoreError.keychainFailure(status) }
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
