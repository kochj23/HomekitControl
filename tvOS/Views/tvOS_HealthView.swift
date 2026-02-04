//
//  tvOS_HealthView.swift
//  HomekitControl
//
//  Device health dashboard for tvOS with 10-foot UI
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

struct tvOS_HealthView: View {
    @StateObject private var healthService = DeviceHealthService.shared
    @StateObject private var homeKitService = HomeKitService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 60) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Device Health")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.white)

                        Text("\(homeKitService.accessories.count) devices monitored")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "heart.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(ModernColors.magenta)
                }
                .padding(.horizontal, 80)

                // Health Summary
                let healthCounts = getHealthCounts()
                HStack(spacing: 40) {
                    TVHealthStatCard(
                        count: healthCounts.healthy,
                        label: "Healthy",
                        icon: "checkmark.circle.fill",
                        color: ModernColors.accentGreen
                    )

                    TVHealthStatCard(
                        count: healthCounts.warning,
                        label: "Warning",
                        icon: "exclamationmark.triangle.fill",
                        color: ModernColors.yellow
                    )

                    TVHealthStatCard(
                        count: healthCounts.critical,
                        label: "Critical",
                        icon: "xmark.circle.fill",
                        color: ModernColors.red
                    )

                    TVHealthStatCard(
                        count: healthCounts.unknown,
                        label: "Unknown",
                        icon: "questionmark.circle.fill",
                        color: .secondary
                    )
                }
                .padding(.horizontal, 80)

                // Devices by Health Status
                let criticalDevices = getDevicesByStatus(.critical)
                if !criticalDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(ModernColors.red)
                            Text("Critical Issues")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 80)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 30),
                            GridItem(.flexible(), spacing: 30),
                            GridItem(.flexible(), spacing: 30),
                            GridItem(.flexible(), spacing: 30)
                        ], spacing: 30) {
                            ForEach(criticalDevices, id: \.uniqueIdentifier) { accessory in
                                TVHealthDeviceCard(
                                    accessory: accessory,
                                    healthInfo: healthService.healthRecords[accessory.uniqueIdentifier]
                                )
                            }
                        }
                        .padding(.horizontal, 80)
                    }
                }

                // Warning Devices
                let warningDevices = getDevicesByStatus(.warning)
                if !warningDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(ModernColors.yellow)
                            Text("Warnings")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 80)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 30),
                            GridItem(.flexible(), spacing: 30),
                            GridItem(.flexible(), spacing: 30),
                            GridItem(.flexible(), spacing: 30)
                        ], spacing: 30) {
                            ForEach(warningDevices, id: \.uniqueIdentifier) { accessory in
                                TVHealthDeviceCard(
                                    accessory: accessory,
                                    healthInfo: healthService.healthRecords[accessory.uniqueIdentifier]
                                )
                            }
                        }
                        .padding(.horizontal, 80)
                    }
                }

                // All Devices
                VStack(alignment: .leading, spacing: 24) {
                    Text("All Devices")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 80)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 30),
                        GridItem(.flexible(), spacing: 30),
                        GridItem(.flexible(), spacing: 30),
                        GridItem(.flexible(), spacing: 30)
                    ], spacing: 30) {
                        ForEach(homeKitService.accessories, id: \.uniqueIdentifier) { accessory in
                            TVHealthDeviceCard(
                                accessory: accessory,
                                healthInfo: healthService.healthRecords[accessory.uniqueIdentifier]
                            )
                        }
                    }
                    .padding(.horizontal, 80)
                }
            }
            .padding(.vertical, 60)
        }
        .onAppear {
            healthService.startMonitoring()
        }
    }

    private func getHealthCounts() -> (healthy: Int, warning: Int, critical: Int, unknown: Int) {
        var healthy = 0, warning = 0, critical = 0, unknown = 0

        for accessory in homeKitService.accessories {
            let status = healthService.getHealthStatus(for: accessory.uniqueIdentifier)
            switch status {
            case .healthy: healthy += 1
            case .warning, .degraded: warning += 1
            case .critical, .unreachable: critical += 1
            case .unknown, .testing: unknown += 1
            }
        }

        return (healthy, warning, critical, unknown)
    }

    private func getDevicesByStatus(_ status: HealthStatus) -> [HMAccessory] {
        homeKitService.accessories.filter {
            healthService.getHealthStatus(for: $0.uniqueIdentifier) == status
        }
    }
}

// MARK: - TV Health Stat Card

struct TVHealthStatCard: View {
    let count: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(color)

                Text("\(count)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)

                Text(label)
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .padding(30)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - TV Health Device Card

struct TVHealthDeviceCard: View {
    let accessory: HMAccessory
    let healthInfo: DeviceHealthInfo?
    @FocusState private var isFocused: Bool

    var body: some View {
        Button { } label: {
            GlassCard {
                VStack(spacing: 12) {
                    HStack {
                        Spacer()
                        Circle()
                            .fill((healthInfo?.status ?? .unknown).color)
                            .frame(width: 14, height: 14)
                    }

                    Image(systemName: accessory.isReachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(accessory.isReachable ? ModernColors.accentGreen : ModernColors.red)

                    Text(accessory.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text(accessory.isReachable ? "Online" : "Offline")
                        .font(.system(size: 14))
                        .foregroundStyle(accessory.isReachable ? ModernColors.accentGreen : ModernColors.red)

                    if let health = healthInfo {
                        Text(String(format: "%.0f%% uptime", health.uptimePercentage))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.card)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

#Preview {
    tvOS_HealthView()
}
