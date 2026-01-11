//
//  PrivacyService.swift
//  rufus
//
//  Created for privacy and encryption features
//

import Foundation
import CryptoKit

@MainActor
class PrivacyService: ObservableObject {
    static let shared = PrivacyService()

    @Published var encryptionEnabled: Bool = false

    private let encryptionKey: SymmetricKey

    private init() {
        // Generate or retrieve encryption key from Keychain
        if let existingKey = PrivacyService.retrieveKeyFromKeychain() {
            self.encryptionKey = existingKey
        } else {
            self.encryptionKey = SymmetricKey(size: .bits256)
            PrivacyService.storeKeyInKeychain(self.encryptionKey)
        }
    }

    // MARK: - Encryption/Decryption

    func encrypt(_ data: String) -> String? {
        guard let dataToEncrypt = data.data(using: .utf8) else {
            return nil
        }

        do {
            let sealedBox = try AES.GCM.seal(dataToEncrypt, using: encryptionKey)
            guard let combined = sealedBox.combined else {
                return nil
            }
            return combined.base64EncodedString()
        } catch {
            print("Encryption error: \(error)")
            return nil
        }
    }

    func decrypt(_ encryptedString: String) -> String? {
        guard let data = Data(base64Encoded: encryptedString) else {
            return nil
        }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            print("Decryption error: \(error)")
            return nil
        }
    }

    // MARK: - Keychain Storage

    private static func storeKeyInKeychain(_ key: SymmetricKey) {
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "rufus_encryption_key",
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Delete any existing key first
        SecItemDelete(query as CFDictionary)

        // Add new key
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Failed to store encryption key in keychain")
        }
    }

    private static func retrieveKeyFromKeychain() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "rufus_encryption_key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let keyData = result as? Data else {
            return nil
        }

        return SymmetricKey(data: keyData)
    }

    // MARK: - Privacy Helpers

    func shouldSyncToCloud(isPrivate: Bool) -> Bool {
        return !isPrivate
    }

    func markItemAsPrivate() {
        // Helper method for UI
        encryptionEnabled = true
    }

    func getEncryptionStatus() -> EncryptionStatus {
        return encryptionEnabled ? .enabled : .disabled
    }

    enum EncryptionStatus: String {
        case enabled = "Enabled"
        case disabled = "Disabled"

        var icon: String {
            switch self {
            case .enabled: return "lock.fill"
            case .disabled: return "lock.open.fill"
            }
        }

        var color: String {
            switch self {
            case .enabled: return "#10B981"  // Green
            case .disabled: return "#6B7280"  // Gray
            }
        }
    }
}
