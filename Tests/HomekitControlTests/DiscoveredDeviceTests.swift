//
//  DiscoveredDeviceTests.swift
//  HomekitControlTests
//
//  Tests for DiscoveredDevice model and DiscoverySource enum.
//  Network device discovery models must serialize correctly to avoid
//  losing scan results or misidentifying devices on the network.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

final class DiscoveredDeviceTests: XCTestCase {

    // MARK: - Initialization

    func test_init_defaults() {
        let device = DiscoveredDevice(name: "Unknown Device")

        XCTAssertEqual(device.name, "Unknown Device")
        XCTAssertNil(device.ipAddress)
        XCTAssertNil(device.macAddress)
        XCTAssertNil(device.hostname)
        XCTAssertEqual(device.discoverySource, .bonjour)
        XCTAssertNil(device.serviceType)
        XCTAssertTrue(device.txtRecords.isEmpty)
        XCTAssertEqual(device.manufacturer, .unknown)
        XCTAssertEqual(device.deviceType, .other)
        XCTAssertEqual(device.protocolType, .unknown)
        XCTAssertNil(device.model)
        XCTAssertNil(device.firmwareVersion)
        XCTAssertTrue(device.openPorts.isEmpty)
        XCTAssertTrue(device.serviceNames.isEmpty)
        XCTAssertFalse(device.homeKitMatch)
        XCTAssertEqual(device.matchConfidence, 0.0)
        XCTAssertNil(device.matchedAccessoryName)
    }

    func test_init_fullDevice() {
        let device = DiscoveredDevice(
            name: "Hue Bridge",
            ipAddress: "192.168.1.2",
            macAddress: "00:17:88:01:02:03",
            hostname: "philips-hue",
            discoverySource: .bonjour,
            serviceType: "_hue._tcp",
            txtRecords: ["modelid": "BSB002", "bridgeid": "001788FFFE010203"],
            manufacturer: .philipsHue,
            deviceType: .bridge,
            protocolType: .wifi,
            model: "BSB002",
            firmwareVersion: "1947054050",
            openPorts: [80, 443, 8080],
            serviceNames: ["Philips Hue Bridge"],
            homeKitMatch: true,
            matchConfidence: 0.95,
            matchedAccessoryName: "Hue Bridge"
        )

        XCTAssertEqual(device.name, "Hue Bridge")
        XCTAssertEqual(device.ipAddress, "192.168.1.2")
        XCTAssertEqual(device.macAddress, "00:17:88:01:02:03")
        XCTAssertEqual(device.manufacturer, .philipsHue)
        XCTAssertEqual(device.deviceType, .bridge)
        XCTAssertEqual(device.openPorts, [80, 443, 8080])
        XCTAssertTrue(device.homeKitMatch)
        XCTAssertEqual(device.matchConfidence, 0.95)
        XCTAssertEqual(device.txtRecords["modelid"], "BSB002")
    }

    // MARK: - Codable Roundtrip

    func test_codableRoundtrip() throws {
        let original = DiscoveredDevice(
            name: "Smart Plug",
            ipAddress: "10.0.0.100",
            discoverySource: .portScan,
            manufacturer: .meross,
            deviceType: .outlet,
            protocolType: .wifi,
            openPorts: [80],
            homeKitMatch: false,
            matchConfidence: 0.3
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DiscoveredDevice.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.ipAddress, original.ipAddress)
        XCTAssertEqual(decoded.discoverySource, .portScan)
        XCTAssertEqual(decoded.manufacturer, .meross)
        XCTAssertEqual(decoded.openPorts, [80])
        XCTAssertEqual(decoded.matchConfidence, 0.3)
    }

    func test_codableRoundtrip_withTxtRecords() throws {
        let original = DiscoveredDevice(
            name: "HAP Device",
            txtRecords: ["md": "MyDevice", "ci": "2", "sf": "1"]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DiscoveredDevice.self, from: data)

        XCTAssertEqual(decoded.txtRecords.count, 3)
        XCTAssertEqual(decoded.txtRecords["md"], "MyDevice")
    }

    // MARK: - Match Confidence Bounds

    func test_matchConfidence_zero() {
        let device = DiscoveredDevice(name: "Unknown", matchConfidence: 0.0)
        XCTAssertEqual(device.matchConfidence, 0.0)
    }

    func test_matchConfidence_one() {
        let device = DiscoveredDevice(name: "Exact Match", matchConfidence: 1.0)
        XCTAssertEqual(device.matchConfidence, 1.0)
    }
}

// MARK: - DiscoverySource Tests

final class DiscoverySourceTests: XCTestCase {

    func test_allSources_haveIcons() {
        for source in DiscoverySource.allCases {
            XCTAssertFalse(source.icon.isEmpty, "\(source) has no icon")
        }
    }

    func test_allSources_haveRawValues() {
        XCTAssertEqual(DiscoverySource.bonjour.rawValue, "Bonjour")
        XCTAssertEqual(DiscoverySource.portScan.rawValue, "Port Scan")
        XCTAssertEqual(DiscoverySource.arpScan.rawValue, "ARP Scan")
        XCTAssertEqual(DiscoverySource.manual.rawValue, "Manual")
    }

    func test_codableRoundtrip() throws {
        for source in DiscoverySource.allCases {
            let data = try JSONEncoder().encode(source)
            let decoded = try JSONDecoder().decode(DiscoverySource.self, from: data)
            XCTAssertEqual(decoded, source)
        }
    }

    func test_caseCount() {
        XCTAssertEqual(DiscoverySource.allCases.count, 4)
    }
}
