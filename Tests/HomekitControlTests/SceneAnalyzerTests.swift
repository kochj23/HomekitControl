//
//  SceneAnalyzerTests.swift
//  HomekitControlTests
//
//  Tests for SceneAnalysisResult and convertToUnifiedScene.
//  Analysis results determine which scenes are flagged as degraded or broken.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

final class SceneAnalyzerTests: XCTestCase {

    // MARK: - SceneAnalysisResult

    func test_analysisResult_hasIssues_withUnreachable() {
        let result = SceneAnalysisResult(
            sceneId: UUID(),
            sceneName: "Test",
            actionCount: 5,
            accessoryNames: ["Light", "Fan"],
            unreachableAccessories: ["Fan"],
            healthStatus: .degraded,
            analyzedAt: Date()
        )
        XCTAssertTrue(result.hasIssues)
        XCTAssertEqual(result.issueCount, 1)
    }

    func test_analysisResult_noIssues() {
        let result = SceneAnalysisResult(
            sceneId: UUID(),
            sceneName: "Healthy Scene",
            actionCount: 3,
            accessoryNames: ["Light 1", "Light 2"],
            unreachableAccessories: [],
            healthStatus: .healthy,
            analyzedAt: Date()
        )
        XCTAssertFalse(result.hasIssues)
        XCTAssertEqual(result.issueCount, 0)
    }

    func test_analysisResult_multipleIssues() {
        let result = SceneAnalysisResult(
            sceneId: UUID(),
            sceneName: "Broken Scene",
            actionCount: 4,
            accessoryNames: ["A", "B", "C", "D"],
            unreachableAccessories: ["A", "C", "D"],
            healthStatus: .unreachable,
            analyzedAt: Date()
        )
        XCTAssertTrue(result.hasIssues)
        XCTAssertEqual(result.issueCount, 3)
    }

    // MARK: - Convert to UnifiedScene

    @MainActor
    func test_convertToUnifiedScene() {
        let service = SceneAnalyzerService.shared
        let result = SceneAnalysisResult(
            sceneId: UUID(),
            sceneName: "Good Night",
            actionCount: 8,
            accessoryNames: ["Light 1", "Light 2", "Lock"],
            unreachableAccessories: ["Lock"],
            healthStatus: .degraded,
            analyzedAt: Date()
        )

        let scene = service.convertToUnifiedScene(result)

        XCTAssertEqual(scene.name, "Good Night")
        XCTAssertEqual(scene.accessoryCount, 3)
        XCTAssertEqual(scene.accessoryNames, ["Light 1", "Light 2", "Lock"])
        XCTAssertEqual(scene.actionCount, 8)
        XCTAssertTrue(scene.hasUnreachableDevices)
        XCTAssertEqual(scene.unreachableDeviceNames, ["Lock"])
        XCTAssertEqual(scene.healthStatus, .degraded)
    }

    @MainActor
    func test_convertToUnifiedScene_healthy() {
        let service = SceneAnalyzerService.shared
        let result = SceneAnalysisResult(
            sceneId: UUID(),
            sceneName: "Morning",
            actionCount: 3,
            accessoryNames: ["Light"],
            unreachableAccessories: [],
            healthStatus: .healthy,
            analyzedAt: Date()
        )

        let scene = service.convertToUnifiedScene(result)

        XCTAssertFalse(scene.hasUnreachableDevices)
        XCTAssertTrue(scene.unreachableDeviceNames.isEmpty)
        XCTAssertEqual(scene.healthStatus, .healthy)
    }

    // MARK: - RepairResult

    func test_repairResult_success() {
        let result = RepairResult(sceneName: "Test", removedCount: 2, success: true)
        XCTAssertEqual(result.sceneName, "Test")
        XCTAssertEqual(result.removedCount, 2)
        XCTAssertTrue(result.success)
    }

    func test_repairResult_noChanges() {
        let result = RepairResult(sceneName: "Clean", removedCount: 0, success: false)
        XCTAssertEqual(result.removedCount, 0)
        XCTAssertFalse(result.success)
    }
}
