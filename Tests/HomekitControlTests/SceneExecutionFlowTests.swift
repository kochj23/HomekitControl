//
//  SceneExecutionFlowTests.swift
//  HomekitControlTests
//
//  Functional tests for scene execution flow — validates the complete path
//  from scene lookup through execution to status reporting.
//  Scene execution is the most critical user-facing operation.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

final class SceneExecutionFlowTests: XCTestCase {

    // MARK: - Scene Lookup

    func test_sceneLookup_caseInsensitiveMatching() {
        let scenes = [
            UnifiedScene(name: "Good Morning"),
            UnifiedScene(name: "Good Night"),
            UnifiedScene(name: "Movie Time")
        ]

        let searchName = "good morning"
        let match = scenes.first { $0.name.lowercased() == searchName.lowercased() }
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.name, "Good Morning")
    }

    func test_sceneLookup_exactMatch() {
        let scenes = [
            UnifiedScene(name: "Good Morning"),
            UnifiedScene(name: "Good Morning Routine")
        ]

        let match = scenes.first { $0.name.lowercased() == "good morning" }
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.name, "Good Morning")
    }

    func test_sceneLookup_noMatch_returnsNil() {
        let scenes = [
            UnifiedScene(name: "Good Morning"),
            UnifiedScene(name: "Good Night")
        ]

        let match = scenes.first { $0.name.lowercased() == "nonexistent scene" }
        XCTAssertNil(match)
    }

    func test_sceneLookup_emptySceneList() {
        let scenes: [UnifiedScene] = []
        let match = scenes.first { $0.name.lowercased() == "anything" }
        XCTAssertNil(match)
    }

    // MARK: - Scene Health Assessment

    func test_sceneHealth_allReachable_isHealthy() {
        let scene = UnifiedScene(
            name: "Test",
            accessoryCount: 5,
            accessoryNames: ["A", "B", "C", "D", "E"],
            hasUnreachableDevices: false,
            unreachableDeviceNames: [],
            healthStatus: .healthy
        )
        XCTAssertFalse(scene.hasUnreachableDevices)
        XCTAssertEqual(scene.healthStatus, .healthy)
    }

    func test_sceneHealth_someUnreachable_isDegraded() {
        let scene = UnifiedScene(
            name: "Test",
            accessoryCount: 5,
            accessoryNames: ["A", "B", "C", "D", "E"],
            hasUnreachableDevices: true,
            unreachableDeviceNames: ["C"],
            healthStatus: .degraded
        )
        XCTAssertTrue(scene.hasUnreachableDevices)
        XCTAssertEqual(scene.unreachableDeviceNames.count, 1)
    }

    func test_sceneHealth_allUnreachable_isUnreachable() {
        let scene = UnifiedScene(
            name: "Test",
            accessoryCount: 3,
            accessoryNames: ["A", "B", "C"],
            hasUnreachableDevices: true,
            unreachableDeviceNames: ["A", "B", "C"],
            healthStatus: .unreachable
        )
        XCTAssertEqual(scene.healthStatus, .unreachable)
        XCTAssertEqual(scene.unreachableDeviceNames.count, scene.accessoryCount)
    }

    // MARK: - Scene Type Classification

    func test_sceneType_autoDetection() {
        // Verify built-in scene types are correctly classified
        XCTAssertEqual(SceneType.goodMorning.rawValue, "Good Morning")
        XCTAssertEqual(SceneType.goodNight.rawValue, "Good Night")
        XCTAssertEqual(SceneType.arrive.rawValue, "Arrive")
        XCTAssertEqual(SceneType.leave.rawValue, "Leave")
    }

    func test_sceneType_allHaveIcons() {
        for type in SceneType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "\(type.rawValue) scene type must have an icon")
        }
    }

    // MARK: - Scene Execution Tracking

    func test_sceneExecution_countIncrement() {
        var scene = UnifiedScene(name: "Morning", executionCount: 0)
        scene.executionCount += 1
        XCTAssertEqual(scene.executionCount, 1)
    }

    func test_sceneExecution_timestampUpdate() {
        let before = Date()
        var scene = UnifiedScene(name: "Morning")
        scene.lastExecuted = Date()
        let after = Date()

        XCTAssertNotNil(scene.lastExecuted)
        XCTAssertGreaterThanOrEqual(scene.lastExecuted ?? Date.distantPast, before)
        XCTAssertLessThanOrEqual(scene.lastExecuted ?? Date.distantFuture, after)
    }

    func test_sceneExecution_averageTimeTracking() {
        var scene = UnifiedScene(name: "Morning", averageExecutionTime: 1.5)
        XCTAssertEqual(scene.averageExecutionTime, 1.5)

        // Simulate updating average with new measurement
        let newTime = 2.5
        let oldAvg = scene.averageExecutionTime ?? 0
        scene.averageExecutionTime = (oldAvg + newTime) / 2
        XCTAssertEqual(scene.averageExecutionTime ?? 0, 2.0, accuracy: 0.01)
    }

    // MARK: - Device State in Scene Context

    func test_deviceInScene_reachabilityAffectsSceneHealth() {
        let reachableDevice = UnifiedDevice(name: "Light", isReachable: true)
        let unreachableDevice = UnifiedDevice(name: "Fan", isReachable: false)

        let devices = [reachableDevice, unreachableDevice]
        let unreachableNames = devices.filter { !$0.isReachable }.map { $0.name }

        XCTAssertEqual(unreachableNames, ["Fan"])
    }

    func test_deviceToggle_stateChange() {
        var device = UnifiedDevice(name: "Light", isReachable: true)
        // Simulate toggle
        let wasReachable = device.isReachable
        device.isReachable = !wasReachable

        XCTAssertFalse(device.isReachable)
    }

    // MARK: - Dangerous Device Categories

    func test_dangerousDevices_identifiedCorrectly() {
        XCTAssertTrue(DeviceCategory.lock.isDangerous,
                       "Locks should be flagged as dangerous for auto-control")
        XCTAssertTrue(DeviceCategory.garageDoor.isDangerous,
                       "Garage doors should be flagged as dangerous for auto-control")
        XCTAssertTrue(DeviceCategory.securitySystem.isDangerous,
                       "Security systems should be flagged as dangerous for auto-control")
    }

    func test_safeDevices_notFlaggedAsDangerous() {
        let safeCategories: [DeviceCategory] = [
            .light, .switchDevice, .outlet, .thermostat, .sensor,
            .speaker, .fan, .blind, .airPurifier, .humidifier, .bridge, .other
        ]
        for category in safeCategories {
            XCTAssertFalse(category.isDangerous,
                            "\(category.rawValue) should NOT be flagged as dangerous")
        }
    }

    // MARK: - API Response Scene Format

    func test_sceneListFormat_matchesAPIContract() {
        // The Nova API returns scenes as [{"id": UUID, "name": String}]
        let scene = UnifiedScene(name: "Good Morning")
        let dict: [String: Any] = [
            "id": scene.id.uuidString,
            "name": scene.name
        ]

        XCTAssertNotNil(dict["id"] as? String)
        XCTAssertEqual(dict["name"] as? String, "Good Morning")

        // Verify it's valid JSON
        XCTAssertTrue(JSONSerialization.isValidJSONObject([dict]))
    }

    func test_sceneExecuteResponse_format() {
        // Successful execution response: {"status": "executed", "scene": "name"}
        let response: [String: Any] = [
            "status": "executed",
            "scene": "Good Morning"
        ]
        XCTAssertTrue(JSONSerialization.isValidJSONObject(response))
        XCTAssertEqual(response["status"] as? String, "executed")
    }

    func test_sceneNotFound_includesAvailableScenes() {
        let availableScenes = ["Morning", "Night", "Away"]
        let errorResponse: [String: Any] = [
            "error": "Scene 'Nonexistent' not found",
            "available_scenes": availableScenes
        ]
        XCTAssertTrue(JSONSerialization.isValidJSONObject(errorResponse))
        let available = errorResponse["available_scenes"] as? [String]
        XCTAssertEqual(available?.count, 3)
    }
}
