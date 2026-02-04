//
//  SceneSuggestionService.swift
//  HomekitControl
//
//  ML-based scene and automation suggestions
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Models

struct UsagePattern: Codable, Identifiable {
    let id: UUID
    let deviceId: UUID
    let deviceName: String
    let dayOfWeek: Int
    let hour: Int
    let action: DeviceAction
    var frequency: Int // How many times this pattern has been observed

    enum DeviceAction: String, Codable {
        case turnedOn = "Turned On"
        case turnedOff = "Turned Off"
        case brightnessChanged = "Brightness Changed"
        case colorChanged = "Color Changed"
        case sceneActivated = "Scene Activated"
    }
}

struct SceneSuggestion: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let confidence: Double // 0-1
    let basedOnPatterns: [UsagePattern]
    let suggestedActions: [SuggestedAction]
    let triggerTime: DateComponents?
    let triggerCondition: TriggerCondition?

    enum TriggerCondition: String {
        case timeOfDay = "Time of Day"
        case arrivedHome = "Arrived Home"
        case leftHome = "Left Home"
        case motionDetected = "Motion Detected"
        case noMotion = "No Motion"
        case sunset = "Sunset"
        case sunrise = "Sunrise"
    }
}

struct SuggestedAction: Identifiable {
    let id = UUID()
    let deviceId: UUID
    let deviceName: String
    let action: String
    let value: Any?
}

struct DeviceUsageLog: Codable, Identifiable {
    let id: UUID
    let deviceId: UUID
    let deviceName: String
    let timestamp: Date
    let action: UsagePattern.DeviceAction
    let value: Double?

    init(deviceId: UUID, deviceName: String, action: UsagePattern.DeviceAction, value: Double? = nil) {
        self.id = UUID()
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.timestamp = Date()
        self.action = action
        self.value = value
    }
}

// MARK: - Scene Suggestion Service

@MainActor
class SceneSuggestionService: ObservableObject {
    static let shared = SceneSuggestionService()

    // MARK: - Published Properties

    @Published var suggestions: [SceneSuggestion] = []
    @Published var patterns: [UsagePattern] = []
    @Published var usageLogs: [DeviceUsageLog] = []
    @Published var isLearning = true
    @Published var minimumConfidence: Double = 0.6
    @Published var dismissedSuggestionIds: Set<UUID> = []

    // MARK: - Private Properties

    private let storageKey = "HomekitControl_SceneSuggestions"
    private let minimumPatternFrequency = 3 // Minimum times a pattern must occur

    // MARK: - Initialization

    private init() {
        loadData()
    }

    // MARK: - Usage Logging

    func logDeviceUsage(deviceId: UUID, deviceName: String, action: UsagePattern.DeviceAction, value: Double? = nil) {
        guard isLearning else { return }

        let log = DeviceUsageLog(
            deviceId: deviceId,
            deviceName: deviceName,
            action: action,
            value: value
        )
        usageLogs.append(log)

        // Update patterns
        updatePatterns(from: log)

        // Trim old logs (keep 30 days)
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        usageLogs.removeAll { $0.timestamp < cutoff }

        // Generate suggestions
        generateSuggestions()

        saveData()
    }

    private func updatePatterns(from log: DeviceUsageLog) {
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: log.timestamp)
        let hour = calendar.component(.hour, from: log.timestamp)

