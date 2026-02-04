//
//  SecurityService.swift
//  HomekitControl
//
//  Security dashboard with cameras, locks, and sensors
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Models

struct SecurityDevice: Identifiable {
    let id: UUID
    let name: String
    let type: SecurityDeviceType
    var state: SecurityDeviceState
    var lastUpdated: Date
    var batteryLevel: Int?

    enum SecurityDeviceType: String, Codable {
        case camera = "Camera"
        case doorLock = "Door Lock"
        case motionSensor = "Motion Sensor"
        case contactSensor = "Contact Sensor"
        case smokeSensor = "Smoke Sensor"
        case coSensor = "CO Sensor"
        case waterSensor = "Water Sensor"
        case alarm = "Alarm"
    }

    enum SecurityDeviceState: String, Codable {
        case secure = "Secure"
        case triggered = "Triggered"
        case open = "Open"
        case closed = "Closed"
        case locked = "Locked"
        case unlocked = "Unlocked"
        case armed = "Armed"
        case disarmed = "Disarmed"
        case motionDetected = "Motion Detected"
        case noMotion = "No Motion"
        case streaming = "Streaming"
        case offline = "Offline"
        case unknown = "Unknown"
    }
}

struct SecurityEvent: Codable, Identifiable {
    let id: UUID
    let deviceId: UUID
    let deviceName: String
    let eventType: SecurityEventType
    let timestamp: Date
    var isRead: Bool

    enum SecurityEventType: String, Codable {
        case motionDetected = "Motion Detected"
        case doorOpened = "Door Opened"
        case doorClosed = "Door Closed"
        case lockLocked = "Locked"
        case lockUnlocked = "Unlocked"
        case alarmTriggered = "Alarm Triggered"
        case smokeDetected = "Smoke Detected"
        case coDetected = "CO Detected"
        case waterDetected = "Water Detected"
        case deviceOffline = "Device Offline"
        case deviceOnline = "Device Online"
        case lowBattery = "Low Battery"
    }
}

struct SecurityZone: Codable, Identifiable {
    let id: UUID
    var name: String
    var deviceIds: [UUID]
    var isArmed: Bool

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.deviceIds = []
        self.isArmed = false
    }
}

enum SecurityMode: String, Codable, CaseIterable {
    case disarmed = "Disarmed"
    case home = "Home"
    case away = "Away"
    case night = "Night"

    var icon: String {
        switch self {
        case .disarmed: return "shield.slash"
        case .home: return "house.fill"
        case .away: return "airplane"
        case .night: return "moon.fill"
        }
    }

    var color: Color {
        switch self {
        case .disarmed: return .secondary
        case .home: return ModernColors.accentGreen
        case .away: return ModernColors.orange
        case .night: return ModernColors.purple
        }
    }
}

// MARK: - Security Service

@MainActor
class SecurityService: ObservableObject {
    static let shared = SecurityService()

    // MARK: - Published Properties

    @Published var securityDevices: [SecurityDevice] = []
    @Published var events: [SecurityEvent] = []
    @Published var zones: [SecurityZone] = []
    @Published var currentMode: SecurityMode = .disarmed
    @Published var isMonitoring = false

    // Alert settings
    @Published var alertOnMotion = true
    @Published var alertOnDoorOpen = true
    @Published var alertOnUnlock = true
    @Published var quietHoursEnabled = false
    @Published var quietHoursStart = DateComponents(hour: 22, minute: 0)
    @Published var quietHoursEnd = DateComponents(hour: 7, minute: 0)

    // MARK: - Private Properties

    private let storageKey = "HomekitControl_Security"
    private var monitoringTask: Task<Void, Never>?

    // MARK: - Initialization

    private init() {
        loadData()
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        refreshDevices()

        monitoringTask = Task {
            while !Task.isCancelled && isMonitoring {
                await refreshDevices()
                try? await Task.sleep(nanoseconds: 30_000_000_000) // Every 30 seconds
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
    }

    func refreshDevices() {
        #if canImport(HomeKit)
        securityDevices = []

        for accessory in HomeKitService.shared.accessories {
            for service in accessory.services {
                if let device = createSecurityDevice(from: accessory, service: service) {
                    securityDevices.append(device)
                }
            }
        }
        #endif
    }

    #if canImport(HomeKit)
    private func createSecurityDevice(from accessory: HMAccessory, service: HMService) -> SecurityDevice? {
        let type: SecurityDevice.SecurityDeviceType
        var state: SecurityDevice.SecurityDeviceState = .unknown

        switch service.serviceType {
        case HMServiceTypeLockMechanism:
            type = .doorLock
            // HMCharacteristicTypeLockCurrentState uses "00000000-0000-1000-8000-0026BB765291" UUID
            if let lockState = service.characteristics.first(where: { $0.characteristicType == "00000000-0000-1000-8000-0026BB765291" }),
               let value = lockState.value as? Int {
                state = value == 1 ? .locked : .unlocked
            }

        case HMServiceTypeMotionSensor:
            type = .motionSensor
            if let motionDetected = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeMotionDetected }),
               let value = motionDetected.value as? Bool {
                state = value ? .motionDetected : .noMotion
            }

        case HMServiceTypeContactSensor:
            type = .contactSensor
            if let contactState = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeContactState }),
               let value = contactState.value as? Int {
                state = value == 0 ? .closed : .open
            }

