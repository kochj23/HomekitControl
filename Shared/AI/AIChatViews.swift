//
//  AIChatViews.swift
//  HomekitControl
//
//  Chat bubble and AI source badge shared by the iOS and macOS assistants.
//
//  Author: Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import NovaAIKit

/// "AI · Ollama (model)" or "Built-in".
struct AISourceBadge: View {
    let source: NovaAISource

    var body: some View {
        Label(source.label, systemImage: source.isAI ? "sparkles" : "house")
            .font(.caption2)
            .foregroundStyle(source.isAI ? ModernColors.accent : ModernColors.textSecondary)
            .accessibilityLabel("Source: \(source.label)")
    }
}

struct MessageBubble: View {
    let message: AIMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .padding(12)
                    .background {
                        if message.role == .user {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(ModernColors.accent)
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.1))
                        }
                    }

                HStack(spacing: 8) {
                    if let source = message.source {
                        AISourceBadge(source: source)
                    }
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if message.role == .assistant {
                Spacer()
            }
        }
    }
}
