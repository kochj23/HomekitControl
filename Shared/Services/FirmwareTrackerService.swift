//
//  FirmwareTrackerService.swift
//  HomekitControl
//
//  Track device firmware versions and updates
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Models

struct DeviceFirmwareInfo: Codable, Identifiable {
    let id: UUID
    let deviceId: UUID
    var deviceName: String
    var manufacturer: String
    var model: String
    var currentVersion: String
    var lastChecked: Date
    var updateAvailable: Bool
    var latestVersion: String?
    var releaseNotes: String?
    var updateURL: String?

    init(deviceId: UUID, deviceName: String, manufacturer: String, model: String, currentVersion: String) {
        self.id = UUID()
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.manufacturer = manufacturer
        self.model = model
        self.currentVersion = currentVersion
        self.lastChecked = Date()
        self.updateAvailable = false
        self.latestVersion = nil
        self.releaseNotes = nil
        self.updateURL = nil
    }
}

struct FirmwareUpdateAlert: Codable, Identifiable {
    let id: UUID
    let deviceId: UUID
    let deviceName: String
    let currentVersion: String
    let newVersion: String
    let timestamp: Date
    var isDismissed: Bool

    init(deviceId: UUID, deviceName: String, currentVersion: String, newVersion: String) {
        self.id = UUID()
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.currentVersion = currentVersion
        self.newVersion = newVersion
        self.timestamp = Date()
        self.isDismissed = false
    }
}

struct CompatibilityWarning: Codable, Identifiable {
    let id: UUID
    let deviceId: UUID
    let deviceName: String
    let warningType: WarningType
    let message: String
    let timestamp: Date

    enum WarningType: String, Codable {
        case deprecatedProtocol = "Deprecated Protocol"
        case endOfSupport = "End of Support"
        case securityVulnerability = "Security Vulnerability"
        case performanceIssue = "Performance Issue"
        case incompatibleWithOS = "OS Incompatibility"
    }
}

// MARK: - Firmware Tracker Service

@MainActor
class FirmwareTrackerService: ObservableObject {
    static let shared = FirmwareTrackerService()

    // MARK: - Published Properties

    @Published var firmwareInfo: [DeviceFirmwareInfo] = []
    @Published var updateAlerts: [FirmwareUpdateAlert] = []
    @Published var compatibilityWarnings: [CompatibilityWarning] = []
    @Published var isChecking = false
    @Published var lastFullCheck: Date?
    @Published var autoCheckEnabled = true
    @Published var checkInterval: TimeInterval = 86400 // Daily

    // MARK: - Private Properties

    private let storageKey = "HomekitControl_FirmwareTracker"
    private var checkTimer: Timer?

    // MARK: - Initialization

    private init() {
        loadData()
        if autoCheckEnabled {
            scheduleAutoCheck()
        }
    }

    // MARK: - Firmware Scanning

    func scanAllDevices() {
        isChecking = true

        #if canImport(HomeKit)
        firmwareInfo = []

        for accessory in HomeKitService.shared.accessories {
            let info = extractFirmwareInfo(from: accessory)
            firmwareInfo.append(info)
        }
        #endif

        lastFullCheck = Date()
        isChecking = false
        saveData()
    }

    #if canImport(HomeKit)
    private func extractFirmwareInfo(from accessory: HMAccessory) -> DeviceFirmwareInfo {
        var manufacturer = "Unknown"
        var model = "Unknown"
        var firmwareVersion = "Unknown"

        // Find accessory information service
        if let infoService = accessory.services.first(where: { $0.serviceType == HMServiceTypeAccessoryInformation }) {
            for characteristic in infoService.characteristics {
                switch characteristic.characteristicType {
                case HMCharacteristicTypeManufacturer:
                    manufacturer = characteristic.value as? String ?? "Unknown"
                case HMCharacteristicTypeModel:
                    model = characteristic.value as? String ?? "Unknown"
                case HMCharacteristicTypeFirmwareVersion:
                    firmwareVersion = characteristic.value as? String ?? "Unknown"
                default:
                    break
                }
            }
        }

        return DeviceFirmwareInfo(
            deviceId: accessory.uniqueIdentifier,
            deviceName: accessory.name,
            manufacturer: manufacturer,
            model: model,
            currentVersion: firmwareVersion
        )
    }
    #endif

    // MARK: - Update Checking

    func checkForUpdates() async {
        isChecking = true

        for i in 0..<firmwareInfo.count {
            // In a real implementation, this would query manufacturer APIs
            // For now, we'll simulate update checking
            let hasUpdate = simulateUpdateCheck(for: firmwareInfo[i])

            if hasUpdate {
                firmwareInfo[i].updateAvailable = true
                firmwareInfo[i].latestVersion = incrementVersion(firmwareInfo[i].currentVersion)

                // Create alert if not already exists
                if !updateAlerts.contains(where: { $0.deviceId == firmwareInfo[i].deviceId && !$0.isDismissed }) {
                    let alert = FirmwareUpdateAlert(
                        deviceId: firmwareInfo[i].deviceId,
                        deviceName: firmwareInfo[i].deviceName,
                        currentVersion: firmwareInfo[i].currentVersion,
                        newVersion: firmwareInfo[i].latestVersion ?? "Unknown"
                    )
                    updateAlerts.append(alert)
                }
            }

            firmwareInfo[i].lastChecked = Date()
        }

        // Check for compatibility warnings
        checkCompatibility()

        lastFullCheck = Date()
        isChecking = false
        saveData()
    }

