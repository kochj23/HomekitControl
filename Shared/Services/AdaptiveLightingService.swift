//
//  AdaptiveLightingService.swift
//  HomekitControl
//
//  Circadian rhythm and adaptive lighting automation
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Models

struct LightingProfile: Codable, Identifiable {
    let id: UUID
    var name: String
    var isEnabled: Bool
    var deviceIds: [UUID]
    var schedule: [LightingSchedulePoint]
    var motionActivated: Bool
    var motionTimeout: TimeInterval // seconds
    var ambientLightThreshold: Double? // lux

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.isEnabled = true
        self.deviceIds = []
        self.schedule = LightingSchedulePoint.defaultCircadian
        self.motionActivated = false
        self.motionTimeout = 300 // 5 minutes
        self.ambientLightThreshold = nil
    }
}

struct LightingSchedulePoint: Codable, Identifiable {
    let id: UUID
    var hour: Int
    var minute: Int
    var brightness: Int // 0-100
    var colorTemperature: Int // Kelvin (2700-6500)
    var transitionDuration: TimeInterval // seconds

    init(hour: Int, minute: Int, brightness: Int, colorTemperature: Int, transitionDuration: TimeInterval = 1800) {
        self.id = UUID()
        self.hour = hour
        self.minute = minute
        self.brightness = brightness
        self.colorTemperature = colorTemperature
        self.transitionDuration = transitionDuration
    }

    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    static var defaultCircadian: [LightingSchedulePoint] {
        [
            LightingSchedulePoint(hour: 6, minute: 0, brightness: 30, colorTemperature: 2700), // Warm wake-up
            LightingSchedulePoint(hour: 8, minute: 0, brightness: 80, colorTemperature: 4000), // Morning energy
            LightingSchedulePoint(hour: 12, minute: 0, brightness: 100, colorTemperature: 5500), // Midday peak
            LightingSchedulePoint(hour: 17, minute: 0, brightness: 80, colorTemperature: 4500), // Afternoon
            LightingSchedulePoint(hour: 20, minute: 0, brightness: 50, colorTemperature: 3000), // Evening wind-down
            LightingSchedulePoint(hour: 22, minute: 0, brightness: 20, colorTemperature: 2700)  // Night mode
        ]
    }
}

struct MotionEvent: Codable, Identifiable {
    let id: UUID
    let sensorId: UUID
    let sensorName: String
    let timestamp: Date
    let triggeredLights: [UUID]
}

// MARK: - Adaptive Lighting Service

@MainActor
class AdaptiveLightingService: ObservableObject {
    static let shared = AdaptiveLightingService()

    // MARK: - Published Properties

    @Published var profiles: [LightingProfile] = []
    @Published var isEnabled = true
    @Published var currentBrightness: Int = 100
    @Published var currentColorTemp: Int = 4000
    @Published var motionEvents: [MotionEvent] = []
    @Published var activeMotionTimers: [UUID: Date] = [:] // Device ID -> timeout date

    // MARK: - Private Properties

    private let storageKey = "HomekitControl_AdaptiveLighting"
    private var updateTimer: Timer?
    private var motionTimers: [UUID: Timer] = [:]

    // MARK: - Initialization

    private init() {
        loadData()
        if profiles.isEmpty {
            createDefaultProfile()
        }
    }

    // MARK: - Profile Management

    func addProfile(_ profile: LightingProfile) {
        profiles.append(profile)
        saveData()
    }

