//
//  iOS_FirmwareView.swift
//  HomekitControl
//
//  Device firmware tracker for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct iOS_FirmwareView: View {
    @StateObject private var firmwareService = FirmwareTrackerService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overview
                GlassCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Firmware Health")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Text("\(Int(firmwareService.overallHealth))% up to date")
                                .font(.subheadline)
                                .foregroundStyle(firmwareService.overallHealth > 80 ? ModernColors.accentGreen : ModernColors.orange)
                        }

                        Spacer()

                        CircularGauge(
                            value: firmwareService.overallHealth,
                            color: firmwareService.overallHealth > 80 ? ModernColors.accentGreen : ModernColors.orange,
                            lineWidth: 8,
                            size: 70
                        )
                    }
                    .padding()
                }

                // Quick Actions
                HStack(spacing: 12) {
                    Button {
                        firmwareService.scanAllDevices()
                    } label: {
                        GlassCard {
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.title2)
                                    .foregroundStyle(ModernColors.cyan)
                                Text("Scan")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                    }

                    Button {
                        Task { await firmwareService.checkForUpdates() }
                    } label: {
                        GlassCard {
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.title2)
                                    .foregroundStyle(ModernColors.purple)
                                Text("Check Updates")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                // Update Alerts
                if !firmwareService.activeAlerts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Updates Available")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(firmwareService.activeAlerts) { alert in
                            GlassCard {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundStyle(ModernColors.orange)

                                    VStack(alignment: .leading) {
                                        Text(alert.deviceName)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Text("\(alert.currentVersion) → \(alert.newVersion)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Button {
                                        firmwareService.dismissAlert(alert)
                                    } label: {
                                        Image(systemName: "xmark.circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                }

                // Compatibility Warnings
                if !firmwareService.compatibilityWarnings.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Compatibility Warnings")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(firmwareService.compatibilityWarnings) { warning in
                            GlassCard {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(ModernColors.yellow)

                                    VStack(alignment: .leading) {
                                        Text(warning.deviceName)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Text(warning.message)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding()
                            }
                        }
                    }
                }

                // All Devices
                VStack(alignment: .leading, spacing: 12) {
                    Text("All Devices")
                        .font(.headline)
                        .foregroundStyle(.white)

                    if firmwareService.firmwareInfo.isEmpty {
                        GlassCard {
                            VStack(spacing: 12) {
                                Image(systemName: "cpu")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                                Text("No devices scanned")
                                    .foregroundStyle(.secondary)
                                Button("Scan Now") {
                                    firmwareService.scanAllDevices()
                                }
                                .foregroundStyle(ModernColors.cyan)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        ForEach(firmwareService.firmwareInfo) { info in
                            GlassCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(info.deviceName)
                                            .font(.headline)
                                            .foregroundStyle(.white)

                                        Text("\(info.manufacturer) • \(info.model)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("v\(info.currentVersion)")
                                            .font(.subheadline)
                                            .foregroundStyle(info.updateAvailable ? ModernColors.orange : ModernColors.accentGreen)

                                        if info.updateAvailable {
                                            Text("Update available")
                                                .font(.caption)
                                                .foregroundStyle(ModernColors.orange)
                                        }
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                }

                // Settings
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $firmwareService.autoCheckEnabled) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(ModernColors.cyan)
                                Text("Auto-check for updates")
                                    .foregroundStyle(.white)
                            }
                        }
                        .tint(ModernColors.cyan)
                        .onChange(of: firmwareService.autoCheckEnabled) { _, newValue in
                            firmwareService.enableAutoCheck(newValue)
                        }

                        if let lastCheck = firmwareService.lastFullCheck {
                            Text("Last checked: \(lastCheck, style: .relative) ago")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
        .background(LinearGradient.modernBackground.ignoresSafeArea())
        .navigationTitle("Firmware")
        .onAppear {
            if firmwareService.firmwareInfo.isEmpty {
                firmwareService.scanAllDevices()
            }
        }
        .overlay {
            if firmwareService.isChecking {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(ModernColors.cyan)
            }
        }
    }
}
