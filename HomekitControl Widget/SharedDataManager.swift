//
//  SharedDataManager.swift
//  HomekitControl Widget
//
//  App Group data sharing between main app and widget
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import WidgetKit

/// Manager for sharing data between the main app and widget via App Groups
final class SharedDataManager {
    static let shared = SharedDataManager()

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
        UserDefaults(suiteName: SharedDataManager.appGroupIdentifier)
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Widget Data

    /// Save widget data to shared storage
    func saveWidgetData(_ data: WidgetData) {
        guard let defaults = sharedDefaults else {
            NSLog("[SharedDataManager] ERROR: Could not access shared UserDefaults")
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let encoded = try encoder.encode(data)
            defaults.set(encoded, forKey: widgetDataKey)
            defaults.synchronize()

            NSLog("[SharedDataManager] Saved widget data: \(data.favoriteScenes.count) scenes, \(data.deviceHealth.totalDevices) devices")
        } catch {
            NSLog("[SharedDataManager] ERROR: Failed to encode widget data: \(error.localizedDescription)")
        }
    }

    /// Load widget data from shared storage
    func loadWidgetData() -> WidgetData {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: widgetDataKey) else {
            NSLog("[SharedDataManager] No widget data found in shared storage")
            return .empty
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let widgetData = try decoder.decode(WidgetData.self, from: data)
            NSLog("[SharedDataManager] Loaded widget data: \(widgetData.favoriteScenes.count) scenes")
            return widgetData
        } catch {
            NSLog("[SharedDataManager] ERROR: Failed to decode widget data: \(error.localizedDescription)")
            return .empty
        }
    }

    // MARK: - Favorite Scenes

    /// Save favorite scene IDs
    func saveFavoriteSceneIDs(_ ids: [UUID]) {
        guard let defaults = sharedDefaults else { return }

        let idStrings = ids.map { $0.uuidString }
        defaults.set(idStrings, forKey: favoriteScenesKey)
        defaults.synchronize()
    }

    /// Load favorite scene IDs
    func loadFavoriteSceneIDs() -> [UUID] {
        guard let defaults = sharedDefaults,
              let idStrings = defaults.stringArray(forKey: favoriteScenesKey) else {
            return []
        }

        return idStrings.compactMap { UUID(uuidString: $0) }
    }

    // MARK: - Widget Refresh

    /// Request widget timeline refresh
    func refreshWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
        NSLog("[SharedDataManager] Requested widget timeline refresh")
    }

    /// Request refresh for specific widget kind
    func refreshWidget(kind: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
        NSLog("[SharedDataManager] Requested refresh for widget: \(kind)")
    }

    // MARK: - Convenience Methods

    /// Check if widget data exists
    var hasWidgetData: Bool {
        guard let defaults = sharedDefaults else { return false }
        return defaults.data(forKey: widgetDataKey) != nil
    }

    /// Clear all widget data
    func clearWidgetData() {
        guard let defaults = sharedDefaults else { return }
        defaults.removeObject(forKey: widgetDataKey)
        defaults.removeObject(forKey: favoriteScenesKey)
        defaults.synchronize()
        NSLog("[SharedDataManager] Cleared all widget data")
    }

    /// Get the age of the cached widget data
    func getDataAge() -> TimeInterval? {
        let data = loadWidgetData()
        guard data.lastUpdated != Date.distantPast else { return nil }
        return Date().timeIntervalSince(data.lastUpdated)
    }
}

// MARK: - Main App Integration

extension SharedDataManager {
    /// Update widget data from main app
    /// Call this when devices or scenes change in the main app
    func updateFromMainApp(
        favoriteScenes: [WidgetScene],
        totalDevices: Int,
        healthyCount: Int,
        warningCount: Int,
        unreachableCount: Int,
        homeName: String
    ) {
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
            homeName: homeName,
            lastUpdated: Date()
        )

        saveWidgetData(widgetData)
        refreshWidgets()
    }
}
