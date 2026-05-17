//
//  AuditLogService.swift
//  HomekitControl
//
//  Tamper-Evident Audit Log — hash-chained log with SHA-256 integrity,
//  SQLite write-only storage, biometric confirmation for high-security ops,
//  and signed JSON export.
//
//  Enterprise Feature: Cryptographic audit trail for all device operations.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import CryptoKit
import SwiftUI
import SQLite3
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

// MARK: - Audit Event Models

enum AuditEventSeverity: String, Codable, CaseIterable {
    case info = "Info"
    case warning = "Warning"
    case critical = "Critical"
    case security = "Security"

    var color: Color {
        switch self {
        case .info: return .secondary
        case .warning: return ModernColors.yellow
        case .critical: return ModernColors.red
        case .security: return ModernColors.purple
        }
    }

    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "exclamationmark.octagon"
        case .security: return "lock.shield"
        }
    }
}

enum AuditEventCategory: String, Codable, CaseIterable {
    case deviceControl = "Device Control"
    case sceneExecution = "Scene Execution"
    case automationRun = "Automation"
    case securityChange = "Security Change"
    case lockOperation = "Lock Operation"
    case configChange = "Configuration"
    case accessGrant = "Access Grant"
    case accessRevoke = "Access Revoke"
    case systemEvent = "System Event"
}

struct AuditEvent: Codable, Identifiable {
    let id: UUID
    let sequence: Int64
    let timestamp: Date
    let category: AuditEventCategory
    let severity: AuditEventSeverity
    let description: String
    let deviceId: UUID?
    let deviceName: String?
    let userId: String?
    let metadata: [String: String]
    /// SHA-256 hash of (previousHash + sequence + timestamp + description)
    let hash: String
    /// Hash of the previous event in the chain
    let previousHash: String
    /// Whether biometric auth was required and confirmed for this operation
    let biometricConfirmed: Bool
}

struct AuditExport: Codable {
    let version: Int
    let exportDate: Date
    let deviceId: String
    let eventCount: Int
    let events: [AuditEvent]
    /// SHA-256 signature of the entire events array (for integrity verification)
    let integrityHash: String
}

// MARK: - Audit Log Service

@MainActor
class AuditLogService: ObservableObject {
    static let shared = AuditLogService()

    // MARK: - Published Properties

    @Published var recentEvents: [AuditEvent] = []
    @Published var totalEventCount: Int64 = 0
    @Published var chainValid = true
    @Published var lastVerification: Date?

    // MARK: - Private Properties

    private var db: OpaquePointer?
    private let dbPath: String
    private var lastHash: String = "GENESIS"
    private var currentSequence: Int64 = 0
    private let maxRecentEvents = 100

    // Categories that require biometric confirmation
    private let highSecurityCategories: Set<AuditEventCategory> = [
        .lockOperation, .securityChange, .accessGrant, .accessRevoke
    ]

    // MARK: - Initialization

    private init() {
        // Store in app's Application Support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("HomekitControl", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        dbPath = appDir.appendingPathComponent("audit_log.sqlite").path

        openDatabase()
        createTable()
        loadState()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Database Setup

    private func openDatabase() {
        // Open with SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            NSLog("[AuditLog] Failed to open database: \(String(cString: sqlite3_errmsg(db)))")
        }

        // Enable WAL mode for performance
        execute("PRAGMA journal_mode=WAL")
        // Ensure data integrity
        execute("PRAGMA synchronous=FULL")
    }

