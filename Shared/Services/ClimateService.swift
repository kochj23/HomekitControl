//
//  ClimateService.swift
//  HomekitControl
//
//  Climate zones and multi-thermostat coordination
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Models

struct ClimateZone: Codable, Identifiable {
    let id: UUID
    var name: String
    var thermostatIds: [UUID]
    var targetTemperature: Double
    var isEnabled: Bool
    var schedule: [ClimateScheduleEntry]
    var occupancySensorId: UUID?
    var unoccupiedSetback: Double // Temperature reduction when unoccupied

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.thermostatIds = []
        self.targetTemperature = 72.0
        self.isEnabled = true
        self.schedule = []
        self.occupancySensorId = nil
        self.unoccupiedSetback = 4.0
    }
}

struct ClimateScheduleEntry: Codable, Identifiable {
    let id: UUID
    var dayOfWeek: Int // 1-7 (Sunday-Saturday)
    var hour: Int
    var minute: Int
    var targetTemperature: Double
    var mode: ThermostatMode

    init(dayOfWeek: Int, hour: Int, minute: Int, targetTemperature: Double, mode: ThermostatMode) {
        self.id = UUID()
        self.dayOfWeek = dayOfWeek
        self.hour = hour
        self.minute = minute
        self.targetTemperature = targetTemperature
        self.mode = mode
    }
}

enum ThermostatMode: String, Codable, CaseIterable {
    case off = "Off"
    case heat = "Heat"
    case cool = "Cool"
    case auto = "Auto"

    var icon: String {
        switch self {
        case .off: return "power"
        case .heat: return "flame.fill"
        case .cool: return "snowflake"
        case .auto: return "arrow.left.arrow.right"
        }
    }

    var color: Color {
        switch self {
        case .off: return .secondary
        case .heat: return ModernColors.orange
        case .cool: return ModernColors.cyan
        case .auto: return ModernColors.accentGreen
        }
    }
}

struct ThermostatStatus: Identifiable {
    let id: UUID
    let name: String
    var currentTemperature: Double
    var targetTemperature: Double
    var humidity: Double?
    var mode: ThermostatMode
    var isHeating: Bool
    var isCooling: Bool
    var isReachable: Bool
}

struct ClimateHistoryEntry: Codable, Identifiable {
    let id: UUID
    let zoneId: UUID
    let zoneName: String
    let timestamp: Date
    let temperature: Double
    let targetTemperature: Double
    let mode: ThermostatMode
    let wasOccupied: Bool
}

// MARK: - Climate Service

@MainActor
class ClimateService: ObservableObject {
    static let shared = ClimateService()

    // MARK: - Published Properties

    @Published var zones: [ClimateZone] = []
    @Published var thermostats: [ThermostatStatus] = []
    @Published var history: [ClimateHistoryEntry] = []
    @Published var isMonitoring = false

    // Settings
    @Published var temperatureUnit: TemperatureUnit = .fahrenheit
    @Published var awayModeEnabled = false
    @Published var awayTemperature: Double = 65.0

    enum TemperatureUnit: String, Codable, CaseIterable {
        case fahrenheit = "°F"
        case celsius = "°C"
    }

    // MARK: - Private Properties

    private let storageKey = "HomekitControl_Climate"
    private var monitoringTask: Task<Void, Never>?
    private var scheduleTimer: Timer?

    // MARK: - Initialization

    private init() {
        loadData()
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        refreshThermostats()
        startScheduleTimer()

        monitoringTask = Task {
            while !Task.isCancelled && isMonitoring {
                await refreshThermostats()
                await checkSchedules()
                try? await Task.sleep(nanoseconds: 60_000_000_000) // Every minute
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        scheduleTimer?.invalidate()
    }

    private func startScheduleTimer() {
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkSchedules()
            }
        }
    }

