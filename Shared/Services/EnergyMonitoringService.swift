//
//  EnergyMonitoringService.swift
//  HomekitControl
//
//  Energy consumption tracking and analysis
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Energy Models

struct EnergyReading: Codable, Identifiable {
    let id: UUID
    let deviceId: UUID
    let timestamp: Date
    let watts: Double
    let voltage: Double?
    let amperage: Double?

    init(deviceId: UUID, watts: Double, voltage: Double? = nil, amperage: Double? = nil) {
        self.id = UUID()
        self.deviceId = deviceId
        self.timestamp = Date()
        self.watts = watts
        self.voltage = voltage
        self.amperage = amperage
    }
}

struct DailyEnergyUsage: Codable, Identifiable {
    let id: UUID
    let date: Date
    let deviceId: UUID?
    let totalKWh: Double
    let peakWatts: Double
    let averageWatts: Double
    let cost: Double

    init(date: Date, deviceId: UUID? = nil, totalKWh: Double, peakWatts: Double, averageWatts: Double, cost: Double) {
        self.id = UUID()
        self.date = date
        self.deviceId = deviceId
        self.totalKWh = totalKWh
        self.peakWatts = peakWatts
        self.averageWatts = averageWatts
        self.cost = cost
    }
}

struct DevicePowerUsage: Codable, Identifiable {
    let id: UUID
    let deviceId: UUID
    let deviceName: String
    let currentWatts: Double
    let todayKWh: Double
    let estimatedMonthlyCost: Double

    init(deviceId: UUID, deviceName: String, currentWatts: Double, todayKWh: Double, utilityRate: Double) {
        self.id = UUID()
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.currentWatts = currentWatts
        self.todayKWh = todayKWh
        self.estimatedMonthlyCost = todayKWh * 30 * utilityRate
    }
}

struct EnergyAlert: Codable, Identifiable {
    let id: UUID
    let deviceId: UUID?
    let alertType: AlertType
    let message: String
    let timestamp: Date
    var isRead: Bool

    enum AlertType: String, Codable {
        case highUsage = "High Usage"
        case unusualPattern = "Unusual Pattern"
        case deviceAlwaysOn = "Always On"
        case costThreshold = "Cost Threshold"
    }

    init(deviceId: UUID? = nil, alertType: AlertType, message: String) {
        self.id = UUID()
        self.deviceId = deviceId
        self.alertType = alertType
        self.message = message
        self.timestamp = Date()
        self.isRead = false
    }
}

// MARK: - Energy Monitoring Service

@MainActor
class EnergyMonitoringService: ObservableObject {
    static let shared = EnergyMonitoringService()

    @Published var readings: [EnergyReading] = []
    @Published var dailyUsage: [DailyEnergyUsage] = []
    @Published var alerts: [EnergyAlert] = []
    @Published var isMonitoring = false

    // Settings
    @Published var utilityRate: Double = 0.12 // $ per kWh
    @Published var highUsageThreshold: Double = 500 // watts
    @Published var monthlyBudget: Double = 100 // dollars

    private let storageKey = "HomekitControl_EnergyData"
    private var monitoringTask: Task<Void, Never>?

