//
//  NotificationService.swift
//  HomekitControl
//
//  Push notifications for device state changes and alerts
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI
import UserNotifications
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Notification Models

struct NotificationRule: Codable, Identifiable {
    let id: UUID
    var name: String
    var deviceId: UUID?
    var eventType: EventType
    var isEnabled: Bool
    var quietHoursStart: Date?
    var quietHoursEnd: Date?

    enum EventType: String, Codable, CaseIterable {
        case stateChange = "State Change"
        case motionDetected = "Motion Detected"
        case doorOpened = "Door Opened"
        case windowOpened = "Window Opened"
        case lockUnlocked = "Lock Unlocked"
        case temperatureThreshold = "Temperature Threshold"
        case deviceOffline = "Device Offline"
        case lowBattery = "Low Battery"

        var icon: String {
            switch self {
            case .stateChange: return "bolt.fill"
            case .motionDetected: return "figure.walk.motion"
            case .doorOpened: return "door.left.hand.open"
            case .windowOpened: return "window.vertical.open"
            case .lockUnlocked: return "lock.open.fill"
            case .temperatureThreshold: return "thermometer.high"
            case .deviceOffline: return "wifi.slash"
            case .lowBattery: return "battery.25"
            }
        }
    }

    init(name: String, eventType: EventType) {
        self.id = UUID()
        self.name = name
        self.eventType = eventType
        self.isEnabled = true
    }
}

struct NotificationLog: Codable, Identifiable {
    let id: UUID
    let ruleId: UUID?
    let title: String
    let body: String
    let timestamp: Date
    var isRead: Bool

    init(ruleId: UUID? = nil, title: String, body: String) {
        self.id = UUID()
        self.ruleId = ruleId
        self.title = title
        self.body = body
        self.timestamp = Date()
        self.isRead = false
    }
}

