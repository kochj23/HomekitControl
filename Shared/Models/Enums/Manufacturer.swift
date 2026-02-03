//
//  Manufacturer.swift
//  HomekitControl
//
//  Device manufacturer enumeration
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Known smart home device manufacturers
enum Manufacturer: String, Codable, CaseIterable, Hashable {
    case philipsHue = "Philips Hue"
    case lutron = "Lutron"
    case ikea = "IKEA"
    case nanoleaf = "Nanoleaf"
    case ecobee = "ecobee"
    case schlage = "Schlage"
    case yale = "Yale"
    case august = "August"
    case eve = "Eve"
    case lifx = "LIFX"
    case wemo = "Wemo"
    case tpLink = "TP-Link"
    case meross = "Meross"
    case aqara = "Aqara"
    case sonos = "Sonos"
    case apple = "Apple"
    case google = "Google"
    case amazon = "Amazon"
    case ring = "Ring"
    case nest = "Nest"
    case honeywell = "Honeywell"
    case leviton = "Leviton"
    case ge = "GE"
    case hatch = "Hatch"
    case unknown = "Unknown"

    /// SF Symbol icon for this manufacturer
    var icon: String {
        switch self {
        case .philipsHue: return "lightbulb.led.fill"
        case .lutron: return "lightswitch.on"
        case .ikea: return "lamp.floor.fill"
        case .nanoleaf: return "triangle.fill"
        case .ecobee: return "thermometer"
        case .schlage, .yale, .august: return "lock.fill"
        case .eve: return "leaf.fill"
        case .lifx: return "lightbulb.fill"
        case .wemo, .tpLink, .meross: return "poweroutlet.type.b.fill"
        case .aqara: return "sensor.fill"
        case .sonos: return "hifispeaker.2.fill"
        case .apple: return "apple.logo"
        case .google: return "g.circle.fill"
        case .amazon: return "a.circle.fill"
        case .ring: return "bell.fill"
        case .nest: return "house.fill"
        case .honeywell: return "thermometer"
        case .leviton, .ge: return "switch.2"
        case .hatch: return "lightbulb.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    /// Detect manufacturer from device name or model string
    static func detect(from text: String) -> Manufacturer {
        let lowercased = text.lowercased()

        if lowercased.contains("hue") || lowercased.contains("philips") { return .philipsHue }
        if lowercased.contains("lutron") || lowercased.contains("caseta") { return .lutron }
        if lowercased.contains("ikea") || lowercased.contains("tradfri") { return .ikea }
        if lowercased.contains("nanoleaf") { return .nanoleaf }
        if lowercased.contains("ecobee") { return .ecobee }
        if lowercased.contains("schlage") { return .schlage }
        if lowercased.contains("yale") { return .yale }
        if lowercased.contains("august") { return .august }
        if lowercased.contains("eve") && !lowercased.contains("leviton") { return .eve }
        if lowercased.contains("lifx") { return .lifx }
        if lowercased.contains("wemo") || lowercased.contains("belkin") { return .wemo }
        if lowercased.contains("tp-link") || lowercased.contains("kasa") { return .tpLink }
        if lowercased.contains("meross") { return .meross }
        if lowercased.contains("aqara") || lowercased.contains("xiaomi") { return .aqara }
        if lowercased.contains("sonos") { return .sonos }
        if lowercased.contains("apple") || lowercased.contains("homepod") { return .apple }
        if lowercased.contains("google") { return .google }
        if lowercased.contains("amazon") || lowercased.contains("echo") { return .amazon }
        if lowercased.contains("ring") { return .ring }
        if lowercased.contains("nest") { return .nest }
        if lowercased.contains("honeywell") { return .honeywell }
        if lowercased.contains("leviton") { return .leviton }
        if lowercased.contains("ge") || lowercased.contains("cync") { return .ge }
        if lowercased.contains("hatch") { return .hatch }

        return .unknown
    }
}