    private func createTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS audit_events (
            sequence INTEGER PRIMARY KEY,
            id TEXT NOT NULL UNIQUE,
            timestamp REAL NOT NULL,
            category TEXT NOT NULL,
            severity TEXT NOT NULL,
            description TEXT NOT NULL,
            device_id TEXT,
            device_name TEXT,
            user_id TEXT,
            metadata TEXT,
            hash TEXT NOT NULL,
            previous_hash TEXT NOT NULL,
            biometric_confirmed INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_events(timestamp);
        CREATE INDEX IF NOT EXISTS idx_audit_category ON audit_events(category);
        CREATE INDEX IF NOT EXISTS idx_audit_severity ON audit_events(severity);
        CREATE INDEX IF NOT EXISTS idx_audit_device ON audit_events(device_id);
        """
        execute(sql)
    }

    private func loadState() {
        // Get the last event's hash and sequence
        var stmt: OpaquePointer?
        let sql = "SELECT sequence, hash FROM audit_events ORDER BY sequence DESC LIMIT 1"

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                currentSequence = sqlite3_column_int64(stmt, 0)
                if let hashPtr = sqlite3_column_text(stmt, 1) {
                    lastHash = String(cString: hashPtr)
                }
            }
        }
        sqlite3_finalize(stmt)

        // Count total events
        totalEventCount = currentSequence

        // Load recent events for display
        loadRecentEvents()
    }

    // MARK: - Logging Events

    /// Log an audit event. High-security operations require biometric confirmation.
    func logEvent(
        category: AuditEventCategory,
        severity: AuditEventSeverity = .info,
        description: String,
        deviceId: UUID? = nil,
        deviceName: String? = nil,
        userId: String? = nil,
        metadata: [String: String] = [:],
        requireBiometric: Bool? = nil
    ) async -> Bool {
        // Determine if biometric is needed
        let needsBiometric = requireBiometric ?? highSecurityCategories.contains(category)
        var biometricConfirmed = false

        if needsBiometric {
            biometricConfirmed = await requestBiometricAuth(reason: "Confirm \(category.rawValue): \(description)")
            if !biometricConfirmed && severity == .security {
                // Security events MUST be confirmed — log the attempt but mark it
                let failEvent = buildEvent(
                    category: .systemEvent,
                    severity: .warning,
                    description: "Biometric confirmation FAILED for: \(description)",
                    deviceId: deviceId,
                    deviceName: deviceName,
                    userId: userId,
                    metadata: ["originalCategory": category.rawValue, "rejected": "true"],
                    biometricConfirmed: false
                )
                insertEvent(failEvent)
                return false
            }
        }

        let event = buildEvent(
            category: category,
            severity: severity,
            description: description,
            deviceId: deviceId,
            deviceName: deviceName,
            userId: userId,
            metadata: metadata,
            biometricConfirmed: biometricConfirmed
        )

        insertEvent(event)
        return true
    }

    /// Log without biometric (for non-security events called from sync contexts)
    func logEventSync(
        category: AuditEventCategory,
        severity: AuditEventSeverity = .info,
        description: String,
        deviceId: UUID? = nil,
        deviceName: String? = nil,
        metadata: [String: String] = [:]
    ) {
        let event = buildEvent(
            category: category,
            severity: severity,
            description: description,
            deviceId: deviceId,
            deviceName: deviceName,
            userId: nil,
            metadata: metadata,
            biometricConfirmed: false
        )
        insertEvent(event)
    }

    private func buildEvent(
        category: AuditEventCategory,
        severity: AuditEventSeverity,
        description: String,
        deviceId: UUID?,
        deviceName: String?,
        userId: String?,
        metadata: [String: String],
        biometricConfirmed: Bool
    ) -> AuditEvent {
        currentSequence += 1
        let timestamp = Date()

        // Build hash chain: SHA-256(previousHash + sequence + timestamp + description)
        let hashInput = "\(lastHash)|\(currentSequence)|\(timestamp.timeIntervalSince1970)|\(description)"
        let hash = SHA256.hash(data: Data(hashInput.utf8)).map { String(format: "%02x", $0) }.joined()

        let event = AuditEvent(
            id: UUID(),
            sequence: currentSequence,
            timestamp: timestamp,
            category: category,
            severity: severity,
            description: description,
            deviceId: deviceId,
            deviceName: deviceName,
            userId: userId,
            metadata: metadata,
            hash: hash,
            previousHash: lastHash,
            biometricConfirmed: biometricConfirmed
        )

        lastHash = hash
        return event
    }

    private func insertEvent(_ event: AuditEvent) {
        let sql = """
        INSERT INTO audit_events (sequence, id, timestamp, category, severity, description,
            device_id, device_name, user_id, metadata, hash, previous_hash, biometric_confirmed)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }

