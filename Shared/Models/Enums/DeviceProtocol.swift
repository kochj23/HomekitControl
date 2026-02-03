//
//  DeviceProtocol.swift
//  HomekitControl
//
//  Device communication protocol enumeration
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Communication protocols for smart home devices
enum DeviceProtocol: String, Codable, CaseIterable, Hashable {
    case wifi = "Wi-Fi"
    case zigbee = "Zigbee"
    case zwave = "Z-Wave"
    case bluetooth = "Bluetooth"
    case thread = "Thread"
    case matter = "Matter"
    case unknown = "Unknown"

    /// SF Symbol icon for this protocol
    var icon: String {
        switch self {
        case .wifi: return "wifi"
        case .zigbee: return "dot.radiowaves.left.and.right"
        case .zwave: return "wave.3.right"
        case .bluetooth: return "bluetooth"
        case .thread: return "point.3.filled.connected.trianglepath.dotted"
        case .matter: return "m.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}
