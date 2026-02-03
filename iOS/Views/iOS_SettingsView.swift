//
//  iOS_SettingsView.swift
//  HomekitControl
//
//  iOS settings view
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct iOS_SettingsView: View {
    @StateObject private var aiService = AIService.shared
    @AppStorage("ollamaEndpoint") private var ollamaEndpoint = "http://192.168.1.100:11434"
    @AppStorage("ollamaModel") private var ollamaModel = "llama3.1"
    @State private var showingAbout = false

    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphicBackground()

                List {
                    // AI Settings
                    Section {
                        Picker("Provider", selection: $aiService.selectedProvider) {
                            ForEach(AIProvider.allCases, id: \.self) { provider in
                                Label(provider.rawValue, systemImage: provider.icon)
                                    .tag(provider)
                            }
                        }

                        if aiService.selectedProvider == .ollama {
                            TextField("Ollama Endpoint", text: $ollamaEndpoint)
                                .textContentType(.URL)
                                .keyboardType(.URL)
                                .autocapitalization(.none)

                            TextField("Model Name", text: $ollamaModel)
                                .autocapitalization(.none)
                        }
                    } header: {
                        Label("AI Assistant", systemImage: "brain")
                    }

                    // Export Options
                    Section {
                        NavigationLink {
                            ExportSettingsView()
                        } label: {
                            Label("Export Settings", systemImage: "square.and.arrow.up")
                        }
                    } header: {
                        Label("Data", systemImage: "folder")
                    }

                    // Health Monitoring
                    Section {
                        NavigationLink {
                            HealthSettingsView()
                        } label: {
                            Label("Health Monitoring", systemImage: "heart.fill")
                        }
                    } header: {
                        Label("Devices", systemImage: "lightbulb")
                    }

                    // About
                    Section {
                        Button {
                            showingAbout = true
                        } label: {
                            HStack {
                                Label("About HomekitControl", systemImage: "info.circle")
                                Spacer()
                                Text("1.0.0")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Label("App", systemImage: "app")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .onChange(of: ollamaEndpoint) { _, newValue in
                aiService.ollamaEndpoint = newValue
                aiService.saveConfiguration()
            }
            .onChange(of: ollamaModel) { _, newValue in
                aiService.ollamaModel = newValue
                aiService.saveConfiguration()
            }
        }
    }
}

// MARK: - Export Settings View

struct ExportSettingsView: View {
    @StateObject private var exportService = ExportService.shared
    @StateObject private var homeKitService = HomeKitService.shared
    @StateObject private var codeVault = CodeVaultService.shared

    var body: some View {
        List {
            Section("Devices") {
                Button("Export Devices (JSON)") {
                    // Export logic handled by share sheet
                }

                Button("Export Devices (CSV)") {
                    // Export logic handled by share sheet
                }
            }

            Section("Setup Codes") {
                Button("Export Setup Codes (JSON)") {
                    // Export logic
                }

                Button("Export Setup Codes (CSV)") {
                    // Export logic
                }
            }
        }
        .navigationTitle("Export")
    }
}

// MARK: - Health Settings View

struct HealthSettingsView: View {
    @StateObject private var healthService = DeviceHealthService.shared
    @AppStorage("healthTestInterval") private var testInterval: Double = 30.0

    var body: some View {
        List {
            Section("Automatic Testing") {
                Stepper("Test every \(Int(testInterval))s", value: $testInterval, in: 10...300, step: 10)
            }

            Section("History") {
                Button("Clear Health Records", role: .destructive) {
                    healthService.clearHealthRecords()
                }
            }
        }
        .navigationTitle("Health Monitoring")
        .onChange(of: testInterval) { _, newValue in
            healthService.testInterval = newValue
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphicBackground()

                VStack(spacing: 24) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(ModernColors.accent)

                    Text("HomekitControl")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("Version 1.0.0")
                        .foregroundStyle(.secondary)

                    Text("A unified smart home control app combining the best features of HomeKitAdopter, HomeKitAssistant, HomeKitRestore, HomeKitTV, and SceneFixer.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer()

                    Text("Created by Jordan Koch")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("Copyright 2026 Jordan Koch. All rights reserved.")
                        .font(.caption)
                        .foregroundStyle(ModernColors.textTertiary)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    iOS_SettingsView()
}
