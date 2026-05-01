//
//  SceneSchedulingTests.swift
//  HomekitControlTests
//
//  Tests for SceneSchedule model and schedule type behavior.
//  Scheduling bugs can cause scenes to fire at wrong times, potentially
//  turning on lights at 3 AM or failing to arm security at night.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

final class SceneSchedulingTests: XCTestCase {

    // MARK: - SceneSchedule Model

    func test_schedule_init_defaults() {
        let schedule = SceneSchedule(name: "Morning Lights")
        XCTAssertEqual(schedule.name, "Morning Lights")
        XCTAssertNil(schedule.sceneId)
        XCTAssertEqual(schedule.scheduleType, .time)
        XCTAssertTrue(schedule.isEnabled)
        XCTAssertNil(schedule.lastRun)
        XCTAssertTrue(schedule.repeatDays.isEmpty)
        XCTAssertEqual(schedule.sunOffset, 0)
        XCTAssertNil(schedule.oneTimeDate)
    }

    func test_schedule_codableRoundtrip() throws {
        var schedule = SceneSchedule(name: "Sunset Scene", scheduleType: .sunset)
        schedule.sunOffset = -15
        schedule.isEnabled = false
        schedule.sceneId = UUID()

        let data = try JSONEncoder().encode(schedule)
        let decoded = try JSONDecoder().decode(SceneSchedule.self, from: data)

        XCTAssertEqual(decoded.name, "Sunset Scene")
        XCTAssertEqual(decoded.scheduleType, .sunset)
        XCTAssertEqual(decoded.sunOffset, -15)
        XCTAssertFalse(decoded.isEnabled)
        XCTAssertEqual(decoded.sceneId, schedule.sceneId)
    }

    // MARK: - ScheduleType

    func test_scheduleType_allCases() {
        XCTAssertEqual(SceneSchedule.ScheduleType.allCases.count, 4)
    }

    func test_scheduleType_icons() {
        for type in SceneSchedule.ScheduleType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "\(type) has no icon")
        }
    }

    func test_scheduleType_codable() throws {
        for type in SceneSchedule.ScheduleType.allCases {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(SceneSchedule.ScheduleType.self, from: data)
            XCTAssertEqual(decoded, type)
        }
    }

    // MARK: - Repeat Days

    func test_schedule_repeatDays_weekdaysOnly() throws {
        var schedule = SceneSchedule(name: "Weekday Alarm")
        schedule.repeatDays = [2, 3, 4, 5, 6] // Mon-Fri (1=Sun, 7=Sat)

        let data = try JSONEncoder().encode(schedule)
        let decoded = try JSONDecoder().decode(SceneSchedule.self, from: data)

        XCTAssertEqual(decoded.repeatDays, [2, 3, 4, 5, 6])
        XCTAssertFalse(decoded.repeatDays.contains(1)) // No Sunday
        XCTAssertFalse(decoded.repeatDays.contains(7)) // No Saturday
    }

    func test_schedule_repeatDays_weekendOnly() throws {
        var schedule = SceneSchedule(name: "Weekend Mode")
        schedule.repeatDays = [1, 7] // Sun, Sat

        let data = try JSONEncoder().encode(schedule)
        let decoded = try JSONDecoder().decode(SceneSchedule.self, from: data)

        XCTAssertEqual(decoded.repeatDays, [1, 7])
    }

    // MARK: - Sun Offset

    func test_schedule_negativeSunOffset() throws {
        var schedule = SceneSchedule(name: "Before Sunset", scheduleType: .sunset)
        schedule.sunOffset = -30 // 30 minutes before sunset

        let data = try JSONEncoder().encode(schedule)
        let decoded = try JSONDecoder().decode(SceneSchedule.self, from: data)

        XCTAssertEqual(decoded.sunOffset, -30)
    }

    func test_schedule_positiveSunOffset() throws {
        var schedule = SceneSchedule(name: "After Sunrise", scheduleType: .sunrise)
        schedule.sunOffset = 45 // 45 minutes after sunrise

        let data = try JSONEncoder().encode(schedule)
        let decoded = try JSONDecoder().decode(SceneSchedule.self, from: data)

        XCTAssertEqual(decoded.sunOffset, 45)
    }
}
