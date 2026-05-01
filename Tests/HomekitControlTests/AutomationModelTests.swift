//
//  AutomationModelTests.swift
//  HomekitControlTests
//
//  Tests for automation data models — triggers, conditions, actions, and automations.
//  Automation logic errors can cause unintended physical device activations at wrong
//  times, or fail to trigger safety-critical automations.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

final class AutomationModelTests: XCTestCase {

    // MARK: - TriggerType

    func test_triggerType_allCases() {
        XCTAssertEqual(TriggerType.allCases.count, 6)
    }

    func test_triggerType_icons() {
        for type in TriggerType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "\(type) has no icon")
        }
    }

    func test_triggerType_identifiable() {
        for type in TriggerType.allCases {
            XCTAssertEqual(type.id, type.rawValue)
        }
    }

    // MARK: - ConditionOperator

    func test_conditionOperator_allCases() {
        XCTAssertEqual(ConditionOperator.allCases.count, 5)
        XCTAssertTrue(ConditionOperator.allCases.contains(.equals))
        XCTAssertTrue(ConditionOperator.allCases.contains(.notEquals))
        XCTAssertTrue(ConditionOperator.allCases.contains(.greaterThan))
        XCTAssertTrue(ConditionOperator.allCases.contains(.lessThan))
        XCTAssertTrue(ConditionOperator.allCases.contains(.contains))
    }

    // MARK: - AutomationTrigger

    func test_trigger_init() {
        let trigger = AutomationTrigger(type: .time)
        XCTAssertEqual(trigger.type, .time)
        XCTAssertNil(trigger.timeValue)
        XCTAssertNil(trigger.sunriseOffset)
        XCTAssertNil(trigger.sunsetOffset)
        XCTAssertNil(trigger.deviceId)
        XCTAssertNil(trigger.deviceState)
    }

    func test_trigger_codableRoundtrip() throws {
        var trigger = AutomationTrigger(type: .sunset)
        trigger.sunsetOffset = -30
        trigger.timeValue = Date()

        let data = try JSONEncoder().encode(trigger)
        let decoded = try JSONDecoder().decode(AutomationTrigger.self, from: data)

        XCTAssertEqual(decoded.id, trigger.id)
        XCTAssertEqual(decoded.type, .sunset)
        XCTAssertEqual(decoded.sunsetOffset, -30)
    }

    // MARK: - AutomationCondition

    func test_condition_init_defaults() {
        let condition = AutomationCondition()
        XCTAssertEqual(condition.characteristic, "power")
        XCTAssertEqual(condition.operatorType, .equals)
        XCTAssertEqual(condition.value, "on")
        XCTAssertTrue(condition.isEnabled)
        XCTAssertNil(condition.deviceId)
    }

    func test_condition_codableRoundtrip() throws {
        var condition = AutomationCondition(
            characteristic: "brightness",
            operatorType: .greaterThan,
            value: "50"
        )
        condition.isEnabled = false

        let data = try JSONEncoder().encode(condition)
        let decoded = try JSONDecoder().decode(AutomationCondition.self, from: data)

        XCTAssertEqual(decoded.characteristic, "brightness")
        XCTAssertEqual(decoded.operatorType, .greaterThan)
        XCTAssertEqual(decoded.value, "50")
        XCTAssertFalse(decoded.isEnabled)
    }

    // MARK: - AutomationAction

    func test_action_init() {
        let action = AutomationAction(actionType: .turnOn, delay: 5.0, order: 1)
        XCTAssertEqual(action.actionType, .turnOn)
        XCTAssertEqual(action.delay, 5.0)
        XCTAssertEqual(action.order, 1)
        XCTAssertNil(action.deviceId)
        XCTAssertNil(action.sceneId)
        XCTAssertNil(action.value)
    }

    func test_action_allTypes() {
        XCTAssertEqual(AutomationAction.ActionType.allCases.count, 6)
    }

    func test_action_codableRoundtrip() throws {
        var action = AutomationAction(actionType: .setBrightness, delay: 0, order: 2)
        action.value = "75"
        action.deviceId = UUID()

        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(AutomationAction.self, from: data)

        XCTAssertEqual(decoded.actionType, .setBrightness)
        XCTAssertEqual(decoded.value, "75")
        XCTAssertEqual(decoded.order, 2)
        XCTAssertEqual(decoded.deviceId, action.deviceId)
    }

    // MARK: - CustomAutomation

    func test_automation_init() {
        let automation = CustomAutomation(name: "Morning Routine")
        XCTAssertEqual(automation.name, "Morning Routine")
        XCTAssertTrue(automation.isEnabled)
        XCTAssertTrue(automation.triggers.isEmpty)
        XCTAssertTrue(automation.conditions.isEmpty)
        XCTAssertTrue(automation.actions.isEmpty)
        XCTAssertEqual(automation.runCount, 0)
        XCTAssertNil(automation.lastTriggered)
        XCTAssertNil(automation.lastRun)
    }

    func test_automation_icon_basedOnFirstTrigger() {
        var automation = CustomAutomation(name: "Test")
        // No triggers
        XCTAssertEqual(automation.icon, "gearshape.2.fill")

        // Add a sunset trigger
        automation.triggers = [AutomationTrigger(type: .sunset)]
        XCTAssertEqual(automation.icon, "sunset.fill")

        // Change to time trigger
        automation.triggers = [AutomationTrigger(type: .time)]
        XCTAssertEqual(automation.icon, "clock.fill")
    }

    func test_automation_codableRoundtrip() throws {
        var automation = CustomAutomation(name: "Night Mode")
        automation.triggers = [AutomationTrigger(type: .time)]
        automation.conditions = [AutomationCondition()]
        automation.actions = [
            AutomationAction(actionType: .turnOff, delay: 0, order: 0),
            AutomationAction(actionType: .executeScene, delay: 2.0, order: 1)
        ]
        automation.isEnabled = false
        automation.runCount = 15

        let data = try JSONEncoder().encode(automation)
        let decoded = try JSONDecoder().decode(CustomAutomation.self, from: data)

        XCTAssertEqual(decoded.id, automation.id)
        XCTAssertEqual(decoded.name, "Night Mode")
        XCTAssertFalse(decoded.isEnabled)
        XCTAssertEqual(decoded.triggers.count, 1)
        XCTAssertEqual(decoded.conditions.count, 1)
        XCTAssertEqual(decoded.actions.count, 2)
        XCTAssertEqual(decoded.runCount, 15)
    }

    // MARK: - Action Ordering

    func test_actions_sortByOrder() {
        let action1 = AutomationAction(actionType: .turnOn, delay: 0, order: 2)
        let action2 = AutomationAction(actionType: .setBrightness, delay: 0, order: 0)
        let action3 = AutomationAction(actionType: .wait, delay: 5.0, order: 1)

        let sorted = [action1, action2, action3].sorted { $0.order < $1.order }

        XCTAssertEqual(sorted[0].actionType, .setBrightness)
        XCTAssertEqual(sorted[1].actionType, .wait)
        XCTAssertEqual(sorted[2].actionType, .turnOn)
    }
}