    func updateProfile(_ profile: LightingProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
            saveData()
        }
    }

    func deleteProfile(_ profile: LightingProfile) {
        profiles.removeAll { $0.id == profile.id }
        saveData()
    }

    private func createDefaultProfile() {
        let profile = LightingProfile(name: "Circadian Rhythm")
        profiles.append(profile)
        saveData()
    }

    // MARK: - Adaptive Lighting Control

    func startAdaptiveLighting() {
        guard isEnabled else { return }

        // Initial update
        updateLighting()

        // Schedule regular updates every 5 minutes
        updateTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateLighting()
            }
        }
    }

    func stopAdaptiveLighting() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    func updateLighting() {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTimeMinutes = currentHour * 60 + currentMinute

        for profile in profiles where profile.isEnabled {
            let (brightness, colorTemp) = calculateLightingValues(
                schedule: profile.schedule,
                currentTimeMinutes: currentTimeMinutes
            )

            currentBrightness = brightness
            currentColorTemp = colorTemp

            // Apply to devices
            applyLightingToDevices(profile.deviceIds, brightness: brightness, colorTemp: colorTemp)
        }
    }

    private func calculateLightingValues(schedule: [LightingSchedulePoint], currentTimeMinutes: Int) -> (brightness: Int, colorTemp: Int) {
        guard !schedule.isEmpty else { return (100, 4000) }

        let sortedSchedule = schedule.sorted { ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute) }

        // Find the two schedule points we're between
        var previousPoint = sortedSchedule.last!
        var nextPoint = sortedSchedule.first!

        for i in 0..<sortedSchedule.count {
            let pointMinutes = sortedSchedule[i].hour * 60 + sortedSchedule[i].minute
            if pointMinutes > currentTimeMinutes {
                nextPoint = sortedSchedule[i]
                previousPoint = i > 0 ? sortedSchedule[i - 1] : sortedSchedule.last!
                break
            }
            if i == sortedSchedule.count - 1 {
                previousPoint = sortedSchedule[i]
                nextPoint = sortedSchedule.first!
            }
        }

        // Calculate interpolation
        let prevMinutes = previousPoint.hour * 60 + previousPoint.minute
        var nextMinutes = nextPoint.hour * 60 + nextPoint.minute
        var currentAdjusted = currentTimeMinutes

        // Handle day wraparound
        if nextMinutes < prevMinutes {
            nextMinutes += 24 * 60
            if currentAdjusted < prevMinutes {
                currentAdjusted += 24 * 60
            }
        }

        let totalDuration = nextMinutes - prevMinutes
        let elapsed = currentAdjusted - prevMinutes
        let progress = totalDuration > 0 ? Double(elapsed) / Double(totalDuration) : 0

        // Interpolate values
        let brightness = Int(Double(previousPoint.brightness) + (Double(nextPoint.brightness) - Double(previousPoint.brightness)) * progress)
        let colorTemp = Int(Double(previousPoint.colorTemperature) + (Double(nextPoint.colorTemperature) - Double(previousPoint.colorTemperature)) * progress)

        return (brightness, colorTemp)
    }

    private func applyLightingToDevices(_ deviceIds: [UUID], brightness: Int, colorTemp: Int) {
        #if canImport(HomeKit)
        Task {
            for deviceId in deviceIds {
                guard let accessory = HomeKitService.shared.accessories.first(where: { $0.uniqueIdentifier == deviceId }) else { continue }

                // Set brightness
                try? await HomeKitService.shared.setBrightness(accessory, value: brightness)

                // Set color temperature if supported
                if let service = accessory.services.first(where: { $0.serviceType == HMServiceTypeLightbulb }),
                   let colorTempChar = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeColorTemperature }) {
                    // Convert Kelvin to mireds (HomeKit uses mireds)
                    let mireds = 1_000_000 / colorTemp
                    try? await colorTempChar.writeValue(mireds)
                }
            }
        }
        #endif
    }

    // MARK: - Motion Activation

    func handleMotionDetected(sensorId: UUID, sensorName: String) {
        // Find profiles that use motion activation
        for profile in profiles where profile.isEnabled && profile.motionActivated {
            // Turn on lights
            let (brightness, colorTemp) = (currentBrightness, currentColorTemp)
            applyLightingToDevices(profile.deviceIds, brightness: brightness, colorTemp: colorTemp)

            // Log motion event
            let event = MotionEvent(
                id: UUID(),
                sensorId: sensorId,
                sensorName: sensorName,
                timestamp: Date(),
                triggeredLights: profile.deviceIds
            )
            motionEvents.insert(event, at: 0)

            // Set timeout timer
            for deviceId in profile.deviceIds {
                activeMotionTimers[deviceId] = Date().addingTimeInterval(profile.motionTimeout)

                // Cancel existing timer
                motionTimers[deviceId]?.invalidate()

                // Set new timer
                motionTimers[deviceId] = Timer.scheduledTimer(withTimeInterval: profile.motionTimeout, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        self?.turnOffDevice(deviceId)
                        self?.activeMotionTimers.removeValue(forKey: deviceId)
                    }
                }
            }
        }

        // Trim motion events
        if motionEvents.count > 100 {
            motionEvents = Array(motionEvents.prefix(100))
        }

        saveData()
    }

    private func turnOffDevice(_ deviceId: UUID) {
        #if canImport(HomeKit)
        Task {
            if let accessory = HomeKitService.shared.accessories.first(where: { $0.uniqueIdentifier == deviceId }) {
                try? await HomeKitService.shared.setAccessoryPower(accessory, on: false)
            }
        }
        #endif
    }

    // MARK: - Ambient Light Integration

    func handleAmbientLightReading(_ lux: Double, sensorId: UUID) {
        for profile in profiles where profile.isEnabled {
            guard let threshold = profile.ambientLightThreshold else { continue }

            if lux < threshold {
                // It's dark enough, apply lighting
                let (brightness, colorTemp) = (currentBrightness, currentColorTemp)
                applyLightingToDevices(profile.deviceIds, brightness: brightness, colorTemp: colorTemp)
            } else {
                // It's bright enough, turn off or dim lights
                applyLightingToDevices(profile.deviceIds, brightness: 0, colorTemp: currentColorTemp)
            }
        }
    }

    // MARK: - Computed Properties

    var currentColorTempDescription: String {
        switch currentColorTemp {
        case ..<3000: return "Warm"
        case 3000..<4000: return "Soft White"
        case 4000..<5000: return "Neutral"
        case 5000..<6000: return "Daylight"
        default: return "Cool"
        }
    }

    var currentColorTempColor: Color {
        // Approximate color temperature to RGB
        let temp = Double(currentColorTemp)
        let red: Double
        let green: Double
        let blue: Double

        if temp <= 4000 {
            red = 1.0
            green = 0.4 + (temp - 2700) / 1300 * 0.4
            blue = 0.2 + (temp - 2700) / 1300 * 0.3
        } else {
            red = 1.0 - (temp - 4000) / 2500 * 0.2
            green = 0.8 + (temp - 4000) / 2500 * 0.2
            blue = 0.5 + (temp - 4000) / 2500 * 0.5
        }

        return Color(red: red, green: green, blue: blue)
    }

    var enabledProfiles: [LightingProfile] {
        profiles.filter { $0.isEnabled }
    }

    var motionActiveDeviceCount: Int {
        activeMotionTimers.count
    }

    // MARK: - Persistence

    private func saveData() {
        let settings: [String: Any] = [
            "isEnabled": isEnabled
        ]

        if let encoded = try? JSONSerialization.data(withJSONObject: settings) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }

        if let profilesData = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(profilesData, forKey: storageKey + "_profiles")
        }

        if let eventsData = try? JSONEncoder().encode(Array(motionEvents.prefix(100))) {
            UserDefaults.standard.set(eventsData, forKey: storageKey + "_motionEvents")
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            isEnabled = settings["isEnabled"] as? Bool ?? true
        }

        if let profilesData = UserDefaults.standard.data(forKey: storageKey + "_profiles"),
           let saved = try? JSONDecoder().decode([LightingProfile].self, from: profilesData) {
            profiles = saved
        }

        if let eventsData = UserDefaults.standard.data(forKey: storageKey + "_motionEvents"),
           let saved = try? JSONDecoder().decode([MotionEvent].self, from: eventsData) {
            motionEvents = saved
        }
    }
}
