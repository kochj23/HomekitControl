//
//  UnifiedSceneTests.swift
//  HomekitControlTests
//
//  Tests for UnifiedScene and SceneType models.
//  Scene data integrity directly affects which devices get activated
//  when a scene is executed.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

final class UnifiedSceneTests: XCTestCase {

    // MARK: - Initialization Defaults

    func test_init_defaults() {
        let scene = UnifiedScene(name: "Test Scene")

        XCTAssertEqual(scene.name, "Test Scene")
        XCTAssertNil(scene.home)
        XCTAssertNil(scene.roomName)
        XCTAssertEqual(scene.accessoryCount, 0)
        XCTAssertTrue(scene.accessoryNames.isEmpty)
        XCTAssertEqual(scene.actionCount, 0)
        XCTAssertFalse(scene.hasUnreachableDevices)
        XCTAssertTrue(scene.unreachableDeviceNames.isEmpty)
        XCTAssertEqual(scene.healthStatus, .unknown)
        XCTAssertNil(scene.lastExecuted)
        XCTAssertEqual(scene.executionCount, 0)
        XCTAssertNil(scene.averageExecutionTime)
        XCTAssertFalse(scene.isBuiltIn)
        XCTAssertEqual(scene.sceneType, .custom)
    }

    func test_init_fullScene() {
        let now = Date()
        let scene = UnifiedScene(
            name: "Good Morning",
            home: "My Home",
            roomName: "Living Room",
            accessoryCount: 5,
            accessoryNames: ["Light 1", "Light 2", "Fan", "Blind", "Speaker"],
            actionCount: 10,
            hasUnreachableDevices: true,
            unreachableDeviceNames: ["Fan"],
            healthStatus: .degraded,
            lastExecuted: now,
            executionCount: 42,
            averageExecutionTime: 1.5,
            isBuiltIn: true,
            sceneType: .goodMorning
        )

        XCTAssertEqual(scene.name, "Good Morning")
        XCTAssertEqual(scene.home, "My Home")
        XCTAssertEqual(scene.accessoryCount, 5)
        XCTAssertEqual(scene.accessoryNames.count, 5)
        XCTAssertTrue(scene.hasUnreachableDevices)
        XCTAssertEqual(scene.unreachableDeviceNames, ["Fan"])
        XCTAssertEqual(scene.healthStatus, .degraded)
        XCTAssertEqual(scene.executionCount, 42)
        XCTAssertEqual(scene.averageExecutionTime, 1.5)
        XCTAssertTrue(scene.isBuiltIn)
        XCTAssertEqual(scene.sceneType, .goodMorning)
    }

    // MARK: - Codable

    func test_codableRoundtrip() throws {
        let original = UnifiedScene(
            name: "Movie Night",
            home: "Home",
            accessoryCount: 3,
            accessoryNames: ["TV", "Dimmer", "Blinds"],
            actionCount: 6,
            healthStatus: .healthy,
            sceneType: .custom
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UnifiedScene.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.home, original.home)
        XCTAssertEqual(decoded.accessoryCount, original.accessoryCount)
        XCTAssertEqual(decoded.accessoryNames, original.accessoryNames)
        XCTAssertEqual(decoded.actionCount, original.actionCount)
        XCTAssertEqual(decoded.healthStatus, original.healthStatus)
        XCTAssertEqual(decoded.sceneType, original.sceneType)
    }
}

// MARK: - SceneType Tests

final class SceneTypeTests: XCTestCase {

    func test_allSceneTypes_haveIcons() {
        for type in SceneType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "\(type) has no icon")
        }
    }

    func test_sceneType_rawValues() {
        XCTAssertEqual(SceneType.goodMorning.rawValue, "Good Morning")
        XCTAssertEqual(SceneType.goodNight.rawValue, "Good Night")
        XCTAssertEqual(SceneType.arrive.rawValue, "Arrive")
        XCTAssertEqual(SceneType.leave.rawValue, "Leave")
        XCTAssertEqual(SceneType.custom.rawValue, "Custom")
    }

    func test_sceneType_codableRoundtrip() throws {
        for type in SceneType.allCases {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(SceneType.self, from: data)
            XCTAssertEqual(decoded, type, "Roundtrip failed for \(type)")
        }
    }

    func test_sceneType_caseCount() {
        XCTAssertEqual(SceneType.allCases.count, 5)
    }
}
