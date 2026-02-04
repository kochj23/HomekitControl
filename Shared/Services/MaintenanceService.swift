//
//  MaintenanceService.swift
//  HomekitControl
//
//  Device maintenance reminders and tracking
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Models

struct MaintenanceTask: Codable, Identifiable {
    let id: UUID
    let deviceId: UUID?
    var deviceName: String
    var taskType: TaskType
    var description: String
    var intervalDays: Int
    var lastCompleted: Date?
    var isEnabled: Bool
    var notifyBeforeDays: Int

    enum TaskType: String, Codable, CaseIterable {
        case filterChange = "Filter Change"
        case bulbReplacement = "Bulb Replacement"
        case batteryReplacement = "Battery Replacement"
        case cleaning = "Cleaning"
        case inspection = "Inspection"
        case calibration = "Calibration"
        case softwareUpdate = "Software Update"
        case custom = "Custom"

        var icon: String {
            switch self {
            case .filterChange: return "line.3.horizontal.decrease.circle"
            case .bulbReplacement: return "lightbulb"
            case .batteryReplacement: return "battery.50"
            case .cleaning: return "sparkles"
            case .inspection: return "eye"
            case .calibration: return "dial.high"
            case .softwareUpdate: return "arrow.down.circle"
            case .custom: return "wrench.and.screwdriver"
            }
        }

        var color: Color {
            switch self {
            case .filterChange: return ModernColors.cyan
            case .bulbReplacement: return ModernColors.yellow
            case .batteryReplacement: return ModernColors.accentGreen
            case .cleaning: return ModernColors.purple
            case .inspection: return ModernColors.accentBlue
            case .calibration: return ModernColors.orange
            case .softwareUpdate: return ModernColors.teal
            case .custom: return .secondary
            }
        }

        var defaultInterval: Int {
            switch self {
            case .filterChange: return 90
            case .bulbReplacement: return 365
            case .batteryReplacement: return 180
            case .cleaning: return 30
            case .inspection: return 365
            case .calibration: return 180
            case .softwareUpdate: return 30
            case .custom: return 90
            }
        }
    }

    init(deviceId: UUID? = nil, deviceName: String, taskType: TaskType, description: String = "") {
        self.id = UUID()
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.taskType = taskType
        self.description = description.isEmpty ? taskType.rawValue : description
        self.intervalDays = taskType.defaultInterval
        self.lastCompleted = nil
        self.isEnabled = true
        self.notifyBeforeDays = 7
    }

    var nextDue: Date? {
        guard let lastCompleted = lastCompleted else { return nil }
        return Calendar.current.date(byAdding: .day, value: intervalDays, to: lastCompleted)
    }

    var daysUntilDue: Int? {
        guard let nextDue = nextDue else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: nextDue).day
    }

    var isOverdue: Bool {
        guard let daysUntilDue = daysUntilDue else { return false }
        return daysUntilDue < 0
    }

    var isDueSoon: Bool {
        guard let daysUntilDue = daysUntilDue else { return false }
        return daysUntilDue >= 0 && daysUntilDue <= notifyBeforeDays
    }
}

struct MaintenanceLog: Codable, Identifiable {
    let id: UUID
    let taskId: UUID
    let taskName: String
    let deviceName: String
    let completedDate: Date
    var notes: String?
    var cost: Double?

    init(taskId: UUID, taskName: String, deviceName: String, notes: String? = nil, cost: Double? = nil) {
        self.id = UUID()
        self.taskId = taskId
        self.taskName = taskName
        self.deviceName = deviceName
        self.completedDate = Date()
        self.notes = notes
        self.cost = cost
    }
}

// MARK: - Maintenance Service

@MainActor
class MaintenanceService: ObservableObject {
    static let shared = MaintenanceService()

    // MARK: - Published Properties

    @Published var tasks: [MaintenanceTask] = []
    @Published var logs: [MaintenanceLog] = []
    @Published var notificationsEnabled = true

    // MARK: - Private Properties

    private let storageKey = "HomekitControl_Maintenance"

    // MARK: - Initialization

    private init() {
        loadData()
    }

    // MARK: - Task Management

    func addTask(_ task: MaintenanceTask) {
        tasks.append(task)
        saveData()
    }

