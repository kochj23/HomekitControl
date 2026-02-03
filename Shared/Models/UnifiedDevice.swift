//
//  UnifiedDevice.swift
//  HomekitControl
//
//  Unified device model combining all project device models
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Unified device model that works across all platforms
struct UnifiedDevice: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var room: String?
    var home: String?

    // MARK: - Identity

    var homeKitUUID: UUID?
    var manufacturer: Manufacturer
    var model: String?
    var firmwareVersion: String?
    var serialNumber: String?
    var category: DeviceCategory

    // MARK: - Network Info (from HomeKitAdopter/Restore)

    var ipAddress: String?
    var macAddress: String?
    var protocolType: DeviceProtocol

    // MARK: - Health Tracking (from SceneFixer)

    var healthStatus: HealthStatus
    var isReachable: Bool
    var reliabilityScore: Double
    var lastSeen: Date?
    var averageResponseTime: Double?
    var testHistory: [DeviceTestResult]

    // MARK: - Scene Membership (from SceneFixer)

    var sceneCount: Int
    var sceneNames: [String]

    // MARK: - Setup Code (from HomeKitRestore) - iOS/macOS only

    var setupCode: String?
    var setupCodePhotoPath: String?

    // MARK: - Additional Info

    var hubName: String?
    var notes: String?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        room: String? = nil,
        home: String? = nil,
        homeKitUUID: UUID? = nil,
        manufacturer: Manufacturer = .unknown,
        model: String? = nil,
        firmwareVersion: String? = nil,
        serialNumber: String? = nil,
        category: DeviceCategory = .other,
        ipAddress: String? = nil,
        macAddress: String? = nil,
        protocolType: DeviceProtocol = .unknown,
        healthStatus: HealthStatus = .unknown,
        isReachable: Bool = true,
        reliabilityScore: Double = 100.0,
        lastSeen: Date? = nil,
        averageResponseTime: Double? = nil,
        testHistory: [DeviceTestResult] = [],
        sceneCount: Int = 0,
        sceneNames: [String] = [],
        setupCode: String? = nil,
        setupCodePhotoPath: String? = nil,
        hubName: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.room = room
        self.home = home
        self.homeKitUUID = homeKitUUID
        self.manufacturer = manufacturer
        self.model = model
        self.firmwareVersion = firmwareVersion
        self.serialNumber = serialNumber
        self.category = category
        self.ipAddress = ipAddress
        self.macAddress = macAddress
        self.protocolType = protocolType
        self.healthStatus = healthStatus
        self.isReachable = isReachable
        self.reliabilityScore = reliabilityScore
        self.lastSeen = lastSeen
        self.averageResponseTime = averageResponseTime
        self.testHistory = testHistory
        self.sceneCount = sceneCount
        self.sceneNames = sceneNames
        self.setupCode = setupCode
        self.setupCodePhotoPath = setupCodePhotoPath
        self.hubName = hubName
        self.notes = notes
    }
}

// MARK: - Device Test Result

struct DeviceTestResult: Codable, Hashable, Identifiable {
    let id: UUID
    let timestamp: Date
    let success: Bool
    let responseTimeMs: Double?
    let errorMessage: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        success: Bool,
        responseTimeMs: Double? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.success = success
        self.responseTimeMs = responseTimeMs
        self.errorMessage = errorMessage
    }
}
