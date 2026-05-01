//
//  SecurityModelTests.swift
//  HomekitControlTests
//
//  Tests for security-related models — SecurityMode, SecurityZone, SecurityEvent.
//  These models gate physical security device behavior (locks, alarms, sensors).
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

final class SecurityModelTests: XCTestCase {

    // MARK: - SecurityMode

    func test_securityMode_allCases() {
        XCTAssertEqual(SecurityMode.allCases.count, 4)
        XCTAssertTrue(SecurityMode.allCases.contains(.disarmed))
        XCTAssertTrue(SecurityMode.allCases.contains(.home))
        XCTAssertTrue(SecurityMode.allCases.contains(.away))
        XCTAssertTrue(SecurityMode.allCases.contains(.night))
    }

    func test_securityMode_icons() {
        for mode in SecurityMode.allCases {
            XCTAssertFalse(mode.icon.isEmpty, "\(mode) has no icon")
        }
    }

    func test_securityMode_codable() throws {
        for mode in SecurityMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(SecurityMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }

    // MARK: - SecurityZone

    func test_securityZone_init() {
        let zone = SecurityZone(name: "Perimeter")
        XCTAssertEqual(zone.name, "Perimeter")
        XCTAssertTrue(zone.deviceIds.isEmpty)
        XCTAssertFalse(zone.isArmed)
    }

    func test_securityZone_codable() throws {
        var original = SecurityZone(name: "Interior")
        original.deviceIds = [UUID(), UUID()]
        original.isArmed = true

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SecurityZone.self, from: data)

        XCTAssertEqual(decoded.name, "Interior")
        XCTAssertEqual(decoded.deviceIds.count, 2)
        XCTAssertTrue(decoded.isArmed)
    }

    // MARK: - SecurityEvent

    func test_securityEvent_codable() throws {
        let original = SecurityEvent(
            id: UUID(),
            deviceId: UUID(),
            deviceName: "Front Door Lock",
            eventType: .lockUnlocked,
            timestamp: Date(),
            isRead: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SecurityEvent.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.deviceName, "Front Door Lock")
        XCTAssertEqual(decoded.eventType, .lockUnlocked)
        XCTAssertFalse(decoded.isRead)
    }

    func test_securityEvent_allEventTypes() {
        // Verify all critical event types exist
        let criticalTypes: [SecurityEvent.SecurityEventType] = [
            .smokeDetected, .coDetected, .waterDetected, .alarmTriggered
        ]

        for type in criticalTypes {
            XCTAssertNotNil(type.rawValue, "\(type) should have a raw value")
        }
    }

    // MARK: - SecurityDevice Types

    func test_securityDeviceType_codable() throws {
        let types: [SecurityDevice.SecurityDeviceType] = [
            .camera, .doorLock, .motionSensor, .contactSensor,
            .smokeSensor, .coSensor, .waterSensor, .alarm
        ]

        for type in types {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(SecurityDevice.SecurityDeviceType.self, from: data)
            XCTAssertEqual(decoded, type, "Roundtrip failed for \(type)")
        }
    }

    func test_securityDeviceState_codable() throws {
        let states: [SecurityDevice.SecurityDeviceState] = [
            .secure, .triggered, .open, .closed, .locked, .unlocked,
            .armed, .disarmed, .motionDetected, .noMotion, .streaming, .offline, .unknown
        ]

        for state in states {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(SecurityDevice.SecurityDeviceState.self, from: data)
            XCTAssertEqual(decoded, state, "Roundtrip failed for \(state)")
        }
    }
}
