//
//  iOS_HealthDashboardView.swift
//  HomekitControl
//
//  Expanded device health dashboard for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import Charts
#if canImport(HomeKit)
import HomeKit
#endif

struct iOS_HealthDashboardView: View {
    @StateObject private var healthService = DeviceHealthService.shared
    @StateObject private var homeKitService = HomeKitService.shared
    @State private var selectedDevice: HMAccessory?
    @State private var isTestingAll = false

    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphicBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Overview Stats
                        overviewSection

                        // Problem Devices
                        problemDevicesSection

                        // Battery Status
                        batterySection

                        // All Devices Health
                        allDevicesSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Device Health")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            isTestingAll = true
                            if let home = homeKitService.currentHome {
                                await healthService.testAllDevices(in: home)
                            }
                            isTestingAll = false
                        }
                    } label: {
                        if isTestingAll {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(isTestingAll)
                }
            }
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                HealthStatCard(
                    value: "\(homeKitService.accessories.filter { $0.isReachable }.count)",
                    total: "\(homeKitService.accessories.count)",
                    label: "Online",
                    icon: "checkmark.circle.fill",
                    color: ModernColors.accentGreen
                )

                HealthStatCard(
                    value: "\(homeKitService.accessories.filter { !$0.isReachable }.count)",
                    total: nil,
                    label: "Offline",
                    icon: "xmark.circle.fill",
                    color: ModernColors.red
                )

                HealthStatCard(
                    value: "\(warningDeviceCount)",
                    total: nil,
                    label: "Warnings",
                    icon: "exclamationmark.triangle.fill",
                    color: ModernColors.statusHigh
                )

                HealthStatCard(
                    value: String(format: "%.0f%%", averageHealth),
                    total: nil,
                    label: "Avg Health",
                    icon: "heart.fill",
                    color: healthColor(for: averageHealth / 100)
                )
            }
        }
    }

    private var warningDeviceCount: Int {
        homeKitService.accessories.filter { accessory in
            let status = healthService.getHealthStatus(for: accessory.uniqueIdentifier)
            return status == .degraded
        }.count
    }

    private var averageHealth: Double {
        let records = healthService.deviceHealth.values
        guard !records.isEmpty else { return 100 }
        let total = records.reduce(0.0) { $0 + $1.reliabilityScore }
        return total / Double(records.count)
    }

    private var problemDevicesSection: some View {
        let problemDevices = homeKitService.accessories.filter { accessory in
            let status = healthService.getHealthStatus(for: accessory.uniqueIdentifier)
            return status == .unreachable || status == .degraded || !accessory.isReachable
        }

        return Group {
            if !problemDevices.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Problem Devices", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(ModernColors.statusHigh)

                    ForEach(problemDevices, id: \.uniqueIdentifier) { device in
                        ProblemDeviceCard(device: device)
                    }
                }
            }
        }
    }

    private var batterySection: some View {
        let devicesWithBattery = homeKitService.accessories.filter { accessory in
            accessory.services.contains { service in
                service.characteristics.contains { $0.characteristicType == HMCharacteristicTypeBatteryLevel }
            }
        }

        return Group {
            if !devicesWithBattery.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Battery Status", systemImage: "battery.100")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(devicesWithBattery, id: \.uniqueIdentifier) { device in
                        BatteryDeviceCard(device: device)
                    }
                }
            }
        }
    }

    private var allDevicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Devices")
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(homeKitService.accessories.sorted { $0.name < $1.name }, id: \.uniqueIdentifier) { device in
                DeviceHealthCard(device: device)
            }
        }
    }

    private func healthColor(for percentage: Double) -> Color {
        switch percentage {
        case 0..<0.25: return ModernColors.statusCritical
        case 0.25..<0.5: return ModernColors.statusHigh
        case 0.5..<0.75: return ModernColors.statusMedium
        default: return ModernColors.statusLow
        }
    }
}

// MARK: - Health Stat Card