        sqlite3_bind_int64(stmt, 1, event.sequence)
        sqlite3_bind_text(stmt, 2, (event.id.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 3, event.timestamp.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 4, (event.category.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 5, (event.severity.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 6, (event.description as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 7, (event.deviceId?.uuidString as NSString?)?.utf8String, -1, nil)
        sqlite3_bind_text(stmt, 8, (event.deviceName as NSString?)?.utf8String, -1, nil)
        sqlite3_bind_text(stmt, 9, (event.userId as NSString?)?.utf8String, -1, nil)

        if let metadataJson = try? JSONEncoder().encode(event.metadata) {
            sqlite3_bind_text(stmt, 10, (String(data: metadataJson, encoding: .utf8)! as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_text(stmt, 10, "{}", -1, nil)
        }

        sqlite3_bind_text(stmt, 11, (event.hash as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 12, (event.previousHash as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 13, event.biometricConfirmed ? 1 : 0)

        if sqlite3_step(stmt) != SQLITE_DONE {
            NSLog("[AuditLog] Insert failed: \(String(cString: sqlite3_errmsg(db)))")
        }

        sqlite3_finalize(stmt)

        totalEventCount = currentSequence
        recentEvents.insert(event, at: 0)
        if recentEvents.count > maxRecentEvents {
            recentEvents = Array(recentEvents.prefix(maxRecentEvents))
        }
    }

    // MARK: - Chain Verification

    /// Verify the integrity of the entire hash chain
    func verifyChain() -> Bool {
        var stmt: OpaquePointer?
        let sql = "SELECT sequence, timestamp, description, hash, previous_hash FROM audit_events ORDER BY sequence ASC"

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }

        var expectedPreviousHash = "GENESIS"
        var isValid = true

        while sqlite3_step(stmt) == SQLITE_ROW {
            let sequence = sqlite3_column_int64(stmt, 0)
            let timestamp = sqlite3_column_double(stmt, 1)
            let descPtr = sqlite3_column_text(stmt, 2)
            let hashPtr = sqlite3_column_text(stmt, 3)
            let prevHashPtr = sqlite3_column_text(stmt, 4)

            guard let descPtr, let hashPtr, let prevHashPtr else { continue }

            let description = String(cString: descPtr)
            let storedHash = String(cString: hashPtr)
            let storedPrevHash = String(cString: prevHashPtr)

            // Verify previous hash matches
            if storedPrevHash != expectedPreviousHash {
                NSLog("[AuditLog] Chain broken at sequence \(sequence): previous hash mismatch")
                isValid = false
                break
            }

            // Recompute hash and verify
            let hashInput = "\(expectedPreviousHash)|\(sequence)|\(timestamp)|\(description)"
            let computedHash = SHA256.hash(data: Data(hashInput.utf8)).map { String(format: "%02x", $0) }.joined()

            if computedHash != storedHash {
                NSLog("[AuditLog] Chain broken at sequence \(sequence): hash mismatch")
                isValid = false
                break
            }

            expectedPreviousHash = storedHash
        }

        sqlite3_finalize(stmt)

        chainValid = isValid
        lastVerification = Date()
        return isValid
    }

    // MARK: - Export

    /// Export the audit log as signed JSON
    func exportSignedJSON(from: Date? = nil, to: Date? = nil) -> Data? {
        var events: [AuditEvent] = []

        var sql = "SELECT * FROM audit_events"
        var conditions: [String] = []

        if let from {
            conditions.append("timestamp >= \(from.timeIntervalSince1970)")
        }
        if let to {
            conditions.append("timestamp <= \(to.timeIntervalSince1970)")
        }

        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY sequence ASC"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }

        while sqlite3_step(stmt) == SQLITE_ROW {
            if let event = parseRow(stmt) {
                events.append(event)
            }
        }
        sqlite3_finalize(stmt)

        // Compute integrity hash over all events
        let eventsData = (try? JSONEncoder().encode(events)) ?? Data()
        let integrityHash = SHA256.hash(data: eventsData).map { String(format: "%02x", $0) }.joined()

        let export = AuditExport(
            version: 1,
            exportDate: Date(),
            deviceId: KeychainService.shared.load(key: "HomekitControl_DeviceId") ?? "unknown",
            eventCount: events.count,
            events: events,
            integrityHash: integrityHash
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(export)
    }

    /// Verify an exported JSON file's integrity
    func verifyExport(_ data: Data) -> Bool {
        guard let export = try? JSONDecoder().decode(AuditExport.self, from: data) else { return false }

        let eventsData = (try? JSONEncoder().encode(export.events)) ?? Data()
        let computedHash = SHA256.hash(data: eventsData).map { String(format: "%02x", $0) }.joined()

        return computedHash == export.integrityHash
    }

    // MARK: - Query

    func getEvents(category: AuditEventCategory? = nil, severity: AuditEventSeverity? = nil, limit: Int = 50) -> [AuditEvent] {
        var sql = "SELECT * FROM audit_events"
        var conditions: [String] = []

        if let category {
            conditions.append("category = '\(category.rawValue)'")
        }
        if let severity {
            conditions.append("severity = '\(severity.rawValue)'")
        }

        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY sequence DESC LIMIT \(limit)"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }

        var events: [AuditEvent] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let event = parseRow(stmt) {
                events.append(event)
            }
        }
        sqlite3_finalize(stmt)
        return events
    }

    // MARK: - Biometric Auth

    private func requestBiometricAuth(reason: String) async -> Bool {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            return false
        }
        #else
        return true
        #endif
    }

    // MARK: - Private Helpers

    private func parseRow(_ stmt: OpaquePointer?) -> AuditEvent? {
        guard let stmt else { return nil }

        let sequence = sqlite3_column_int64(stmt, 0)
        guard let idPtr = sqlite3_column_text(stmt, 1) else { return nil }
        let timestamp = sqlite3_column_double(stmt, 2)
        guard let catPtr = sqlite3_column_text(stmt, 3) else { return nil }
        guard let sevPtr = sqlite3_column_text(stmt, 4) else { return nil }
        guard let descPtr = sqlite3_column_text(stmt, 5) else { return nil }
        let deviceIdPtr = sqlite3_column_text(stmt, 6)
        let deviceNamePtr = sqlite3_column_text(stmt, 7)
        let userIdPtr = sqlite3_column_text(stmt, 8)
        let metadataPtr = sqlite3_column_text(stmt, 9)
        guard let hashPtr = sqlite3_column_text(stmt, 10) else { return nil }
        guard let prevHashPtr = sqlite3_column_text(stmt, 11) else { return nil }
        let biometric = sqlite3_column_int(stmt, 12)

        let idStr = String(cString: idPtr)
        let catStr = String(cString: catPtr)
        let sevStr = String(cString: sevPtr)

        guard let id = UUID(uuidString: idStr),
              let category = AuditEventCategory(rawValue: catStr),
              let severity = AuditEventSeverity(rawValue: sevStr) else { return nil }

        var metadata: [String: String] = [:]
        if let metadataPtr {
            let metaStr = String(cString: metadataPtr)
            if let data = metaStr.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
                metadata = decoded
            }
        }

        return AuditEvent(
            id: id,
            sequence: sequence,
            timestamp: Date(timeIntervalSince1970: timestamp),
            category: category,
            severity: severity,
            description: String(cString: descPtr),
            deviceId: deviceIdPtr.flatMap { UUID(uuidString: String(cString: $0)) },
            deviceName: deviceNamePtr.flatMap { String(cString: $0) },
            userId: userIdPtr.flatMap { String(cString: $0) },
            metadata: metadata,
            hash: String(cString: hashPtr),
            previousHash: String(cString: prevHashPtr),
            biometricConfirmed: biometric != 0
        )
    }

    private func loadRecentEvents() {
        recentEvents = getEvents(limit: maxRecentEvents)
    }

    @discardableResult
    private func execute(_ sql: String) -> Bool {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let errMsg {
                NSLog("[AuditLog] SQL error: \(String(cString: errMsg))")
                sqlite3_free(errMsg)
            }
            return false
        }
        return true
    }
}
