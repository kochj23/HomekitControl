//
//  iOS_DeviceComparisonView.swift
//  HomekitControl
//
//  Device comparison view for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct iOS_DeviceComparisonView: View {
    @StateObject private var comparisonService = DeviceComparisonService.shared
    @State private var selectedComparisonType: DeviceComparison.ComparisonType = .energy
    @State private var showDeviceSelector = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                GlassCard {
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Device Comparison")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Compare device performance")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "arrow.left.arrow.right")
                                .font(.title)
                                .foregroundStyle(ModernColors.yellow)
                        }

                        // Comparison type picker
                        Picker("Type", selection: $selectedComparisonType) {
                            ForEach(DeviceComparison.ComparisonType.allCases, id: \.self) { type in
                                Label(type.rawValue, systemImage: type.icon)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                }

                // Selected Devices
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Selected Devices (\(comparisonService.selectedDevices.count)/4)")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Spacer()

                        Button {
                            showDeviceSelector = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(ModernColors.cyan)
                        }
                    }

                    if comparisonService.selectedDevices.isEmpty {
                        GlassCard {
                            VStack(spacing: 12) {
                                Image(systemName: "plus.square.dashed")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                                Text("Select devices to compare")
                                    .foregroundStyle(.secondary)
                                Button("Add Devices") {
                                    showDeviceSelector = true
                                }
                                .font(.subheadline)
                                .foregroundStyle(ModernColors.cyan)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(comparisonService.selectedDevices) { device in
                                GlassCard {
                                    VStack(spacing: 8) {
                                        HStack {
                                            Spacer()
                                            Button {
                                                comparisonService.deselectDevice(device)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Text(device.name)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.white)
                                            .lineLimit(1)

                                        Text(device.manufacturer)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        // Score based on selected type
                                        let score = scoreFor(device)
                                        CircularGauge(
                                            value: score,
                                            color: colorForScore(score),
                                            lineWidth: 4,
                                            size: 50
                                        )
                                    }
                                    .padding()
                                }
                            }
                        }
                    }
                }

                // Compare Button
                if comparisonService.selectedDevices.count >= 2 {
                    Button {
                        Task {
                            await comparisonService.compare(type: selectedComparisonType)
                        }
                    } label: {
                        HStack {
                            if comparisonService.isComparing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "chart.bar.fill")
                            }
                            Text(comparisonService.isComparing ? "Comparing..." : "Compare Devices")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ModernColors.cyan)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(comparisonService.isComparing)
                }

                // Current Comparison Results
                if let comparison = comparisonService.currentComparison {
                    ComparisonResultsSection(comparison: comparison)
                }

                // Previous Comparisons
                if !comparisonService.comparisons.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Comparisons")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(comparisonService.comparisons.prefix(5)) { comparison in
                            GlassCard {
                                HStack {
                                    Image(systemName: comparison.comparisonType.icon)
                                        .foregroundStyle(comparison.comparisonType.color)

                                    VStack(alignment: .leading) {
                                        Text(comparison.comparisonType.rawValue)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Text("\(comparison.devices.count) devices")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text(comparison.comparisonDate, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                            }
                            .onTapGesture {
                                comparisonService.currentComparison = comparison
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(LinearGradient.modernBackground.ignoresSafeArea())
        .navigationTitle("Compare")
        .sheet(isPresented: $showDeviceSelector) {
            DeviceSelectorView()
        }
    }

    private func scoreFor(_ device: ComparedDevice) -> Double {
        switch selectedComparisonType {
        case .energy: return device.energyScore
        case .reliability: return device.reliabilityScore
        case .responsiveness: return device.responsivenessScore
        case .cost: return device.overallScore
        }
    }

    private func colorForScore(_ score: Double) -> Color {
        if score >= 80 { return ModernColors.accentGreen }
        if score >= 50 { return ModernColors.yellow }
        return ModernColors.red
    }
}

struct ComparisonResultsSection: View {
    let comparison: DeviceComparison
    @StateObject private var comparisonService = DeviceComparisonService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Results: \(comparison.comparisonType.rawValue)")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: comparison.comparisonType.icon)
                    .foregroundStyle(comparison.comparisonType.color)
            }

            // Winner
            if let winner = comparisonService.getWinner(comparison) {
                GlassCard {
                    HStack {
                        Image(systemName: "trophy.fill")
                            .font(.title2)
                            .foregroundStyle(ModernColors.yellow)

                        VStack(alignment: .leading) {
                            Text("Winner")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(winner.name)
                                .font(.headline)
                                .foregroundStyle(.white)
                        }

                        Spacer()

                        let score = getScore(winner)
                        CircularGauge(
                            value: score,
                            color: ModernColors.accentGreen,
                            lineWidth: 6,
                            size: 60
                        )
                    }
                    .padding()
                }
            }

            // Metrics
            let results = comparisonService.getComparisonResults(comparison)
            ForEach(results) { result in
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.metric)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)

                        ForEach(result.values, id: \.device.id) { item in
                            HStack {
                                Text(item.device.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)

                                Spacer()

                                Text(formatValue(item.value, unit: result.unit))
                                    .font(.headline)
                                    .foregroundStyle(item.device.id == result.winner?.id ? ModernColors.accentGreen : .white)

                                if item.device.id == result.winner?.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(ModernColors.accentGreen)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }

            // Recommendation
            GlassCard {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(ModernColors.yellow)

                    Text(comparisonService.getRecommendation(for: comparison))
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                .padding()
            }
        }
    }

    private func getScore(_ device: ComparedDevice) -> Double {
        switch comparison.comparisonType {
        case .energy: return device.energyScore
        case .reliability: return device.reliabilityScore
        case .responsiveness: return device.responsivenessScore
        case .cost: return device.overallScore
        }
    }

    private func formatValue(_ value: Double, unit: String) -> String {
        if unit == "$" {
            return String(format: "$%.2f", value)
        } else if unit == "%" {
            return String(format: "%.1f%%", value)
        } else if unit.isEmpty {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f %@", value, unit)
        }
    }
}

struct DeviceSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var comparisonService = DeviceComparisonService.shared

    var body: some View {
        NavigationStack {
            List {
                ForEach(comparisonService.availableDevices) { device in
                    let isSelected = comparisonService.selectedDevices.contains { $0.id == device.id }

                    Button {
                        if isSelected {
                            comparisonService.deselectDevice(device)
                        } else {
                            comparisonService.selectDevice(device)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.name)
                                    .foregroundStyle(.primary)
                                Text("\(device.manufacturer) • \(device.category)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(ModernColors.cyan)
                            }
                        }
                    }
                    .disabled(!isSelected && comparisonService.selectedDevices.count >= 4)
                }
            }
            .navigationTitle("Select Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear") {
                        comparisonService.clearSelection()
                    }
                }
            }
        }
    }
}
