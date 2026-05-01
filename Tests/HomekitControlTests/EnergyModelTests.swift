//
//  EnergyModelTests.swift
//  HomekitControlTests
//
//  Tests for energy monitoring data models — readings, usage, alerts.
//  Incorrect energy calculations could cause false cost projections
//  or miss high-usage alerts.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

final class EnergyModelTests: XCTestCase {

    // MARK: - EnergyReading

    func test_energyReading_init() {
        let deviceId = UUID()
        let reading = EnergyReading(deviceId: deviceId, watts: 100.0, voltage: 120.0, amperage: 0.83)

        XCTAssertEqual(reading.deviceId, deviceId)
        XCTAssertEqual(reading.watts, 100.0)
        XCTAssertEqual(reading.voltage, 120.0)
        XCTAssertEqual(reading.amperage, 0.83)
    }

    func test_energyReading_codable() throws {
        let original = EnergyReading(deviceId: UUID(), watts: 50.0)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EnergyReading.self, from: data)

        XCTAssertEqual(decoded.deviceId, original.deviceId)
        XCTAssertEqual(decoded.watts, 50.0)
        XCTAssertNil(decoded.voltage)
        XCTAssertNil(decoded.amperage)
    }

    // MARK: - DailyEnergyUsage

    func test_dailyEnergyUsage_codable() throws {
        let original = DailyEnergyUsage(
            date: Date(),
            deviceId: UUID(),
            totalKWh: 5.2,
            peakWatts: 500.0,
            averageWatts: 216.7,
            cost: 0.624
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DailyEnergyUsage.self, from: data)

        XCTAssertEqual(decoded.totalKWh, 5.2)
        XCTAssertEqual(decoded.peakWatts, 500.0)
        XCTAssertEqual(decoded.averageWatts, 216.7)
        XCTAssertEqual(decoded.cost, 0.624)
    }

    // MARK: - DevicePowerUsage

    func test_devicePowerUsage_monthlyCostCalculation() {
        let usage = DevicePowerUsage(
            deviceId: UUID(),
            deviceName: "Space Heater",
            currentWatts: 1500.0,
            todayKWh: 10.0,
            utilityRate: 0.12
        )

        // Expected: 10.0 kWh/day * 30 days * $0.12/kWh = $36.00
        XCTAssertEqual(usage.estimatedMonthlyCost, 36.0, accuracy: 0.01)
    }

    func test_devicePowerUsage_zeroCost() {
        let usage = DevicePowerUsage(
            deviceId: UUID(),
            deviceName: "Off Device",
            currentWatts: 0.0,
            todayKWh: 0.0,
            utilityRate: 0.12
        )

        XCTAssertEqual(usage.estimatedMonthlyCost, 0.0)
    }

    func test_devicePowerUsage_codable() throws {
        let original = DevicePowerUsage(
            deviceId: UUID(),
            deviceName: "Light",
            currentWatts: 10.0,
            todayKWh: 0.24,
            utilityRate: 0.15
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DevicePowerUsage.self, from: data)

        XCTAssertEqual(decoded.deviceName, "Light")
        XCTAssertEqual(decoded.currentWatts, 10.0)
    }

    // MARK: - EnergyAlert

    func test_energyAlert_init() {
        let alert = EnergyAlert(
            deviceId: UUID(),
            alertType: .highUsage,
            message: "Device using 800W"
        )

        XCTAssertEqual(alert.alertType, .highUsage)
        XCTAssertEqual(alert.message, "Device using 800W")
        XCTAssertFalse(alert.isRead)
    }

    func test_energyAlert_allTypes() throws {
        let types: [EnergyAlert.AlertType] = [
            .highUsage, .unusualPattern, .deviceAlwaysOn, .costThreshold
        ]

        for type in types {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(EnergyAlert.AlertType.self, from: data)
            XCTAssertEqual(decoded, type)
        }
    }

    func test_energyAlert_codable() throws {
        var original = EnergyAlert(alertType: .costThreshold, message: "Over budget")
        original.isRead = true

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EnergyAlert.self, from: data)

        XCTAssertEqual(decoded.alertType, .costThreshold)
        XCTAssertTrue(decoded.isRead)
    }
}
