//
//  SiriShortcutsService.swift
//  HomekitControl
//
//  Siri Shortcuts and widget integration
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI
#if canImport(Intents)
import Intents
#endif
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Shortcut Models

struct ShortcutAction: Codable, Identifiable {
    let id: UUID
    var name: String
    var actionType: ActionType
    var targetId: UUID? // Device or Scene ID
    var targetName: String
    var phrase: String?
    var isEnabled: Bool
    var iconName: String
    var iconColor: String

    enum ActionType: String, Codable, CaseIterable {
        case toggleDevice = "Toggle Device"
        case turnOnDevice = "Turn On Device"
        case turnOffDevice = "Turn Off Device"
        case executeScene = "Execute Scene"
        case runAutomation = "Run Automation"
        case controlGroup = "Control Group"

        var icon: String {
            switch self {
            case .toggleDevice: return "power"
            case .turnOnDevice: return "lightbulb.fill"
            case .turnOffDevice: return "lightbulb.slash"
            case .executeScene: return "theatermasks.fill"
            case .runAutomation: return "gearshape.2.fill"
            case .controlGroup: return "rectangle.3.group.fill"
            }
        }
    }

    init(name: String, actionType: ActionType, targetId: UUID?, targetName: String) {
        self.id = UUID()
        self.name = name
        self.actionType = actionType
        self.targetId = targetId
        self.targetName = targetName
        self.isEnabled = true
        self.iconName = actionType.icon
        self.iconColor = "cyan"
    }
}

struct WidgetData: Codable {
    let favoriteDevices: [UUID]
    let favoriteScenes: [UUID]
    let quickActions: [UUID]
    let lastUpdated: Date
}

// MARK: - Siri Shortcuts Service

@MainActor
class SiriShortcutsService: ObservableObject {
    static let shared = SiriShortcutsService()

    @Published var shortcuts: [ShortcutAction] = []
    @Published var widgetData = WidgetData(favoriteDevices: [], favoriteScenes: [], quickActions: [], lastUpdated: Date())

    private let storageKey = "HomekitControl_SiriShortcuts"
    private let widgetGroupId = "group.com.kochj.HomekitControl"

    private init() {
        loadData()
    }

    // MARK: - Shortcut Management

    func createShortcut(name: String, actionType: ShortcutAction.ActionType, targetId: UUID?, targetName: String) -> ShortcutAction {
        let shortcut = ShortcutAction(name: name, actionType: actionType, targetId: targetId, targetName: targetName)
        shortcuts.append(shortcut)
        saveData()
        donateShortcut(shortcut)
        return shortcut
    }

