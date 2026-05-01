//
//  DeviceGroupModelTests.swift
//  HomekitControlTests
//
//  Tests for DeviceGroup and Zone models.
//  Group control sends commands to multiple devices at once —
//  a corrupted group could control the wrong devices.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

final class DeviceGroupModelTests: XCTestCase {

    // MARK: - DeviceGroup

    func test_group_init_defaults() {
        let group = DeviceGroup(name: "All Lights")
        XCTAssertEqual(group.name, "All Lights")
        XCTAssertEqual(group.icon, "rectangle.3.group.fill")
        XCTAssertEqual(group.color, "cyan")
        XCTAssertTrue(group.deviceIds.isEmpty)
        XCTAssertTrue(group.isEnabled)
    }

    func test_group_deviceCount() {
        var group = DeviceGroup(name: "Test")
        XCTAssertEqual(group.deviceCount, 0)

        group.deviceIds = [UUID(), UUID(), UUID()]
        XCTAssertEqual(group.deviceCount, 3)
    }

    func test_group_codable() throws {
        var original = DeviceGroup(name: "Bedroom", icon: "bed.double.fill", color: "purple")
        original.deviceIds = [UUID(), UUID()]
        original.isEnabled = false

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DeviceGroup.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, "Bedroom")
        XCTAssertEqual(decoded.icon, "bed.double.fill")
        XCTAssertEqual(decoded.color, "purple")
        XCTAssertEqual(decoded.deviceIds.count, 2)
        XCTAssertFalse(decoded.isEnabled)
    }

    // MARK: - Zone

    func test_zone_init() {
        let zone = Zone(name: "Upstairs")
        XCTAssertEqual(zone.name, "Upstairs")
        XCTAssertEqual(zone.icon, "building.2.fill")
        XCTAssertTrue(zone.roomIds.isEmpty)
        XCTAssertTrue(zone.groupIds.isEmpty)
    }

    func test_zone_codable() throws {
        var original = Zone(name: "Ground Floor", icon: "house.fill")
        original.roomIds = [UUID(), UUID()]
        original.groupIds = [UUID()]

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Zone.self, from: data)

        XCTAssertEqual(decoded.name, "Ground Floor")
        XCTAssertEqual(decoded.icon, "house.fill")
        XCTAssertEqual(decoded.roomIds.count, 2)
        XCTAssertEqual(decoded.groupIds.count, 1)
    }
}
