//
//  CodeVaultService.swift
//  HomekitControl
//
//  Service for securely storing HomeKit setup codes
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
#if canImport(Security)
import Security
#endif

/// Service for storing and managing HomeKit setup codes
@MainActor
final class CodeVaultService: ObservableObject {
    static let shared = CodeVaultService()

    // MARK: - Published Properties

    @Published var setupCodes: [SetupCode] = []
    @Published var isLoading = false
    @Published var statusMessage = ""

    // MARK: - Private Properties

    private let keychainService = "com.jordankoch.HomekitControl.CodeVault"
    private let storageKey = "setupCodes"

    // MARK: - Initialization

    private init() {
        loadCodes()
    }

    // MARK: - CRUD Operations

    func addCode(_ code: SetupCode) {
        setupCodes.append(code)
        saveCodes()
        statusMessage = "Added \(code.deviceName)"
        clearStatusMessage()
    }

    func updateCode(_ code: SetupCode) {
        if let index = setupCodes.firstIndex(where: { $0.id == code.id }) {
            var updatedCode = code
            updatedCode = SetupCode(
                id: code.id,
                deviceName: code.deviceName,
                code: code.code,
                manufacturer: code.manufacturer,
                category: code.category,
                photoPath: code.photoPath,
                photoData: code.photoData,
                room: code.room,
                notes: code.notes,
                createdAt: code.createdAt,
                updatedAt: Date(),
                serialNumber: code.serialNumber,
                model: code.model
            )
            setupCodes[index] = updatedCode
            saveCodes()
            statusMessage = "Updated \(code.deviceName)"
            clearStatusMessage()
        }
    }

    func deleteCode(_ code: SetupCode) {
        setupCodes.removeAll { $0.id == code.id }
        saveCodes()
        statusMessage = "Deleted \(code.deviceName)"
        clearStatusMessage()
    }

    func getCode(for deviceName: String) -> SetupCode? {
        setupCodes.first { $0.deviceName.lowercased() == deviceName.lowercased() }
    }

    // MARK: - Search

    func search(_ query: String) -> [SetupCode] {
        guard !query.isEmpty else { return setupCodes }
        let lowercased = query.lowercased()
        return setupCodes.filter {
            $0.deviceName.lowercased().contains(lowercased) ||
            $0.room?.lowercased().contains(lowercased) == true ||
            $0.manufacturer.rawValue.lowercased().contains(lowercased) ||
            $0.category.rawValue.lowercased().contains(lowercased)
        }
    }

    // MARK: - Storage

    private func saveCodes() {
        #if os(macOS) || os(iOS)
        saveToKeychain()
        #else
        saveToUserDefaults()
        #endif
    }

    private func loadCodes() {
        isLoading = true

        #if os(macOS) || os(iOS)
        loadFromKeychain()
        #else
        loadFromUserDefaults()
        #endif

        isLoading = false
    }

    // MARK: - Keychain Storage (iOS/macOS)

    #if os(macOS) || os(iOS)
    private func saveToKeychain() {
        guard let data = try? JSONEncoder().encode(setupCodes) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: storageKey
        ]

        // Delete existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        var newQuery = query
        newQuery[kSecValueData as String] = data
        SecItemAdd(newQuery as CFDictionary, nil)
    }

    private func loadFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: storageKey,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let codes = try? JSONDecoder().decode([SetupCode].self, from: data) {
            setupCodes = codes
        }
    }
    #endif

    // MARK: - UserDefaults Storage (tvOS fallback)

    private func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(setupCodes) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadFromUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let codes = try? JSONDecoder().decode([SetupCode].self, from: data) {
            setupCodes = codes
        }
    }

    // MARK: - Export/Import

    func exportCodes() -> Data? {
        try? JSONEncoder().encode(setupCodes)
    }

    func importCodes(from data: Data) throws {
        let codes = try JSONDecoder().decode([SetupCode].self, from: data)
        setupCodes.append(contentsOf: codes)
        saveCodes()
        statusMessage = "Imported \(codes.count) codes"
        clearStatusMessage()
    }

    // MARK: - Helpers

    private func clearStatusMessage() {
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            statusMessage = ""
        }
    }
}
