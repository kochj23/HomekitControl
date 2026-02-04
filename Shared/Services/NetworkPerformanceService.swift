//
//  NetworkPerformanceService.swift
//  HomekitControl
//
//  Monitor network performance and device connectivity
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Network
import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Models

struct DeviceNetworkStatus: Identifiable {
    let id: UUID
    let deviceId: UUID
    let deviceName: String
    var ipAddress: String?
    var signalStrength: Int? // dBm or percentage
    var latency: Double // milliseconds
    var isReachable: Bool
    var lastSeen: Date
    var connectionType: ConnectionType
    var packetLoss: Double // percentage

    enum ConnectionType: String {
        case wifi = "WiFi"
        case ethernet = "Ethernet"
        case thread = "Thread"
        case bluetooth = "Bluetooth"
        case unknown = "Unknown"
    }
}

struct NetworkIssue: Codable, Identifiable {
    let id: UUID
    let deviceId: UUID
    let deviceName: String
    let issueType: IssueType
    let severity: Severity
    let message: String
    let timestamp: Date
    var isResolved: Bool

    enum IssueType: String, Codable {
        case highLatency = "High Latency"
        case packetLoss = "Packet Loss"
        case unreachable = "Unreachable"
        case weakSignal = "Weak Signal"
        case frequentDisconnects = "Frequent Disconnects"
        case ipConflict = "IP Conflict"
    }

    enum Severity: String, Codable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"

        var color: Color {
            switch self {
            case .low: return .secondary
            case .medium: return ModernColors.yellow
            case .high: return ModernColors.orange
            case .critical: return ModernColors.red
            }
        }
    }
}

struct LatencyHistory: Codable, Identifiable {
    let id: UUID
    let deviceId: UUID
    let timestamp: Date
    let latency: Double
}

// MARK: - Network Performance Service

@MainActor
class NetworkPerformanceService: ObservableObject {
    static let shared = NetworkPerformanceService()

    // MARK: - Published Properties

    @Published var deviceStatuses: [DeviceNetworkStatus] = []
    @Published var issues: [NetworkIssue] = []
    @Published var latencyHistory: [LatencyHistory] = []
    @Published var isMonitoring = false
    @Published var networkHealth: Double = 100 // Percentage

    // Thresholds
    @Published var highLatencyThreshold: Double = 500 // ms
    @Published var weakSignalThreshold: Int = -70 // dBm
    @Published var packetLossThreshold: Double = 5 // percentage

    // MARK: - Private Properties

    private let storageKey = "HomekitControl_NetworkPerformance"
    private var monitoringTask: Task<Void, Never>?
    private let pingQueue = DispatchQueue(label: "com.homekitcontrol.ping", qos: .utility)

    // MARK: - Initialization

