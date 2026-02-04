//
//  BackupService.swift
//  HomekitControl
//
//  Full HomeKit configuration backup and restore
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Backup Models

struct HomeKitBackup: Codable, Identifiable {
    let id: UUID
    let name: String
    let createdAt: Date
    let version: String
    let homeData: HomeBackupData
    let automationData: [AutomationBackupData]
    let customData: CustomBackupData

    init(name: String, homeData: HomeBackupData, automationData: [AutomationBackupData], customData: CustomBackupData) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.version = "1.0"
        self.homeData = homeData
        self.automationData = automationData
        self.customData = customData
    }
}

struct HomeBackupData: Codable {
    let homeName: String
    let rooms: [RoomBackupData]
    let accessories: [AccessoryBackupData]
    let scenes: [SceneBackupData]
    let serviceGroups: [ServiceGroupBackupData]
}

struct RoomBackupData: Codable {
    let id: UUID
    let name: String
    let accessoryIds: [UUID]
}

struct AccessoryBackupData: Codable {
    let id: UUID
    let name: String
    let roomId: UUID?
    let manufacturer: String?
    let model: String?
    let firmwareVersion: String?
    let services: [ServiceBackupData]
}

struct ServiceBackupData: Codable {
    let id: UUID
    let name: String
    let serviceType: String
    let characteristics: [CharacteristicBackupData]
}

struct CharacteristicBackupData: Codable {
    let id: UUID
    let characteristicType: String
    let value: String?
}

struct SceneBackupData: Codable {
    let id: UUID
    let name: String
    let actions: [ActionBackupData]
}

struct ActionBackupData: Codable {
    let accessoryId: UUID
    let characteristicType: String
    let targetValue: String?
}

struct ServiceGroupBackupData: Codable {
    let id: UUID
    let name: String
    let serviceIds: [UUID]
}

struct AutomationBackupData: Codable {
    let id: UUID
    let name: String
    let isEnabled: Bool
    let triggerData: String
    let actionSetIds: [UUID]
}

struct CustomBackupData: Codable {
    let deviceGroups: Data?
    let schedules: Data?
    let automations: Data?
    let notificationRules: Data?
}

// MARK: - Backup Service

@MainActor
class BackupService: ObservableObject {
    static let shared = BackupService()

    @Published var backups: [HomeKitBackup] = []
    @Published var isBackingUp = false
    @Published var isRestoring = false
    @Published var lastBackup: Date?
    @Published var lastError: String?

    private let storageKey = "HomekitControl_Backups"
    private let maxBackups = 10

    private init() {
        loadBackups()
    }

    // MARK: - Create Backup

    func createBackup(name: String? = nil) async throws -> HomeKitBackup {
        isBackingUp = true
        defer { isBackingUp = false }

        let backupName = name ?? "Backup \(formatDate(Date()))"

        #if canImport(HomeKit)
        guard let home = HomeKitService.shared.currentHome else {
            throw BackupError.noHomeAvailable
        }

        // Backup home data
        let homeData = createHomeBackupData(from: home)

        // Backup automations (HMTriggers)
        let automationData = home.triggers.map { trigger -> AutomationBackupData in
            AutomationBackupData(
                id: trigger.uniqueIdentifier,
                name: trigger.name,
                isEnabled: trigger.isEnabled,
                triggerData: String(describing: type(of: trigger)),
                actionSetIds: trigger.actionSets.map { $0.uniqueIdentifier }
            )
        }

        // Backup custom app data
        let customData = CustomBackupData(
            deviceGroups: try? JSONEncoder().encode(DeviceGroupService.shared.groups),
            schedules: try? JSONEncoder().encode(SceneSchedulingService.shared.schedules),
            automations: try? JSONEncoder().encode(AutomationService.shared.automations),
            notificationRules: try? JSONEncoder().encode(NotificationService.shared.rules)
        )

        let backup = HomeKitBackup(
            name: backupName,
            homeData: homeData,
            automationData: automationData,
            customData: customData
        )

        backups.insert(backup, at: 0)

        // Limit number of backups
        if backups.count > maxBackups {
            backups = Array(backups.prefix(maxBackups))
        }

        lastBackup = Date()
        saveBackups()

        return backup
        #else
        throw BackupError.homeKitNotAvailable
        #endif
    }

