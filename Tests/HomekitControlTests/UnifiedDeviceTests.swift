//
//  UnifiedDeviceTests.swift
//  HomekitControlTests
//
//  Tests for UnifiedDevice model — the core device representation.
//  Codable correctness is essential because this model is persisted and
//  sent over the Nova API. A deserialization failure could lose device data.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

final class UnifiedDeviceTests: XCTestCase {

    // MARK: - Initialization Defaults

    func test_init_defaults_healthyReachableDevice() {
        let device = UnifiedDevice(name: "Test Device")
        XCTAssertEqual(device.name, "Test Device")
        XCTAssertNil(device.room)
        XCTAssertNil(device.home)
        XCTAssertEqual(device.manufacturer, .unknown)
        XCTAssertEqual(device.category, .other)
        XCTAssertEqual(device.protocolType, .unknown)
        XCTAssertEqual(device.healthStatus, .unknown)
        XCTAssertTrue(device.isReachable)
        XCTAssertEqual(device.reliabilityScore, 100.0)
        XCTAssertNil(device.lastSeen)
        XCTAssertNil(device.averageResponseTime)
        XCTAssertTrue(device.testHistory.isEmpty)
        XCTAssertEqual(device.sceneCount, 0)
        XCTAssertTrue(device.sceneNames.isEmpty)
        XCTAssertNil(device.setupCode)
        XCTAssertNil(device.hubName)
        XCTAssertNil(device.notes)
    }

