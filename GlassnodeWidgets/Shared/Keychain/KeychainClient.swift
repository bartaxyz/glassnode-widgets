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
        case interactionNotAllowed  // Device is locked (error -25308)

        var errorDescription: String? {
            switch self {
            case .unhandledStatus(let status):
                return "Keychain error with status: \(status)"
            case .invalidItemFormat:
                return "Keychain item has invalid format"
            case .itemNotFound:
                return "Keychain item not found"
            case .interactionNotAllowed:
                return "Keychain item not accessible - device is locked"
            }
        }
    }

    // MARK: - Read
    func readAPIKey() throws -> String? {
        // First attempt: Try to read synchronizable item (preferred for iCloud sync)
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
        var status = SecItemCopyMatching(query as CFDictionary, &result)

        // If we get errSecInteractionNotAllowed (error -25308), the device is locked
        // and the keychain item has accessibility set to kSecAttrAccessibleWhenUnlocked.
        // This shouldn't happen after migration, but if it does, throw a specific error.
        if status == errSecInteractionNotAllowed {
            throw KeychainError.interactionNotAllowed
        }

        // If synchronizable item not found, try searching for any item (synchronizable or not)
        if status == errSecItemNotFound {
            // Fallback: Try to find ANY matching item (synchronizable or not)
            query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
            status = SecItemCopyMatching(query as CFDictionary, &result)

            // If we still get errSecInteractionNotAllowed, device is locked
            if status == errSecInteractionNotAllowed {
                throw KeychainError.interactionNotAllowed
            }

            if status == errSecItemNotFound {
                return nil  // No key exists
            }
        }

        guard status == errSecSuccess else { throw KeychainError.unhandledStatus(status) }
        guard let data = result as? Data, let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidItemFormat
        }
        return string
    }

    // MARK: - Save (Add or Update)
    func saveAPIKey(_ key: String) throws {
        // Try to delete any existing items first (both synchronizable and non-synchronizable)
        // This ensures we clean up old items with incorrect accessibility settings
        try? deleteAllMatchingItems()

        // Now add the new item with correct settings

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
        try deleteAllMatchingItems()
    }

    /// Delete all matching keychain items (both synchronizable and non-synchronizable)
    /// This is a helper to ensure we clean up legacy items with incorrect settings
    private func deleteAllMatchingItems() throws {
        // First, try to delete synchronizable items
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainConfig.service,
            kSecAttrAccount as String: KeychainConfig.account,
            kSecAttrSynchronizable as String: true
        ]

        if let accessGroup = KeychainConfig.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
            #if os(macOS)
            query[kSecUseDataProtectionKeychain as String] = true
            #endif
        }

        var status = SecItemDelete(query as CFDictionary)
        // Ignore "not found" errors - we just want to make sure it's deleted

        // Second, try to delete non-synchronizable items
        query[kSecAttrSynchronizable as String] = false
        status = SecItemDelete(query as CFDictionary)
        // Again, ignore "not found" errors

        // Finally, use kSecAttrSynchronizableAny to catch any remaining items
        query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        status = SecItemDelete(query as CFDictionary)

        // We don't throw errors here because we just want to ensure cleanup
        // The goal is to remove any legacy items, regardless of their attributes
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