    private init() {
        loadData()
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        refreshStatuses()

        monitoringTask = Task {
            while !Task.isCancelled && isMonitoring {
                await refreshStatuses()
                await checkForIssues()
                try? await Task.sleep(nanoseconds: 30_000_000_000) // Every 30 seconds
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
    }

    func refreshStatuses() {
        #if canImport(HomeKit)
        var newStatuses: [DeviceNetworkStatus] = []

        for accessory in HomeKitService.shared.accessories {
            let status = DeviceNetworkStatus(
                id: UUID(),
                deviceId: accessory.uniqueIdentifier,
                deviceName: accessory.name,
                ipAddress: nil, // Would need mDNS lookup
                signalStrength: nil, // Not available via HomeKit
                latency: measureLatency(for: accessory),
                isReachable: accessory.isReachable,
                lastSeen: Date(),
                connectionType: .unknown,
                packetLoss: 0
            )
            newStatuses.append(status)

            // Log latency history
            let historyEntry = LatencyHistory(
                id: UUID(),
                deviceId: accessory.uniqueIdentifier,
                timestamp: Date(),
                latency: status.latency
            )
            latencyHistory.append(historyEntry)
        }

        deviceStatuses = newStatuses

        // Trim history (keep 24 hours)
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        latencyHistory.removeAll { $0.timestamp < cutoff }

        calculateNetworkHealth()
        saveData()
        #endif
    }

    #if canImport(HomeKit)
    private func measureLatency(for accessory: HMAccessory) -> Double {
        // Simulate latency measurement
        // In a real implementation, this would ping the device
        guard accessory.isReachable else { return Double.infinity }

        // Simulate reasonable latency values
        return Double.random(in: 10...200)
    }
    #endif

    // MARK: - Issue Detection

    private func checkForIssues() {
        var newIssues: [NetworkIssue] = []

        for status in deviceStatuses {
            // Check for high latency
            if status.latency > highLatencyThreshold && status.latency != Double.infinity {
                let issue = NetworkIssue(
                    id: UUID(),
                    deviceId: status.deviceId,
                    deviceName: status.deviceName,
                    issueType: .highLatency,
                    severity: status.latency > highLatencyThreshold * 2 ? .high : .medium,
                    message: "Response time: \(Int(status.latency))ms",
                    timestamp: Date(),
                    isResolved: false
                )
                newIssues.append(issue)
            }

            // Check for unreachable devices
            if !status.isReachable {
                let issue = NetworkIssue(
                    id: UUID(),
                    deviceId: status.deviceId,
                    deviceName: status.deviceName,
                    issueType: .unreachable,
                    severity: .critical,
                    message: "Device is not responding",
                    timestamp: Date(),
                    isResolved: false
                )
                newIssues.append(issue)
            }

            // Check for weak signal
            if let signal = status.signalStrength, signal < weakSignalThreshold {
                let issue = NetworkIssue(
                    id: UUID(),
                    deviceId: status.deviceId,
                    deviceName: status.deviceName,
                    issueType: .weakSignal,
                    severity: signal < weakSignalThreshold - 10 ? .high : .medium,
                    message: "Signal strength: \(signal) dBm",
                    timestamp: Date(),
                    isResolved: false
                )
                newIssues.append(issue)
            }

            // Check for packet loss
            if status.packetLoss > packetLossThreshold {
                let issue = NetworkIssue(
                    id: UUID(),
                    deviceId: status.deviceId,
                    deviceName: status.deviceName,
                    issueType: .packetLoss,
                    severity: status.packetLoss > packetLossThreshold * 2 ? .high : .medium,
                    message: "Packet loss: \(Int(status.packetLoss))%",
                    timestamp: Date(),
                    isResolved: false
                )
                newIssues.append(issue)
            }
        }

        // Mark old issues as resolved if no longer present
        for i in 0..<issues.count {
            if !newIssues.contains(where: { $0.deviceId == issues[i].deviceId && $0.issueType == issues[i].issueType }) {
                issues[i].isResolved = true
            }
        }

        // Add new issues
        for newIssue in newIssues {
            if !issues.contains(where: { $0.deviceId == newIssue.deviceId && $0.issueType == newIssue.issueType && !$0.isResolved }) {
                issues.append(newIssue)
            }
        }

        // Trim old resolved issues
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        issues.removeAll { $0.isResolved && $0.timestamp < cutoff }

        saveData()
    }

    private func calculateNetworkHealth() {
        guard !deviceStatuses.isEmpty else {
            networkHealth = 100
            return
        }

        var score: Double = 100

        // Deduct for unreachable devices
        let unreachableCount = deviceStatuses.filter { !$0.isReachable }.count
        score -= Double(unreachableCount) / Double(deviceStatuses.count) * 50

        // Deduct for high latency
        let highLatencyCount = deviceStatuses.filter { $0.latency > highLatencyThreshold }.count
        score -= Double(highLatencyCount) / Double(deviceStatuses.count) * 25

        // Deduct for active issues
        let activeIssueCount = issues.filter { !$0.isResolved }.count
        score -= Double(activeIssueCount) * 2

        networkHealth = max(0, min(100, score))
    }

    // MARK: - Analysis

    func getLatencyTrend(for deviceId: UUID) -> [Double] {
        let deviceHistory = latencyHistory.filter { $0.deviceId == deviceId }
            .sorted { $0.timestamp < $1.timestamp }
        return deviceHistory.map { $0.latency }
    }

    func getAverageLatency(for deviceId: UUID) -> Double {
        let deviceHistory = latencyHistory.filter { $0.deviceId == deviceId }
        guard !deviceHistory.isEmpty else { return 0 }
        return deviceHistory.map { $0.latency }.reduce(0, +) / Double(deviceHistory.count)
    }

    // MARK: - Computed Properties

    var reachableDevices: [DeviceNetworkStatus] {
        deviceStatuses.filter { $0.isReachable }
    }

    var unreachableDevices: [DeviceNetworkStatus] {
        deviceStatuses.filter { !$0.isReachable }
    }

    var activeIssues: [NetworkIssue] {
        issues.filter { !$0.isResolved }
    }

    var criticalIssues: [NetworkIssue] {
        activeIssues.filter { $0.severity == .critical }
    }

    var averageLatency: Double {
        let reachable = deviceStatuses.filter { $0.isReachable && $0.latency != Double.infinity }
        guard !reachable.isEmpty else { return 0 }
        return reachable.map { $0.latency }.reduce(0, +) / Double(reachable.count)
    }

    var worstPerformers: [DeviceNetworkStatus] {
        deviceStatuses
            .filter { $0.isReachable }
            .sorted { $0.latency > $1.latency }
            .prefix(5)
            .map { $0 }
    }

    var bestPerformers: [DeviceNetworkStatus] {
        deviceStatuses
            .filter { $0.isReachable }
            .sorted { $0.latency < $1.latency }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Persistence

    private func saveData() {
        let settings: [String: Any] = [
            "highLatencyThreshold": highLatencyThreshold,
            "weakSignalThreshold": weakSignalThreshold,
            "packetLossThreshold": packetLossThreshold
        ]

        if let encoded = try? JSONSerialization.data(withJSONObject: settings) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }

        if let issuesData = try? JSONEncoder().encode(issues) {
            UserDefaults.standard.set(issuesData, forKey: storageKey + "_issues")
        }

        if let historyData = try? JSONEncoder().encode(Array(latencyHistory.suffix(1000))) {
            UserDefaults.standard.set(historyData, forKey: storageKey + "_history")
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            highLatencyThreshold = settings["highLatencyThreshold"] as? Double ?? 500
            weakSignalThreshold = settings["weakSignalThreshold"] as? Int ?? -70
            packetLossThreshold = settings["packetLossThreshold"] as? Double ?? 5
        }

        if let issuesData = UserDefaults.standard.data(forKey: storageKey + "_issues"),
           let saved = try? JSONDecoder().decode([NetworkIssue].self, from: issuesData) {
            issues = saved
        }

        if let historyData = UserDefaults.standard.data(forKey: storageKey + "_history"),
           let saved = try? JSONDecoder().decode([LatencyHistory].self, from: historyData) {
            latencyHistory = saved
        }
    }
}