        case HMServiceTypeSmokeSensor:
            type = .smokeSensor
            if let smokeDetected = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeSmokeDetected }),
               let value = smokeDetected.value as? Int {
                state = value == 0 ? .secure : .triggered
            }

        case HMServiceTypeCarbonMonoxideSensor:
            type = .coSensor
            if let coDetected = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeCarbonMonoxideDetected }),
               let value = coDetected.value as? Int {
                state = value == 0 ? .secure : .triggered
            }

        case HMServiceTypeSecuritySystem:
            type = .alarm
            // Security System Current State UUID
            if let alarmState = service.characteristics.first(where: { $0.characteristicType == "00000066-0000-1000-8000-0026BB765291" }),
               let value = alarmState.value as? Int {
                state = value == 3 ? .disarmed : .armed
            }

        default:
            return nil
        }

        // Get battery level if available
        var batteryLevel: Int?
        if let batteryService = accessory.services.first(where: { $0.serviceType == HMServiceTypeBattery }),
           let batteryChar = batteryService.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeBatteryLevel }),
           let level = batteryChar.value as? Int {
            batteryLevel = level
        }

        return SecurityDevice(
            id: accessory.uniqueIdentifier,
            name: accessory.name,
            type: type,
            state: state,
            lastUpdated: Date(),
            batteryLevel: batteryLevel
        )
    }
    #endif

    // MARK: - Lock Control

    func lockDoor(_ deviceId: UUID) async {
        #if canImport(HomeKit)
        guard let accessory = HomeKitService.shared.accessories.first(where: { $0.uniqueIdentifier == deviceId }),
              let lockService = accessory.services.first(where: { $0.serviceType == HMServiceTypeLockMechanism }),
              // Lock Target State UUID
              let targetState = lockService.characteristics.first(where: { $0.characteristicType == "0000001E-0000-1000-8000-0026BB765291" }) else {
            return
        }

        do {
            try await targetState.writeValue(1) // 1 = Locked
            logEvent(deviceId: deviceId, deviceName: accessory.name, eventType: .lockLocked)
            refreshDevices()
        } catch {
            print("Failed to lock: \(error)")
        }
        #endif
    }

    func unlockDoor(_ deviceId: UUID) async {
        #if canImport(HomeKit)
        guard let accessory = HomeKitService.shared.accessories.first(where: { $0.uniqueIdentifier == deviceId }),
              let lockService = accessory.services.first(where: { $0.serviceType == HMServiceTypeLockMechanism }),
              // Lock Target State UUID
              let targetState = lockService.characteristics.first(where: { $0.characteristicType == "0000001E-0000-1000-8000-0026BB765291" }) else {
            return
        }

        do {
            try await targetState.writeValue(0) // 0 = Unlocked
            logEvent(deviceId: deviceId, deviceName: accessory.name, eventType: .lockUnlocked)
            refreshDevices()
        } catch {
            print("Failed to unlock: \(error)")
        }
        #endif
    }

    func lockAllDoors() async {
        let locks = securityDevices.filter { $0.type == .doorLock }
        for lock in locks {
            await lockDoor(lock.id)
        }
    }

    // MARK: - Security Mode

    func setSecurityMode(_ mode: SecurityMode) {
        currentMode = mode

        switch mode {
        case .disarmed:
            // Disarm all zones
            for i in 0..<zones.count {
                zones[i].isArmed = false
            }

        case .home:
            // Arm perimeter only
            for i in 0..<zones.count {
                zones[i].isArmed = zones[i].name.lowercased().contains("perimeter")
            }

        case .away:
            // Arm all zones
            for i in 0..<zones.count {
                zones[i].isArmed = true
            }
            // Lock all doors
            Task { await lockAllDoors() }

        case .night:
            // Arm all zones, similar to away
            for i in 0..<zones.count {
                zones[i].isArmed = true
            }
        }

        saveData()
    }

    // MARK: - Zone Management

    func addZone(_ zone: SecurityZone) {
        zones.append(zone)
        saveData()
    }

    func updateZone(_ zone: SecurityZone) {
        if let index = zones.firstIndex(where: { $0.id == zone.id }) {
            zones[index] = zone
            saveData()
        }
    }

    func deleteZone(_ zone: SecurityZone) {
        zones.removeAll { $0.id == zone.id }
        saveData()
    }

    // MARK: - Event Logging

    func logEvent(deviceId: UUID, deviceName: String, eventType: SecurityEvent.SecurityEventType) {
        let event = SecurityEvent(
            id: UUID(),
            deviceId: deviceId,
            deviceName: deviceName,
            eventType: eventType,
            timestamp: Date(),
            isRead: false
        )
        events.insert(event, at: 0)

        // Trim old events
        if events.count > 500 {
            events = Array(events.prefix(500))
        }

        saveData()

        // Send notification if appropriate
        if shouldSendAlert(for: eventType) {
            sendAlert(event)
        }
    }

    private func shouldSendAlert(for eventType: SecurityEvent.SecurityEventType) -> Bool {
        // Check quiet hours
        if quietHoursEnabled {
            let calendar = Calendar.current
            let now = Date()
            let currentHour = calendar.component(.hour, from: now)
            let currentMinute = calendar.component(.minute, from: now)

            let startMinutes = (quietHoursStart.hour ?? 22) * 60 + (quietHoursStart.minute ?? 0)
            let endMinutes = (quietHoursEnd.hour ?? 7) * 60 + (quietHoursEnd.minute ?? 0)
            let currentMinutes = currentHour * 60 + currentMinute

            let inQuietHours: Bool
            if startMinutes > endMinutes {
                // Quiet hours span midnight
                inQuietHours = currentMinutes >= startMinutes || currentMinutes < endMinutes
            } else {
                inQuietHours = currentMinutes >= startMinutes && currentMinutes < endMinutes
            }

            if inQuietHours {
                return false
            }
        }

        // Check event type settings
        switch eventType {
        case .motionDetected: return alertOnMotion && currentMode != .disarmed
        case .doorOpened: return alertOnDoorOpen && currentMode != .disarmed
        case .lockUnlocked: return alertOnUnlock && currentMode != .disarmed
        case .smokeDetected, .coDetected, .waterDetected, .alarmTriggered: return true
        default: return false
        }
    }

    private func sendAlert(_ event: SecurityEvent) {
        #if os(iOS)
        Task {
            await NotificationService.shared.sendNotification(
                title: "Security Alert: \(event.eventType.rawValue)",
                body: "\(event.deviceName) - \(event.eventType.rawValue)"
            )
        }
        #endif
    }

    // MARK: - Computed Properties

    var unlockedDoors: [SecurityDevice] {
        securityDevices.filter { $0.type == .doorLock && $0.state == .unlocked }
    }

    var openContacts: [SecurityDevice] {
        securityDevices.filter { $0.type == .contactSensor && $0.state == .open }
    }

    var motionSensors: [SecurityDevice] {
        securityDevices.filter { $0.type == .motionSensor }
    }

    var activeMotionSensors: [SecurityDevice] {
        securityDevices.filter { $0.type == .motionSensor && $0.state == .motionDetected }
    }

    var locks: [SecurityDevice] {
        securityDevices.filter { $0.type == .doorLock }
    }

    var cameras: [SecurityDevice] {
        securityDevices.filter { $0.type == .camera }
    }

    var unreadEventCount: Int {
        events.filter { !$0.isRead }.count
    }

    var isSecure: Bool {
        unlockedDoors.isEmpty && openContacts.isEmpty
    }

    var recentEvents: [SecurityEvent] {
        Array(events.prefix(20))
    }

    // MARK: - Persistence

    private func saveData() {
        let settings: [String: Any] = [
            "currentMode": currentMode.rawValue,
            "alertOnMotion": alertOnMotion,
            "alertOnDoorOpen": alertOnDoorOpen,
            "alertOnUnlock": alertOnUnlock,
            "quietHoursEnabled": quietHoursEnabled
        ]

        if let encoded = try? JSONSerialization.data(withJSONObject: settings) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }

        if let zonesData = try? JSONEncoder().encode(zones) {
            UserDefaults.standard.set(zonesData, forKey: storageKey + "_zones")
        }

        if let eventsData = try? JSONEncoder().encode(Array(events.prefix(500))) {
            UserDefaults.standard.set(eventsData, forKey: storageKey + "_events")
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let modeStr = settings["currentMode"] as? String,
               let mode = SecurityMode(rawValue: modeStr) {
                currentMode = mode
            }
            alertOnMotion = settings["alertOnMotion"] as? Bool ?? true
            alertOnDoorOpen = settings["alertOnDoorOpen"] as? Bool ?? true
            alertOnUnlock = settings["alertOnUnlock"] as? Bool ?? true
            quietHoursEnabled = settings["quietHoursEnabled"] as? Bool ?? false
        }

        if let zonesData = UserDefaults.standard.data(forKey: storageKey + "_zones"),
           let saved = try? JSONDecoder().decode([SecurityZone].self, from: zonesData) {
            zones = saved
        }

        if let eventsData = UserDefaults.standard.data(forKey: storageKey + "_events"),
           let saved = try? JSONDecoder().decode([SecurityEvent].self, from: eventsData) {
            events = saved
        }
    }
}
