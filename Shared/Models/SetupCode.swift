//
//  SetupCode.swift
//  HomekitControl
//
//  Model for HomeKit setup codes (pairing codes)
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// HomeKit setup code for device pairing
struct SetupCode: Identifiable, Codable, Hashable {
    let id: UUID
    var deviceName: String
    var code: String
    var manufacturer: Manufacturer
    var category: DeviceCategory

    // MARK: - Photo Storage (iOS/macOS only)

    var photoPath: String?
    var photoData: Data?

    // MARK: - Metadata

    var room: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Device Info

    var serialNumber: String?
    var model: String?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        deviceName: String,
        code: String,
        manufacturer: Manufacturer = .unknown,
        category: DeviceCategory = .other,
        photoPath: String? = nil,
        photoData: Data? = nil,
        room: String? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        serialNumber: String? = nil,
        model: String? = nil
    ) {
        self.id = id
        self.deviceName = deviceName
        self.code = code
        self.manufacturer = manufacturer
        self.category = category
        self.photoPath = photoPath
        self.photoData = photoData
        self.room = room
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.serialNumber = serialNumber
        self.model = model
    }

    // MARK: - Formatted Code

    /// Returns the code formatted as XXX-XX-XXX
    var formattedCode: String {
        let cleaned = code.replacingOccurrences(of: "-", with: "")
        guard cleaned.count == 8 else { return code }
        let part1 = String(cleaned.prefix(3))
        let part2 = String(cleaned.dropFirst(3).prefix(2))
        let part3 = String(cleaned.suffix(3))
        return "\(part1)-\(part2)-\(part3)"
    }
}

// MARK: - Setup Code Validation

extension SetupCode {
    /// Check if the code is valid (8 digits)
    var isValidCode: Bool {
        let cleaned = code.replacingOccurrences(of: "-", with: "")
        return cleaned.count == 8 && cleaned.allSatisfy { $0.isNumber }
    }
}