// MARK: - Notification Service

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var rules: [NotificationRule] = []
    @Published var logs: [NotificationLog] = []
    @Published var isAuthorized = false
    @Published var unreadCount = 0

    // Quiet Hours
    @Published var quietHoursEnabled = false
    @Published var quietHoursStart = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    @Published var quietHoursEnd = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()

    private let storageKey = "HomekitControl_Notifications"

    private init() {
        loadData()
        checkAuthorization()
        createDefaultRules()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Default Rules

    private func createDefaultRules() {
        if rules.isEmpty {
            rules = [
                NotificationRule(name: "Motion Alerts", eventType: .motionDetected),
                NotificationRule(name: "Door Alerts", eventType: .doorOpened),
                NotificationRule(name: "Device Offline", eventType: .deviceOffline),
                NotificationRule(name: "Low Battery", eventType: .lowBattery)
            ]
            saveData()
        }
    }

    // MARK: - Rule Management

    func createRule(name: String, eventType: NotificationRule.EventType) -> NotificationRule {
        let rule = NotificationRule(name: name, eventType: eventType)
        rules.append(rule)
        saveData()
        return rule
    }

    func updateRule(_ rule: NotificationRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
            saveData()
        }
    }

    func deleteRule(_ rule: NotificationRule) {
        rules.removeAll { $0.id == rule.id }
        saveData()
    }

    func toggleRule(_ rule: NotificationRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index].isEnabled.toggle()
            saveData()
        }
    }

    // MARK: - Send Notifications

    func sendNotification(title: String, body: String, ruleId: UUID? = nil) async {
        // Check quiet hours
        if isInQuietHours() && quietHoursEnabled {
            // Log but don't send
            let log = NotificationLog(ruleId: ruleId, title: title, body: body + " (Quiet Hours)")
            logs.insert(log, at: 0)
            saveData()
            return
        }

        // Log notification
        let log = NotificationLog(ruleId: ruleId, title: title, body: body)
        logs.insert(log, at: 0)
        unreadCount += 1

        // Trim old logs (keep 100)
        if logs.count > 100 {
            logs = Array(logs.prefix(100))
        }

        saveData()

        // Send system notification (not available on tvOS)
        #if !os(tvOS)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
        #endif
    }

    func sendDeviceStateNotification(deviceName: String, oldState: String, newState: String) async {
        guard let rule = rules.first(where: { $0.eventType == .stateChange && $0.isEnabled }) else { return }

        await sendNotification(
            title: "Device State Changed",
            body: "\(deviceName): \(oldState) → \(newState)",
            ruleId: rule.id
        )
    }

    func sendMotionNotification(deviceName: String) async {
        guard let rule = rules.first(where: { $0.eventType == .motionDetected && $0.isEnabled }) else { return }

        await sendNotification(
            title: "Motion Detected",
            body: "Motion detected by \(deviceName)",
            ruleId: rule.id
        )
    }

    func sendDoorNotification(deviceName: String, isOpen: Bool) async {
        guard let rule = rules.first(where: { $0.eventType == .doorOpened && $0.isEnabled }) else { return }

        await sendNotification(
            title: isOpen ? "Door Opened" : "Door Closed",
            body: "\(deviceName) was \(isOpen ? "opened" : "closed")",
            ruleId: rule.id
        )
    }

    func sendDeviceOfflineNotification(deviceName: String) async {
        guard let rule = rules.first(where: { $0.eventType == .deviceOffline && $0.isEnabled }) else { return }

        await sendNotification(
            title: "Device Offline",
            body: "\(deviceName) is not responding",
            ruleId: rule.id
        )
    }

    func sendLowBatteryNotification(deviceName: String, batteryLevel: Int) async {
        guard let rule = rules.first(where: { $0.eventType == .lowBattery && $0.isEnabled }) else { return }

        await sendNotification(
            title: "Low Battery",
            body: "\(deviceName) battery is at \(batteryLevel)%",
            ruleId: rule.id
        )
    }

    // MARK: - Quiet Hours

    private func isInQuietHours() -> Bool {
        guard quietHoursEnabled else { return false }

        let now = Date()
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        let startComponents = calendar.dateComponents([.hour, .minute], from: quietHoursStart)
        let endComponents = calendar.dateComponents([.hour, .minute], from: quietHoursEnd)

        guard let nowMinutes = nowComponents.hour.map({ $0 * 60 + (nowComponents.minute ?? 0) }),
              let startMinutes = startComponents.hour.map({ $0 * 60 + (startComponents.minute ?? 0) }),
              let endMinutes = endComponents.hour.map({ $0 * 60 + (endComponents.minute ?? 0) }) else {
            return false
        }

        // Handle overnight quiet hours (e.g., 22:00 - 07:00)
        if startMinutes > endMinutes {
            return nowMinutes >= startMinutes || nowMinutes < endMinutes
        } else {
            return nowMinutes >= startMinutes && nowMinutes < endMinutes
        }
    }

    // MARK: - Log Management

    func markAsRead(_ log: NotificationLog) {
        if let index = logs.firstIndex(where: { $0.id == log.id }) {
            logs[index].isRead = true
            unreadCount = logs.filter { !$0.isRead }.count
            saveData()
        }
    }

    func markAllAsRead() {
        for index in logs.indices {
            logs[index].isRead = true
        }
        unreadCount = 0
        saveData()
    }

    func clearLogs() {
        logs.removeAll()
        unreadCount = 0
        saveData()
    }

    // MARK: - Persistence

    private func saveData() {
        if let rulesData = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(rulesData, forKey: storageKey + "_rules")
        }
        if let logsData = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(logsData, forKey: storageKey + "_logs")
        }

        let settings: [String: Any] = [
            "quietHoursEnabled": quietHoursEnabled,
            "quietHoursStart": quietHoursStart.timeIntervalSince1970,
            "quietHoursEnd": quietHoursEnd.timeIntervalSince1970
        ]
        UserDefaults.standard.set(settings, forKey: storageKey + "_settings")
    }

    private func loadData() {
        if let rulesData = UserDefaults.standard.data(forKey: storageKey + "_rules"),
           let saved = try? JSONDecoder().decode([NotificationRule].self, from: rulesData) {
            rules = saved
        }
        if let logsData = UserDefaults.standard.data(forKey: storageKey + "_logs"),
           let saved = try? JSONDecoder().decode([NotificationLog].self, from: logsData) {
            logs = saved
            unreadCount = logs.filter { !$0.isRead }.count
        }
        if let settings = UserDefaults.standard.dictionary(forKey: storageKey + "_settings") {
            quietHoursEnabled = settings["quietHoursEnabled"] as? Bool ?? false
            if let start = settings["quietHoursStart"] as? TimeInterval {
                quietHoursStart = Date(timeIntervalSince1970: start)
            }
            if let end = settings["quietHoursEnd"] as? TimeInterval {
                quietHoursEnd = Date(timeIntervalSince1970: end)
            }
        }
    }
}
