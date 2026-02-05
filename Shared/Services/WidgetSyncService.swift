//
//  WidgetSyncService.swift
//  HomekitControl
//
//  Service for syncing data between main app and widget
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import WidgetKit

#if canImport(HomeKit)
import HomeKit
#endif

/// Service for syncing HomeKit data to the widget extension
@MainActor
final class WidgetSyncService: ObservableObject {
    static let shared = WidgetSyncService()

    // MARK: - Constants

    /// App Group identifier for shared data
    static let appGroupIdentifier = "group.com.jkoch.homekitcontrol"

    /// Key for storing widget data in UserDefaults
    private let widgetDataKey = "HomekitControlWidgetData"

    /// Key for storing favorite scene IDs
    private let favoriteScenesKey = "HomekitControlFavoriteScenes"

    // MARK: - Properties

    /// Shared UserDefaults for App Group
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: WidgetSyncService.appGroupIdentifier)
    }

    /// Favorite scene IDs
    @Published var favoriteSceneIDs: Set<UUID> = []

    // MARK: - Initialization

    private init() {
        loadFavoriteScenes()
    }

    // MARK: - Widget Data Models (Duplicated for main app access)

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
    }

    // MARK: - Favorite Scenes Management

    /// Add a scene to favorites
    func addFavorite(sceneID: UUID) {
        favoriteSceneIDs.insert(sceneID)
        saveFavoriteScenes()
        syncToWidget()
    }

    /// Remove a scene from favorites
    func removeFavorite(sceneID: UUID) {
        favoriteSceneIDs.remove(sceneID)
        saveFavoriteScenes()
        syncToWidget()
    }

    /// Toggle favorite status for a scene
    func toggleFavorite(sceneID: UUID) {
        if favoriteSceneIDs.contains(sceneID) {
            removeFavorite(sceneID: sceneID)
        } else {
            addFavorite(sceneID: sceneID)
        }
    }

    /// Check if a scene is a favorite
    func isFavorite(sceneID: UUID) -> Bool {
        favoriteSceneIDs.contains(sceneID)
    }

    private func saveFavoriteScenes() {
        guard let defaults = sharedDefaults else { return }
        let idStrings = favoriteSceneIDs.map { $0.uuidString }
        defaults.set(Array(idStrings), forKey: favoriteScenesKey)
        defaults.synchronize()
    }

    private func loadFavoriteScenes() {
        guard let defaults = sharedDefaults,
              let idStrings = defaults.stringArray(forKey: favoriteScenesKey) else {
            return
        }
        favoriteSceneIDs = Set(idStrings.compactMap { UUID(uuidString: $0) })
    }

    // MARK: - Widget Sync

    /// Sync current HomeKit data to the widget
    func syncToWidget() {
        #if canImport(HomeKit) && !os(macOS)
        syncHomeKitDataToWidget()
        #else
        syncManualDataToWidget()
        #endif
    }

    #if canImport(HomeKit) && !os(macOS)
    /// Sync HomeKit data to widget (iOS/tvOS)
    private func syncHomeKitDataToWidget() {
        let homeService = HomeKitService.shared
        let healthService = DeviceHealthService.shared

        guard let home = homeService.currentHome else {
            NSLog("[WidgetSyncService] No current home available")
            return
        }

        // Build favorite scenes list
        var favoriteScenes: [WidgetScene] = []
        for scene in homeService.scenes {
            if favoriteSceneIDs.contains(scene.uniqueIdentifier) {
                let hasUnreachable = scene.actions.contains { action in
                    if let charAction = action as? HMCharacteristicWriteAction<NSCopying> {
                        return !(charAction.characteristic.service?.accessory?.isReachable ?? true)
                    }
                    return false
                }

                let icon = getSceneIcon(for: scene.name)
                let sceneType = getSceneType(for: scene.name)

                favoriteScenes.append(WidgetScene(
                    id: scene.uniqueIdentifier,
                    name: scene.name,
                    icon: icon,
                    sceneType: sceneType,
                    isFavorite: true,
                    hasUnreachableDevices: hasUnreachable
                ))
            }
        }

        // Calculate device health stats
        var healthyCount = 0
        var warningCount = 0
        var unreachableCount = 0

        for accessory in homeService.accessories {
            if !accessory.isReachable {
                unreachableCount += 1
            } else {
                let status = healthService.getHealthStatus(for: accessory.uniqueIdentifier)
                switch status {
                case .healthy:
                    healthyCount += 1
                case .warning, .degraded:
                    warningCount += 1
                case .critical, .unreachable:
                    unreachableCount += 1
                default:
                    healthyCount += 1  // Assume healthy if unknown
                }
            }
        }

        let totalDevices = homeService.accessories.count
        let healthPercentage = totalDevices > 0 ? Double(healthyCount) / Double(totalDevices) * 100.0 : 100.0

        let deviceHealth = WidgetDeviceHealth(
            totalDevices: totalDevices,
            healthyCount: healthyCount,
            warningCount: warningCount,
            unreachableCount: unreachableCount,
            overallHealthPercentage: healthPercentage,
            lastUpdated: Date()
        )

        let widgetData = WidgetData(
            favoriteScenes: favoriteScenes,
            deviceHealth: deviceHealth,
            homeName: home.name,
            lastUpdated: Date()
        )

        saveWidgetData(widgetData)
        refreshWidgets()

        NSLog("[WidgetSyncService] Synced to widget: \(favoriteScenes.count) scenes, \(totalDevices) devices (\(unreachableCount) unreachable)")
    }
    #endif

    /// Sync manual data to widget (macOS)
    private func syncManualDataToWidget() {
        #if os(macOS)
        let devices = HomeKitService.shared.manualDevices
        let healthService = DeviceHealthService.shared

        var healthyCount = 0
        var warningCount = 0
        var unreachableCount = 0

        for device in devices {
            if !device.isReachable {
                unreachableCount += 1
            } else {
                let status = healthService.getHealthStatus(for: device.id)
                switch status {
                case .healthy:
                    healthyCount += 1
                case .warning, .degraded:
                    warningCount += 1
                case .critical, .unreachable:
                    unreachableCount += 1
                default:
                    healthyCount += 1
                }
            }
        }

        let totalDevices = devices.count
        let healthPercentage = totalDevices > 0 ? Double(healthyCount) / Double(totalDevices) * 100.0 : 100.0

        let deviceHealth = WidgetDeviceHealth(
            totalDevices: totalDevices,
            healthyCount: healthyCount,
            warningCount: warningCount,
            unreachableCount: unreachableCount,
            overallHealthPercentage: healthPercentage,
            lastUpdated: Date()
        )

        let widgetData = WidgetData(
            favoriteScenes: [],  // No scenes on macOS
            deviceHealth: deviceHealth,
            homeName: "My Home",
            lastUpdated: Date()
        )

        saveWidgetData(widgetData)
        refreshWidgets()
        #endif
    }

    // MARK: - Persistence

    private func saveWidgetData(_ data: WidgetData) {
        guard let defaults = sharedDefaults else {
            NSLog("[WidgetSyncService] ERROR: Could not access shared UserDefaults")
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let encoded = try encoder.encode(data)
            defaults.set(encoded, forKey: widgetDataKey)
            defaults.synchronize()
        } catch {
            NSLog("[WidgetSyncService] ERROR: Failed to encode widget data: \(error.localizedDescription)")
        }
    }

    // MARK: - Widget Refresh

    private func refreshWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Helpers

    private func getSceneIcon(for name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("morning") || lowercased.contains("sunrise") {
            return "sun.max.fill"
        } else if lowercased.contains("night") || lowercased.contains("sleep") || lowercased.contains("bedtime") {
            return "moon.stars.fill"
        } else if lowercased.contains("arrive") || lowercased.contains("home") {
            return "house.fill"
        } else if lowercased.contains("leave") || lowercased.contains("away") || lowercased.contains("goodbye") {
            return "figure.walk"
        } else if lowercased.contains("movie") || lowercased.contains("cinema") || lowercased.contains("tv") {
            return "tv.fill"
        } else if lowercased.contains("party") || lowercased.contains("entertain") {
            return "party.popper.fill"
        } else if lowercased.contains("relax") || lowercased.contains("chill") {
            return "leaf.fill"
        } else if lowercased.contains("work") || lowercased.contains("focus") || lowercased.contains("study") {
            return "desktopcomputer"
        } else if lowercased.contains("dinner") || lowercased.contains("dining") {
            return "fork.knife"
        } else if lowercased.contains("bright") || lowercased.contains("all on") {
            return "lightbulb.fill"
        } else if lowercased.contains("off") || lowercased.contains("dark") {
            return "lightbulb.slash.fill"
        }
        return "sparkles"
    }

    private func getSceneType(for name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("morning") || lowercased.contains("sunrise") {
            return "Good Morning"
        } else if lowercased.contains("night") || lowercased.contains("sleep") || lowercased.contains("bedtime") {
            return "Good Night"
        } else if lowercased.contains("arrive") || lowercased.contains("home") {
            return "Arrive"
        } else if lowercased.contains("leave") || lowercased.contains("away") || lowercased.contains("goodbye") {
            return "Leave"
        }
        return "Custom"
    }
}