        // Find existing pattern
        if let index = patterns.firstIndex(where: {
            $0.deviceId == log.deviceId &&
            $0.dayOfWeek == dayOfWeek &&
            $0.hour == hour &&
            $0.action == log.action
        }) {
            patterns[index].frequency += 1
        } else {
            // Create new pattern
            let pattern = UsagePattern(
                id: UUID(),
                deviceId: log.deviceId,
                deviceName: log.deviceName,
                dayOfWeek: dayOfWeek,
                hour: hour,
                action: log.action,
                frequency: 1
            )
            patterns.append(pattern)
        }
    }

    // MARK: - Suggestion Generation

    func generateSuggestions() {
        suggestions = []

        // Find strong patterns
        let strongPatterns = patterns.filter { $0.frequency >= minimumPatternFrequency }

        // Group patterns by time
        let patternsByTime = Dictionary(grouping: strongPatterns) { pattern in
            "\(pattern.dayOfWeek)-\(pattern.hour)"
        }

        for (_, timePatterns) in patternsByTime {
            if timePatterns.count >= 2 {
                // Multiple devices used at same time - suggest a scene
                let suggestion = createSceneSuggestion(from: timePatterns)
                if suggestion.confidence >= minimumConfidence && !dismissedSuggestionIds.contains(suggestion.id) {
                    suggestions.append(suggestion)
                }
            }
        }

        // Look for sequential patterns
        findSequentialPatterns()

        // Look for morning/evening routines
        findRoutinePatterns()

        // Sort by confidence
        suggestions.sort { $0.confidence > $1.confidence }
    }

    private func createSceneSuggestion(from patterns: [UsagePattern]) -> SceneSuggestion {
        let avgFrequency = Double(patterns.map { $0.frequency }.reduce(0, +)) / Double(patterns.count)
        let maxPossibleFrequency = Double(usageLogs.count / 7) // Approximate max weekly frequency
        let confidence = min(avgFrequency / max(maxPossibleFrequency, 1), 1.0)

        let actions = patterns.map { pattern in
            SuggestedAction(
                deviceId: pattern.deviceId,
                deviceName: pattern.deviceName,
                action: pattern.action.rawValue,
                value: nil
            )
        }

        let dayName = dayOfWeekName(patterns.first?.dayOfWeek ?? 1)
        let hour = patterns.first?.hour ?? 12
        let timeString = String(format: "%d:00 %@", hour > 12 ? hour - 12 : hour, hour >= 12 ? "PM" : "AM")

        return SceneSuggestion(
            id: UUID(),
            title: "\(dayName) \(timeString) Routine",
            description: "You often use these \(patterns.count) devices together at this time",
            confidence: confidence,
            basedOnPatterns: patterns,
            suggestedActions: actions,
            triggerTime: DateComponents(hour: hour, weekday: patterns.first?.dayOfWeek),
            triggerCondition: .timeOfDay
        )
    }

    private func findSequentialPatterns() {
        // Group logs by device
        let logsByDevice = Dictionary(grouping: usageLogs) { $0.deviceId }

        for (_, deviceLogs) in logsByDevice {
            let sortedLogs = deviceLogs.sorted { $0.timestamp < $1.timestamp }

            // Look for regular intervals
            var intervals: [TimeInterval] = []
            for i in 1..<sortedLogs.count {
                let interval = sortedLogs[i].timestamp.timeIntervalSince(sortedLogs[i-1].timestamp)
                if interval > 3600 && interval < 86400 * 7 { // Between 1 hour and 1 week
                    intervals.append(interval)
                }
            }

            if intervals.count >= 3 {
                // Calculate average interval
                let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
                let stdDev = sqrt(intervals.map { pow($0 - avgInterval, 2) }.reduce(0, +) / Double(intervals.count))

                // If consistent interval (low standard deviation)
                if stdDev < avgInterval * 0.3 {
                    // Create suggestion for regular usage
                    let deviceName = deviceLogs.first?.deviceName ?? "Device"
                    let suggestion = SceneSuggestion(
                        id: UUID(),
                        title: "Regular \(deviceName) Usage",
                        description: "You use this device regularly every \(formatInterval(avgInterval))",
                        confidence: 0.7,
                        basedOnPatterns: [],
                        suggestedActions: [],
                        triggerTime: nil,
                        triggerCondition: nil
                    )
                    if !dismissedSuggestionIds.contains(suggestion.id) {
                        suggestions.append(suggestion)
                    }
                }
            }
        }
    }

    private func findRoutinePatterns() {
        // Morning routine (6-9 AM)
        let morningPatterns = patterns.filter { $0.hour >= 6 && $0.hour < 9 && $0.frequency >= minimumPatternFrequency }
        if morningPatterns.count >= 2 {
            let suggestion = SceneSuggestion(
                id: UUID(),
                title: "Morning Routine",
                description: "Create a scene for your typical morning activities",
                confidence: 0.8,
                basedOnPatterns: morningPatterns,
                suggestedActions: morningPatterns.map {
                    SuggestedAction(deviceId: $0.deviceId, deviceName: $0.deviceName, action: $0.action.rawValue, value: nil)
                },
                triggerTime: DateComponents(hour: 7),
                triggerCondition: .timeOfDay
            )
            if !dismissedSuggestionIds.contains(suggestion.id) {
                suggestions.append(suggestion)
            }
        }

        // Evening routine (8-11 PM)
        let eveningPatterns = patterns.filter { $0.hour >= 20 && $0.hour < 23 && $0.frequency >= minimumPatternFrequency }
        if eveningPatterns.count >= 2 {
            let suggestion = SceneSuggestion(
                id: UUID(),
                title: "Evening Routine",
                description: "Create a scene for your typical evening activities",
                confidence: 0.8,
                basedOnPatterns: eveningPatterns,
                suggestedActions: eveningPatterns.map {
                    SuggestedAction(deviceId: $0.deviceId, deviceName: $0.deviceName, action: $0.action.rawValue, value: nil)
                },
                triggerTime: DateComponents(hour: 20),
                triggerCondition: .timeOfDay
            )
            if !dismissedSuggestionIds.contains(suggestion.id) {
                suggestions.append(suggestion)
            }
        }
    }

    // MARK: - Suggestion Actions

    func dismissSuggestion(_ suggestion: SceneSuggestion) {
        dismissedSuggestionIds.insert(suggestion.id)
        suggestions.removeAll { $0.id == suggestion.id }
        saveData()
    }

    func acceptSuggestion(_ suggestion: SceneSuggestion) {
        // Create automation based on suggestion
        // This would integrate with AutomationService
        dismissSuggestion(suggestion)
    }

    func clearAllSuggestions() {
        for suggestion in suggestions {
            dismissedSuggestionIds.insert(suggestion.id)
        }
        suggestions = []
        saveData()
    }

    // MARK: - Helper Methods

    private func dayOfWeekName(_ day: Int) -> String {
        let days = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return days[min(max(day, 1), 7)]
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        if hours < 24 {
            return "\(hours) hours"
        } else {
            let days = hours / 24
            return "\(days) day\(days > 1 ? "s" : "")"
        }
    }

    // MARK: - Computed Properties

    var topSuggestions: [SceneSuggestion] {
        Array(suggestions.prefix(5))
    }

    var hasNewSuggestions: Bool {
        !suggestions.isEmpty
    }

    var learningProgress: Double {
        let minLogs = 50.0
        return min(Double(usageLogs.count) / minLogs, 1.0)
    }

    // MARK: - Persistence

    private func saveData() {
        let settings: [String: Any] = [
            "isLearning": isLearning,
            "minimumConfidence": minimumConfidence
        ]

        if let encoded = try? JSONSerialization.data(withJSONObject: settings) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }

        if let patternsData = try? JSONEncoder().encode(patterns) {
            UserDefaults.standard.set(patternsData, forKey: storageKey + "_patterns")
        }

        if let logsData = try? JSONEncoder().encode(Array(usageLogs.suffix(1000))) {
            UserDefaults.standard.set(logsData, forKey: storageKey + "_logs")
        }

        let dismissedArray = Array(dismissedSuggestionIds.map { $0.uuidString })
        UserDefaults.standard.set(dismissedArray, forKey: storageKey + "_dismissed")
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            isLearning = settings["isLearning"] as? Bool ?? true
            minimumConfidence = settings["minimumConfidence"] as? Double ?? 0.6
        }

        if let patternsData = UserDefaults.standard.data(forKey: storageKey + "_patterns"),
           let saved = try? JSONDecoder().decode([UsagePattern].self, from: patternsData) {
            patterns = saved
        }

        if let logsData = UserDefaults.standard.data(forKey: storageKey + "_logs"),
           let saved = try? JSONDecoder().decode([DeviceUsageLog].self, from: logsData) {
            usageLogs = saved
        }

        if let dismissedArray = UserDefaults.standard.stringArray(forKey: storageKey + "_dismissed") {
            dismissedSuggestionIds = Set(dismissedArray.compactMap { UUID(uuidString: $0) })
        }
    }
}
