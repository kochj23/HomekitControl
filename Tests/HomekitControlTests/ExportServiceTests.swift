//
//  ExportServiceTests.swift
//  HomekitControlTests
//
//  Tests for ExportService — CSV escaping, JSON export, and data integrity.
//  Export errors can corrupt backup data or produce invalid files that
//  cannot be re-imported.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

@MainActor
final class ExportServiceTests: XCTestCase {

    let service = ExportService.shared

    // MARK: - Device JSON Export

    func test_exportDevicesAsJSON_empty() {
        let data = service.exportDevicesAsJSON([])
        XCTAssertNotNil(data)
        if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            XCTAssertTrue(json.isEmpty)
        }
    }

    func test_exportDevicesAsJSON_singleDevice() {
        let device = UnifiedDevice(
            name: "Kitchen Light",
            room: "Kitchen",
            manufacturer: .philipsHue,
            category: .light
        )
        let data = service.exportDevicesAsJSON([device])
        XCTAssertNotNil(data)

        if let data = data {
            let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            XCTAssertEqual(json?.count, 1)
            XCTAssertEqual(json?.first?["name"] as? String, "Kitchen Light")
        }
    }

    func test_exportDevicesAsJSON_multipleDevices() {
        let devices = [
            UnifiedDevice(name: "Light 1"),
            UnifiedDevice(name: "Light 2"),
            UnifiedDevice(name: "Light 3")
        ]
        let data = service.exportDevicesAsJSON(devices)
        XCTAssertNotNil(data)

        if let data = data {
            let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            XCTAssertEqual(json?.count, 3)
        }
    }

    // MARK: - Device CSV Export

    func test_exportDevicesAsCSV_hasHeader() {
        let csv = service.exportDevicesAsCSV([])
        XCTAssertTrue(csv.hasPrefix("Name,Room,Home,Manufacturer,Category,Protocol,Health,Reliability,IP Address,MAC Address,Last Seen"))
    }

    func test_exportDevicesAsCSV_singleDevice() {
        let device = UnifiedDevice(
            name: "Test Light",
            room: "Living Room",
            manufacturer: .philipsHue,
            category: .light,
            protocolType: .wifi,
            healthStatus: .healthy,
            reliabilityScore: 99.5
        )
        let csv = service.exportDevicesAsCSV([device])
        let lines = csv.components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 3) // header + 1 row + empty trailing
        XCTAssertTrue(lines[1].contains("Test Light"))
        XCTAssertTrue(lines[1].contains("Living Room"))
        XCTAssertTrue(lines[1].contains("Philips Hue"))
        XCTAssertTrue(lines[1].contains("Wi-Fi"))
    }

    func test_exportDevicesAsCSV_escapesCommasInNames() {
        let device = UnifiedDevice(
            name: "Living Room, Main Light",
            room: "Living Room"
        )
        let csv = service.exportDevicesAsCSV([device])
        // Name with comma should be quoted
        XCTAssertTrue(csv.contains("\"Living Room, Main Light\""))
    }

    func test_exportDevicesAsCSV_escapesQuotesInNames() {
        let device = UnifiedDevice(
            name: "The \"Smart\" Light",
            room: "Room"
        )
        let csv = service.exportDevicesAsCSV([device])
        // Quotes should be doubled and field should be quoted
        XCTAssertTrue(csv.contains("\"The \"\"Smart\"\" Light\""))
    }

    // MARK: - Scene CSV Export

    func test_exportScenesAsCSV_hasHeader() {
        let csv = service.exportScenesAsCSV([])
        XCTAssertTrue(csv.hasPrefix("Name,Home,Room,Accessory Count,Action Count,Health,Has Unreachable,Unreachable Devices,Last Executed"))
    }

    func test_exportScenesAsCSV_singleScene() {
        let scene = UnifiedScene(
            name: "Good Morning",
            home: "My Home",
            accessoryCount: 5,
            actionCount: 10,
            healthStatus: .healthy
        )
        let csv = service.exportScenesAsCSV([scene])
        let lines = csv.components(separatedBy: "\n")

        XCTAssertTrue(lines[1].contains("Good Morning"))
        XCTAssertTrue(lines[1].contains("My Home"))
        XCTAssertTrue(lines[1].contains("5"))
        XCTAssertTrue(lines[1].contains("10"))
    }

    func test_exportScenesAsCSV_unreachableDevices() {
        let scene = UnifiedScene(
            name: "Scene",
            hasUnreachableDevices: true,
            unreachableDeviceNames: ["Light 1", "Fan"]
        )
        let csv = service.exportScenesAsCSV([scene])
        XCTAssertTrue(csv.contains("Yes"))
        XCTAssertTrue(csv.contains("Light 1; Fan"))
    }

    // MARK: - Setup Codes CSV Export

    func test_exportSetupCodesAsCSV_hasHeader() {
        let csv = service.exportSetupCodesAsCSV([])
        XCTAssertTrue(csv.hasPrefix("Device Name,Code,Manufacturer,Category,Room,Serial Number,Model,Notes,Created"))
    }

    func test_exportSetupCodesAsCSV_formatsCode() {
        let code = SetupCode(
            deviceName: "Lock",
            code: "12345678",
            manufacturer: .schlage,
            category: .lock,
            room: "Front Door"
        )
        let csv = service.exportSetupCodesAsCSV([code])
        // Should contain formatted code 123-45-678
        XCTAssertTrue(csv.contains("123-45-678"))
    }

    // MARK: - Discovered Devices CSV Export

    func test_exportDiscoveredDevicesAsCSV_hasHeader() {
        let csv = service.exportDiscoveredDevicesAsCSV([])
        XCTAssertTrue(csv.contains("Name,IP Address,MAC Address"))
    }

    func test_exportDiscoveredDevicesAsCSV_formatsConfidence() {
        let device = DiscoveredDevice(
            name: "Device",
            matchConfidence: 0.85
        )
        let csv = service.exportDiscoveredDevicesAsCSV([device])
        XCTAssertTrue(csv.contains("85%"))
    }

    func test_exportDiscoveredDevicesAsCSV_formatsPorts() {
        let device = DiscoveredDevice(
            name: "Device",
            openPorts: [80, 443, 8080]
        )
        let csv = service.exportDiscoveredDevicesAsCSV([device])
        XCTAssertTrue(csv.contains("80;443;8080"))
    }

    // MARK: - Scene JSON Export

    func test_exportScenesAsJSON_roundtrip() throws {
        let scenes = [
            UnifiedScene(name: "Morning", accessoryCount: 3, healthStatus: .healthy),
            UnifiedScene(name: "Night", accessoryCount: 5, healthStatus: .degraded)
        ]

        guard let data = service.exportScenesAsJSON(scenes) else {
            XCTFail("Export returned nil")
            return
        }

        let decoded = try JSONDecoder().decode([UnifiedScene].self, from: data)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].name, "Morning")
        XCTAssertEqual(decoded[1].name, "Night")
    }

    // MARK: - ExportFormat

    func test_exportFormat_fileExtensions() {
        XCTAssertEqual(ExportFormat.json.fileExtension, "json")
        XCTAssertEqual(ExportFormat.csv.fileExtension, "csv")
    }

    func test_exportFormat_mimeTypes() {
        XCTAssertEqual(ExportFormat.json.mimeType, "application/json")
        XCTAssertEqual(ExportFormat.csv.mimeType, "text/csv")
    }
}