    private func simulateUpdateCheck(for info: DeviceFirmwareInfo) -> Bool {
        // Simulate 10% chance of update available
        return Int.random(in: 1...10) == 1
    }

    private func incrementVersion(_ version: String) -> String {
        let components = version.split(separator: ".").compactMap { Int($0) }
        guard !components.isEmpty else { return version }

        var newComponents = components
        newComponents[newComponents.count - 1] += 1
        return newComponents.map { String($0) }.joined(separator: ".")
    }

    // MARK: - Compatibility Checking

    private func checkCompatibility() {
        compatibilityWarnings = []

        for info in firmwareInfo {
            // Check for known issues (in real implementation, this would use a database)
            if info.manufacturer.lowercased().contains("deprecated") {
                let warning = CompatibilityWarning(
                    id: UUID(),
                    deviceId: info.deviceId,
                    deviceName: info.deviceName,
                    warningType: .deprecatedProtocol,
                    message: "This device uses a deprecated protocol",
                    timestamp: Date()
                )
                compatibilityWarnings.append(warning)
            }

            // Check firmware age (simulate old firmware warning)
            if let versionNum = Int(info.currentVersion.replacingOccurrences(of: ".", with: "")),
               versionNum < 100 {
                let warning = CompatibilityWarning(
                    id: UUID(),
                    deviceId: info.deviceId,
                    deviceName: info.deviceName,
                    warningType: .securityVulnerability,
                    message: "Outdated firmware may have security vulnerabilities",
                    timestamp: Date()
                )
                compatibilityWarnings.append(warning)
            }
        }
    }

    // MARK: - Auto Check

    private func scheduleAutoCheck() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkForUpdates()
            }
        }
    }

    func enableAutoCheck(_ enabled: Bool) {
        autoCheckEnabled = enabled
        if enabled {
            scheduleAutoCheck()
        } else {
            checkTimer?.invalidate()
        }
        saveData()
    }

    // MARK: - Alert Management

    func dismissAlert(_ alert: FirmwareUpdateAlert) {
        if let index = updateAlerts.firstIndex(where: { $0.id == alert.id }) {
            updateAlerts[index].isDismissed = true
            saveData()
        }
    }

    func clearDismissedAlerts() {
        updateAlerts.removeAll { $0.isDismissed }
        saveData()
    }

    // MARK: - Computed Properties

    var devicesWithUpdates: [DeviceFirmwareInfo] {
        firmwareInfo.filter { $0.updateAvailable }
    }

    var activeAlerts: [FirmwareUpdateAlert] {
        updateAlerts.filter { !$0.isDismissed }
    }

    var updateCount: Int {
        devicesWithUpdates.count
    }

    var warningCount: Int {
        compatibilityWarnings.count
    }

    var overallHealth: Double {
        guard !firmwareInfo.isEmpty else { return 100 }
        let upToDateCount = firmwareInfo.filter { !$0.updateAvailable }.count
        return Double(upToDateCount) / Double(firmwareInfo.count) * 100
    }

    // MARK: - Persistence

    private func saveData() {
        let settings: [String: Any] = [
            "autoCheckEnabled": autoCheckEnabled,
            "checkInterval": checkInterval,
            "lastFullCheck": lastFullCheck?.timeIntervalSince1970 ?? 0
        ]

        if let encoded = try? JSONSerialization.data(withJSONObject: settings) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }

        if let infoData = try? JSONEncoder().encode(firmwareInfo) {
            UserDefaults.standard.set(infoData, forKey: storageKey + "_info")
        }

        if let alertsData = try? JSONEncoder().encode(updateAlerts) {
            UserDefaults.standard.set(alertsData, forKey: storageKey + "_alerts")
        }

        if let warningsData = try? JSONEncoder().encode(compatibilityWarnings) {
            UserDefaults.standard.set(warningsData, forKey: storageKey + "_warnings")
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            autoCheckEnabled = settings["autoCheckEnabled"] as? Bool ?? true
            checkInterval = settings["checkInterval"] as? TimeInterval ?? 86400
            if let timestamp = settings["lastFullCheck"] as? TimeInterval, timestamp > 0 {
                lastFullCheck = Date(timeIntervalSince1970: timestamp)
            }
        }

        if let infoData = UserDefaults.standard.data(forKey: storageKey + "_info"),
           let saved = try? JSONDecoder().decode([DeviceFirmwareInfo].self, from: infoData) {
            firmwareInfo = saved
        }

        if let alertsData = UserDefaults.standard.data(forKey: storageKey + "_alerts"),
           let saved = try? JSONDecoder().decode([FirmwareUpdateAlert].self, from: alertsData) {
            updateAlerts = saved
        }

        if let warningsData = UserDefaults.standard.data(forKey: storageKey + "_warnings"),
           let saved = try? JSONDecoder().decode([CompatibilityWarning].self, from: warningsData) {
            compatibilityWarnings = saved
        }
    }
}