struct HealthStatCard: View {
    let value: String
    let total: String?
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        GlassCard {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    if let total = total {
                        Text("/\(total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

// MARK: - Problem Device Card

struct ProblemDeviceCard: View {
    let device: HMAccessory
    @StateObject private var healthService = DeviceHealthService.shared

    var body: some View {
        let status = healthService.getHealthStatus(for: device.uniqueIdentifier)
        let record = healthService.deviceHealth[device.uniqueIdentifier]

        GlassCard {
            HStack {
                Circle()
                    .fill(status.color)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading) {
                    Text(device.name)
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        if !device.isReachable {
                            Label("Offline", systemImage: "wifi.slash")
                                .font(.caption)
                                .foregroundStyle(ModernColors.red)
                        }

                        if let responseTime = record?.averageResponseTime, responseTime > 2000 {
                            Label("Slow (\(Int(responseTime))ms)", systemImage: "tortoise.fill")
                                .font(.caption)
                                .foregroundStyle(ModernColors.statusHigh)
                        }

                        let failures = record?.testHistory.filter { !$0.success }.count ?? 0
                        if failures > 0 {
                            Label("\(failures) failures", systemImage: "xmark.circle")
                                .font(.caption)
                                .foregroundStyle(ModernColors.red)
                        }
                    }
                }

                Spacer()

                CircularGauge(
                    value: record?.reliabilityScore ?? 100,
                    color: status.color,
                    lineWidth: 4,
                    size: 40
                )
            }
            .padding()
        }
    }
}

// MARK: - Battery Device Card

struct BatteryDeviceCard: View {
    let device: HMAccessory
    @State private var batteryLevel: Int = 100

    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: batteryIcon)
                    .foregroundStyle(batteryColor)

                Text(device.name)
                    .foregroundStyle(.white)

                Spacer()

                Text("\(batteryLevel)%")
                    .font(.headline)
                    .foregroundStyle(batteryColor)
            }
            .padding()
        }
        .onAppear {
            loadBatteryLevel()
        }
    }

    private func loadBatteryLevel() {
        for service in device.services {
            for characteristic in service.characteristics {
                if characteristic.characteristicType == HMCharacteristicTypeBatteryLevel {
                    characteristic.readValue { error in
                        if error == nil, let value = characteristic.value as? Int {
                            batteryLevel = value
                        }
                    }
                }
            }
        }
    }

    private var batteryIcon: String {
        switch batteryLevel {
        case 0..<10: return "battery.0"
        case 10..<25: return "battery.25"
        case 25..<50: return "battery.50"
        case 50..<75: return "battery.75"
        default: return "battery.100"
        }
    }

    private var batteryColor: Color {
        switch batteryLevel {
        case 0..<20: return ModernColors.red
        case 20..<50: return ModernColors.statusHigh
        default: return ModernColors.accentGreen
        }
    }
}

// MARK: - Device Health Card

struct DeviceHealthCard: View {
    let device: HMAccessory
    @StateObject private var healthService = DeviceHealthService.shared

    var body: some View {
        let status = healthService.getHealthStatus(for: device.uniqueIdentifier)
        let record = healthService.deviceHealth[device.uniqueIdentifier]

        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(device.isReachable ? ModernColors.accentGreen : ModernColors.red)
                            .frame(width: 8, height: 8)

                        Text(device.name)
                            .foregroundStyle(.white)
                    }

                    HStack(spacing: 12) {
                        if let manufacturer = device.manufacturer {
                            Text(manufacturer)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let responseTime = record?.averageResponseTime {
                            Text("\(Int(responseTime))ms")
                                .font(.caption)
                                .foregroundStyle(responseTime > 1000 ? ModernColors.statusHigh : .secondary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing) {
                    CircularGauge(
                        value: record?.reliabilityScore ?? 100,
                        color: status.color,
                        lineWidth: 4,
                        size: 36
                    )

                    Text(status.rawValue)
                        .font(.caption2)
                        .foregroundStyle(status.color)
                }
            }
            .padding()
        }
    }
}

#Preview {
    iOS_HealthDashboardView()
}
