//
//  AdaptiveLightingTests.swift
//  HomekitControlTests
//
//  Tests for adaptive lighting models — schedule points, profiles, circadian defaults.
//  Incorrect lighting values can cause lights to flash to 100% at midnight or
//  set color temperatures outside device ranges.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

final class AdaptiveLightingTests: XCTestCase {

    // MARK: - LightingSchedulePoint

    func test_schedulePoint_timeString() {
        let point = LightingSchedulePoint(hour: 6, minute: 30, brightness: 50, colorTemperature: 3000)
        XCTAssertEqual(point.timeString, "06:30")
    }

    func test_schedulePoint_timeString_midnight() {
        let point = LightingSchedulePoint(hour: 0, minute: 0, brightness: 0, colorTemperature: 2700)
        XCTAssertEqual(point.timeString, "00:00")
    }

    func test_schedulePoint_timeString_singleDigits() {
        let point = LightingSchedulePoint(hour: 5, minute: 5, brightness: 30, colorTemperature: 2700)
        XCTAssertEqual(point.timeString, "05:05")
    }

    func test_schedulePoint_codable() throws {
        let original = LightingSchedulePoint(
            hour: 12, minute: 0,
            brightness: 100, colorTemperature: 5500,
            transitionDuration: 900
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LightingSchedulePoint.self, from: data)

        XCTAssertEqual(decoded.hour, 12)
        XCTAssertEqual(decoded.minute, 0)
        XCTAssertEqual(decoded.brightness, 100)
        XCTAssertEqual(decoded.colorTemperature, 5500)
        XCTAssertEqual(decoded.transitionDuration, 900)
    }

    // MARK: - Default Circadian Schedule

    func test_defaultCircadian_hasSixPoints() {
        let schedule = LightingSchedulePoint.defaultCircadian
        XCTAssertEqual(schedule.count, 6)
    }

    func test_defaultCircadian_isChronologicallyOrdered() {
        let schedule = LightingSchedulePoint.defaultCircadian
        for i in 1..<schedule.count {
            let prevMinutes = schedule[i-1].hour * 60 + schedule[i-1].minute
            let currMinutes = schedule[i].hour * 60 + schedule[i].minute
            XCTAssertLessThan(prevMinutes, currMinutes,
                              "Schedule point \(i) is not after point \(i-1)")
        }
    }

    func test_defaultCircadian_brightnessRange() {
        let schedule = LightingSchedulePoint.defaultCircadian
        for point in schedule {
            XCTAssertGreaterThanOrEqual(point.brightness, 0,
                                        "Brightness at \(point.timeString) below 0")
            XCTAssertLessThanOrEqual(point.brightness, 100,
                                     "Brightness at \(point.timeString) above 100")
        }
    }

    func test_defaultCircadian_colorTempRange() {
        let schedule = LightingSchedulePoint.defaultCircadian
        for point in schedule {
            XCTAssertGreaterThanOrEqual(point.colorTemperature, 2700,
                                        "Color temp at \(point.timeString) below 2700K")
            XCTAssertLessThanOrEqual(point.colorTemperature, 6500,
                                     "Color temp at \(point.timeString) above 6500K")
        }
    }

    func test_defaultCircadian_peakBrightnessAtMidday() {
        let schedule = LightingSchedulePoint.defaultCircadian
        let middayPoint = schedule.first { $0.hour == 12 }
        XCTAssertNotNil(middayPoint)
        XCTAssertEqual(middayPoint?.brightness, 100)
    }

    func test_defaultCircadian_warmAtNight() {
        let schedule = LightingSchedulePoint.defaultCircadian
        let nightPoint = schedule.last
        XCTAssertNotNil(nightPoint)
        XCTAssertEqual(nightPoint?.colorTemperature, 2700)
        XCTAssertLessThanOrEqual(nightPoint!.brightness, 30)
    }

    // MARK: - LightingProfile

    func test_profile_init_defaults() {
        let profile = LightingProfile(name: "Default")
        XCTAssertEqual(profile.name, "Default")
        XCTAssertTrue(profile.isEnabled)
        XCTAssertTrue(profile.deviceIds.isEmpty)
        XCTAssertFalse(profile.motionActivated)
        XCTAssertEqual(profile.motionTimeout, 300)
        XCTAssertNil(profile.ambientLightThreshold)
        XCTAssertEqual(profile.schedule.count, 6) // Uses default circadian
    }

    func test_profile_codable() throws {
        var profile = LightingProfile(name: "Kitchen")
        profile.deviceIds = [UUID(), UUID()]
        profile.motionActivated = true
        profile.motionTimeout = 600
        profile.ambientLightThreshold = 200.0

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(LightingProfile.self, from: data)

        XCTAssertEqual(decoded.name, "Kitchen")
        XCTAssertEqual(decoded.deviceIds.count, 2)
        XCTAssertTrue(decoded.motionActivated)
        XCTAssertEqual(decoded.motionTimeout, 600)
        XCTAssertEqual(decoded.ambientLightThreshold, 200.0)
    }

    // MARK: - MotionEvent

    func test_motionEvent_codable() throws {
        let original = MotionEvent(
            id: UUID(),
            sensorId: UUID(),
            sensorName: "Hall Sensor",
            timestamp: Date(),
            triggeredLights: [UUID(), UUID()]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MotionEvent.self, from: data)

        XCTAssertEqual(decoded.sensorName, "Hall Sensor")
        XCTAssertEqual(decoded.triggeredLights.count, 2)
    }
}
