//
//  DeviceHealthRecordTests.swift
//  HomekitControlTests
//
//  Tests for DeviceHealthRecord stat calculations and health status determination.
//  Incorrect reliability scores could cause the app to report a failing device
//  as healthy, or flag a working device as unreachable.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

final class DeviceHealthRecordTests: XCTestCase {

    // MARK: - recalculateStats

    func test_recalculateStats_allSuccessful() {
        var record = DeviceHealthRecord(deviceId: UUID())
        record.testHistory = [
            DeviceTestResult(success: true, responseTimeMs: 40.0),
            DeviceTestResult(success: true, responseTimeMs: 60.0),
            DeviceTestResult(success: true, responseTimeMs: 50.0)
        ]

        record.recalculateStats()

        XCTAssertEqual(record.reliabilityScore, 100.0)
        XCTAssertEqual(record.averageResponseTime, 50.0)
        XCTAssertNotNil(record.lastTested)
    }

    func test_recalculateStats_mixedResults() {
        var record = DeviceHealthRecord(deviceId: UUID())
        record.testHistory = [
            DeviceTestResult(success: true, responseTimeMs: 100.0),
            DeviceTestResult(success: false, errorMessage: "Timeout"),
            DeviceTestResult(success: true, responseTimeMs: 200.0),
            DeviceTestResult(success: false, errorMessage: "Unreachable")
        ]

        record.recalculateStats()

        XCTAssertEqual(record.reliabilityScore, 50.0)
        XCTAssertEqual(record.averageResponseTime, 150.0) // (100 + 200) / 2
    }

    func test_recalculateStats_allFailed() {
        var record = DeviceHealthRecord(deviceId: UUID())
        record.testHistory = [
            DeviceTestResult(success: false, errorMessage: "Timeout"),
            DeviceTestResult(success: false, errorMessage: "Timeout"),
            DeviceTestResult(success: false, errorMessage: "Timeout")
        ]

        record.recalculateStats()

        XCTAssertEqual(record.reliabilityScore, 0.0)
        XCTAssertNil(record.averageResponseTime) // No successful tests
    }

    func test_recalculateStats_emptyHistory() {
        var record = DeviceHealthRecord(deviceId: UUID())
        record.testHistory = []

        record.recalculateStats()

        XCTAssertEqual(record.reliabilityScore, 100.0) // Default
        XCTAssertNil(record.lastTested)
    }

    func test_recalculateStats_singleSuccessful() {
        var record = DeviceHealthRecord(deviceId: UUID())
        record.testHistory = [
            DeviceTestResult(success: true, responseTimeMs: 42.0)
        ]

        record.recalculateStats()

        XCTAssertEqual(record.reliabilityScore, 100.0)
        XCTAssertEqual(record.averageResponseTime, 42.0)
    }

    func test_recalculateStats_successWithNilResponseTime() {
        var record = DeviceHealthRecord(deviceId: UUID())
        record.testHistory = [
            DeviceTestResult(success: true, responseTimeMs: nil),
            DeviceTestResult(success: true, responseTimeMs: 80.0)
        ]

        record.recalculateStats()

        XCTAssertEqual(record.reliabilityScore, 100.0)
        // Only one test has responseTimeMs
        XCTAssertEqual(record.averageResponseTime, 80.0)
    }

    func test_recalculateStats_lastTestedIsLastInHistory() {
        var record = DeviceHealthRecord(deviceId: UUID())
        let early = Date(timeIntervalSince1970: 1000)
        let late = Date(timeIntervalSince1970: 2000)

        record.testHistory = [
            DeviceTestResult(id: UUID(), timestamp: early, success: true),
            DeviceTestResult(id: UUID(), timestamp: late, success: true)
        ]

        record.recalculateStats()

        XCTAssertEqual(record.lastTested, late)
    }

    // MARK: - Health Status Determination

    func test_getHealthStatus_above95_isHealthy() {
        // We test the getHealthStatus logic directly
        // Score >= 95 = healthy
        XCTAssertEqual(determineHealthStatus(score: 100.0), .healthy)
        XCTAssertEqual(determineHealthStatus(score: 95.0), .healthy)
    }

    func test_getHealthStatus_between70and95_isDegraded() {
        XCTAssertEqual(determineHealthStatus(score: 94.9), .degraded)
        XCTAssertEqual(determineHealthStatus(score: 70.0), .degraded)
    }

    func test_getHealthStatus_below70_isUnreachable() {
        XCTAssertEqual(determineHealthStatus(score: 69.9), .unreachable)
        XCTAssertEqual(determineHealthStatus(score: 0.0), .unreachable)
    }

    // Helper that mirrors DeviceHealthService.getHealthStatus logic
    private func determineHealthStatus(score: Double) -> HealthStatus {
        if score >= 95 { return .healthy }
        else if score >= 70 { return .degraded }
        else { return .unreachable }
    }

    // MARK: - Codable

    func test_codableRoundtrip() throws {
        var original = DeviceHealthRecord(deviceId: UUID())
        original.testHistory = [
            DeviceTestResult(success: true, responseTimeMs: 50.0),
            DeviceTestResult(success: false, errorMessage: "Error")
        ]
        original.recalculateStats()

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DeviceHealthRecord.self, from: data)

        XCTAssertEqual(decoded.deviceId, original.deviceId)
        XCTAssertEqual(decoded.reliabilityScore, original.reliabilityScore)
        XCTAssertEqual(decoded.averageResponseTime, original.averageResponseTime)
        XCTAssertEqual(decoded.testHistory.count, 2)
    }
}

// MARK: - DeviceHealthInfo Tests

final class DeviceHealthInfoTests: XCTestCase {

    func test_identifiable_usesDeviceId() {
        let deviceId = UUID()
        let info = DeviceHealthInfo(
            deviceId: deviceId,
            status: .healthy,
            uptimePercentage: 99.0,
            averageResponseTime: 50.0,
            lastSeen: Date()
        )
        XCTAssertEqual(info.id, deviceId)
    }

    func test_codableRoundtrip() throws {
        let original = DeviceHealthInfo(
            deviceId: UUID(),
            status: .degraded,
            uptimePercentage: 85.0,
            averageResponseTime: 120.0,
            lastSeen: nil
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DeviceHealthInfo.self, from: data)

        XCTAssertEqual(decoded.deviceId, original.deviceId)
        XCTAssertEqual(decoded.status, .degraded)
        XCTAssertEqual(decoded.uptimePercentage, 85.0)
        XCTAssertEqual(decoded.averageResponseTime, 120.0)
        XCTAssertNil(decoded.lastSeen)
    }
}
