//
//  DeviceComparisonService.swift
//  HomekitControl
//
//  Device comparison and analytics service
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import Combine
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Models

struct DeviceComparison: Identifiable {
    let id: UUID
    let devices: [ComparedDevice]
    let comparisonDate: Date
    let comparisonType: ComparisonType

    enum ComparisonType: String, CaseIterable {
        case energy = "Energy Usage"
        case reliability = "Reliability"
        case responsiveness = "Responsiveness"
        case cost = "Cost Efficiency"

        var icon: String {
            switch self {
            case .energy: return "bolt.fill"
            case .reliability: return "heart.fill"
            case .responsiveness: return "clock.fill"
            case .cost: return "dollarsign.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .energy: return ModernColors.yellow
            case .reliability: return ModernColors.accentGreen
            case .responsiveness: return ModernColors.cyan
            case .cost: return ModernColors.purple
            }
        }
    }

    init(devices: [ComparedDevice], comparisonType: ComparisonType) {
        self.id = UUID()
        self.devices = devices
        self.comparisonDate = Date()
        self.comparisonType = comparisonType
    }
}

struct ComparedDevice: Identifiable, Codable {
    let id: UUID
    let deviceId: String
    let name: String
    let category: String
    let manufacturer: String

    // Energy metrics
    var averagePowerWatts: Double
    var dailyEnergyKwh: Double
    var monthlyEnergyKwh: Double
    var estimatedMonthlyCost: Double

    // Reliability metrics
    var uptimePercentage: Double
    var failureCount: Int
    var lastFailureDate: Date?
    var meanTimeBetweenFailures: TimeInterval

    // Responsiveness metrics
    var averageResponseTimeMs: Double
    var minResponseTimeMs: Double
    var maxResponseTimeMs: Double
    var responseTimeConsistency: Double // 0-100

    // Comparison scores
    var energyScore: Double // 0-100, higher is better (more efficient)
    var reliabilityScore: Double // 0-100
    var responsivenessScore: Double // 0-100
    var overallScore: Double // 0-100

    init(deviceId: String, name: String, category: String, manufacturer: String) {
        self.id = UUID()
        self.deviceId = deviceId
        self.name = name
        self.category = category
        self.manufacturer = manufacturer

        // Initialize with default values
        self.averagePowerWatts = 0
        self.dailyEnergyKwh = 0
        self.monthlyEnergyKwh = 0
        self.estimatedMonthlyCost = 0

        self.uptimePercentage = 100
        self.failureCount = 0
        self.lastFailureDate = nil
        self.meanTimeBetweenFailures = 0

        self.averageResponseTimeMs = 0
        self.minResponseTimeMs = 0
        self.maxResponseTimeMs = 0
        self.responseTimeConsistency = 100

        self.energyScore = 50
        self.reliabilityScore = 50
        self.responsivenessScore = 50
        self.overallScore = 50
    }
}

struct ComparisonResult: Identifiable {
    let id: UUID
    let metric: String
    let winner: ComparedDevice?
    let values: [(device: ComparedDevice, value: Double)]
    let unit: String
    let higherIsBetter: Bool

    init(metric: String, values: [(device: ComparedDevice, value: Double)], unit: String, higherIsBetter: Bool) {
        self.id = UUID()
        self.metric = metric
        self.values = values
        self.unit = unit
        self.higherIsBetter = higherIsBetter

        // Determine winner
        if higherIsBetter {
            self.winner = values.max(by: { $0.value < $1.value })?.device
        } else {
            self.winner = values.min(by: { $0.value < $1.value })?.device
        }
    }
}

// MARK: - Service

class DeviceComparisonService: ObservableObject {
    static let shared = DeviceComparisonService()

    @Published var comparisons: [DeviceComparison] = []
    @Published var availableDevices: [ComparedDevice] = []
    @Published var selectedDevices: [ComparedDevice] = []
    @Published var currentComparison: DeviceComparison?
    @Published var isComparing = false

    private var energyRatePerKwh: Double = 0.12 // Default electricity rate

    private init() {
        loadData()
        Task { @MainActor in
            refreshAvailableDevices()
        }
    }

    // MARK: - Device Selection