    #if canImport(HomeKit)
    private func createHomeBackupData(from home: HMHome) -> HomeBackupData {
        // Rooms
        let rooms = home.rooms.map { room -> RoomBackupData in
            RoomBackupData(
                id: room.uniqueIdentifier,
                name: room.name,
                accessoryIds: room.accessories.map { $0.uniqueIdentifier }
            )
        }

        // Accessories
        let accessories = home.accessories.map { accessory -> AccessoryBackupData in
            let services = accessory.services.map { service -> ServiceBackupData in
                let characteristics = service.characteristics.map { char -> CharacteristicBackupData in
                    CharacteristicBackupData(
                        id: char.uniqueIdentifier,
                        characteristicType: char.characteristicType,
                        value: char.value.map { String(describing: $0) }
                    )
                }
                return ServiceBackupData(
                    id: service.uniqueIdentifier,
                    name: service.name,
                    serviceType: service.serviceType,
                    characteristics: characteristics
                )
            }

            return AccessoryBackupData(
                id: accessory.uniqueIdentifier,
                name: accessory.name,
                roomId: accessory.room?.uniqueIdentifier,
                manufacturer: accessory.manufacturer,
                model: accessory.model,
                firmwareVersion: accessory.firmwareVersion,
                services: services
            )
        }

        // Scenes
        let scenes = home.actionSets.map { actionSet -> SceneBackupData in
            let actions = actionSet.actions.compactMap { action -> ActionBackupData? in
                guard let charAction = action as? HMCharacteristicWriteAction<NSCopying> else { return nil }
                return ActionBackupData(
                    accessoryId: charAction.characteristic.service?.accessory?.uniqueIdentifier ?? UUID(),
                    characteristicType: charAction.characteristic.characteristicType,
                    targetValue: String(describing: charAction.targetValue)
                )
            }
            return SceneBackupData(
                id: actionSet.uniqueIdentifier,
                name: actionSet.name,
                actions: actions
            )
        }

        // Service Groups
        let serviceGroups = home.serviceGroups.map { group -> ServiceGroupBackupData in
            ServiceGroupBackupData(
                id: group.uniqueIdentifier,
                name: group.name,
                serviceIds: group.services.map { $0.uniqueIdentifier }
            )
        }

        return HomeBackupData(
            homeName: home.name,
            rooms: rooms,
            accessories: accessories,
            scenes: scenes,
            serviceGroups: serviceGroups
        )
    }
    #endif

    // MARK: - Restore

    func restoreBackup(_ backup: HomeKitBackup) async throws {
        isRestoring = true
        defer { isRestoring = false }

        // Restore custom app data
        if let groupsData = backup.customData.deviceGroups,
           let groups = try? JSONDecoder().decode([DeviceGroup].self, from: groupsData) {
            DeviceGroupService.shared.groups = groups
        }

        if let schedulesData = backup.customData.schedules,
           let schedules = try? JSONDecoder().decode([SceneSchedule].self, from: schedulesData) {
            SceneSchedulingService.shared.schedules = schedules
        }

        if let automationsData = backup.customData.automations,
           let automations = try? JSONDecoder().decode([CustomAutomation].self, from: automationsData) {
            AutomationService.shared.automations = automations
        }

        if let rulesData = backup.customData.notificationRules,
           let rules = try? JSONDecoder().decode([NotificationRule].self, from: rulesData) {
            NotificationService.shared.rules = rules
        }

        // Note: Restoring HomeKit configuration requires HomeKit APIs
        // that can recreate rooms, scenes, etc. - which is limited by Apple's API
    }

    // MARK: - Export/Import

    func exportBackup(_ backup: HomeKitBackup) -> Data? {
        try? JSONEncoder().encode(backup)
    }

    func importBackup(from data: Data) throws -> HomeKitBackup {
        let backup = try JSONDecoder().decode(HomeKitBackup.self, from: data)
        backups.insert(backup, at: 0)
        saveBackups()
        return backup
    }

    // MARK: - Management

    func deleteBackup(_ backup: HomeKitBackup) {
        backups.removeAll { $0.id == backup.id }
        saveBackups()
    }

    func deleteAllBackups() {
        backups.removeAll()
        saveBackups()
    }

    // MARK: - Persistence

    private func saveBackups() {
        if let data = try? JSONEncoder().encode(backups) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        if let lastBackup = lastBackup {
            UserDefaults.standard.set(lastBackup, forKey: storageKey + "_lastBackup")
        }
    }

    private func loadBackups() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([HomeKitBackup].self, from: data) {
            backups = saved
        }
        lastBackup = UserDefaults.standard.object(forKey: storageKey + "_lastBackup") as? Date
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Errors

enum BackupError: LocalizedError {
    case noHomeAvailable
    case homeKitNotAvailable
    case exportFailed
    case importFailed

    var errorDescription: String? {
        switch self {
        case .noHomeAvailable: return "No HomeKit home available"
        case .homeKitNotAvailable: return "HomeKit not available on this platform"
        case .exportFailed: return "Failed to export backup"
        case .importFailed: return "Failed to import backup"
        }
    }
}
