//
//  DeviceHealthService.swift
//  HomekitControl
//
//  Service for monitoring and tracking device health
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation

#if canImport(HomeKit)
import HomeKit
#endif

/// Service for monitoring device health and reliability
@MainActor
final class DeviceHealthService: ObservableObject {
    static let shared = DeviceHealthService()

    // MARK: - Published Properties

    @Published var isTesting = false
    @Published var testResults: [UUID: DeviceTestResult] = [:]
    @Published var deviceHealth: [UUID: DeviceHealthRecord] = [:]
    @Published var statusMessage = ""

    // MARK: - Configuration

    var testInterval: TimeInterval = 30.0  // seconds between tests
    var maxHistoryCount = 100  // maximum test results to keep per device

    // MARK: - Private Properties

    private var testTask: Task<Void, Never>?

    // MARK: - Initialization

    private init() {
        loadHealthRecords()
    }

    // MARK: - Health Testing

    #if canImport(HomeKit) && !os(macOS)
    func testDevice(_ accessory: HMAccessory) async -> DeviceTestResult {
        let startTime = Date()
        var success = false
        var errorMessage: String?

        do {
            // Test by reading a characteristic
            if let service = accessory.services.first(where: { $0.serviceType == HMServiceTypeLightbulb || $0.serviceType == HMServiceTypeSwitch }),
               let characteristic = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypePowerState }) {

                try await characteristic.readValue()
                success = true
            } else if accessory.isReachable {
                success = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        let endTime = Date()
        let responseTime = endTime.timeIntervalSince(startTime) * 1000  // ms

        let result = DeviceTestResult(
            success: success,
            responseTimeMs: responseTime,
            errorMessage: errorMessage
        )

        // Update health record
        updateHealthRecord(for: accessory.uniqueIdentifier, with: result)

        return result
    }

    func testAllDevices(in home: HMHome) async {
        isTesting = true
        statusMessage = "Testing devices..."

        for accessory in home.accessories {
            statusMessage = "Testing \(accessory.name)..."
            let result = await testDevice(accessory)
            testResults[accessory.uniqueIdentifier] = result
        }

        isTesting = false
        statusMessage = "Testing complete"
        clearStatusMessage()
    }

    func startContinuousTesting(in home: HMHome) {
        stopContinuousTesting()

        testTask = Task {
            while !Task.isCancelled {
                await testAllDevices(in: home)
                try? await Task.sleep(nanoseconds: UInt64(testInterval * 1_000_000_000))
            }
        }
    }

    func stopContinuousTesting() {
        testTask?.cancel()
        testTask = nil
    }
    #endif

    // MARK: - Health Records

    private func updateHealthRecord(for deviceId: UUID, with result: DeviceTestResult) {
        var record = deviceHealth[deviceId] ?? DeviceHealthRecord(deviceId: deviceId)

        // Add to history
        record.testHistory.append(result)

        // Trim history if needed
        if record.testHistory.count > maxHistoryCount {
            record.testHistory.removeFirst(record.testHistory.count - maxHistoryCount)
        }

        // Calculate statistics
        record.recalculateStats()

        deviceHealth[deviceId] = record
        saveHealthRecords()
    }

    func getHealthStatus(for deviceId: UUID) -> HealthStatus {
        guard let record = deviceHealth[deviceId] else { return .unknown }

        if record.reliabilityScore >= 95 {
            return .healthy
        } else if record.reliabilityScore >= 70 {
            return .degraded
        } else {
            return .unreachable
        }
    }

    func getReliabilityScore(for deviceId: UUID) -> Double {
        deviceHealth[deviceId]?.reliabilityScore ?? 100.0
    }

    func getAverageResponseTime(for deviceId: UUID) -> Double? {
        deviceHealth[deviceId]?.averageResponseTime
    }

    // MARK: - Persistence

    private func saveHealthRecords() {
        if let data = try? JSONEncoder().encode(deviceHealth) {
            UserDefaults.standard.set(data, forKey: "deviceHealthRecords")
        }
    }

    private func loadHealthRecords() {
        if let data = UserDefaults.standard.data(forKey: "deviceHealthRecords"),
           let records = try? JSONDecoder().decode([UUID: DeviceHealthRecord].self, from: data) {
            deviceHealth = records
        }
    }

    func clearHealthRecords() {
        deviceHealth.removeAll()
        testResults.removeAll()
        saveHealthRecords()
    }

    // MARK: - Helpers

    private func clearStatusMessage() {
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            statusMessage = ""
        }
    }
}

// MARK: - Supporting Types

struct DeviceHealthRecord: Codable, Identifiable {
    var id: UUID { deviceId }
    let deviceId: UUID
    var testHistory: [DeviceTestResult] = []
    var reliabilityScore: Double = 100.0
    var averageResponseTime: Double?
    var lastTested: Date?

    mutating func recalculateStats() {
        guard !testHistory.isEmpty else { return }

        // Calculate reliability (percentage of successful tests)
        let successCount = testHistory.filter { $0.success }.count
        reliabilityScore = Double(successCount) / Double(testHistory.count) * 100.0

        // Calculate average response time (only for successful tests)
        let successfulTests = testHistory.filter { $0.success && $0.responseTimeMs != nil }
        if !successfulTests.isEmpty {
            let totalTime = successfulTests.compactMap { $0.responseTimeMs }.reduce(0, +)
            averageResponseTime = totalTime / Double(successfulTests.count)
        }

        lastTested = testHistory.last?.timestamp
    }
}
