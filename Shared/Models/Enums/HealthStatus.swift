//
//  HealthStatus.swift
//  HomekitControl
//
//  Device health status enumeration
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Health status for devices
enum HealthStatus: String, Codable, CaseIterable, Hashable {
    case healthy = "Healthy"
    case degraded = "Degraded"
    case unreachable = "Unreachable"
    case unknown = "Unknown"
    case testing = "Testing"

    /// Color for this health status
    var color: Color {
        switch self {
        case .healthy: return ModernColors.statusLow
        case .degraded: return ModernColors.statusMedium
        case .unreachable: return ModernColors.statusCritical
        case .unknown: return ModernColors.textTertiary
        case .testing: return ModernColors.cyan
        }
    }

    /// SF Symbol icon for this status
    var icon: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .degraded: return "exclamationmark.triangle.fill"
        case .unreachable: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        case .testing: return "arrow.triangle.2.circlepath"
        }
    }
}
