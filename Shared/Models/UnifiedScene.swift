//
//  UnifiedScene.swift
//  HomekitControl
//
//  Unified scene model for all platforms
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Unified scene model that works across all platforms
struct UnifiedScene: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var home: String?
    var roomName: String?

    // MARK: - Scene Contents

    var accessoryCount: Int
    var accessoryNames: [String]
    var actionCount: Int

    // MARK: - Health

    var hasUnreachableDevices: Bool
    var unreachableDeviceNames: [String]
    var healthStatus: HealthStatus

    // MARK: - Execution Info

    var lastExecuted: Date?
    var executionCount: Int
    var averageExecutionTime: Double?

    // MARK: - Type

    var isBuiltIn: Bool
    var sceneType: SceneType

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        home: String? = nil,
        roomName: String? = nil,
        accessoryCount: Int = 0,
        accessoryNames: [String] = [],
        actionCount: Int = 0,
        hasUnreachableDevices: Bool = false,
        unreachableDeviceNames: [String] = [],
        healthStatus: HealthStatus = .unknown,
        lastExecuted: Date? = nil,
        executionCount: Int = 0,
        averageExecutionTime: Double? = nil,
        isBuiltIn: Bool = false,
        sceneType: SceneType = .custom
    ) {
        self.id = id
        self.name = name
        self.home = home
        self.roomName = roomName
        self.accessoryCount = accessoryCount
        self.accessoryNames = accessoryNames
        self.actionCount = actionCount
        self.hasUnreachableDevices = hasUnreachableDevices
        self.unreachableDeviceNames = unreachableDeviceNames
        self.healthStatus = healthStatus
        self.lastExecuted = lastExecuted
        self.executionCount = executionCount
        self.averageExecutionTime = averageExecutionTime
        self.isBuiltIn = isBuiltIn
        self.sceneType = sceneType
    }
}

// MARK: - Scene Type

enum SceneType: String, Codable, CaseIterable, Hashable {
    case goodMorning = "Good Morning"
    case goodNight = "Good Night"
    case arrive = "Arrive"
    case leave = "Leave"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .goodMorning: return "sun.max.fill"
        case .goodNight: return "moon.stars.fill"
        case .arrive: return "house.fill"
        case .leave: return "figure.walk"
        case .custom: return "sparkles"
        }
    }
}
