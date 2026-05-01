//
//  GuestAccessTests.swift
//  HomekitControlTests
//
//  Tests for GuestAccess model — access code generation, expiration, and validation.
//  Security-critical: a bug here could grant unauthorized access to physical devices.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

final class GuestAccessTests: XCTestCase {

    // MARK: - Access Code Generation

    func test_generateAccessCode_isSixCharacters() {
        let code = GuestAccess.generateAccessCode()
        XCTAssertEqual(code.count, 6)
    }

    func test_generateAccessCode_containsOnlyAllowedCharacters() {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        for _ in 0..<100 { // Run many times for randomness coverage
            let code = GuestAccess.generateAccessCode()
            for char in code.unicodeScalars {
                XCTAssertTrue(allowed.contains(char),
                              "Code '\(code)' contains disallowed character '\(char)'")
            }
        }
    }

    func test_generateAccessCode_excludesConfusingCharacters() {
        // The allowed set "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" excludes:
        // 0 (confused with O), 1 (confused with I/L), I (confused with 1/L), O (confused with 0)
        // Note: L is intentionally INCLUDED in the allowed set
        let excluded = CharacterSet(charactersIn: "0OoIi1")
        for _ in 0..<100 {
            let code = GuestAccess.generateAccessCode()
            for char in code.unicodeScalars {
                XCTAssertFalse(excluded.contains(char),
                               "Code '\(code)' contains excluded character '\(char)'")
            }
        }
    }

    func test_generateAccessCode_isUnique() {
        var codes = Set<String>()
        for _ in 0..<100 {
            codes.insert(GuestAccess.generateAccessCode())
        }
        // Statistically, 100 random 6-char codes should all be unique
        // (there are 32^6 = ~1 billion possible codes)
        XCTAssertEqual(codes.count, 100,
                       "Generated duplicate access codes — randomness may be insufficient")
    }

    // MARK: - Initialization

    func test_guestAccess_init_defaults() {
        let guest = GuestAccess(name: "John")
        XCTAssertEqual(guest.name, "John")
        XCTAssertEqual(guest.accessCode.count, 6)
        XCTAssertTrue(guest.allowedDeviceIds.isEmpty)
        XCTAssertTrue(guest.allowedSceneIds.isEmpty)
        XCTAssertTrue(guest.isActive)
        XCTAssertNil(guest.expiresAt)
        XCTAssertNil(guest.lastUsed)
        XCTAssertEqual(guest.usageCount, 0)
    }

    func test_guestAccess_init_withExpiry() {
        let expiry = Date().addingTimeInterval(3600) // 1 hour
        let guest = GuestAccess(name: "Jane", expiresAt: expiry)
        XCTAssertNotNil(guest.expiresAt)
        XCTAssertEqual(guest.expiresAt!.timeIntervalSince1970, expiry.timeIntervalSince1970, accuracy: 1.0)
    }

    // MARK: - Expiration

    func test_isExpired_noExpiry_returnsFalse() {
        let guest = GuestAccess(name: "Guest")
        XCTAssertFalse(guest.isExpired)
    }

    func test_isExpired_futureExpiry_returnsFalse() {
        let guest = GuestAccess(name: "Guest", expiresAt: Date().addingTimeInterval(3600))
        XCTAssertFalse(guest.isExpired)
    }

    func test_isExpired_pastExpiry_returnsTrue() {
        let guest = GuestAccess(name: "Guest", expiresAt: Date().addingTimeInterval(-3600))
        XCTAssertTrue(guest.isExpired)
    }

    // MARK: - Validity

    func test_isValid_activeNotExpired_returnsTrue() {
        var guest = GuestAccess(name: "Guest")
        guest.isActive = true
        XCTAssertTrue(guest.isValid)
    }

    func test_isValid_inactive_returnsFalse() {
        var guest = GuestAccess(name: "Guest")
        guest.isActive = false
        XCTAssertFalse(guest.isValid)
    }

    func test_isValid_activeButExpired_returnsFalse() {
        var guest = GuestAccess(name: "Guest", expiresAt: Date().addingTimeInterval(-60))
        guest.isActive = true
        XCTAssertFalse(guest.isValid)
    }

    func test_isValid_inactiveAndExpired_returnsFalse() {
        var guest = GuestAccess(name: "Guest", expiresAt: Date().addingTimeInterval(-60))
        guest.isActive = false
        XCTAssertFalse(guest.isValid)
    }

    // MARK: - Codable

    func test_codableRoundtrip() throws {
        var original = GuestAccess(name: "Test Guest", expiresAt: Date().addingTimeInterval(7200))
        original.allowedDeviceIds = [UUID(), UUID()]
        original.allowedSceneIds = [UUID()]
        original.usageCount = 5

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GuestAccess.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, "Test Guest")
        XCTAssertEqual(decoded.accessCode, original.accessCode)
        XCTAssertEqual(decoded.allowedDeviceIds.count, 2)
        XCTAssertEqual(decoded.allowedSceneIds.count, 1)
        XCTAssertEqual(decoded.usageCount, 5)
    }
}

// MARK: - GuestActivityLog Tests

final class GuestActivityLogTests: XCTestCase {

    func test_init() {
        let guestId = UUID()
        let log = GuestActivityLog(
            guestId: guestId,
            guestName: "John",
            action: "Turned on light",
            deviceName: "Kitchen Light"
        )

        XCTAssertEqual(log.guestId, guestId)
        XCTAssertEqual(log.guestName, "John")
        XCTAssertEqual(log.action, "Turned on light")
        XCTAssertEqual(log.deviceName, "Kitchen Light")
    }

    func test_init_noDevice() {
        let log = GuestActivityLog(
            guestId: UUID(),
            guestName: "Jane",
            action: "Logged in"
        )
        XCTAssertNil(log.deviceName)
    }

    func test_codableRoundtrip() throws {
        let original = GuestActivityLog(
            guestId: UUID(),
            guestName: "Guest",
            action: "Executed scene",
            deviceName: nil
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GuestActivityLog.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.guestName, "Guest")
        XCTAssertEqual(decoded.action, "Executed scene")
        XCTAssertNil(decoded.deviceName)
    }
}
