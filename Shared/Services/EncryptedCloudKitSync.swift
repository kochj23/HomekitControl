//
//  EncryptedCloudKitSync.swift
//  HomekitControl
//
//  Encrypted CloudKit Sync — migrates sensitive data from UserDefaults to
//  encrypted CloudKit private database with CryptoKit AES-256-GCM.
//
//  Enterprise Feature: Secure cross-device sync with end-to-end encryption.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import CryptoKit
import SwiftUI

#if canImport(CloudKit)
import CloudKit
#endif

// MARK: - Encrypted Storage Models

struct EncryptedRecord: Codable, Identifiable {
    let id: UUID
    let recordType: SyncRecordType
    let encryptedData: Data
    let nonce: Data
    let tag: Data
    let lastModified: Date
    let deviceId: String

    enum SyncRecordType: String, Codable, CaseIterable {
        case automations = "Automations"
        case climateZones = "ClimateZones"
        case securityZones = "SecurityZones"
        case lightingProfiles = "LightingProfiles"
        case voiceCommands = "VoiceCommands"
        case deviceGroups = "DeviceGroups"
        case schedules = "Schedules"
    }
}

// MARK: - Sync Status

enum SyncStatus: String {
    case idle = "Idle"
    case syncing = "Syncing"
    case success = "Synced"
    case error = "Error"
    case offline = "Offline"
    case conflictResolution = "Resolving Conflicts"
}

struct SyncConflict: Identifiable {
    let id: UUID
    let recordType: EncryptedRecord.SyncRecordType
    let localModified: Date
    let remoteModified: Date
    let localData: Data
    let remoteData: Data
}

// MARK: - Encrypted CloudKit Sync Service

@MainActor
class EncryptedCloudKitSync: ObservableObject {
    static let shared = EncryptedCloudKitSync()

    // MARK: - Published Properties

    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var pendingChanges: Int = 0
    @Published var conflicts: [SyncConflict] = []
    @Published var iCloudAvailable = false

    // MARK: - Private Properties

    private let containerIdentifier = "iCloud.com.jordankoch.HomekitControl"
    private let encryptionKeyTag = "com.jordankoch.HomekitControl.syncKey"
    private let deviceId: String

    #if canImport(CloudKit)
    private var container: CKContainer?
    private var privateDatabase: CKDatabase?
    private var changeToken: CKServerChangeToken?
    #endif

    private var syncTimer: Timer?

    // MARK: - Initialization

    private init() {
        // Generate unique device identifier
        if let existing = KeychainService.shared.load(key: "HomekitControl_DeviceId") {
            deviceId = existing
        } else {
            let newId = UUID().uuidString
            KeychainService.shared.save(key: "HomekitControl_DeviceId", value: newId)
            deviceId = newId
        }

        #if canImport(CloudKit)
        setupCloudKit()
        #endif

        loadChangeToken()
    }

    // MARK: - Encryption

    /// Get or create the symmetric encryption key stored in Keychain
    private func getEncryptionKey() -> SymmetricKey {
        if let existingKeyData = KeychainService.shared.loadData(key: encryptionKeyTag) {
            return SymmetricKey(data: existingKeyData)
        }

        // Generate new AES-256 key
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        KeychainService.shared.save(key: encryptionKeyTag, data: keyData)
        return key
    }

    /// Encrypt data using AES-256-GCM
    func encrypt(_ data: Data) throws -> (ciphertext: Data, nonce: Data, tag: Data) {
        let key = getEncryptionKey()
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(data, using: key, nonce: nonce)

        guard let ciphertext = sealed.ciphertext as Data?,
              let tag = sealed.tag as Data? else {
            throw SyncError.encryptionFailed
        }

        return (ciphertext, Data(nonce), Data(tag))
    }

