//
//  HomeKitService.swift
//  HomekitControl
//
//  Unified HomeKit service for all platforms
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

#if canImport(HomeKit)
import HomeKit
#endif

/// Unified HomeKit service that handles platform-specific capabilities
@MainActor
final class HomeKitService: NSObject, ObservableObject {
    static let shared = HomeKitService()

    // MARK: - Published Properties

    @Published var isAuthorized = false
    @Published var isLoading = false
    @Published var statusMessage = ""

    #if canImport(HomeKit) && !os(macOS)
    @Published var homes: [HMHome] = []
    @Published var currentHome: HMHome?
    @Published var rooms: [HMRoom] = []
    @Published var accessories: [HMAccessory] = []
    @Published var scenes: [HMActionSet] = []

    private var homeManager: HMHomeManager?
    #else
    // macOS uses manual inventory
    @Published var manualDevices: [UnifiedDevice] = []
    #endif

    // MARK: - Initialization

    private override init() {
        super.init()
        #if canImport(HomeKit) && !os(macOS)
        setupHomeKit()
        #else
        loadManualInventory()
        #endif
    }

    // MARK: - Platform Capabilities

    var canControlDevices: Bool { PlatformCapabilities.canControlDevices }
    var canModifyScenes: Bool { PlatformCapabilities.canModifyScenes }
    var canRemoveDevices: Bool { PlatformCapabilities.canRemoveDevices }

    // MARK: - HomeKit Setup

    #if canImport(HomeKit) && !os(macOS)
    private func setupHomeKit() {
        homeManager = HMHomeManager()
        homeManager?.delegate = self
        isLoading = true
    }

    private func loadHomeData() {
        // primaryHome is deprecated on iOS 16.1+ and tvOS 16.1+
        // Just use homes.first as fallback
        let home = currentHome ?? homeManager?.homes.first

        guard let home else {
            isLoading = false
            return
        }

        currentHome = home
        rooms = home.rooms.sorted { $0.name < $1.name }
        accessories = home.accessories.sorted { $0.name < $1.name }
        scenes = home.actionSets.sorted { $0.name < $1.name }

        isLoading = false
        isAuthorized = true

        NSLog("[HomeKitService] Loaded: \(accessories.count) accessories, \(rooms.count) rooms, \(scenes.count) scenes")
    }
    #endif

    // MARK: - macOS Manual Inventory

    #if os(macOS)
    private func loadManualInventory() {
        // Load from UserDefaults on macOS
        if let data = UserDefaults.standard.data(forKey: "manualDevices"),
           let devices = try? JSONDecoder().decode([UnifiedDevice].self, from: data) {
            manualDevices = devices
        }
        isAuthorized = true
        isLoading = false
    }

    func saveManualInventory() {
        if let data = try? JSONEncoder().encode(manualDevices) {
            UserDefaults.standard.set(data, forKey: "manualDevices")
        }
    }

    func addManualDevice(_ device: UnifiedDevice) {
        manualDevices.append(device)
        saveManualInventory()
    }

    func removeManualDevice(_ device: UnifiedDevice) {
        manualDevices.removeAll { $0.id == device.id }
        saveManualInventory()
    }
    #endif

    // MARK: - Refresh

    func refreshAll() async {
        isLoading = true
        statusMessage = "Refreshing..."

        #if canImport(HomeKit) && !os(macOS)
        loadHomeData()
        #else
        loadManualInventory()
        #endif

        try? await Task.sleep(nanoseconds: 500_000_000)
        statusMessage = ""
    }

    // MARK: - Device Control

    #if canImport(HomeKit) && !os(macOS)
    func toggleAccessory(_ accessory: HMAccessory) async throws {
        guard let service = accessory.services.first(where: { $0.serviceType == HMServiceTypeLightbulb || $0.serviceType == HMServiceTypeSwitch || $0.serviceType == HMServiceTypeOutlet }),
              let powerChar = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypePowerState }) else {
            return
        }

        let currentValue = powerChar.value as? Bool ?? false
        try await powerChar.writeValue(!currentValue)

        statusMessage = "\(accessory.name) turned \(!currentValue ? "on" : "off")"
        clearStatusMessage()
    }

    func setBrightness(_ accessory: HMAccessory, value: Int) async throws {
        guard let service = accessory.services.first(where: { $0.serviceType == HMServiceTypeLightbulb }),
              let brightnessChar = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeBrightness }) else {
            return
        }

        try await brightnessChar.writeValue(value)
        statusMessage = "\(accessory.name) brightness set to \(value)%"
        clearStatusMessage()
    }

    func executeScene(_ scene: HMActionSet) async throws {
        guard let home = currentHome else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            home.executeActionSet(scene) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        statusMessage = "Executed: \(scene.name)"
        clearStatusMessage()
    }
    #endif

    // MARK: - Helpers

    private func clearStatusMessage() {
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            statusMessage = ""
        }
    }
}

// MARK: - HomeKit Delegates

#if canImport(HomeKit) && !os(macOS)
extension HomeKitService: HMHomeManagerDelegate {
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            homes = manager.homes
            if currentHome == nil {
                currentHome = manager.homes.first
            }
            loadHomeData()
        }
    }
}
#endif
