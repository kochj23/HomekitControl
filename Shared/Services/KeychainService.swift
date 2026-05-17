//
//  KeychainService.swift
//  HomekitControl
//
//  Secure Keychain storage for all credentials and tokens
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Security

/// Thread-safe Keychain wrapper for storing secrets securely.
/// All API keys, tokens, and credentials MUST use this service.
final class KeychainService {
    static let shared = KeychainService()

    private let serviceName = "com.jordankoch.HomekitControl"

    private init() {}

    // MARK: - Public API

    /// Save a string value to Keychain
    @discardableResult
    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return save(key: key, data: data)
    }

    /// Save raw data to Keychain
    @discardableResult
    func save(key: String, data: Data) -> Bool {
        // Delete existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Load a string value from Keychain
    func load(key: String) -> String? {
        guard let data = loadData(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Load raw data from Keychain
    func loadData(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Update existing Keychain item
    @discardableResult
    func update(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            return save(key: key, value: value)
        }

        return status == errSecSuccess
    }

    /// Delete a Keychain item
    @discardableResult
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Check if a key exists in Keychain
    func exists(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

// MARK: - Keychain Keys

extension KeychainService {
    enum Keys {
        static let openAIKey = "HomekitControl_OpenAI_APIKey"
        static let claudeKey = "HomekitControl_Claude_APIKey"
        static let novaAPIToken = "HomekitControl_Nova_APIToken"
        static let cloudKitSyncToken = "HomekitControl_CloudKit_SyncToken"
        static let auditLogSigningKey = "HomekitControl_AuditLog_SigningKey"
    }
}