    /// Decrypt data using AES-256-GCM
    func decrypt(ciphertext: Data, nonce: Data, tag: Data) throws -> Data {
        let key = getEncryptionKey()
        let gcmNonce = try AES.GCM.Nonce(data: nonce)
        let sealedBox = try AES.GCM.SealedBox(nonce: gcmNonce, ciphertext: ciphertext, tag: tag)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - CloudKit Setup

    #if canImport(CloudKit)
    private func setupCloudKit() {
        container = CKContainer(identifier: containerIdentifier)
        privateDatabase = container?.privateCloudDatabase

        // Check iCloud availability
        container?.accountStatus { [weak self] status, error in
            Task { @MainActor in
                self?.iCloudAvailable = (status == .available)
                if status == .available {
                    self?.startAutoSync()
                }
            }
        }
    }
    #endif

    // MARK: - Sync Operations

    /// Start automatic background sync every 5 minutes
    func startAutoSync() {
        guard syncTimer == nil else { return }
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncAll()
            }
        }
    }

    func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    /// Sync all record types
    func syncAll() async {
        guard iCloudAvailable else {
            syncStatus = .offline
            return
        }

        syncStatus = .syncing

        do {
            // Push local changes
            try await pushLocalChanges()

            // Pull remote changes
            try await pullRemoteChanges()

            syncStatus = .success
            lastSyncDate = Date()
            pendingChanges = 0
        } catch {
            syncStatus = .error
            NSLog("[CloudKitSync] Sync failed: \(error.localizedDescription)")
        }
    }

    /// Push a specific record type to CloudKit
    func pushRecord(type: EncryptedRecord.SyncRecordType, data: Data) async throws {
        let (ciphertext, nonce, tag) = try encrypt(data)

        let record = EncryptedRecord(
            id: UUID(),
            recordType: type,
            encryptedData: ciphertext,
            nonce: nonce,
            tag: tag,
            lastModified: Date(),
            deviceId: deviceId
        )

        #if canImport(CloudKit)
        try await saveToCloudKit(record)
        #endif

        pendingChanges = max(0, pendingChanges - 1)
    }

    /// Pull and decrypt a specific record type
    func pullRecord(type: EncryptedRecord.SyncRecordType) async throws -> Data? {
        #if canImport(CloudKit)
        guard let record = try await fetchFromCloudKit(type: type) else { return nil }
        return try decrypt(ciphertext: record.encryptedData, nonce: record.nonce, tag: record.tag)
        #else
        return nil
        #endif
    }

    // MARK: - CloudKit CRUD

    #if canImport(CloudKit)
    private func saveToCloudKit(_ record: EncryptedRecord) async throws {
        guard let database = privateDatabase else { throw SyncError.databaseUnavailable }

        let ckRecord = CKRecord(recordType: "EncryptedData", recordID: CKRecord.ID(recordName: record.recordType.rawValue))
        ckRecord["encryptedData"] = record.encryptedData as NSData
        ckRecord["nonce"] = record.nonce as NSData
        ckRecord["tag"] = record.tag as NSData
        ckRecord["lastModified"] = record.lastModified as NSDate
        ckRecord["deviceId"] = record.deviceId as NSString

        do {
            try await database.save(ckRecord)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Conflict — handle with last-write-wins or prompt user
            try await handleConflict(record: record, serverRecord: error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord)
        }
    }

    private func fetchFromCloudKit(type: EncryptedRecord.SyncRecordType) async throws -> EncryptedRecord? {
        guard let database = privateDatabase else { throw SyncError.databaseUnavailable }

        let recordID = CKRecord.ID(recordName: type.rawValue)

        do {
            let ckRecord = try await database.record(for: recordID)

            guard let encryptedData = ckRecord["encryptedData"] as? Data,
                  let nonce = ckRecord["nonce"] as? Data,
                  let tag = ckRecord["tag"] as? Data,
                  let lastModified = ckRecord["lastModified"] as? Date,
                  let remoteDeviceId = ckRecord["deviceId"] as? String else {
                return nil
            }

            return EncryptedRecord(
                id: UUID(),
                recordType: type,
                encryptedData: encryptedData,
                nonce: nonce,
                tag: tag,
                lastModified: lastModified,
                deviceId: remoteDeviceId
            )
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private func pushLocalChanges() async throws {
        // Sync automations
        if let data = try? JSONEncoder().encode(AutomationService.shared.automations) {
            try await pushRecord(type: .automations, data: data)
        }

        // Sync climate zones
        if let data = try? JSONEncoder().encode(ClimateService.shared.zones) {
            try await pushRecord(type: .climateZones, data: data)
        }

        // Sync lighting profiles
        if let data = try? JSONEncoder().encode(AdaptiveLightingService.shared.profiles) {
            try await pushRecord(type: .lightingProfiles, data: data)
        }
    }

    private func pullRemoteChanges() async throws {
        guard let database = privateDatabase else { return }

        let query = CKQuery(recordType: "EncryptedData", predicate: NSPredicate(value: true))
        let (results, _) = try await database.records(matching: query)

        for (_, result) in results {
            if let record = try? result.get() {
                guard let encryptedData = record["encryptedData"] as? Data,
                      let nonce = record["nonce"] as? Data,
                      let tag = record["tag"] as? Data,
                      let remoteDeviceId = record["deviceId"] as? String else {
                    continue
                }

                // Skip our own records
                guard remoteDeviceId != deviceId else { continue }

                // Decrypt and merge
                if let decrypted = try? decrypt(ciphertext: encryptedData, nonce: nonce, tag: tag) {
                    await mergeRemoteData(recordName: record.recordID.recordName, data: decrypted)
                }
            }
        }
    }

    private func mergeRemoteData(recordName: String, data: Data) async {
        guard let type = EncryptedRecord.SyncRecordType(rawValue: recordName) else { return }

        switch type {
        case .automations:
            if let remote = try? JSONDecoder().decode([CustomAutomation].self, from: data) {
                // Merge: add automations that don't exist locally
                for automation in remote {
                    if !AutomationService.shared.automations.contains(where: { $0.id == automation.id }) {
                        AutomationService.shared.automations.append(automation)
                    }
                }
            }
        case .climateZones:
            if let remote = try? JSONDecoder().decode([ClimateZone].self, from: data) {
                for zone in remote {
                    if !ClimateService.shared.zones.contains(where: { $0.id == zone.id }) {
                        ClimateService.shared.zones.append(zone)
                    }
                }
            }
        case .lightingProfiles:
            if let remote = try? JSONDecoder().decode([LightingProfile].self, from: data) {
                for profile in remote {
                    if !AdaptiveLightingService.shared.profiles.contains(where: { $0.id == profile.id }) {
                        AdaptiveLightingService.shared.profiles.append(profile)
                    }
                }
            }
        default:
            break
        }
    }

    private func handleConflict(record: EncryptedRecord, serverRecord: CKRecord?) async throws {
        // Last-write-wins strategy: if our record is newer, overwrite
        if let serverModified = serverRecord?["lastModified"] as? Date,
           record.lastModified > serverModified,
           let database = privateDatabase {
            serverRecord?["encryptedData"] = record.encryptedData as NSData
            serverRecord?["nonce"] = record.nonce as NSData
            serverRecord?["tag"] = record.tag as NSData
            serverRecord?["lastModified"] = record.lastModified as NSDate
            serverRecord?["deviceId"] = record.deviceId as NSString

            if let updatedRecord = serverRecord {
                try await database.save(updatedRecord)
            }
        }
    }
    #endif

    // MARK: - Change Token Persistence

    private func loadChangeToken() {
        #if canImport(CloudKit)
        if let tokenData = UserDefaults.standard.data(forKey: "HomekitControl_CKChangeToken") {
            changeToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: tokenData)
        }
        #endif
    }

    private func saveChangeToken() {
        #if canImport(CloudKit)
        if let token = changeToken,
           let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: "HomekitControl_CKChangeToken")
        }
        #endif
    }
}

// MARK: - Errors

enum SyncError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case databaseUnavailable
    case recordNotFound
    case conflictUnresolved

    var errorDescription: String? {
        switch self {
        case .encryptionFailed: return "Failed to encrypt data for sync"
        case .decryptionFailed: return "Failed to decrypt synced data"
        case .databaseUnavailable: return "iCloud database unavailable"
        case .recordNotFound: return "Record not found in iCloud"
        case .conflictUnresolved: return "Sync conflict could not be resolved"
        }
    }
}