    func updateShortcut(_ shortcut: ShortcutAction) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index] = shortcut
            saveData()
            donateShortcut(shortcut)
        }
    }

    func deleteShortcut(_ shortcut: ShortcutAction) {
        shortcuts.removeAll { $0.id == shortcut.id }
        saveData()
        removeShortcutDonation(shortcut)
    }

    func setPhrase(for shortcut: ShortcutAction, phrase: String) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index].phrase = phrase
            saveData()
            donateShortcut(shortcuts[index])
        }
    }

    // MARK: - Siri Integration

    private func donateShortcut(_ shortcut: ShortcutAction) {
        #if os(iOS)
        // Create NSUserActivity-based shortcut donation
        let activity = NSUserActivity(activityType: "com.kochj.HomekitControl.\(shortcut.actionType.rawValue)")
        activity.title = shortcut.name
        activity.userInfo = [
            "shortcutId": shortcut.id.uuidString,
            "actionType": shortcut.actionType.rawValue,
            "targetId": shortcut.targetId?.uuidString ?? ""
        ]
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true

        if let phrase = shortcut.phrase {
            activity.suggestedInvocationPhrase = phrase
        }

        activity.becomeCurrent()
        #endif
    }

    private func removeShortcutDonation(_ shortcut: ShortcutAction) {
        #if os(iOS)
        NSUserActivity.deleteSavedUserActivities(withPersistentIdentifiers: [shortcut.id.uuidString]) { }
        #endif
    }

    // MARK: - Execute Shortcut

    func executeShortcut(_ shortcut: ShortcutAction) async throws {
        guard shortcut.isEnabled else { return }

        #if canImport(HomeKit)
        switch shortcut.actionType {
        case .toggleDevice, .turnOnDevice, .turnOffDevice:
            if let deviceId = shortcut.targetId,
               let accessory = HomeKitService.shared.accessories.first(where: { $0.uniqueIdentifier == deviceId }) {
                switch shortcut.actionType {
                case .toggleDevice:
                    try await HomeKitService.shared.toggleAccessory(accessory)
                case .turnOnDevice:
                    try await HomeKitService.shared.setAccessoryPower(accessory, on: true)
                case .turnOffDevice:
                    try await HomeKitService.shared.setAccessoryPower(accessory, on: false)
                default:
                    break
                }
            }

        case .executeScene:
            if let sceneId = shortcut.targetId,
               let scene = HomeKitService.shared.scenes.first(where: { $0.uniqueIdentifier == sceneId }) {
                try await HomeKitService.shared.executeScene(scene)
            }

        case .runAutomation:
            if let automationId = shortcut.targetId,
               let automation = AutomationService.shared.automations.first(where: { $0.id == automationId }) {
                try await AutomationService.shared.executeAutomation(automation)
            }

        case .controlGroup:
            if let groupId = shortcut.targetId,
               let group = DeviceGroupService.shared.groups.first(where: { $0.id == groupId }) {
                try await DeviceGroupService.shared.turnOnGroup(group)
            }
        }
        #endif
    }

    // MARK: - Widget Support

    func updateWidgetData() {
        widgetData = WidgetData(
            favoriteDevices: widgetData.favoriteDevices,
            favoriteScenes: widgetData.favoriteScenes,
            quickActions: shortcuts.filter { $0.isEnabled }.map { $0.id },
            lastUpdated: Date()
        )
        saveWidgetData()
    }

    func addFavoriteDevice(_ deviceId: UUID) {
        var devices = widgetData.favoriteDevices
        if !devices.contains(deviceId) {
            devices.append(deviceId)
            widgetData = WidgetData(
                favoriteDevices: devices,
                favoriteScenes: widgetData.favoriteScenes,
                quickActions: widgetData.quickActions,
                lastUpdated: Date()
            )
            saveWidgetData()
        }
    }

    func removeFavoriteDevice(_ deviceId: UUID) {
        var devices = widgetData.favoriteDevices
        devices.removeAll { $0 == deviceId }
        widgetData = WidgetData(
            favoriteDevices: devices,
            favoriteScenes: widgetData.favoriteScenes,
            quickActions: widgetData.quickActions,
            lastUpdated: Date()
        )
        saveWidgetData()
    }

    func addFavoriteScene(_ sceneId: UUID) {
        var scenes = widgetData.favoriteScenes
        if !scenes.contains(sceneId) {
            scenes.append(sceneId)
            widgetData = WidgetData(
                favoriteDevices: widgetData.favoriteDevices,
                favoriteScenes: scenes,
                quickActions: widgetData.quickActions,
                lastUpdated: Date()
            )
            saveWidgetData()
        }
    }

    func removeFavoriteScene(_ sceneId: UUID) {
        var scenes = widgetData.favoriteScenes
        scenes.removeAll { $0 == sceneId }
        widgetData = WidgetData(
            favoriteDevices: widgetData.favoriteDevices,
            favoriteScenes: scenes,
            quickActions: widgetData.quickActions,
            lastUpdated: Date()
        )
        saveWidgetData()
    }

    // MARK: - Quick Shortcut Creation

    func createDeviceShortcuts() {
        #if canImport(HomeKit)
        for accessory in HomeKitService.shared.accessories.prefix(10) {
            let existing = shortcuts.first { $0.targetId == accessory.uniqueIdentifier }
            if existing == nil {
                _ = createShortcut(
                    name: "Toggle \(accessory.name)",
                    actionType: .toggleDevice,
                    targetId: accessory.uniqueIdentifier,
                    targetName: accessory.name
                )
            }
        }
        #endif
    }

    func createSceneShortcuts() {
        #if canImport(HomeKit)
        for scene in HomeKitService.shared.scenes {
            let existing = shortcuts.first { $0.targetId == scene.uniqueIdentifier }
            if existing == nil {
                _ = createShortcut(
                    name: scene.name,
                    actionType: .executeScene,
                    targetId: scene.uniqueIdentifier,
                    targetName: scene.name
                )
            }
        }
        #endif
    }

    // MARK: - Persistence

    private func saveData() {
        if let data = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([ShortcutAction].self, from: data) {
            shortcuts = saved
        }
        loadWidgetData()
    }

    private func saveWidgetData() {
        guard let sharedDefaults = UserDefaults(suiteName: widgetGroupId) else { return }
        if let data = try? JSONEncoder().encode(widgetData) {
            sharedDefaults.set(data, forKey: "widgetData")
        }
    }

    private func loadWidgetData() {
        guard let sharedDefaults = UserDefaults(suiteName: widgetGroupId),
              let data = sharedDefaults.data(forKey: "widgetData"),
              let saved = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return
        }
        widgetData = saved
    }
}
