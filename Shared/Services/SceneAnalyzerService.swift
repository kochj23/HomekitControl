//
//  SceneAnalyzerService.swift
//  HomekitControl
//
//  Service for analyzing and repairing HomeKit scenes
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation

#if canImport(HomeKit)
import HomeKit
#endif

/// Service for analyzing and repairing HomeKit scenes
@MainActor
final class SceneAnalyzerService: ObservableObject {
    static let shared = SceneAnalyzerService()

    // MARK: - Published Properties

    @Published var isAnalyzing = false
    @Published var analysisResults: [SceneAnalysisResult] = []
    @Published var statusMessage = ""

    // MARK: - Initialization

    private init() {}

    // MARK: - Scene Analysis

    #if canImport(HomeKit) && !os(macOS)
    func analyzeAllScenes(in home: HMHome) async -> [SceneAnalysisResult] {
        isAnalyzing = true
        analysisResults.removeAll()
        statusMessage = "Analyzing scenes..."

        let scenes = home.actionSets

        for scene in scenes {
            let result = analyzeScene(scene, in: home)
            analysisResults.append(result)
        }

        isAnalyzing = false
        statusMessage = "Analysis complete. \(analysisResults.filter { $0.hasIssues }.count) scenes have issues."
        clearStatusMessage()

        return analysisResults
    }

    func analyzeScene(_ scene: HMActionSet, in home: HMHome) -> SceneAnalysisResult {
        let actions = scene.actions
        var unreachableAccessories: [String] = []
        var accessoryNames: [String] = []

        for action in actions {
            if let charAction = action as? HMCharacteristicWriteAction<NSCopying> {
                let accessory = charAction.characteristic.service?.accessory
                let name = accessory?.name ?? "Unknown"
                accessoryNames.append(name)

                if accessory?.isReachable == false {
                    unreachableAccessories.append(name)
                }
            }
        }

        let healthStatus: HealthStatus
        if unreachableAccessories.isEmpty {
            healthStatus = .healthy
        } else if unreachableAccessories.count < actions.count / 2 {
            healthStatus = .degraded
        } else {
            healthStatus = .unreachable
        }

        return SceneAnalysisResult(
            sceneId: scene.uniqueIdentifier,
            sceneName: scene.name,
            actionCount: actions.count,
            accessoryNames: accessoryNames,
            unreachableAccessories: unreachableAccessories,
            healthStatus: healthStatus,
            analyzedAt: Date()
        )
    }

    // MARK: - Scene Repair (iOS only)

    #if os(iOS)
    func repairScene(_ scene: HMActionSet, in home: HMHome) async throws -> RepairResult {
        statusMessage = "Repairing \(scene.name)..."

        let unreachableActions = scene.actions.compactMap { action -> HMAction? in
            if let charAction = action as? HMCharacteristicWriteAction<NSCopying> {
                if charAction.characteristic.service?.accessory?.isReachable == false {
                    return action
                }
            }
            return nil
        }

        var removedCount = 0

        for action in unreachableActions {
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    scene.removeAction(action) { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
                removedCount += 1
            } catch {
                NSLog("[SceneAnalyzer] Failed to remove action: \(error)")
            }
        }

        statusMessage = "Removed \(removedCount) unreachable devices from \(scene.name)"
        clearStatusMessage()

        return RepairResult(
            sceneName: scene.name,
            removedCount: removedCount,
            success: removedCount > 0
        )
    }
    #endif
    #endif

    // MARK: - Convert to Unified Model

    func convertToUnifiedScene(_ result: SceneAnalysisResult) -> UnifiedScene {
        UnifiedScene(
            name: result.sceneName,
            accessoryCount: result.accessoryNames.count,
            accessoryNames: result.accessoryNames,
            actionCount: result.actionCount,
            hasUnreachableDevices: !result.unreachableAccessories.isEmpty,
            unreachableDeviceNames: result.unreachableAccessories,
            healthStatus: result.healthStatus
        )
    }

    // MARK: - Helpers

    private func clearStatusMessage() {
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            statusMessage = ""
        }
    }
}

// MARK: - Supporting Types

struct SceneAnalysisResult: Identifiable {
    let id = UUID()
    let sceneId: UUID
    let sceneName: String
    let actionCount: Int
    let accessoryNames: [String]
    let unreachableAccessories: [String]
    let healthStatus: HealthStatus
    let analyzedAt: Date

    var hasIssues: Bool {
        !unreachableAccessories.isEmpty
    }

    var issueCount: Int {
        unreachableAccessories.count
    }
}

struct RepairResult {
    let sceneName: String
    let removedCount: Int
    let success: Bool
}
