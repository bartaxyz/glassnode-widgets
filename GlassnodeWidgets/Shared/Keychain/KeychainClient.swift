//
//  KeychainClient.swift
//  GlassnodeWidgets
//
//  Created by Assistant on 15/11/25.
//

import Foundation
import Security
internal import Combine

final class KeychainClient: ObservableObject {
    @Published var lastUpdated: Date = Date()

    enum KeychainError: Error, LocalizedError {
        case unhandledStatus(OSStatus)
        case invalidItemFormat
        case itemNotFound

        var errorDescription: String? {
            switch self {
            case .unhandledStatus(let status):
                return "Keychain error with status: \(status)"
            case .invalidItemFormat:
                return "Keychain item has invalid format"
            case .itemNotFound:
                return "Keychain item not found"
            }
        }
    }

    // MARK: - Read
    func readAPIKey() throws -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainConfig.service,
            kSecAttrAccount as String: KeychainConfig.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: true  // Look for synchronizable item
        ]

        if let accessGroup = KeychainConfig.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
            #if os(macOS)
            // On macOS, kSecUseDataProtectionKeychain is required when using kSecAttrAccessGroup with kSecAttrSynchronizable
            query[kSecUseDataProtectionKeychain as String] = true
            #endif
        }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unhandledStatus(status) }
        guard let data = result as? Data, let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidItemFormat
        }
        return string
    }

    // MARK: - Save (Add or Update)
    func saveAPIKey(_ key: String) throws {
        // Try update first
        var updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainConfig.service,
            kSecAttrAccount as String: KeychainConfig.account,
            kSecAttrSynchronizable as String: true  // Query for synchronizable item
        ]

        if let accessGroup = KeychainConfig.accessGroup {
            updateQuery[kSecAttrAccessGroup as String] = accessGroup
            #if os(macOS)
            // On macOS, kSecUseDataProtectionKeychain is required when using kSecAttrAccessGroup with kSecAttrSynchronizable
            updateQuery[kSecUseDataProtectionKeychain as String] = true
            #endif
        }

        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: key.data(using: .utf8) as Any,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock  // Update accessibility for existing keys
        ]

        let status = SecItemUpdate(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
        if status == errSecSuccess { return }
        if status != errSecItemNotFound && status != errSecNoSuchKeychain {
            throw KeychainError.unhandledStatus(status)
        }

        // Add new - with both access group and synchronizable for sharing + iCloud sync
        var addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainConfig.service,
            kSecAttrAccount as String: KeychainConfig.account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,  // Allows widget access when locked
            kSecAttrSynchronizable as String: true,  // Enable iCloud Keychain sync
            kSecValueData as String: key.data(using: .utf8) as Any
        ]

        if let accessGroup = KeychainConfig.accessGroup {
            addQuery[kSecAttrAccessGroup as String] = accessGroup
            #if os(macOS)
            // On macOS, kSecUseDataProtectionKeychain is required when using kSecAttrAccessGroup with kSecAttrSynchronizable
            addQuery[kSecUseDataProtectionKeychain as String] = true
            #endif
        }

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError.unhandledStatus(addStatus) }
    }

    // MARK: - Delete
    func deleteAPIKey() throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainConfig.service,
            kSecAttrAccount as String: KeychainConfig.account,
            kSecAttrSynchronizable as String: true  // Query for synchronizable item
        ]

        if let accessGroup = KeychainConfig.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
            #if os(macOS)
            // On macOS, kSecUseDataProtectionKeychain is required when using kSecAttrAccessGroup with kSecAttrSynchronizable
            query[kSecUseDataProtectionKeychain as String] = true
            #endif
        }

        let status = SecItemDelete(query as CFDictionary)
        if status == errSecItemNotFound { return }
        guard status == errSecSuccess else { throw KeychainError.unhandledStatus(status) }
    }

    // MARK: - Migration
    /// Migrate existing API key to use kSecAttrAccessibleAfterFirstUnlock
    /// This should be called once when the app launches to ensure widgets can access the key when locked
    func migrateAPIKeyAccessibility() throws {
        // Try to read the existing key
        guard let existingKey = try readAPIKey() else {
            // No key to migrate
            return
        }

        // Re-save the key, which will update it with the new accessibility setting
        try saveAPIKey(existingKey)
    }

    // MARK: - Anonimized Key
    static func anonymizedKey(_ key: String) -> String {
        guard key.count > 10 else { return String(repeating: "•", count: max(4, key.count)) }
        let prefix = key.prefix(4)
        let suffix = key.suffix(4)
        return "\(prefix)••••••••\(suffix)"
    }
}

