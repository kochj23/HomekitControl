//
//  NotificationModelTests.swift
//  HomekitControlTests
//
//  Tests for notification models — rules, logs, event types.
//  Notification failures can mean missed security alerts or
//  device offline warnings that should have triggered action.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

final class NotificationModelTests: XCTestCase {

    // MARK: - NotificationRule

    func test_rule_init() {
        let rule = NotificationRule(name: "Motion Alert", eventType: .motionDetected)
        XCTAssertEqual(rule.name, "Motion Alert")
        XCTAssertEqual(rule.eventType, .motionDetected)
        XCTAssertTrue(rule.isEnabled)
        XCTAssertNil(rule.deviceId)
        XCTAssertNil(rule.quietHoursStart)
        XCTAssertNil(rule.quietHoursEnd)
    }

    func test_rule_codable() throws {
        var original = NotificationRule(name: "Door Alert", eventType: .doorOpened)
        original.deviceId = UUID()
        original.isEnabled = false

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NotificationRule.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, "Door Alert")
        XCTAssertEqual(decoded.eventType, .doorOpened)
        XCTAssertFalse(decoded.isEnabled)
        XCTAssertEqual(decoded.deviceId, original.deviceId)
    }

    // MARK: - EventType

    func test_eventType_allCases() {
        XCTAssertEqual(NotificationRule.EventType.allCases.count, 8)
    }

    func test_eventType_icons() {
        for type in NotificationRule.EventType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "\(type) has no icon")
        }
    }

    func test_eventType_codable() throws {
        for type in NotificationRule.EventType.allCases {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(NotificationRule.EventType.self, from: data)
            XCTAssertEqual(decoded, type)
        }
    }

    // MARK: - NotificationLog

    func test_log_init() {
        let log = NotificationLog(
            ruleId: UUID(),
            title: "Motion Detected",
            body: "Motion in Kitchen"
        )

        XCTAssertNotNil(log.ruleId)
        XCTAssertEqual(log.title, "Motion Detected")
        XCTAssertEqual(log.body, "Motion in Kitchen")
        XCTAssertFalse(log.isRead)
    }

    func test_log_init_noRule() {
        let log = NotificationLog(title: "System", body: "Test")
        XCTAssertNil(log.ruleId)
    }

    func test_log_codable() throws {
        var original = NotificationLog(
            ruleId: UUID(),
            title: "Device Offline",
            body: "Kitchen Light is not responding"
        )
        original.isRead = true

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NotificationLog.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, "Device Offline")
        XCTAssertEqual(decoded.body, "Kitchen Light is not responding")
        XCTAssertTrue(decoded.isRead)
    }
}
