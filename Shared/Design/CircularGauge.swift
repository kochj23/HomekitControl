//
//  CircularGauge.swift
//  HomekitControl
//
//  Circular progress gauge component
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// A circular progress gauge with animated fill
struct CircularGauge: View {
    let value: Double
    let maxValue: Double
    let color: Color
    let lineWidth: CGFloat
    let size: CGFloat

    init(
        value: Double,
        maxValue: Double = 100,
        color: Color = ModernColors.cyan,
        lineWidth: CGFloat = 8,
        size: CGFloat = 80
    ) {
        self.value = value
        self.maxValue = maxValue
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
    }

    private var progress: Double {
        min(value / maxValue, 1.0)
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(
                    color.opacity(0.2),
                    lineWidth: lineWidth
                )

            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: progress)

            // Value text
            Text("\(Int(value))")
                .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                .foregroundColor(ModernColors.textPrimary)
        }
        .frame(width: size, height: size)
    }
}

/// A smaller mini gauge variant
struct MiniGauge: View {
    let value: Double
    let maxValue: Double
    let color: Color

    init(value: Double, maxValue: Double = 100, color: Color = ModernColors.cyan) {
        self.value = value
        self.maxValue = maxValue
        self.color = color
    }

    var body: some View {
        CircularGauge(
            value: value,
            maxValue: maxValue,
            color: color,
            lineWidth: 4,
            size: 40
        )
    }
}

#Preview {
    ZStack {
        GlassmorphicBackground()

        HStack(spacing: 20) {
            CircularGauge(value: 75, color: ModernColors.cyan)
            CircularGauge(value: 45, color: ModernColors.orange)
            CircularGauge(value: 90, color: ModernColors.accentGreen)
            MiniGauge(value: 30, color: ModernColors.purple)
        }
    }
}
