//
//  DiscoveredDevice.swift
//  HomekitControl
//
//  Model for devices discovered via network scanning
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// A device discovered via network scanning (Bonjour, port scan, ARP)
struct DiscoveredDevice: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var ipAddress: String?
    var macAddress: String?
    var hostname: String?

    // MARK: - Discovery Source

    var discoverySource: DiscoverySource
    var serviceType: String?
    var txtRecords: [String: String]

    // MARK: - Device Info

    var manufacturer: Manufacturer
    var deviceType: DeviceCategory
    var protocolType: DeviceProtocol
    var model: String?
    var firmwareVersion: String?

    // MARK: - Port Info

    var openPorts: [Int]
    var serviceNames: [String]

    // MARK: - Matching

    var homeKitMatch: Bool
    var matchConfidence: Double
    var matchedAccessoryName: String?

    // MARK: - Timestamps

    var discoveredAt: Date
    var lastSeen: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        ipAddress: String? = nil,
        macAddress: String? = nil,
        hostname: String? = nil,
        discoverySource: DiscoverySource = .bonjour,
        serviceType: String? = nil,
        txtRecords: [String: String] = [:],
        manufacturer: Manufacturer = .unknown,
        deviceType: DeviceCategory = .other,
        protocolType: DeviceProtocol = .unknown,
        model: String? = nil,
        firmwareVersion: String? = nil,
        openPorts: [Int] = [],
        serviceNames: [String] = [],
        homeKitMatch: Bool = false,
        matchConfidence: Double = 0.0,
        matchedAccessoryName: String? = nil,
        discoveredAt: Date = Date(),
        lastSeen: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.ipAddress = ipAddress
        self.macAddress = macAddress
        self.hostname = hostname
        self.discoverySource = discoverySource
        self.serviceType = serviceType
        self.txtRecords = txtRecords
        self.manufacturer = manufacturer
        self.deviceType = deviceType
        self.protocolType = protocolType
        self.model = model
        self.firmwareVersion = firmwareVersion
        self.openPorts = openPorts
        self.serviceNames = serviceNames
        self.homeKitMatch = homeKitMatch
        self.matchConfidence = matchConfidence
        self.matchedAccessoryName = matchedAccessoryName
        self.discoveredAt = discoveredAt
        self.lastSeen = lastSeen
    }
}

// MARK: - Discovery Source

enum DiscoverySource: String, Codable, CaseIterable, Hashable {
    case bonjour = "Bonjour"
    case portScan = "Port Scan"
    case arpScan = "ARP Scan"
    case manual = "Manual"

    var icon: String {
        switch self {
        case .bonjour: return "antenna.radiowaves.left.and.right"
        case .portScan: return "network"
        case .arpScan: return "tablecells"
        case .manual: return "hand.raised"
        }
    }
}
