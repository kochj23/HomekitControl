//
//  iOS_VoiceControlView.swift
//  HomekitControl
//
//  Voice control dashboard for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct iOS_VoiceControlView: View {
    @StateObject private var voiceService = VoiceControlService.shared
    @State private var showSettings = false
    @State private var showAddCommand = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Main Control
                GlassCard {
                    VStack(spacing: 20) {
                        // Listening indicator
                        ZStack {
                            Circle()
                                .fill(voiceService.isListening ? ModernColors.cyan : ModernColors.glassBackground)
                                .frame(width: 120, height: 120)

                            if voiceService.isListening {
                                ForEach(0..<3) { i in
                                    Circle()
                                        .stroke(ModernColors.cyan.opacity(0.3), lineWidth: 2)
                                        .frame(width: CGFloat(120 + i * 30), height: CGFloat(120 + i * 30))
                                        .scaleEffect(voiceService.isListening ? 1.2 : 1)
                                        .opacity(voiceService.isListening ? 0 : 1)
                                        .animation(
                                            .easeOut(duration: 1.5)
                                            .repeatForever(autoreverses: false)
                                            .delay(Double(i) * 0.3),
                                            value: voiceService.isListening
                                        )
                                }
                            }

                            Image(systemName: voiceService.isListening ? "waveform" : "mic.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white)
                        }

                        // Status
                        Text(voiceService.isListening ? "Listening..." : "Tap to speak")
                            .font(.headline)
                            .foregroundStyle(.white)

                        if !voiceService.transcript.isEmpty {
                            Text(voiceService.transcript)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // Control button
                        Button {
                            if voiceService.isListening {
                                voiceService.stopListening()
                            } else {
                                voiceService.startListening()
                            }
                        } label: {
                            Text(voiceService.isListening ? "Stop" : "Start Listening")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(voiceService.isListening ? ModernColors.red : ModernColors.cyan)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                }

                // Wake Word
                GlassCard {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(ModernColors.yellow)

                        VStack(alignment: .leading) {
                            Text("Wake Word")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("\"\(voiceService.wakeWord)\"")
                                .font(.subheadline)
                                .foregroundStyle(ModernColors.cyan)
                        }

                        Spacer()

                        Image(systemName: voiceService.wakeWordDetected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(voiceService.wakeWordDetected ? ModernColors.accentGreen : .secondary)
                    }
                    .padding()
                }

                // Custom Commands
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Custom Commands")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Spacer()

                        Button {
                            showAddCommand = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(ModernColors.cyan)
                        }
                    }

                    ForEach(voiceService.commands) { command in
                        GlassCard {
                            HStack {
                                Circle()
                                    .fill(command.isEnabled ? ModernColors.accentGreen : .secondary)
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading) {
                                    Text("\"\(command.phrase)\"")
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    Text(describeAction(command.action))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .padding()
                        }
                    }
                }

                // Settings
                GlassCard {
                    VStack(spacing: 16) {
                        Toggle(isOn: $voiceService.feedbackEnabled) {
                            HStack {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(ModernColors.purple)
                                Text("Voice Feedback")
                                    .foregroundStyle(.white)
                            }
                        }
                        .tint(ModernColors.cyan)

                        Divider()

                        Button {
                            showSettings = true
                        } label: {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                    .foregroundStyle(ModernColors.orange)
                                Text("Voice Settings")
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                }

                // History
                if !voiceService.history.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Commands")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(voiceService.history.prefix(5)) { entry in
                            GlassCard {
                                HStack {
                                    Image(systemName: entry.wasSuccessful ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(entry.wasSuccessful ? ModernColors.accentGreen : ModernColors.red)

                                    VStack(alignment: .leading) {
                                        Text(entry.transcript)
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                            .lineLimit(1)

                                        if let matched = entry.matchedCommand {
                                            Text("Matched: \(matched)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    Text(entry.timestamp, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(LinearGradient.modernBackground.ignoresSafeArea())
        .navigationTitle("Voice Control")
        .onAppear {
            Task {
                _ = await voiceService.requestAuthorization()
            }
        }
        .sheet(isPresented: $showSettings) {
            VoiceSettingsView()
        }
        .sheet(isPresented: $showAddCommand) {
            AddVoiceCommandView()
        }
    }

    private func describeAction(_ action: VoiceAction) -> String {
        switch action {
        case .toggleDevice: return "Toggle device"
        case .setDeviceBrightness(_, let brightness): return "Set brightness to \(brightness)%"
        case .executeScene: return "Execute scene"
        case .setThermostat(let temp): return "Set temperature to \(Int(temp))°"
        case .lockDoor: return "Lock door"
        case .unlockDoor: return "Unlock door"
        case .custom(let cmd): return cmd
        }
    }
}

struct VoiceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var voiceService = VoiceControlService.shared
    @State private var wakeWord: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Wake Word") {
                    TextField("Wake Word", text: $wakeWord)
                        .autocapitalization(.none)
                }

                Section("Options") {
                    Toggle("Voice Feedback", isOn: $voiceService.feedbackEnabled)
                    Toggle("Continuous Listening", isOn: $voiceService.continuousListening)
                }
            }
            .navigationTitle("Voice Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        voiceService.wakeWord = wakeWord
                        dismiss()
                    }
                }
            }
            .onAppear {
                wakeWord = voiceService.wakeWord
            }
        }
    }
}

struct AddVoiceCommandView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var voiceService = VoiceControlService.shared
    @State private var phrase = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Command") {
                    TextField("Phrase (e.g., \"movie time\")", text: $phrase)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Add Command")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let command = VoiceCommand(
                            phrase: phrase,
                            action: .custom(command: phrase)
                        )
                        voiceService.addCommand(command)
                        dismiss()
                    }
                    .disabled(phrase.isEmpty)
                }
            }
        }
    }
}