    func updateTask(_ task: MaintenanceTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveData()
        }
    }

    func deleteTask(_ task: MaintenanceTask) {
        tasks.removeAll { $0.id == task.id }
        saveData()
    }

    func completeTask(_ taskId: UUID, notes: String? = nil, cost: Double? = nil) {
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            // Log completion
            let log = MaintenanceLog(
                taskId: taskId,
                taskName: tasks[index].description,
                deviceName: tasks[index].deviceName,
                notes: notes,
                cost: cost
            )
            logs.insert(log, at: 0)

            // Update task
            tasks[index].lastCompleted = Date()
            saveData()
        }
    }

    func snoozeTask(_ taskId: UUID, days: Int) {
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            // Extend the due date by snoozing
            if let currentDue = tasks[index].nextDue {
                let calendar = Calendar.current
                if let newLastCompleted = calendar.date(byAdding: .day, value: -tasks[index].intervalDays + days, to: currentDue) {
                    tasks[index].lastCompleted = newLastCompleted
                }
            } else {
                // If never completed, set last completed to today minus interval plus snooze days
                let calendar = Calendar.current
                tasks[index].lastCompleted = calendar.date(byAdding: .day, value: -tasks[index].intervalDays + days, to: Date())
            }
            saveData()
        }
    }

    // MARK: - Auto-Generate Tasks

    func generateDefaultTasks() {
        #if canImport(HomeKit)
        for accessory in HomeKitService.shared.accessories {
            // Check for thermostat (filter changes)
            if accessory.services.contains(where: { $0.serviceType == HMServiceTypeThermostat }) {
                if !tasks.contains(where: { $0.deviceId == accessory.uniqueIdentifier && $0.taskType == .filterChange }) {
                    let task = MaintenanceTask(
                        deviceId: accessory.uniqueIdentifier,
                        deviceName: accessory.name,
                        taskType: .filterChange,
                        description: "Replace HVAC filter"
                    )
                    tasks.append(task)
                }
            }

            // Check for battery-powered devices
            if accessory.services.contains(where: { $0.serviceType == HMServiceTypeBattery }) {
                if !tasks.contains(where: { $0.deviceId == accessory.uniqueIdentifier && $0.taskType == .batteryReplacement }) {
                    let task = MaintenanceTask(
                        deviceId: accessory.uniqueIdentifier,
                        deviceName: accessory.name,
                        taskType: .batteryReplacement,
                        description: "Check/replace batteries"
                    )
                    tasks.append(task)
                }
            }

            // Check for smoke detectors (inspection)
            if accessory.services.contains(where: { $0.serviceType == HMServiceTypeSmokeSensor }) {
                if !tasks.contains(where: { $0.deviceId == accessory.uniqueIdentifier && $0.taskType == .inspection }) {
                    let task = MaintenanceTask(
                        deviceId: accessory.uniqueIdentifier,
                        deviceName: accessory.name,
                        taskType: .inspection,
                        description: "Test smoke detector"
                    )
                    tasks.append(task)
                }
            }
        }

        saveData()
        #endif
    }

    // MARK: - Notifications

    func checkAndSendNotifications() {
        guard notificationsEnabled else { return }

        for task in tasks where task.isEnabled {
            if task.isOverdue {
                sendNotification(
                    title: "Maintenance Overdue",
                    body: "\(task.description) for \(task.deviceName) is overdue"
                )
            } else if task.isDueSoon {
                if let days = task.daysUntilDue {
                    sendNotification(
                        title: "Maintenance Due Soon",
                        body: "\(task.description) for \(task.deviceName) due in \(days) days"
                    )
                }
            }
        }
    }

    private func sendNotification(title: String, body: String) {
        #if os(iOS)
        Task {
            await NotificationService.shared.sendNotification(title: title, body: body)
        }
        #endif
    }

    // MARK: - Computed Properties

    var overdueTasks: [MaintenanceTask] {
        tasks.filter { $0.isEnabled && $0.isOverdue }
    }

    var dueSoonTasks: [MaintenanceTask] {
        tasks.filter { $0.isEnabled && $0.isDueSoon && !$0.isOverdue }
    }

    var upcomingTasks: [MaintenanceTask] {
        tasks.filter { $0.isEnabled && !$0.isOverdue && !$0.isDueSoon }
            .sorted { ($0.daysUntilDue ?? Int.max) < ($1.daysUntilDue ?? Int.max) }
    }

    var neverCompletedTasks: [MaintenanceTask] {
        tasks.filter { $0.isEnabled && $0.lastCompleted == nil }
    }

    var totalMaintenanceCost: Double {
        logs.compactMap { $0.cost }.reduce(0, +)
    }

    var thisMonthCost: Double {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        return logs.filter { $0.completedDate >= startOfMonth }
            .compactMap { $0.cost }
            .reduce(0, +)
    }

    var recentLogs: [MaintenanceLog] {
        Array(logs.prefix(20))
    }

    // MARK: - Persistence

    private func saveData() {
        let settings: [String: Any] = [
            "notificationsEnabled": notificationsEnabled
        ]

        if let encoded = try? JSONSerialization.data(withJSONObject: settings) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }

        if let tasksData = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(tasksData, forKey: storageKey + "_tasks")
        }

        if let logsData = try? JSONEncoder().encode(Array(logs.prefix(500))) {
            UserDefaults.standard.set(logsData, forKey: storageKey + "_logs")
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            notificationsEnabled = settings["notificationsEnabled"] as? Bool ?? true
        }

        if let tasksData = UserDefaults.standard.data(forKey: storageKey + "_tasks"),
           let saved = try? JSONDecoder().decode([MaintenanceTask].self, from: tasksData) {
            tasks = saved
        }

        if let logsData = UserDefaults.standard.data(forKey: storageKey + "_logs"),
           let saved = try? JSONDecoder().decode([MaintenanceLog].self, from: logsData) {
            logs = saved
        }
    }
}