    private init() {
        loadData()
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        monitoringTask = Task {
            while !Task.isCancelled && isMonitoring {
                await collectReadings()
                try? await Task.sleep(nanoseconds: 60_000_000_000) // Every minute
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
    }

    private func collectReadings() async {
        #if canImport(HomeKit)
        for accessory in HomeKitService.shared.accessories {
            // Check for power monitoring characteristics
            for service in accessory.services {
                for characteristic in service.characteristics {
                    // Check for power-related characteristics
                    // Note: Power consumption monitoring requires devices that support energy monitoring
                    if characteristic.characteristicType == HMCharacteristicTypePowerState {
                        // For power state, estimate watts based on device type
                        if let isOn = characteristic.value as? Bool, isOn {
                            let estimatedWatts = estimatePowerUsage(for: accessory)
                            let reading = EnergyReading(
                                deviceId: accessory.uniqueIdentifier,
                                watts: estimatedWatts
                            )
                            readings.append(reading)
                            checkForAlerts(reading: reading, deviceName: accessory.name)
                        }
                    }
                }
            }
        }

        // Trim old readings (keep 7 days)
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        readings.removeAll { $0.timestamp < cutoff }

        saveData()
        #endif
    }

    #if canImport(HomeKit)
    private func estimatePowerUsage(for accessory: HMAccessory) -> Double {
        // Estimate power usage based on device type
        if accessory.services.contains(where: { $0.serviceType == HMServiceTypeLightbulb }) {
            return 10.0 // LED bulb average
        } else if accessory.services.contains(where: { $0.serviceType == HMServiceTypeSwitch }) {
            return 5.0 // Smart switch standby
        } else if accessory.services.contains(where: { $0.serviceType == HMServiceTypeOutlet }) {
            return 50.0 // Outlet with typical load
        }
        return 5.0 // Default standby
    }
    #endif

    private func checkForAlerts(reading: EnergyReading, deviceName: String) {
        if reading.watts > highUsageThreshold {
            let alert = EnergyAlert(
                deviceId: reading.deviceId,
                alertType: .highUsage,
                message: "\(deviceName) is using \(Int(reading.watts))W"
            )
            alerts.append(alert)
        }
    }

    // MARK: - Computed Properties

    var currentTotalPower: Double {
        let recentCutoff = Date().addingTimeInterval(-60) // Last minute
        let recentReadings = readings.filter { $0.timestamp >= recentCutoff }
        return recentReadings.reduce(0.0) { $0 + $1.watts }
    }

    var todayUsage: Double {
        getTodayUsage()
    }

    var estimatedMonthlyCost: Double {
        let dailyUsage = getTodayUsage()
        return dailyUsage * 30 * utilityRate
    }

    var weeklyUsage: [DailyEnergyUsage] {
        getWeekUsage()
    }

    var topConsumers: [DevicePowerUsage] {
        getTopConsumers()
    }

    // MARK: - Analysis

    func getTodayUsage() -> Double {
        let today = Calendar.current.startOfDay(for: Date())
        let todayReadings = readings.filter { $0.timestamp >= today }

        guard !todayReadings.isEmpty else { return 0 }

        // Calculate kWh from readings
        let totalWattMinutes = todayReadings.reduce(0.0) { $0 + $1.watts }
        let averageWatts = totalWattMinutes / Double(todayReadings.count)
        let hours = Double(todayReadings.count) / 60.0
        return (averageWatts * hours) / 1000.0
    }

    func getWeekUsage() -> [DailyEnergyUsage] {
        var weekUsage: [DailyEnergyUsage] = []
        let calendar = Calendar.current

        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { continue }

            let dayReadings = readings.filter { $0.timestamp >= startOfDay && $0.timestamp < endOfDay }

            if !dayReadings.isEmpty {
                let totalWatts = dayReadings.reduce(0.0) { $0 + $1.watts }
                let avgWatts = totalWatts / Double(dayReadings.count)
                let peakWatts = dayReadings.map { $0.watts }.max() ?? 0
                let hours = Double(dayReadings.count) / 60.0
                let kWh = (avgWatts * hours) / 1000.0
                let cost = kWh * utilityRate

                weekUsage.append(DailyEnergyUsage(
                    date: startOfDay,
                    deviceId: nil,
                    totalKWh: kWh,
                    peakWatts: peakWatts,
                    averageWatts: avgWatts,
                    cost: cost
                ))
            }
        }

        return weekUsage.reversed()
    }

    func getMonthCost() -> Double {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) else {
            return 0
        }

        let monthReadings = readings.filter { $0.timestamp >= startOfMonth }
        guard !monthReadings.isEmpty else { return 0 }

        let totalWatts = monthReadings.reduce(0.0) { $0 + $1.watts }
        let avgWatts = totalWatts / Double(monthReadings.count)
        let hours = Double(monthReadings.count) / 60.0
        let kWh = (avgWatts * hours) / 1000.0

        return kWh * utilityRate
    }

    func getDeviceUsage(deviceId: UUID) -> Double {
        let deviceReadings = readings.filter { $0.deviceId == deviceId }
        guard !deviceReadings.isEmpty else { return 0 }

        let totalWatts = deviceReadings.reduce(0.0) { $0 + $1.watts }
        return totalWatts / Double(deviceReadings.count)
    }

    func getTopConsumers() -> [DevicePowerUsage] {
        var deviceUsages: [UUID: (watts: Double, count: Int, name: String)] = [:]

        #if canImport(HomeKit)
        // Group readings by device
        for reading in readings {
            if let existing = deviceUsages[reading.deviceId] {
                deviceUsages[reading.deviceId] = (existing.watts + reading.watts, existing.count + 1, existing.name)
            } else {
                let name = HomeKitService.shared.accessories.first { $0.uniqueIdentifier == reading.deviceId }?.name ?? "Unknown"
                deviceUsages[reading.deviceId] = (reading.watts, 1, name)
            }
        }
        #endif

        return deviceUsages.map { (deviceId, data) -> DevicePowerUsage in
            let avgWatts = data.watts / Double(data.count)
            let hours = Double(data.count) / 60.0
            let kWh = (avgWatts * hours) / 1000.0
            return DevicePowerUsage(
                deviceId: deviceId,
                deviceName: data.name,
                currentWatts: avgWatts,
                todayKWh: kWh,
                utilityRate: utilityRate
            )
        }
        .sorted { $0.currentWatts > $1.currentWatts }
    }

    // MARK: - Persistence

    private func saveData() {
        let data: [String: Any] = [
            "utilityRate": utilityRate,
            "highUsageThreshold": highUsageThreshold,
            "monthlyBudget": monthlyBudget
        ]

        if let encoded = try? JSONSerialization.data(withJSONObject: data) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }

        if let readingsData = try? JSONEncoder().encode(readings) {
            UserDefaults.standard.set(readingsData, forKey: storageKey + "_readings")
        }

        if let alertsData = try? JSONEncoder().encode(alerts) {
            UserDefaults.standard.set(alertsData, forKey: storageKey + "_alerts")
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            utilityRate = dict["utilityRate"] as? Double ?? 0.12
            highUsageThreshold = dict["highUsageThreshold"] as? Double ?? 500
            monthlyBudget = dict["monthlyBudget"] as? Double ?? 100
        }

        if let readingsData = UserDefaults.standard.data(forKey: storageKey + "_readings"),
           let saved = try? JSONDecoder().decode([EnergyReading].self, from: readingsData) {
            readings = saved
        }

        if let alertsData = UserDefaults.standard.data(forKey: storageKey + "_alerts"),
           let saved = try? JSONDecoder().decode([EnergyAlert].self, from: alertsData) {
            alerts = saved
        }
    }
}
