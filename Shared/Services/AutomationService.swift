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

/// Logic group for compound condition evaluation
enum ConditionGroupLogic: String, Codable, CaseIterable {
    case and = "AND"
    case or = "OR"
}

struct AutomationCondition: Codable, Identifiable {
    let id: UUID
    var deviceId: UUID?
    var characteristic: String
    var operatorType: ConditionOperator
    var value: String
    var isEnabled: Bool
    /// Group index for compound AND/OR grouping (conditions in same group share logic)
    var groupIndex: Int
    /// Logic to apply between this condition's group and the next
    var groupLogic: ConditionGroupLogic
    /// Optional time window: condition only active between these hours (24h format)
    var timeWindowStart: Int? // Hour (0-23), nil = always active
    var timeWindowEnd: Int? // Hour (0-23), nil = always active
    /// Minimum duration the condition must be true (seconds)
    var minimumDuration: TimeInterval?

    init(characteristic: String = "power", operatorType: ConditionOperator = .equals, value: String = "on", groupIndex: Int = 0, groupLogic: ConditionGroupLogic = .and) {
        self.id = UUID()
        self.characteristic = characteristic
        self.operatorType = operatorType
        self.value = value
        self.isEnabled = true
        self.groupIndex = groupIndex
        self.groupLogic = groupLogic
        self.timeWindowStart = nil
        self.timeWindowEnd = nil
        self.minimumDuration = nil
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
        let automation = CustomAutomation(name: name)
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

        // Check conditions using compound AND/OR group logic
        let enabledConditions = automation.conditions.filter { $0.isEnabled }
        if !enabledConditions.isEmpty {
            let conditionsMet = await evaluateConditionGroups(enabledConditions)
            if !conditionsMet {
                print("Automation '\(automation.name)' conditions not met")
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

    /// Evaluate conditions using compound AND/OR group logic
    private func evaluateConditionGroups(_ conditions: [AutomationCondition]) async -> Bool {
        // Group conditions by their groupIndex
        let grouped = Dictionary(grouping: conditions, by: { $0.groupIndex })
        let sortedGroupKeys = grouped.keys.sorted()

        var groupResults: [(result: Bool, logic: ConditionGroupLogic)] = []

        for groupKey in sortedGroupKeys {
            guard let groupConditions = grouped[groupKey] else { continue }
            let logic = groupConditions.first?.groupLogic ?? .and

            // Within a group, all conditions must be true (AND within group)
            var groupPassed = true
            for condition in groupConditions {
                // Check time window
                if !isWithinTimeWindow(condition) {
                    groupPassed = false
                    break
                }

                let result = await evaluateCondition(condition)
                if !result {
                    groupPassed = false
                    break
                }
            }

            groupResults.append((result: groupPassed, logic: logic))
        }

        // Combine groups using their logic operators
        guard let first = groupResults.first else { return true }
        var finalResult = first.result

        for i in 1..<groupResults.count {
            let current = groupResults[i]
            // Use the logic from the PREVIOUS group to combine with current
            let combineLogic = groupResults[i - 1].logic

            switch combineLogic {
            case .and:
                finalResult = finalResult && current.result
            case .or:
                finalResult = finalResult || current.result
            }
        }

        return finalResult
    }

    /// Check if current time falls within condition's active time window
    private func isWithinTimeWindow(_ condition: AutomationCondition) -> Bool {
        guard let start = condition.timeWindowStart, let end = condition.timeWindowEnd else {
            return true // No time window restriction
        }

        let currentHour = Calendar.current.component(.hour, from: Date())

        if start <= end {
            return currentHour >= start && currentHour < end
        } else {
            // Spans midnight (e.g., 22:00 - 06:00)
            return currentHour >= start || currentHour < end
        }
    }

    private func evaluateCondition(_ condition: AutomationCondition) async -> Bool {
        #if canImport(HomeKit)
        guard let deviceId = condition.deviceId,
              let accessory = HomeKitService.shared.accessories.first(where: { $0.uniqueIdentifier == deviceId }) else {
            return true // No device specified, condition passes
        }

        // Find the characteristic matching the condition
        for service in accessory.services {
            for characteristic in service.characteristics {
                let charDescription = characteristic.localizedDescription.lowercased()
                let conditionChar = condition.characteristic.lowercased()

                guard charDescription.contains(conditionChar) || characteristic.characteristicType.lowercased().contains(conditionChar) else {
                    continue
                }

                // Read current value from the device
                do {
                    try await characteristic.readValue()
                } catch {
                    NSLog("[AutomationService] Failed to read characteristic for condition: \(error.localizedDescription)")
                    return false
                }

                guard let currentValue = characteristic.value else { return false }

                // Compare based on operator type
                return evaluateComparison(
                    currentValue: currentValue,
                    conditionValue: condition.value,
                    operatorType: condition.operatorType
                )
            }
        }

        // No matching characteristic found
        return false
        #else
        return true
        #endif
    }

    private func evaluateComparison(currentValue: Any, conditionValue: String, operatorType: ConditionOperator) -> Bool {
        // Numeric comparison
        if let numericCurrent = numericValue(from: currentValue),
           let numericCondition = Double(conditionValue) {
            switch operatorType {
            case .equals:
                return abs(numericCurrent - numericCondition) < 0.01
            case .notEquals:
                return abs(numericCurrent - numericCondition) >= 0.01
            case .greaterThan:
                return numericCurrent > numericCondition
            case .lessThan:
                return numericCurrent < numericCondition
            case .contains:
                return String(describing: currentValue).lowercased().contains(conditionValue.lowercased())
            }
        }

        // Boolean comparison
        if let boolCurrent = currentValue as? Bool {
            let boolCondition = conditionValue.lowercased() == "true" || conditionValue == "1" || conditionValue.lowercased() == "on"
            switch operatorType {
            case .equals:
                return boolCurrent == boolCondition
            case .notEquals:
                return boolCurrent != boolCondition
            default:
                return boolCurrent == boolCondition
            }
        }

        // String comparison
        let stringCurrent = String(describing: currentValue).lowercased()
        let stringCondition = conditionValue.lowercased()

        switch operatorType {
        case .equals:
            return stringCurrent == stringCondition
        case .notEquals:
            return stringCurrent != stringCondition
        case .contains:
            return stringCurrent.contains(stringCondition)
        case .greaterThan:
            return stringCurrent > stringCondition
        case .lessThan:
            return stringCurrent < stringCondition
        }
    }

    private func numericValue(from value: Any) -> Double? {
        switch value {
        case let intVal as Int: return Double(intVal)
        case let doubleVal as Double: return doubleVal
        case let floatVal as Float: return Double(floatVal)
        case let boolVal as Bool: return boolVal ? 1.0 : 0.0
        case let nsNumber as NSNumber: return nsNumber.doubleValue
        default: return nil
        }
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
        let decoded = try JSONDecoder().decode(CustomAutomation.self, from: data)
        // Preserve all decoded data (triggers, conditions, actions) while giving it a new identity
        var imported = CustomAutomation(name: decoded.name + " (Imported)")
        imported.triggers = decoded.triggers
        imported.conditions = decoded.conditions
        imported.actions = decoded.actions
        imported.isEnabled = decoded.isEnabled
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
