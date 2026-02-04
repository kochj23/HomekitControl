//
//  DeviceGroupService.swift
//  HomekitControl
//
//  Device grouping and zone management
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Device Group Models

struct DeviceGroup: Codable, Identifiable {
    let id: UUID
    var name: String
    var icon: String
    var color: String
    var deviceIds: [UUID]
    var isEnabled: Bool
    var createdAt: Date

    init(name: String, icon: String = "rectangle.3.group.fill", color: String = "cyan") {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.color = color
        self.deviceIds = []
        self.isEnabled = true
        self.createdAt = Date()
    }

    var deviceCount: Int { deviceIds.count }
}

struct Zone: Codable, Identifiable {
    let id: UUID
    var name: String
    var icon: String
    var roomIds: [UUID]
    var groupIds: [UUID]

    init(name: String, icon: String = "building.2.fill") {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.roomIds = []
        self.groupIds = []
    }
}

// MARK: - Device Group Service

@MainActor
class DeviceGroupService: ObservableObject {
    static let shared = DeviceGroupService()

    @Published var groups: [DeviceGroup] = []
    @Published var zones: [Zone] = []
    @Published var isProcessing = false

    private let storageKey = "HomekitControl_DeviceGroups"

    private init() {
        loadData()
        createDefaultGroups()
    }

    // MARK: - Default Groups

    private func createDefaultGroups() {
        if groups.isEmpty {
            // Create default smart groups
            var allLights = DeviceGroup(name: "All Lights", icon: "lightbulb.fill", color: "yellow")
            var allSwitches = DeviceGroup(name: "All Switches", icon: "switch.2", color: "green")

            #if canImport(HomeKit)
            for accessory in HomeKitService.shared.accessories {
                if accessory.services.contains(where: { $0.serviceType == HMServiceTypeLightbulb }) {
                    allLights.deviceIds.append(accessory.uniqueIdentifier)
                }
                if accessory.services.contains(where: { $0.serviceType == HMServiceTypeSwitch }) {
                    allSwitches.deviceIds.append(accessory.uniqueIdentifier)
                }
            }
            #endif

            if !allLights.deviceIds.isEmpty {
                groups.append(allLights)
            }
            if !allSwitches.deviceIds.isEmpty {
                groups.append(allSwitches)
            }

            saveData()
        }
    }

    // MARK: - Group CRUD

    func createGroup(name: String, icon: String = "rectangle.3.group.fill", color: String = "cyan") -> DeviceGroup {
        let group = DeviceGroup(name: name, icon: icon, color: color)
        groups.append(group)
        saveData()
        return group
    }

    func updateGroup(_ group: DeviceGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
            saveData()
        }
    }

    func deleteGroup(_ group: DeviceGroup) {
        groups.removeAll { $0.id == group.id }
        saveData()
    }

    func addDeviceToGroup(_ deviceId: UUID, group: DeviceGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            if !groups[index].deviceIds.contains(deviceId) {
                groups[index].deviceIds.append(deviceId)
                saveData()
            }
        }
    }

    func removeDeviceFromGroup(_ deviceId: UUID, group: DeviceGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index].deviceIds.removeAll { $0 == deviceId }
            saveData()
        }
    }

    // MARK: - Zone CRUD

    func createZone(name: String, icon: String = "building.2.fill") -> Zone {
        let zone = Zone(name: name, icon: icon)
        zones.append(zone)
        saveData()
        return zone
    }

    func updateZone(_ zone: Zone) {
        if let index = zones.firstIndex(where: { $0.id == zone.id }) {
            zones[index] = zone
            saveData()
        }
    }

    func deleteZone(_ zone: Zone) {
        zones.removeAll { $0.id == zone.id }
        saveData()
    }

    // MARK: - Group Control

    func turnOnGroup(_ group: DeviceGroup) async throws {
        isProcessing = true
        defer { isProcessing = false }

        #if canImport(HomeKit)
        for deviceId in group.deviceIds {
            if let accessory = HomeKitService.shared.accessories.first(where: { $0.uniqueIdentifier == deviceId }) {
                try await HomeKitService.shared.setAccessoryPower(accessory, on: true)
            }
        }
        #endif
    }

    func turnOffGroup(_ group: DeviceGroup) async throws {
        isProcessing = true
        defer { isProcessing = false }

        #if canImport(HomeKit)
        for deviceId in group.deviceIds {
            if let accessory = HomeKitService.shared.accessories.first(where: { $0.uniqueIdentifier == deviceId }) {
                try await HomeKitService.shared.setAccessoryPower(accessory, on: false)
            }
        }
        #endif
    }

    func setGroupBrightness(_ group: DeviceGroup, brightness: Int) async throws {
        isProcessing = true
        defer { isProcessing = false }

        #if canImport(HomeKit)
        for deviceId in group.deviceIds {
            if let accessory = HomeKitService.shared.accessories.first(where: { $0.uniqueIdentifier == deviceId }) {
                try await HomeKitService.shared.setBrightness(accessory, value: brightness)
            }
        }
        #endif
    }

    func setGroupRelativeBrightness(_ group: DeviceGroup, delta: Int) async throws {
        isProcessing = true
        defer { isProcessing = false }

        #if canImport(HomeKit)
        for deviceId in group.deviceIds {
            if let accessory = HomeKitService.shared.accessories.first(where: { $0.uniqueIdentifier == deviceId }) {
                // Get current brightness and adjust
                let currentBrightness = HomeKitService.shared.getBrightness(accessory) ?? 50
                let newBrightness = max(0, min(100, currentBrightness + delta))
                try await HomeKitService.shared.setBrightness(accessory, value: newBrightness)
            }
        }
        #endif
    }

    // MARK: - Helpers

    #if canImport(HomeKit)
    func getDevicesInGroup(_ group: DeviceGroup) -> [HMAccessory] {
        return HomeKitService.shared.accessories.filter { group.deviceIds.contains($0.uniqueIdentifier) }
    }
    #endif

    func getDeviceIdsInGroup(_ group: DeviceGroup) -> [UUID] {
        return group.deviceIds
    }

    func getGroupsForDevice(_ deviceId: UUID) -> [DeviceGroup] {
        groups.filter { $0.deviceIds.contains(deviceId) }
    }

    // MARK: - Persistence

    private func saveData() {
        if let groupsData = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(groupsData, forKey: storageKey + "_groups")
        }
        if let zonesData = try? JSONEncoder().encode(zones) {
            UserDefaults.standard.set(zonesData, forKey: storageKey + "_zones")
        }
    }

    private func loadData() {
        if let groupsData = UserDefaults.standard.data(forKey: storageKey + "_groups"),
           let saved = try? JSONDecoder().decode([DeviceGroup].self, from: groupsData) {
            groups = saved
        }
        if let zonesData = UserDefaults.standard.data(forKey: storageKey + "_zones"),
           let saved = try? JSONDecoder().decode([Zone].self, from: zonesData) {
            zones = saved
        }
    }
}