    func test_init_customValues() {
        let id = UUID()
        let homeKitUUID = UUID()
        let now = Date()
        let device = UnifiedDevice(
            id: id,
            name: "Kitchen Light",
            room: "Kitchen",
            home: "My Home",
            homeKitUUID: homeKitUUID,
            manufacturer: .philipsHue,
            model: "A19",
            firmwareVersion: "1.2.3",
            serialNumber: "SN123",
            category: .light,
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            protocolType: .wifi,
            healthStatus: .healthy,
            isReachable: true,
            reliabilityScore: 99.5,
            lastSeen: now,
            averageResponseTime: 45.2,
            sceneCount: 3,
            sceneNames: ["Morning", "Evening", "Night"],
            setupCode: "12345678",
            hubName: "Bridge",
            notes: "Test note"
        )

        XCTAssertEqual(device.id, id)
        XCTAssertEqual(device.name, "Kitchen Light")
        XCTAssertEqual(device.room, "Kitchen")
        XCTAssertEqual(device.home, "My Home")
        XCTAssertEqual(device.homeKitUUID, homeKitUUID)
        XCTAssertEqual(device.manufacturer, .philipsHue)
        XCTAssertEqual(device.model, "A19")
        XCTAssertEqual(device.firmwareVersion, "1.2.3")
        XCTAssertEqual(device.serialNumber, "SN123")
        XCTAssertEqual(device.category, .light)
        XCTAssertEqual(device.ipAddress, "192.168.1.100")
        XCTAssertEqual(device.macAddress, "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(device.protocolType, .wifi)
        XCTAssertEqual(device.healthStatus, .healthy)
        XCTAssertTrue(device.isReachable)
        XCTAssertEqual(device.reliabilityScore, 99.5)
        XCTAssertEqual(device.lastSeen, now)
        XCTAssertEqual(device.averageResponseTime, 45.2)
        XCTAssertEqual(device.sceneCount, 3)
        XCTAssertEqual(device.sceneNames, ["Morning", "Evening", "Night"])
        XCTAssertEqual(device.setupCode, "12345678")
        XCTAssertEqual(device.hubName, "Bridge")
        XCTAssertEqual(device.notes, "Test note")
    }

    // MARK: - Codable Roundtrip

    func test_codableRoundtrip_fullDevice() throws {
        let original = UnifiedDevice(
            name: "Bedroom Fan",
            room: "Bedroom",
            home: "House",
            manufacturer: .nanoleaf,
            model: "Shapes",
            firmwareVersion: "2.0",
            category: .fan,
            ipAddress: "10.0.0.50",
            protocolType: .thread,
            healthStatus: .degraded,
            isReachable: false,
            reliabilityScore: 72.3,
            sceneCount: 1,
            sceneNames: ["Bedtime"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(UnifiedDevice.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.room, original.room)
        XCTAssertEqual(decoded.manufacturer, original.manufacturer)
        XCTAssertEqual(decoded.category, original.category)
        XCTAssertEqual(decoded.protocolType, original.protocolType)
        XCTAssertEqual(decoded.healthStatus, original.healthStatus)
        XCTAssertEqual(decoded.isReachable, original.isReachable)
        XCTAssertEqual(decoded.reliabilityScore, original.reliabilityScore)
    }

    func test_codableRoundtrip_withTestHistory() throws {
        let result1 = DeviceTestResult(success: true, responseTimeMs: 42.0)
        let result2 = DeviceTestResult(success: false, errorMessage: "Timeout")

        var device = UnifiedDevice(name: "Sensor")
        device.testHistory = [result1, result2]

        let data = try JSONEncoder().encode(device)
        let decoded = try JSONDecoder().decode(UnifiedDevice.self, from: data)

        XCTAssertEqual(decoded.testHistory.count, 2)
        XCTAssertTrue(decoded.testHistory[0].success)
        XCTAssertEqual(decoded.testHistory[0].responseTimeMs, 42.0)
        XCTAssertFalse(decoded.testHistory[1].success)
        XCTAssertEqual(decoded.testHistory[1].errorMessage, "Timeout")
    }

    // MARK: - Hashable / Identifiable

    func test_identifiable_usesId() {
        let device = UnifiedDevice(name: "Test")
        XCTAssertEqual(device.id, device.id)
    }

    func test_hashable_equalDevicesHaveEqualHashes() {
        let id = UUID()
        let d1 = UnifiedDevice(id: id, name: "Same")
        let d2 = UnifiedDevice(id: id, name: "Same")
        XCTAssertEqual(d1, d2)
        XCTAssertEqual(d1.hashValue, d2.hashValue)
    }

    func test_hashable_differentDevicesAreNotEqual() {
        let d1 = UnifiedDevice(name: "Device A")
        let d2 = UnifiedDevice(name: "Device B")
        XCTAssertNotEqual(d1, d2)
    }

    // MARK: - Mutability

    func test_device_isMutable() {
        var device = UnifiedDevice(name: "Original")
        device.name = "Updated"
        device.room = "Living Room"
        device.isReachable = false
        device.reliabilityScore = 50.0

        XCTAssertEqual(device.name, "Updated")
        XCTAssertEqual(device.room, "Living Room")
        XCTAssertFalse(device.isReachable)
        XCTAssertEqual(device.reliabilityScore, 50.0)
    }

    // MARK: - Edge Cases

    func test_device_emptyName() throws {
        let device = UnifiedDevice(name: "")
        let data = try JSONEncoder().encode(device)
        let decoded = try JSONDecoder().decode(UnifiedDevice.self, from: data)
        XCTAssertEqual(decoded.name, "")
    }

    func test_device_reliabilityScoreZero() {
        let device = UnifiedDevice(name: "Dead", reliabilityScore: 0.0)
        XCTAssertEqual(device.reliabilityScore, 0.0)
    }

    func test_device_reliabilityScoreAbove100() {
        // Model doesn't enforce bounds — document this
        let device = UnifiedDevice(name: "Super", reliabilityScore: 150.0)
        XCTAssertEqual(device.reliabilityScore, 150.0)
    }

    func test_device_negativeReliabilityScore() {
        let device = UnifiedDevice(name: "Broken", reliabilityScore: -10.0)
        XCTAssertEqual(device.reliabilityScore, -10.0)
    }
}

// MARK: - DeviceTestResult Tests

final class DeviceTestResultTests: XCTestCase {

    func test_init_successfulResult() {
        let result = DeviceTestResult(success: true, responseTimeMs: 42.0)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.responseTimeMs, 42.0)
        XCTAssertNil(result.errorMessage)
    }

    func test_init_failedResult() {
        let result = DeviceTestResult(success: false, errorMessage: "Connection timeout")
        XCTAssertFalse(result.success)
        XCTAssertNil(result.responseTimeMs)
        XCTAssertEqual(result.errorMessage, "Connection timeout")
    }

    func test_codableRoundtrip() throws {
        let original = DeviceTestResult(
            success: true,
            responseTimeMs: 123.45,
            errorMessage: nil
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DeviceTestResult.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.success, original.success)
        XCTAssertEqual(decoded.responseTimeMs, original.responseTimeMs)
        XCTAssertEqual(decoded.errorMessage, original.errorMessage)
    }
}