    func refreshThermostats() {
        #if canImport(HomeKit)
        thermostats = []

        for accessory in HomeKitService.shared.accessories {
            guard let thermostatService = accessory.services.first(where: { $0.serviceType == HMServiceTypeThermostat }) else {
                continue
            }

            var currentTemp: Double = 0
            var targetTemp: Double = 72
            var humidity: Double?
            var mode: ThermostatMode = .auto
            var isHeating = false
            var isCooling = false

            for characteristic in thermostatService.characteristics {
                switch characteristic.characteristicType {
                case HMCharacteristicTypeCurrentTemperature:
                    if let value = characteristic.value as? Double {
                        currentTemp = temperatureUnit == .fahrenheit ? celsiusToFahrenheit(value) : value
                    }
                case HMCharacteristicTypeTargetTemperature:
                    if let value = characteristic.value as? Double {
                        targetTemp = temperatureUnit == .fahrenheit ? celsiusToFahrenheit(value) : value
                    }
                case HMCharacteristicTypeCurrentRelativeHumidity:
                    humidity = characteristic.value as? Double
                case "00000033-0000-1000-8000-0026BB765291": // Target Heating Cooling State
                    if let value = characteristic.value as? Int {
                        switch value {
                        case 0: mode = .off
                        case 1: mode = .heat
                        case 2: mode = .cool
                        case 3: mode = .auto
                        default: break
                        }
                    }
                case "0000000F-0000-1000-8000-0026BB765291": // Current Heating Cooling State
                    if let value = characteristic.value as? Int {
                        isHeating = value == 1
                        isCooling = value == 2
                    }
                default:
                    break
                }
            }

            let status = ThermostatStatus(
                id: accessory.uniqueIdentifier,
                name: accessory.name,
                currentTemperature: currentTemp,
                targetTemperature: targetTemp,
                humidity: humidity,
                mode: mode,
                isHeating: isHeating,
                isCooling: isCooling,
                isReachable: accessory.isReachable
            )
            thermostats.append(status)
        }
        #endif
    }

    // MARK: - Temperature Control

