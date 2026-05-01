//
//  DeviceCategoryTests.swift
//  HomekitControlTests
//
//  Tests for DeviceCategory — isDangerous is CRITICAL because it gates whether
//  the app will auto-control locks, garage doors, and security systems.
//  A false negative here could unlock someone's front door unintentionally.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

final class DeviceCategoryTests: XCTestCase {

    // MARK: - isDangerous (SAFETY CRITICAL)

    func test_isDangerous_lock_isTrue() {
        XCTAssertTrue(DeviceCategory.lock.isDangerous,
                       "Locks MUST be flagged as dangerous to prevent accidental unlocking")
    }

    func test_isDangerous_garageDoor_isTrue() {
        XCTAssertTrue(DeviceCategory.garageDoor.isDangerous,
                       "Garage doors MUST be flagged as dangerous to prevent accidental opening")
    }

    func test_isDangerous_securitySystem_isTrue() {
        XCTAssertTrue(DeviceCategory.securitySystem.isDangerous,
                       "Security systems MUST be flagged as dangerous to prevent accidental disarming")
    }

    func test_isDangerous_light_isFalse() {
        XCTAssertFalse(DeviceCategory.light.isDangerous)
    }

    func test_isDangerous_switchDevice_isFalse() {
        XCTAssertFalse(DeviceCategory.switchDevice.isDangerous)
    }

    func test_isDangerous_outlet_isFalse() {
        XCTAssertFalse(DeviceCategory.outlet.isDangerous)
    }

    func test_isDangerous_thermostat_isFalse() {
        XCTAssertFalse(DeviceCategory.thermostat.isDangerous)
    }

    func test_isDangerous_sensor_isFalse() {
        XCTAssertFalse(DeviceCategory.sensor.isDangerous)
    }

    func test_isDangerous_camera_isFalse() {
        XCTAssertFalse(DeviceCategory.camera.isDangerous)
    }

    func test_isDangerous_fan_isFalse() {
        XCTAssertFalse(DeviceCategory.fan.isDangerous)
    }

    func test_isDangerous_blind_isFalse() {
        XCTAssertFalse(DeviceCategory.blind.isDangerous)
    }

    func test_isDangerous_other_isFalse() {
        XCTAssertFalse(DeviceCategory.other.isDangerous)
    }

    // MARK: - Exhaustive Safety Check

    func test_allDangerousCategories_areExactlyThree() {
        let dangerousCategories = DeviceCategory.allCases.filter { $0.isDangerous }
        XCTAssertEqual(dangerousCategories.count, 3,
                       "Exactly 3 categories should be dangerous: lock, garageDoor, securitySystem")
        XCTAssertTrue(dangerousCategories.contains(.lock))
        XCTAssertTrue(dangerousCategories.contains(.garageDoor))
        XCTAssertTrue(dangerousCategories.contains(.securitySystem))
    }

    // MARK: - Codable

    func test_allCategories_areCodeable() throws {
        for category in DeviceCategory.allCases {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(DeviceCategory.self, from: data)
            XCTAssertEqual(decoded, category, "Failed roundtrip for \(category)")
        }
    }

    // MARK: - Icons

    func test_allCategories_haveIcons() {
        for category in DeviceCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty, "\(category) has no icon")
        }
    }

    // MARK: - CaseIterable

    func test_allCases_includes18Categories() {
        XCTAssertEqual(DeviceCategory.allCases.count, 18)
    }
}
