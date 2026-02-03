//
//  GlassCard.swift
//  HomekitControl
//
//  Glass morphism card component
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// ViewModifier for glassmorphic card styling
struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(ModernColors.glassBorder, lineWidth: 1)
                    )
            )
    }
}

extension View {
    /// Apply glassmorphic card styling
    func glassCard(cornerRadius: CGFloat = 20, padding: CGFloat = 20) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

/// A pre-styled glass card container
struct GlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 20

    init(cornerRadius: CGFloat = 20, padding: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .glassCard(cornerRadius: cornerRadius, padding: padding)
    }
}
