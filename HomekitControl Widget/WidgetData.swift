//
//  WidgetData.swift
//  HomekitControl Widget
//
//  Data models for widget display
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import WidgetKit

// MARK: - Widget Data Models

/// Data model for a scene displayed in the widget
struct WidgetScene: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let icon: String
    let sceneType: String
    let isFavorite: Bool
    let hasUnreachableDevices: Bool

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "sparkles",
        sceneType: String = "Custom",
        isFavorite: Bool = false,
        hasUnreachableDevices: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.sceneType = sceneType
        self.isFavorite = isFavorite
        self.hasUnreachableDevices = hasUnreachableDevices
    }
}

/// Data model for device health summary
struct WidgetDeviceHealth: Codable {
    let totalDevices: Int
    let healthyCount: Int
    let warningCount: Int
    let unreachableCount: Int
    let overallHealthPercentage: Double
    let lastUpdated: Date

    init(
        totalDevices: Int = 0,
        healthyCount: Int = 0,
        warningCount: Int = 0,
        unreachableCount: Int = 0,
        overallHealthPercentage: Double = 100.0,
        lastUpdated: Date = Date()
    ) {
        self.totalDevices = totalDevices
        self.healthyCount = healthyCount
        self.warningCount = warningCount
        self.unreachableCount = unreachableCount
        self.overallHealthPercentage = overallHealthPercentage
        self.lastUpdated = lastUpdated
    }

    /// Returns true if there are any device issues
    var hasIssues: Bool {
        unreachableCount > 0 || warningCount > 0
    }

    /// Returns a summary string for the health status
    var summaryText: String {
        if unreachableCount > 0 {
            return "\(unreachableCount) unreachable"
        } else if warningCount > 0 {
            return "\(warningCount) warning\(warningCount > 1 ? "s" : "")"
        } else {
            return "All healthy"
        }
    }
}

/// Complete widget data snapshot
struct WidgetData: Codable {
    let favoriteScenes: [WidgetScene]
    let deviceHealth: WidgetDeviceHealth
    let homeName: String
    let lastUpdated: Date

    init(
        favoriteScenes: [WidgetScene] = [],
        deviceHealth: WidgetDeviceHealth = WidgetDeviceHealth(),
        homeName: String = "Home",
        lastUpdated: Date = Date()
    ) {
        self.favoriteScenes = favoriteScenes
        self.deviceHealth = deviceHealth
        self.homeName = homeName
        self.lastUpdated = lastUpdated
    }

    /// Sample data for widget preview
    static let preview = WidgetData(
        favoriteScenes: [
            WidgetScene(name: "Good Morning", icon: "sun.max.fill", sceneType: "Good Morning", isFavorite: true),
            WidgetScene(name: "Good Night", icon: "moon.stars.fill", sceneType: "Good Night", isFavorite: true),
            WidgetScene(name: "Movie Time", icon: "sparkles", sceneType: "Custom", isFavorite: true),
            WidgetScene(name: "Away", icon: "figure.walk", sceneType: "Leave", isFavorite: true)
        ],
        deviceHealth: WidgetDeviceHealth(
            totalDevices: 24,
            healthyCount: 22,
            warningCount: 1,
            unreachableCount: 1,
            overallHealthPercentage: 91.7,
            lastUpdated: Date()
        ),
        homeName: "My Home",
        lastUpdated: Date()
    )

    /// Empty data for when no data is available
    static let empty = WidgetData()
}

// MARK: - Timeline Entry

/// Timeline entry for the widget
struct HomekitControlEntry: TimelineEntry {
    let date: Date
    let data: WidgetData

    init(date: Date = Date(), data: WidgetData = .empty) {
        self.date = date
        self.data = data
    }

    static let preview = HomekitControlEntry(data: .preview)
    static let empty = HomekitControlEntry(data: .empty)
}

// MARK: - Intent Configuration

/// Deep link URLs for widget actions
enum WidgetDeepLink {
    static let baseURL = "homekitcontrol://"

    static func executeScene(id: UUID) -> URL? {
        URL(string: "\(baseURL)scene/\(id.uuidString)")
    }

    static var openDevices: URL? {
        URL(string: "\(baseURL)devices")
    }

    static var openHealth: URL? {
        URL(string: "\(baseURL)health")
    }

    static var openScenes: URL? {
        URL(string: "\(baseURL)scenes")
    }
}