    func setTemperature(_ temperature: Double, for thermostatId: UUID) async {
        #if canImport(HomeKit)
        guard let accessory = HomeKitService.shared.accessories.first(where: { $0.uniqueIdentifier == thermostatId }),
              let thermostatService = accessory.services.first(where: { $0.serviceType == HMServiceTypeThermostat }),
              let targetTempChar = thermostatService.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeTargetTemperature }) else {
            return
        }

        let celsiusTemp = temperatureUnit == .fahrenheit ? fahrenheitToCelsius(temperature) : temperature

        do {
            try await targetTempChar.writeValue(celsiusTemp)
            refreshThermostats()
        } catch {
            print("Failed to set temperature: \(error)")
        }
        #endif
    }

    func setMode(_ mode: ThermostatMode, for thermostatId: UUID) async {
        #if canImport(HomeKit)
        guard let accessory = HomeKitService.shared.accessories.first(where: { $0.uniqueIdentifier == thermostatId }),
              let thermostatService = accessory.services.first(where: { $0.serviceType == HMServiceTypeThermostat }),
              // Target Heating Cooling State UUID
              let modeChar = thermostatService.characteristics.first(where: { $0.characteristicType == "00000033-0000-1000-8000-0026BB765291" }) else {
            return
        }

        let modeValue: Int
        switch mode {
        case .off: modeValue = 0
        case .heat: modeValue = 1
        case .cool: modeValue = 2
        case .auto: modeValue = 3
        }

        do {
            try await modeChar.writeValue(modeValue)
            refreshThermostats()
        } catch {
            print("Failed to set mode: \(error)")
        }
        #endif
    }

    // MARK: - Zone Management

    func addZone(_ zone: ClimateZone) {
        zones.append(zone)
        saveData()
    }

    func updateZone(_ zone: ClimateZone) {
        if let index = zones.firstIndex(where: { $0.id == zone.id }) {
            zones[index] = zone
            saveData()
        }
    }

    func deleteZone(_ zone: ClimateZone) {
        zones.removeAll { $0.id == zone.id }
        saveData()
    }

    func setZoneTemperature(_ zoneId: UUID, temperature: Double) async {
        guard let zone = zones.first(where: { $0.id == zoneId }) else { return }

        for thermostatId in zone.thermostatIds {
            await setTemperature(temperature, for: thermostatId)
        }

        // Update zone target
        if let index = zones.firstIndex(where: { $0.id == zoneId }) {
            zones[index].targetTemperature = temperature
            saveData()
        }
    }

    // MARK: - Scheduling

    private func checkSchedules() async {
        let calendar = Calendar.current
        let now = Date()
        let currentDayOfWeek = calendar.component(.weekday, from: now)
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)

        for zone in zones where zone.isEnabled {
            // Find matching schedule entry
            if let entry = zone.schedule.first(where: {
                $0.dayOfWeek == currentDayOfWeek &&
                $0.hour == currentHour &&
                $0.minute == currentMinute
            }) {
                // Apply schedule
                await setZoneTemperature(zone.id, temperature: entry.targetTemperature)

                for thermostatId in zone.thermostatIds {
                    await setMode(entry.mode, for: thermostatId)
                }

                // Log history
                logHistory(zone: zone, temperature: entry.targetTemperature, mode: entry.mode)
            }
        }
    }

    func handleOccupancyChange(sensorId: UUID, isOccupied: Bool) async {
        for zone in zones where zone.occupancySensorId == sensorId && zone.isEnabled {
            let temperature: Double
            if isOccupied {
                temperature = zone.targetTemperature
            } else {
                temperature = zone.targetTemperature - zone.unoccupiedSetback
            }

            await setZoneTemperature(zone.id, temperature: temperature)
        }
    }

    // MARK: - Away Mode

    func enableAwayMode() async {
        awayModeEnabled = true
        for thermostat in thermostats {
            await setTemperature(awayTemperature, for: thermostat.id)
        }
        saveData()
    }

    func disableAwayMode() async {
        awayModeEnabled = false
        // Restore zone temperatures
        for zone in zones where zone.isEnabled {
            await setZoneTemperature(zone.id, temperature: zone.targetTemperature)
        }
        saveData()
    }

    // MARK: - History

    private func logHistory(zone: ClimateZone, temperature: Double, mode: ThermostatMode) {
        let entry = ClimateHistoryEntry(
            id: UUID(),
            zoneId: zone.id,
            zoneName: zone.name,
            timestamp: Date(),
            temperature: temperature,
            targetTemperature: zone.targetTemperature,
            mode: mode,
            wasOccupied: true
        )
        history.insert(entry, at: 0)

        // Trim history
        if history.count > 1000 {
            history = Array(history.prefix(1000))
        }
        saveData()
    }

    // MARK: - Computed Properties

    var averageTemperature: Double {
        guard !thermostats.isEmpty else { return 0 }
        return thermostats.map { $0.currentTemperature }.reduce(0, +) / Double(thermostats.count)
    }

    var activelyHeating: [ThermostatStatus] {
        thermostats.filter { $0.isHeating }
    }

    var activelyCooling: [ThermostatStatus] {
        thermostats.filter { $0.isCooling }
    }

    var averageHumidity: Double? {
        let humidities = thermostats.compactMap { $0.humidity }
        guard !humidities.isEmpty else { return nil }
        return humidities.reduce(0, +) / Double(humidities.count)
    }

    // MARK: - Temperature Conversion

    func celsiusToFahrenheit(_ celsius: Double) -> Double {
        return celsius * 9.0 / 5.0 + 32.0
    }

    func fahrenheitToCelsius(_ fahrenheit: Double) -> Double {
        return (fahrenheit - 32.0) * 5.0 / 9.0
    }

    func formatTemperature(_ temp: Double) -> String {
        return String(format: "%.0f%@", temp, temperatureUnit.rawValue)
    }

    // MARK: - Persistence

    private func saveData() {
        let settings: [String: Any] = [
            "temperatureUnit": temperatureUnit.rawValue,
            "awayModeEnabled": awayModeEnabled,
            "awayTemperature": awayTemperature
        ]

        if let encoded = try? JSONSerialization.data(withJSONObject: settings) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }

        if let zonesData = try? JSONEncoder().encode(zones) {
            UserDefaults.standard.set(zonesData, forKey: storageKey + "_zones")
        }

        if let historyData = try? JSONEncoder().encode(Array(history.prefix(1000))) {
            UserDefaults.standard.set(historyData, forKey: storageKey + "_history")
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let unitStr = settings["temperatureUnit"] as? String,
               let unit = TemperatureUnit(rawValue: unitStr) {
                temperatureUnit = unit
            }
            awayModeEnabled = settings["awayModeEnabled"] as? Bool ?? false
            awayTemperature = settings["awayTemperature"] as? Double ?? 65.0
        }

        if let zonesData = UserDefaults.standard.data(forKey: storageKey + "_zones"),
           let saved = try? JSONDecoder().decode([ClimateZone].self, from: zonesData) {
            zones = saved
        }

        if let historyData = UserDefaults.standard.data(forKey: storageKey + "_history"),
           let saved = try? JSONDecoder().decode([ClimateHistoryEntry].self, from: historyData) {
            history = saved
        }
    }
}
