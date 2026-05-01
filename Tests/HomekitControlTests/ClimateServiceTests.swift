//
//  ClimateServiceTests.swift
//  HomekitControlTests
//
//  Tests for climate models and temperature conversion logic.
//  Incorrect temperature conversion can cause thermostats to be set
//  dangerously high or low, damaging HVAC systems or creating unsafe conditions.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

@MainActor
final class ClimateModelTests: XCTestCase {

    // MARK: - Temperature Conversion (SAFETY CRITICAL)

    func test_celsiusToFahrenheit_freezing() {
        let service = ClimateService.shared
        let result = service.celsiusToFahrenheit(0)
        XCTAssertEqual(result, 32.0, accuracy: 0.01)
    }

    func test_celsiusToFahrenheit_boiling() {
        let service = ClimateService.shared
        let result = service.celsiusToFahrenheit(100)
        XCTAssertEqual(result, 212.0, accuracy: 0.01)
    }

    func test_celsiusToFahrenheit_bodyTemp() {
        let service = ClimateService.shared
        let result = service.celsiusToFahrenheit(37)
        XCTAssertEqual(result, 98.6, accuracy: 0.01)
    }

    func test_celsiusToFahrenheit_roomTemp() {
        let service = ClimateService.shared
        let result = service.celsiusToFahrenheit(22)
        XCTAssertEqual(result, 71.6, accuracy: 0.01)
    }

    func test_celsiusToFahrenheit_negative() {
        let service = ClimateService.shared
        let result = service.celsiusToFahrenheit(-40)
        XCTAssertEqual(result, -40.0, accuracy: 0.01) // -40 is same in both scales
    }

    func test_fahrenheitToCelsius_freezing() {
        let service = ClimateService.shared
        let result = service.fahrenheitToCelsius(32)
        XCTAssertEqual(result, 0.0, accuracy: 0.01)
    }

    func test_fahrenheitToCelsius_boiling() {
        let service = ClimateService.shared
        let result = service.fahrenheitToCelsius(212)
        XCTAssertEqual(result, 100.0, accuracy: 0.01)
    }

    func test_fahrenheitToCelsius_roomTemp() {
        let service = ClimateService.shared
        let result = service.fahrenheitToCelsius(72)
        XCTAssertEqual(result, 22.22, accuracy: 0.01)
    }

    func test_temperatureConversion_roundtrip() {
        let service = ClimateService.shared
        let originalCelsius = 22.5
        let fahrenheit = service.celsiusToFahrenheit(originalCelsius)
        let backToCelsius = service.fahrenheitToCelsius(fahrenheit)
        XCTAssertEqual(backToCelsius, originalCelsius, accuracy: 0.001)
    }

    // MARK: - Temperature Formatting

    func test_formatTemperature_fahrenheit() {
        let service = ClimateService.shared
        // Service defaults to Fahrenheit
        let result = service.formatTemperature(72.0)
        XCTAssertTrue(result.contains("72"))
        XCTAssertTrue(result.contains("F") || result.contains("°"))
    }

    // MARK: - ClimateZone Model

    func test_climateZone_init_defaults() {
        let zone = ClimateZone(name: "Upstairs")
        XCTAssertEqual(zone.name, "Upstairs")
        XCTAssertTrue(zone.thermostatIds.isEmpty)
        XCTAssertEqual(zone.targetTemperature, 72.0)
        XCTAssertTrue(zone.isEnabled)
        XCTAssertTrue(zone.schedule.isEmpty)
        XCTAssertNil(zone.occupancySensorId)
        XCTAssertEqual(zone.unoccupiedSetback, 4.0)
    }

    func test_climateZone_codableRoundtrip() throws {
        var zone = ClimateZone(name: "Master Bedroom")
        zone.thermostatIds = [UUID(), UUID()]
        zone.targetTemperature = 68.0
        zone.isEnabled = false
        zone.unoccupiedSetback = 6.0

        let data = try JSONEncoder().encode(zone)
        let decoded = try JSONDecoder().decode(ClimateZone.self, from: data)

        XCTAssertEqual(decoded.name, "Master Bedroom")
        XCTAssertEqual(decoded.thermostatIds.count, 2)
        XCTAssertEqual(decoded.targetTemperature, 68.0)
        XCTAssertFalse(decoded.isEnabled)
        XCTAssertEqual(decoded.unoccupiedSetback, 6.0)
    }

    // MARK: - ClimateScheduleEntry

    func test_scheduleEntry_codableRoundtrip() throws {
        let entry = ClimateScheduleEntry(
            dayOfWeek: 2, // Monday
            hour: 7,
            minute: 30,
            targetTemperature: 70.0,
            mode: .heat
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(ClimateScheduleEntry.self, from: data)

        XCTAssertEqual(decoded.dayOfWeek, 2)
        XCTAssertEqual(decoded.hour, 7)
        XCTAssertEqual(decoded.minute, 30)
        XCTAssertEqual(decoded.targetTemperature, 70.0)
        XCTAssertEqual(decoded.mode, .heat)
    }

    // MARK: - ThermostatMode

    func test_thermostatMode_allCases() {
        XCTAssertEqual(ThermostatMode.allCases.count, 4)
    }

    func test_thermostatMode_icons() {
        for mode in ThermostatMode.allCases {
            XCTAssertFalse(mode.icon.isEmpty, "\(mode) has no icon")
        }
    }

    func test_thermostatMode_codable() throws {
        for mode in ThermostatMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(ThermostatMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }

    // MARK: - ClimateHistoryEntry

    func test_historyEntry_codable() throws {
        let entry = ClimateHistoryEntry(
            id: UUID(),
            zoneId: UUID(),
            zoneName: "Living Room",
            timestamp: Date(),
            temperature: 72.0,
            targetTemperature: 72.0,
            mode: .auto,
            wasOccupied: true
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(ClimateHistoryEntry.self, from: data)

        XCTAssertEqual(decoded.zoneName, "Living Room")
        XCTAssertEqual(decoded.temperature, 72.0)
        XCTAssertEqual(decoded.mode, .auto)
        XCTAssertTrue(decoded.wasOccupied)
    }
}
