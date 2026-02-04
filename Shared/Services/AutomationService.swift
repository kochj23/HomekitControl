//
//  AutomationService.swift
//  HomekitControl
//
//  Visual automation builder with triggers, conditions, and actions
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Automation Models

enum TriggerType: String, Codable, CaseIterable, Identifiable {
    case time = "Time"
    case sunrise = "Sunrise"
    case sunset = "Sunset"
    case deviceState = "Device State"
    case location = "Location"
    case manual = "Manual"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .time: return "clock.fill"
        case .sunrise: return "sunrise.fill"
        case .sunset: return "sunset.fill"
        case .deviceState: return "lightbulb.fill"
        case .location: return "location.fill"
        case .manual: return "hand.tap.fill"
        }
    }
}

enum ConditionOperator: String, Codable, CaseIterable {
    case equals = "equals"
    case notEquals = "not equals"
    case greaterThan = "greater than"
    case lessThan = "less than"
    case contains = "contains"
}

struct AutomationTrigger: Codable, Identifiable {
    let id: UUID
    var type: TriggerType
    var timeValue: Date?
    var sunriseOffset: Int? // minutes before/after
    var sunsetOffset: Int?
    var deviceId: UUID?
    var deviceState: String?
    var locationLatitude: Double?
    var locationLongitude: Double?
    var locationRadius: Double?
    var isEntering: Bool?

    init(type: TriggerType) {
        self.id = UUID()
        self.type = type
    }
}

struct AutomationCondition: Codable, Identifiable {
    let id: UUID
    var deviceId: UUID?
    var characteristic: String
    var operatorType: ConditionOperator
    var value: String
    var isEnabled: Bool

    init(characteristic: String = "power", operatorType: ConditionOperator = .equals, value: String = "on") {
        self.id = UUID()
        self.characteristic = characteristic
        self.operatorType = operatorType
        self.value = value
        self.isEnabled = true
    }
}

struct AutomationAction: Codable, Identifiable {
    let id: UUID
    var deviceId: UUID?
    var sceneId: UUID?
    var actionType: ActionType
    var value: String?
    var delay: TimeInterval
    var order: Int

    enum ActionType: String, Codable, CaseIterable {
        case turnOn = "Turn On"
        case turnOff = "Turn Off"
        case setBrightness = "Set Brightness"
        case setColor = "Set Color"
        case executeScene = "Execute Scene"
        case wait = "Wait"
    }

    init(actionType: ActionType, delay: TimeInterval = 0, order: Int = 0) {
        self.id = UUID()
        self.actionType = actionType
        self.delay = delay
        self.order = order
    }
}

struct CustomAutomation: Codable, Identifiable {
    let id: UUID
    var name: String
    var isEnabled: Bool
    var triggers: [AutomationTrigger]
    var conditions: [AutomationCondition]
    var actions: [AutomationAction]
    var createdAt: Date
    var lastTriggered: Date?
    var lastRun: Date? // Alias for lastTriggered
    var runCount: Int

    var icon: String {
        // Return icon based on first trigger type
        triggers.first?.type.icon ?? "gearshape.2.fill"
    }

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.isEnabled = true
        self.triggers = []
        self.conditions = []
        self.actions = []
        self.createdAt = Date()
        self.runCount = 0
    }
}

// MARK: - Automation Service

@MainActor
class AutomationService: ObservableObject {
    static let shared = AutomationService()

    @Published var automations: [CustomAutomation] = []
    @Published var isProcessing = false
    @Published var lastError: String?

    private let storageKey = "HomekitControl_Automations"

    private init() {
        loadAutomations()
    }

    // MARK: - CRUD Operations

    func createAutomation(name: String) -> CustomAutomation {
        var automation = CustomAutomation(name: name)
        automations.append(automation)
        saveAutomations()
        return automation
    }

    func updateAutomation(_ automation: CustomAutomation) {
        if let index = automations.firstIndex(where: { $0.id == automation.id }) {
            automations[index] = automation
            saveAutomations()
        }
    }

    func deleteAutomation(_ automation: CustomAutomation) {
        automations.removeAll { $0.id == automation.id }
        saveAutomations()
    }

    func toggleAutomation(_ automation: CustomAutomation) {
        if let index = automations.firstIndex(where: { $0.id == automation.id }) {
            automations[index].isEnabled.toggle()
            saveAutomations()
        }
    }

    // MARK: - Execution

    func executeAutomation(_ automation: CustomAutomation) async throws {
        guard automation.isEnabled else { return }

        isProcessing = true
        defer { isProcessing = false }

        // Check conditions
        for condition in automation.conditions where condition.isEnabled {
            let conditionMet = await evaluateCondition(condition)
            if !conditionMet {
                print("Automation '\(automation.name)' condition not met")
                return
            }
        }

        // Execute actions in order
        let sortedActions = automation.actions.sorted { $0.order < $1.order }
        for action in sortedActions {
            if action.delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(action.delay * 1_000_000_000))
            }
            try await executeAction(action)
        }

        // Update stats
        if let index = automations.firstIndex(where: { $0.id == automation.id }) {
            automations[index].lastTriggered = Date()
            automations[index].runCount += 1
            saveAutomations()
        }
    }

    private func evaluateCondition(_ condition: AutomationCondition) async -> Bool {
        // Evaluate condition against device state
        #if canImport(HomeKit)
        guard let deviceId = condition.deviceId,
              let accessory = HomeKitService.shared.accessories.first(where: { $0.uniqueIdentifier == deviceId }) else {
            return true // No device specified, condition passes
        }

        // Get characteristic value and compare
        // Simplified - in production would check actual characteristic
        return true
        #else
        return true
        #endif
    }

    private func executeAction(_ action: AutomationAction) async throws {
        #if canImport(HomeKit)
        switch action.actionType {
        case .turnOn, .turnOff:
            if let deviceId = action.deviceId,
               let accessory = HomeKitService.shared.accessories.first(where: { $0.uniqueIdentifier == deviceId }) {
                try await HomeKitService.shared.toggleAccessory(accessory)
            }
        case .setBrightness:
            if let deviceId = action.deviceId,
               let value = action.value,
               let brightness = Int(value),
               let accessory = HomeKitService.shared.accessories.first(where: { $0.uniqueIdentifier == deviceId }) {
                try await HomeKitService.shared.setBrightness(accessory, value: brightness)
            }
        case .executeScene:
            if let sceneId = action.sceneId,
               let scene = HomeKitService.shared.scenes.first(where: { $0.uniqueIdentifier == sceneId }) {
                try await HomeKitService.shared.executeScene(scene)
            }
        case .wait:
            // Delay handled above
            break
        case .setColor:
            // Would implement color setting
            break
        }
        #endif
    }

    // MARK: - Import/Export

    func exportAutomation(_ automation: CustomAutomation) -> Data? {
        try? JSONEncoder().encode(automation)
    }

    func exportAllAutomations() -> Data? {
        try? JSONEncoder().encode(automations)
    }

    func importAutomation(from data: Data) throws -> CustomAutomation {
        let automation = try JSONDecoder().decode(CustomAutomation.self, from: data)
        var imported = automation
        imported = CustomAutomation(name: automation.name + " (Imported)")
        automations.append(imported)
        saveAutomations()
        return imported
    }

    // MARK: - Persistence

    private func saveAutomations() {
        if let data = try? JSONEncoder().encode(automations) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadAutomations() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([CustomAutomation].self, from: data) {
            automations = saved
        }
    }
}
