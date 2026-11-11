//
//  iOS_AIAssistantView.swift
//  HomekitControl
//
//  iOS AI assistant chat interface
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import NovaAIKit

struct iOS_AIAssistantView: View {
    @StateObject private var aiService = HomeAIAssistant.shared
    @ObservedObject private var ai = AppAI.shared
    @State private var showingAISettings = false
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphicBackground()

                VStack(spacing: 0) {
                    // Messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                if aiService.messages.isEmpty {
                                    welcomeMessage
                                }

                                ForEach(aiService.messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }

                                if aiService.isProcessing {
                                    HStack {
                                        TypingIndicator()
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding()
                        }
                        .onChange(of: aiService.messages.count) { _, _ in
                            if let lastMessage = aiService.messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }

                    // Input
                    inputSection
                }
            }
            .navigationTitle("AI Assistant")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NovaAIStatusIndicator(ai: ai)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Use AI", isOn: $ai.isEnabled)

                        Button {
                            showingAISettings = true
                        } label: {
                            Label("AI Settings", systemImage: "gearshape")
                        }

                        Divider()

                        Button("Clear Chat", role: .destructive) {
                            aiService.clearChat()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAISettings) {
                NavigationStack {
                    NovaAISettingsView(ai: ai, footer: AppAI.settingsFooter)
                        .navigationTitle("AI Settings")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showingAISettings = false }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Welcome Message

    private var welcomeMessage: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain")
                .font(.system(size: 60))
                .foregroundStyle(ModernColors.accent)

            Text("Smart Home Assistant")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text("Ask me about your smart home devices, scenes, or network. I can help analyze issues and suggest improvements.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Quick prompts
            VStack(spacing: 12) {
                QuickPromptButton(text: "Analyze my devices") {
                    sendMessage("Analyze my smart home devices and suggest improvements")
                }

                QuickPromptButton(text: "Scene recommendations") {
                    sendMessage("What scenes should I create for my home?")
                }

                QuickPromptButton(text: "Network security tips") {
                    sendMessage("How can I improve my smart home network security?")
                }
            }
        }
        .padding(.top, 60)
    }

    // MARK: - Input Section

    private var inputSection: some View {
        HStack(spacing: 12) {
            TextField("Ask me anything...", text: $inputText)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
                .focused($isInputFocused)
                .onSubmit {
                    sendMessage(inputText)
                }

            Button {
                sendMessage(inputText)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(inputText.isEmpty ? .secondary : ModernColors.accent)
            }
            .disabled(inputText.isEmpty || aiService.isProcessing)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    private func sendMessage(_ text: String) {
        guard !text.isEmpty else { return }
        let message = text
        inputText = ""
        Task {
            await aiService.sendMessage(message)
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(ModernColors.textSecondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.1))
        .clipShape(Capsule())
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Quick Prompt Button

struct QuickPromptButton: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(ModernColors.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ModernColors.accent.opacity(0.1))
                .clipShape(Capsule())
        }
    }
}

#Preview {
    iOS_AIAssistantView()
}
