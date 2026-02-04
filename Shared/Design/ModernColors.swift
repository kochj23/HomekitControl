//
//  ModernColors.swift
//  HomekitControl
//
//  Unified color palette and design system
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Modern color palette with glassmorphic design
struct ModernColors {
    // MARK: - Primary Accent

    /// Primary accent color (cyan)
    static let accent = Color(red: 0.23, green: 0.86, blue: 0.98)

    /// Magenta accent
    static let magenta = Color(red: 0.9, green: 0.3, blue: 0.8)

    // MARK: - Primary Colors

    /// Vibrant cyan accent
    static let cyan = Color(red: 0.23, green: 0.86, blue: 0.98)

    /// Teal accent
    static let teal = Color(red: 0.2, green: 0.8, blue: 0.75)

    /// Purple accent
    static let purple = Color(red: 0.65, green: 0.4, blue: 1.0)

    /// Pink accent
    static let pink = Color(red: 1.0, green: 0.4, blue: 0.7)

    /// Orange accent
    static let orange = Color(red: 1.0, green: 0.6, blue: 0.2)

    /// Yellow accent
    static let yellow = Color(red: 1.0, green: 0.85, blue: 0.3)

    /// Green accent
    static let accentGreen = Color(red: 0.3, green: 0.9, blue: 0.6)

    /// Blue accent
    static let accentBlue = Color(red: 0.3, green: 0.6, blue: 1.0)

    /// Red accent
    static let red = Color(red: 1.0, green: 0.3, blue: 0.4)

    // MARK: - Text Colors

    /// Primary text (white)
    static let textPrimary = Color.white

    /// Secondary text (70% white)
    static let textSecondary = Color.white.opacity(0.7)

    /// Tertiary text (50% white)
    static let textTertiary = Color.white.opacity(0.5)

    // MARK: - Background Colors

    /// Dark navy background start
    static let backgroundStart = Color(red: 0.08, green: 0.12, blue: 0.22)

    /// Dark navy background end
    static let backgroundEnd = Color(red: 0.12, green: 0.18, blue: 0.32)

    /// Dark background (alias for backgroundStart)
    static let darkBackground = Color(red: 0.08, green: 0.12, blue: 0.22)

    /// Glass effect background
    static let glassBackground = Color.white.opacity(0.05)

    /// Glass effect border
    static let glassBorder = Color.white.opacity(0.15)

    // MARK: - Status Colors

    /// Low severity (green)
    static let statusLow = Color(red: 0.3, green: 0.9, blue: 0.6)

    /// Medium severity (yellow)
    static let statusMedium = Color(red: 1.0, green: 0.85, blue: 0.3)

    /// High severity (orange)
    static let statusHigh = Color(red: 1.0, green: 0.6, blue: 0.2)

    /// Critical severity (red)
    static let statusCritical = Color(red: 1.0, green: 0.3, blue: 0.4)

    // MARK: - Health Status Colors

    static func healthColor(for percentage: Double) -> Color {
        switch percentage {
        case 0..<25: return statusCritical
        case 25..<50: return statusHigh
        case 50..<75: return statusMedium
        default: return statusLow
        }
    }
}

// MARK: - Background Gradient

extension LinearGradient {
    static var modernBackground: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [ModernColors.backgroundStart, ModernColors.backgroundEnd]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
