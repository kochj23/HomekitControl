//
//  iOS_SettingsView.swift
//  HomekitControl
//
//  iOS settings view
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import NovaAIKit

struct iOS_SettingsView: View {
    @ObservedObject private var ai = AppAI.shared
    @State private var showingAbout = false

    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphicBackground()

                List {
                    // AI Settings
                    Section {
                        Toggle("Use AI", isOn: $ai.isEnabled)

                        NavigationLink {
                            NovaAISettingsView(ai: ai, footer: AppAI.settingsFooter)
                                .navigationTitle("AI Settings")
                        } label: {
                            HStack {
                                Label("AI Settings", systemImage: "slider.horizontal.3")
                                Spacer()
                                NovaAIStatusIndicator(ai: ai, showsLabel: false)
                            }
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
                                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
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

                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
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