    @MainActor
    func refreshAvailableDevices() {
        #if canImport(HomeKit)
        let homeKitService = HomeKitService.shared
        availableDevices = homeKitService.accessories.map { accessory in
            createComparedDevice(from: accessory)
        }
        #endif
    }

    #if canImport(HomeKit)
    private func createComparedDevice(from accessory: HMAccessory) -> ComparedDevice {
        var device = ComparedDevice(
            deviceId: accessory.uniqueIdentifier.uuidString,
            name: accessory.name,
            category: accessory.category.localizedDescription,
            manufacturer: accessory.manufacturer ?? "Unknown"
        )

        // Simulate metrics for demo
        device.averagePowerWatts = Double.random(in: 1...100)
        device.dailyEnergyKwh = device.averagePowerWatts * 24 / 1000
        device.monthlyEnergyKwh = device.dailyEnergyKwh * 30
        device.estimatedMonthlyCost = device.monthlyEnergyKwh * energyRatePerKwh

        device.uptimePercentage = Double.random(in: 90...100)
        device.failureCount = Int.random(in: 0...5)
        device.meanTimeBetweenFailures = Double.random(in: 100000...1000000)

        device.averageResponseTimeMs = Double.random(in: 50...500)
        device.minResponseTimeMs = device.averageResponseTimeMs * 0.5
        device.maxResponseTimeMs = device.averageResponseTimeMs * 2
        device.responseTimeConsistency = Double.random(in: 70...100)

        // Calculate scores
        device.energyScore = calculateEnergyScore(device)
        device.reliabilityScore = calculateReliabilityScore(device)
        device.responsivenessScore = calculateResponsivenessScore(device)
        device.overallScore = (device.energyScore + device.reliabilityScore + device.responsivenessScore) / 3

        return device
    }
    #endif

    func selectDevice(_ device: ComparedDevice) {
        guard selectedDevices.count < 4 else { return }
        guard !selectedDevices.contains(where: { $0.id == device.id }) else { return }
        selectedDevices.append(device)
    }

    func deselectDevice(_ device: ComparedDevice) {
        selectedDevices.removeAll { $0.id == device.id }
    }

    func clearSelection() {
        selectedDevices.removeAll()
    }

    // MARK: - Comparison

    func compare(type: DeviceComparison.ComparisonType) async {
        guard selectedDevices.count >= 2 else { return }

        await MainActor.run {
            isComparing = true
        }

        // Simulate analysis time
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        let comparison = DeviceComparison(
            devices: selectedDevices,
            comparisonType: type
        )

        await MainActor.run {
            currentComparison = comparison
            comparisons.insert(comparison, at: 0)
            isComparing = false
            saveData()
        }
    }

    func getComparisonResults(_ comparison: DeviceComparison) -> [ComparisonResult] {
        let devices = comparison.devices

        switch comparison.comparisonType {
        case .energy:
            return [
                ComparisonResult(
                    metric: "Average Power",
                    values: devices.map { ($0, $0.averagePowerWatts) },
                    unit: "W",
                    higherIsBetter: false
                ),
                ComparisonResult(
                    metric: "Monthly Energy",
                    values: devices.map { ($0, $0.monthlyEnergyKwh) },
                    unit: "kWh",
                    higherIsBetter: false
                ),
                ComparisonResult(
                    metric: "Monthly Cost",
                    values: devices.map { ($0, $0.estimatedMonthlyCost) },
                    unit: "$",
                    higherIsBetter: false
                ),
                ComparisonResult(
                    metric: "Energy Score",
                    values: devices.map { ($0, $0.energyScore) },
                    unit: "",
                    higherIsBetter: true
                )
            ]

        case .reliability:
            return [
                ComparisonResult(
                    metric: "Uptime",
                    values: devices.map { ($0, $0.uptimePercentage) },
                    unit: "%",
                    higherIsBetter: true
                ),
                ComparisonResult(
                    metric: "Failures",
                    values: devices.map { ($0, Double($0.failureCount)) },
                    unit: "",
                    higherIsBetter: false
                ),
                ComparisonResult(
                    metric: "Reliability Score",
                    values: devices.map { ($0, $0.reliabilityScore) },
                    unit: "",
                    higherIsBetter: true
                )
            ]

        case .responsiveness:
            return [
                ComparisonResult(
                    metric: "Avg Response",
                    values: devices.map { ($0, $0.averageResponseTimeMs) },
                    unit: "ms",
                    higherIsBetter: false
                ),
                ComparisonResult(
                    metric: "Consistency",
                    values: devices.map { ($0, $0.responseTimeConsistency) },
                    unit: "%",
                    higherIsBetter: true
                ),
                ComparisonResult(
                    metric: "Response Score",
                    values: devices.map { ($0, $0.responsivenessScore) },
                    unit: "",
                    higherIsBetter: true
                )
            ]

        case .cost:
            return [
                ComparisonResult(
                    metric: "Monthly Cost",
                    values: devices.map { ($0, $0.estimatedMonthlyCost) },
                    unit: "$",
                    higherIsBetter: false
                ),
                ComparisonResult(
                    metric: "Yearly Cost",
                    values: devices.map { ($0, $0.estimatedMonthlyCost * 12) },
                    unit: "$",
                    higherIsBetter: false
                ),
                ComparisonResult(
                    metric: "Overall Score",
                    values: devices.map { ($0, $0.overallScore) },
                    unit: "",
                    higherIsBetter: true
                )
            ]
        }
    }

