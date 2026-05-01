//
//  EnumCodableTests.swift
//  HomekitControlTests
//
//  Exhaustive Codable roundtrip tests for ALL enums in the codebase.
//  An enum that fails to decode from persisted data means data loss.
//  This is particularly dangerous for HealthStatus and DeviceCategory
//  which affect physical device control decisions.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

final class EnumCodableTests: XCTestCase {

    // MARK: - DeviceProtocol

    func test_deviceProtocol_allCasesRoundtrip() throws {
        for proto in DeviceProtocol.allCases {
            let data = try JSONEncoder().encode(proto)
            let decoded = try JSONDecoder().decode(DeviceProtocol.self, from: data)
            XCTAssertEqual(decoded, proto, "Roundtrip failed for \(proto)")
        }
    }

    func test_deviceProtocol_icons() {
        for proto in DeviceProtocol.allCases {
            XCTAssertFalse(proto.icon.isEmpty, "\(proto) has no icon")
        }
    }

    func test_deviceProtocol_caseCount() {
        XCTAssertEqual(DeviceProtocol.allCases.count, 7)
    }

    // MARK: - HealthStatus

    func test_healthStatus_allCasesRoundtrip() throws {
        for status in HealthStatus.allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(HealthStatus.self, from: data)
            XCTAssertEqual(decoded, status, "Roundtrip failed for \(status)")
        }
    }

    func test_healthStatus_icons() {
        for status in HealthStatus.allCases {
            XCTAssertFalse(status.icon.isEmpty, "\(status) has no icon")
        }
    }

    func test_healthStatus_caseCount() {
        XCTAssertEqual(HealthStatus.allCases.count, 7)
    }

    // MARK: - TriggerType

    func test_triggerType_allCasesRoundtrip() throws {
        for trigger in TriggerType.allCases {
            let data = try JSONEncoder().encode(trigger)
            let decoded = try JSONDecoder().decode(TriggerType.self, from: data)
            XCTAssertEqual(decoded, trigger, "Roundtrip failed for \(trigger)")
        }
    }

    // MARK: - ConditionOperator

    func test_conditionOperator_allCasesRoundtrip() throws {
        for op in ConditionOperator.allCases {
            let data = try JSONEncoder().encode(op)
            let decoded = try JSONDecoder().decode(ConditionOperator.self, from: data)
            XCTAssertEqual(decoded, op, "Roundtrip failed for \(op)")
        }
    }

    // MARK: - AutomationAction.ActionType

    func test_actionType_allCasesRoundtrip() throws {
        for action in AutomationAction.ActionType.allCases {
            let data = try JSONEncoder().encode(action)
            let decoded = try JSONDecoder().decode(AutomationAction.ActionType.self, from: data)
            XCTAssertEqual(decoded, action, "Roundtrip failed for \(action)")
        }
    }

    // MARK: - ThermostatMode

    func test_thermostatMode_allCasesRoundtrip() throws {
        for mode in ThermostatMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(ThermostatMode.self, from: data)
            XCTAssertEqual(decoded, mode, "Roundtrip failed for \(mode)")
        }
    }

    // MARK: - SecurityMode

    func test_securityMode_allCasesRoundtrip() throws {
        for mode in SecurityMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(SecurityMode.self, from: data)
            XCTAssertEqual(decoded, mode, "Roundtrip failed for \(mode)")
        }
    }

    // MARK: - ExportFormat

    func test_exportFormat_allCasesRoundtrip() {
        for format in ExportFormat.allCases {
            XCTAssertFalse(format.fileExtension.isEmpty)
            XCTAssertFalse(format.mimeType.isEmpty)
        }
    }

    // MARK: - DiscoverySource

    func test_discoverySource_allCasesRoundtrip() throws {
        for source in DiscoverySource.allCases {
            let data = try JSONEncoder().encode(source)
            let decoded = try JSONDecoder().decode(DiscoverySource.self, from: data)
            XCTAssertEqual(decoded, source, "Roundtrip failed for \(source)")
        }
    }

    // MARK: - SceneSchedule.ScheduleType

    func test_scheduleType_allCasesRoundtrip() throws {
        for type in SceneSchedule.ScheduleType.allCases {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(SceneSchedule.ScheduleType.self, from: data)
            XCTAssertEqual(decoded, type, "Roundtrip failed for \(type)")
        }
    }

    // MARK: - UsagePattern.DeviceAction

    func test_deviceAction_roundtrip() throws {
        let actions: [UsagePattern.DeviceAction] = [
            .turnedOn, .turnedOff, .brightnessChanged, .colorChanged, .sceneActivated
        ]
        for action in actions {
            let data = try JSONEncoder().encode(action)
            let decoded = try JSONDecoder().decode(UsagePattern.DeviceAction.self, from: data)
            XCTAssertEqual(decoded, action, "Roundtrip failed for \(action)")
        }
    }
}
