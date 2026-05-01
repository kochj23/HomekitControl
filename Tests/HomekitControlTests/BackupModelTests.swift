//
//  BackupModelTests.swift
//  HomekitControlTests
//
//  Tests for backup data models and error types.
//  Backup integrity is critical — a corrupted backup means losing the
//  entire HomeKit configuration if devices need to be re-paired.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

final class BackupModelTests: XCTestCase {

    // MARK: - HomeKitBackup

    func test_backup_init() {
        let homeData = HomeBackupData(
            homeName: "My Home",
            rooms: [],
            accessories: [],
            scenes: [],
            serviceGroups: []
        )
        let customData = CustomBackupData(
            deviceGroups: nil,
            schedules: nil,
            automations: nil,
            notificationRules: nil
        )

        let backup = HomeKitBackup(
            name: "Test Backup",
            homeData: homeData,
            automationData: [],
            customData: customData
        )

        XCTAssertEqual(backup.name, "Test Backup")
        XCTAssertEqual(backup.version, "1.0")
        XCTAssertEqual(backup.homeData.homeName, "My Home")
        XCTAssertTrue(backup.automationData.isEmpty)
    }

    func test_backup_codableRoundtrip() throws {
        let room = RoomBackupData(id: UUID(), name: "Kitchen", accessoryIds: [UUID()])
        let accessory = AccessoryBackupData(
            id: UUID(),
            name: "Light",
            roomId: room.id,
            manufacturer: "Philips",
            model: "Hue",
            firmwareVersion: "1.0",
            services: []
        )
        let scene = SceneBackupData(id: UUID(), name: "Morning", actions: [])

        let homeData = HomeBackupData(
            homeName: "Home",
            rooms: [room],
            accessories: [accessory],
            scenes: [scene],
            serviceGroups: []
        )

        let customData = CustomBackupData(
            deviceGroups: "test".data(using: .utf8),
            schedules: nil,
            automations: nil,
            notificationRules: nil
        )

        let original = HomeKitBackup(
            name: "Full Backup",
            homeData: homeData,
            automationData: [],
            customData: customData
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HomeKitBackup.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, "Full Backup")
        XCTAssertEqual(decoded.version, "1.0")
        XCTAssertEqual(decoded.homeData.homeName, "Home")
        XCTAssertEqual(decoded.homeData.rooms.count, 1)
        XCTAssertEqual(decoded.homeData.accessories.count, 1)
        XCTAssertEqual(decoded.homeData.scenes.count, 1)
        XCTAssertNotNil(decoded.customData.deviceGroups)
    }

    // MARK: - Backup Sub-Models

    func test_roomBackupData_codable() throws {
        let original = RoomBackupData(
            id: UUID(),
            name: "Living Room",
            accessoryIds: [UUID(), UUID(), UUID()]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RoomBackupData.self, from: data)

        XCTAssertEqual(decoded.name, "Living Room")
        XCTAssertEqual(decoded.accessoryIds.count, 3)
    }

    func test_accessoryBackupData_codable() throws {
        let serviceId = UUID()
        let charId = UUID()
        let characteristic = CharacteristicBackupData(
            id: charId,
            characteristicType: "powerState",
            value: "true"
        )
        let service = ServiceBackupData(
            id: serviceId,
            name: "Lightbulb",
            serviceType: "lightbulb",
            characteristics: [characteristic]
        )
        let original = AccessoryBackupData(
            id: UUID(),
            name: "Desk Lamp",
            roomId: UUID(),
            manufacturer: "LIFX",
            model: "Mini",
            firmwareVersion: "2.0",
            services: [service]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AccessoryBackupData.self, from: data)

        XCTAssertEqual(decoded.name, "Desk Lamp")
        XCTAssertEqual(decoded.services.count, 1)
        XCTAssertEqual(decoded.services[0].characteristics.count, 1)
        XCTAssertEqual(decoded.services[0].characteristics[0].value, "true")
    }

    func test_actionBackupData_codable() throws {
        let original = ActionBackupData(
            accessoryId: UUID(),
            characteristicType: "brightness",
            targetValue: "80"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ActionBackupData.self, from: data)

        XCTAssertEqual(decoded.characteristicType, "brightness")
        XCTAssertEqual(decoded.targetValue, "80")
    }

    // MARK: - BackupError

    func test_backupError_descriptions() {
        XCTAssertNotNil(BackupError.noHomeAvailable.errorDescription)
        XCTAssertNotNil(BackupError.homeKitNotAvailable.errorDescription)
        XCTAssertNotNil(BackupError.exportFailed.errorDescription)
        XCTAssertNotNil(BackupError.importFailed.errorDescription)

        XCTAssertTrue(BackupError.noHomeAvailable.errorDescription!.contains("home"))
        XCTAssertTrue(BackupError.homeKitNotAvailable.errorDescription!.contains("HomeKit"))
    }
}
