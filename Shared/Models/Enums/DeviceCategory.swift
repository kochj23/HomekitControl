//
//  DeviceCategory.swift
//  HomekitControl
//
//  Device category enumeration
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Device category types
enum DeviceCategory: String, Codable, CaseIterable, Hashable {
    case light = "Light"
    case switchDevice = "Switch"
    case outlet = "Outlet"
    case thermostat = "Thermostat"
    case lock = "Lock"
    case garageDoor = "Garage Door"
    case sensor = "Sensor"
    case camera = "Camera"
    case doorbell = "Doorbell"
    case speaker = "Speaker"
    case fan = "Fan"
    case blind = "Blind"
    case airPurifier = "Air Purifier"
    case humidifier = "Humidifier"
    case dehumidifier = "Dehumidifier"
    case bridge = "Bridge"
    case securitySystem = "Security System"
    case other = "Other"

    /// SF Symbol icon for this category
    var icon: String {
        switch self {
        case .light: return "lightbulb.fill"
        case .switchDevice: return "switch.2"
        case .outlet: return "poweroutlet.type.b.fill"
        case .thermostat: return "thermometer"
        case .lock: return "lock.fill"
        case .garageDoor: return "door.garage.closed"
        case .sensor: return "sensor.fill"
        case .camera: return "video.fill"
        case .doorbell: return "bell.fill"
        case .speaker: return "hifispeaker.fill"
        case .fan: return "fan.fill"
        case .blind: return "blinds.horizontal.closed"
        case .airPurifier: return "aqi.medium"
        case .humidifier: return "humidity.fill"
        case .dehumidifier: return "dehumidifier.fill"
        case .bridge: return "network"
        case .securitySystem: return "shield.fill"
        case .other: return "questionmark.circle"
        }
    }

    /// Whether this device type is dangerous to auto-control
    var isDangerous: Bool {
        switch self {
        case .lock, .garageDoor, .securitySystem:
            return true
        default:
            return false
        }
    }
}
