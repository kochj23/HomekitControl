//
//  GlassmorphicBackground.swift
//  HomekitControl
//
//  Animated glassmorphic background with floating blobs
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Animated background with floating colored blobs
struct GlassmorphicBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient.modernBackground
                .ignoresSafeArea()

            // Animated blobs
            GeometryReader { geometry in
                ZStack {
                    // Cyan blob
                    FloatingBlob(color: ModernColors.cyan.opacity(0.3), size: geometry.size.width * 0.6)
                        .offset(
                            x: animate ? geometry.size.width * 0.3 : geometry.size.width * 0.1,
                            y: animate ? geometry.size.height * 0.2 : geometry.size.height * 0.4
                        )

                    // Purple blob
                    FloatingBlob(color: ModernColors.purple.opacity(0.25), size: geometry.size.width * 0.5)
                        .offset(
                            x: animate ? geometry.size.width * 0.6 : geometry.size.width * 0.8,
                            y: animate ? geometry.size.height * 0.6 : geometry.size.height * 0.3
                        )

                    // Pink blob
                    FloatingBlob(color: ModernColors.pink.opacity(0.2), size: geometry.size.width * 0.4)
                        .offset(
                            x: animate ? geometry.size.width * 0.2 : geometry.size.width * 0.5,
                            y: animate ? geometry.size.height * 0.7 : geometry.size.height * 0.8
                        )
                }
            }
            .blur(radius: 80)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

/// A single floating blob shape
struct FloatingBlob: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

#Preview {
    GlassmorphicBackground()
}
