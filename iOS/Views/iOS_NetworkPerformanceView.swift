//
//  iOS_NetworkPerformanceView.swift
//  HomekitControl
//
//  Network performance monitor for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct iOS_NetworkPerformanceView: View {
    @StateObject private var networkService = NetworkPerformanceService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overview
                GlassCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Network Health")
                                .font(.headline)
                                .foregroundStyle(.white)

                            HStack(spacing: 4) {
                                Text("\(Int(networkService.networkHealth))%")
                                    .font(.title.bold())
                                Image(systemName: networkService.networkHealth > 80 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            }
                            .foregroundStyle(healthColor)
                        }

                        Spacer()

                        CircularGauge(
                            value: networkService.networkHealth,
                            color: healthColor,
                            lineWidth: 8,
                            size: 70
                        )
                    }
                    .padding()
                }

                // Stats
                HStack(spacing: 12) {
                    NetworkStatCard(
                        title: "Online",
                        value: "\(networkService.reachableDevices.count)",
                        icon: "wifi",
                        color: ModernColors.accentGreen
                    )

                    NetworkStatCard(
                        title: "Offline",
                        value: "\(networkService.unreachableDevices.count)",
                        icon: "wifi.slash",
                        color: ModernColors.red
                    )

                    NetworkStatCard(
                        title: "Avg Latency",
                        value: "\(Int(networkService.averageLatency))ms",
                        icon: "clock",
                        color: ModernColors.cyan
                    )
                }

                // Issues
                if !networkService.activeIssues.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Active Issues")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Spacer()

                            Text("\(networkService.activeIssues.count)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ModernColors.red.opacity(0.3))
                                .clipShape(Capsule())
                                .foregroundStyle(ModernColors.red)
                        }

                        ForEach(networkService.activeIssues) { issue in
                            GlassCard {
                                HStack {
                                    Image(systemName: iconForIssue(issue.issueType))
                                        .foregroundStyle(issue.severity.color)

                                    VStack(alignment: .leading) {
                                        Text(issue.deviceName)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Text(issue.message)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text(issue.severity.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(issue.severity.color.opacity(0.3))
                                        .clipShape(Capsule())
                                        .foregroundStyle(issue.severity.color)
                                }
                                .padding()
                            }
                        }
                    }
                }

                // Worst Performers
                if !networkService.worstPerformers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Slowest Devices")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(networkService.worstPerformers) { device in
                            GlassCard {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundStyle(ModernColors.orange)

                                    Text(device.deviceName)
                                        .font(.subheadline)
                                        .foregroundStyle(.white)

                                    Spacer()

                                    Text("\(Int(device.latency))ms")
                                        .font(.headline)
                                        .foregroundStyle(device.latency > 300 ? ModernColors.red : ModernColors.orange)
                                }
                                .padding()
                            }
                        }
                    }
                }

                // Best Performers
                if !networkService.bestPerformers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Fastest Devices")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(networkService.bestPerformers) { device in
                            GlassCard {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(ModernColors.accentGreen)

                                    Text(device.deviceName)
                                        .font(.subheadline)
                                        .foregroundStyle(.white)

                                    Spacer()

                                    Text("\(Int(device.latency))ms")
                                        .font(.headline)
                                        .foregroundStyle(ModernColors.accentGreen)
                                }
                                .padding()
                            }
                        }
                    }
                }

                // All Devices
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("All Devices")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Spacer()

                        Button {
                            networkService.refreshStatuses()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(ModernColors.cyan)
                        }
                    }

                    ForEach(networkService.deviceStatuses) { device in
                        GlassCard {
                            HStack {
                                Circle()
                                    .fill(device.isReachable ? ModernColors.accentGreen : ModernColors.red)
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading) {
                                    Text(device.deviceName)
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                    Text(device.connectionType.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if device.isReachable {
                                    Text("\(Int(device.latency))ms")
                                        .font(.headline)
                                        .foregroundStyle(latencyColor(device.latency))
                                } else {
                                    Text("Offline")
                                        .font(.caption)
                                        .foregroundStyle(ModernColors.red)
                                }
                            }
                            .padding()
                        }
                    }
                }

                // Settings
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Thresholds")
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack {
                            Text("High Latency")
                            Spacer()
                            Text(">\(Int(networkService.highLatencyThreshold))ms")
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $networkService.highLatencyThreshold, in: 100...1000, step: 50)
                            .tint(ModernColors.cyan)
                    }
                    .padding()
                }
            }
            .padding()
        }
        .background(LinearGradient.modernBackground.ignoresSafeArea())
        .navigationTitle("Network")
        .onAppear {
            networkService.startMonitoring()
        }
    }

    private var healthColor: Color {
        if networkService.networkHealth > 80 { return ModernColors.accentGreen }
        if networkService.networkHealth > 50 { return ModernColors.yellow }
        return ModernColors.red
    }

    private func iconForIssue(_ type: NetworkIssue.IssueType) -> String {
        switch type {
        case .highLatency: return "clock.badge.exclamationmark"
        case .packetLoss: return "wifi.exclamationmark"
        case .unreachable: return "wifi.slash"
        case .weakSignal: return "antenna.radiowaves.left.and.right.slash"
        case .frequentDisconnects: return "arrow.triangle.2.circlepath"
        case .ipConflict: return "exclamationmark.triangle"
        }
    }

    private func latencyColor(_ latency: Double) -> Color {
        if latency < 100 { return ModernColors.accentGreen }
        if latency < 300 { return ModernColors.yellow }
        return ModernColors.red
    }
}

struct NetworkStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        GlassCard {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
}