    func getWinner(_ comparison: DeviceComparison) -> ComparedDevice? {
        switch comparison.comparisonType {
        case .energy:
            return comparison.devices.max(by: { $0.energyScore < $1.energyScore })
        case .reliability:
            return comparison.devices.max(by: { $0.reliabilityScore < $1.reliabilityScore })
        case .responsiveness:
            return comparison.devices.max(by: { $0.responsivenessScore < $1.responsivenessScore })
        case .cost:
            return comparison.devices.max(by: { $0.overallScore < $1.overallScore })
        }
    }

    // MARK: - Score Calculations

    private func calculateEnergyScore(_ device: ComparedDevice) -> Double {
        // Lower power usage = higher score
        let maxPower: Double = 200.0
        let score = max(0, 100 - (device.averagePowerWatts / maxPower * 100))
        return min(100, score)
    }

    private func calculateReliabilityScore(_ device: ComparedDevice) -> Double {
        // Higher uptime and fewer failures = higher score
        let uptimeWeight = device.uptimePercentage * 0.7
        let failurePenalty = min(30, Double(device.failureCount) * 5)
        return max(0, min(100, uptimeWeight + 30 - failurePenalty))
    }

    private func calculateResponsivenessScore(_ device: ComparedDevice) -> Double {
        // Lower response time = higher score
        let maxResponse: Double = 1000.0
        let responseScore = max(0, 100 - (device.averageResponseTimeMs / maxResponse * 100))
        let consistencyBonus = device.responseTimeConsistency * 0.2
        return min(100, responseScore * 0.8 + consistencyBonus)
    }

    // MARK: - Recommendations

    func getRecommendation(for comparison: DeviceComparison) -> String {
        guard let winner = getWinner(comparison) else { return "No clear winner" }

        let secondBest = comparison.devices
            .filter { $0.id != winner.id }
            .max(by: { getScore($0, for: comparison.comparisonType) < getScore($1, for: comparison.comparisonType) })

        let scoreDiff = secondBest.map { getScore(winner, for: comparison.comparisonType) - getScore($0, for: comparison.comparisonType) } ?? 0

        if scoreDiff > 20 {
            return "\(winner.name) significantly outperforms other devices in \(comparison.comparisonType.rawValue.lowercased())."
        } else if scoreDiff > 10 {
            return "\(winner.name) is the better choice for \(comparison.comparisonType.rawValue.lowercased())."
        } else {
            return "All devices perform similarly. Consider other factors."
        }
    }

    private func getScore(_ device: ComparedDevice, for type: DeviceComparison.ComparisonType) -> Double {
        switch type {
        case .energy: return device.energyScore
        case .reliability: return device.reliabilityScore
        case .responsiveness: return device.responsivenessScore
        case .cost: return device.overallScore
        }
    }

    // MARK: - Settings

    @MainActor
    func setEnergyRate(_ rate: Double) {
        energyRatePerKwh = rate
        refreshAvailableDevices()
    }

    // MARK: - Persistence

    private func loadData() {
        // Load saved comparisons if needed
    }

    private func saveData() {
        // Save comparisons if needed
    }
}
