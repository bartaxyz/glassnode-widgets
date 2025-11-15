//
//  KeychainClient.swift
//  GlassnodeWidgets
//
//  Created by Assistant on 15/11/25.
//

import Foundation
import Security

struct KeychainClient {
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
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        if let accessGroup = KeychainConfig.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
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
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        if let accessGroup = KeychainConfig.accessGroup {
            updateQuery[kSecAttrAccessGroup as String] = accessGroup
        }

        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: key.data(using: .utf8) as Any
        ]

        let status = SecItemUpdate(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
        if status == errSecSuccess { return }
        if status != errSecItemNotFound && status != errSecNoSuchKeychain {
            throw KeychainError.unhandledStatus(status)
        }

        // Add new
        var addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainConfig.service,
            kSecAttrAccount as String: KeychainConfig.account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
            kSecValueData as String: key.data(using: .utf8) as Any
        ]
        if let accessGroup = KeychainConfig.accessGroup {
            addQuery[kSecAttrAccessGroup as String] = accessGroup
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
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        if let accessGroup = KeychainConfig.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)
        if status == errSecItemNotFound { return }
        guard status == errSecSuccess else { throw KeychainError.unhandledStatus(status) }
    }
}

