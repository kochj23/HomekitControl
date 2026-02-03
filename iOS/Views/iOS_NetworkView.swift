//
//  iOS_NetworkView.swift
//  HomekitControl
//
//  iOS network discovery view
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct iOS_NetworkView: View {
    @StateObject private var networkService = NetworkDiscoveryService.shared
    @StateObject private var exportService = ExportService.shared
    @State private var searchText = ""
    @State private var selectedFilter: DiscoveryFilter = .all
    @State private var showingExport = false

    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphicBackground()

                if networkService.isScanning && networkService.discoveredDevices.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Scanning network...")
                            .foregroundStyle(.secondary)
                    }
                } else if networkService.discoveredDevices.isEmpty {
                    ContentUnavailableView {
                        Label("No Devices Found", systemImage: "network.slash")
                    } description: {
                        Text("Tap 'Scan' to discover devices on your network.")
                    } actions: {
                        Button("Start Scan") {
                            networkService.startDiscovery()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Filter chips
                            filterSection

                            // Stats card
                            statsCard

                            // Devices list
                            ForEach(filteredDevices) { device in
                                DiscoveredDeviceRow(device: device)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Network")
            .searchable(text: $searchText, prompt: "Search devices")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if networkService.isScanning {
                        Button("Stop") {
                            networkService.stopDiscovery()
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button {
                            networkService.startDiscovery()
                        } label: {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                        }
                        .disabled(networkService.isScanning)

                        Menu {
                            Button("Export JSON") {
                                exportJSON()
                            }
                            Button("Export CSV") {
                                exportCSV()
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(networkService.discoveredDevices.isEmpty)
                    }
                }
            }
            .overlay {
                if !networkService.statusMessage.isEmpty {
                    VStack {
                        Spacer()
                        Text(networkService.statusMessage)
                            .font(.subheadline)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(.bottom, 32)
                    }
                }
            }
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(DiscoveryFilter.allCases, id: \.self) { filter in
                    FilterChip(title: filter.rawValue, isSelected: selectedFilter == filter) {
                        selectedFilter = filter
                    }
                }
            }
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        GlassCard {
            HStack(spacing: 24) {
                StatItem(
                    value: networkService.discoveredDevices.count,
                    label: "Total",
                    color: ModernColors.accent
                )

                StatItem(
                    value: networkService.discoveredDevices.filter { $0.homeKitMatch }.count,
                    label: "HomeKit",
                    color: ModernColors.statusLow
                )

                StatItem(
                    value: Set(networkService.discoveredDevices.map { $0.manufacturer }).count,
                    label: "Brands",
                    color: ModernColors.cyan
                )
            }
            .padding()
        }
    }

    // MARK: - Filtering

    private var filteredDevices: [DiscoveredDevice] {
        var devices = networkService.discoveredDevices

        switch selectedFilter {
        case .all:
            break
        case .homeKit:
            devices = devices.filter { $0.homeKitMatch }
        case .matter:
            devices = devices.filter { $0.protocolType == .matter }
        case .other:
            devices = devices.filter { !$0.homeKitMatch && $0.protocolType != .matter }
        }

        if !searchText.isEmpty {
            devices = devices.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.manufacturer.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }

        return devices.sorted { $0.name < $1.name }
    }

    // MARK: - Export

    private func exportJSON() {
        if let data = exportService.exportDiscoveredDevicesAsJSON(networkService.discoveredDevices) {
            shareData(data, filename: "discovered_devices.json")
        }
    }

    private func exportCSV() {
        let csv = exportService.exportDiscoveredDevicesAsCSV(networkService.discoveredDevices)
        if let data = csv.data(using: .utf8) {
            shareData(data, filename: "discovered_devices.csv")
        }
    }

    private func shareData(_ data: Data, filename: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: tempURL)

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Supporting Types

enum DiscoveryFilter: String, CaseIterable {
    case all = "All"
    case homeKit = "HomeKit"
    case matter = "Matter"
    case other = "Other"
}

// MARK: - Stat Item

struct StatItem: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Discovered Device Row

struct DiscoveredDeviceRow: View {
    let device: DiscoveredDevice

    var body: some View {
        GlassCard {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(device.manufacturer == .unknown ? Color.gray.opacity(0.2) : ModernColors.accent.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: device.deviceType.icon)
                        .font(.title2)
                        .foregroundStyle(device.manufacturer == .unknown ? .secondary : ModernColors.accent)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        Label(device.manufacturer.rawValue, systemImage: device.manufacturer.icon)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if device.homeKitMatch {
                            Label("HomeKit", systemImage: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(ModernColors.statusLow)
                        }
                    }

                    if let ip = device.ipAddress {
                        Text(ip)
                            .font(.caption2)
                            .foregroundStyle(ModernColors.textTertiary)
                    }
                }

                Spacer()

                // Protocol badge
                Text(device.protocolType.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding()
        }
    }
}

#Preview {
    iOS_NetworkView()
}
