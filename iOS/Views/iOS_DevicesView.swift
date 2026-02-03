//
//  iOS_DevicesView.swift
//  HomekitControl
//
//  iOS device list and control view
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

struct iOS_DevicesView: View {
    @StateObject private var homeKitService = HomeKitService.shared
    @StateObject private var healthService = DeviceHealthService.shared
    @State private var searchText = ""
    @State private var selectedRoom: String? = nil
    @State private var showingDetail = false
    @State private var selectedAccessory: HMAccessory?

    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphicBackground()

                if homeKitService.isLoading {
                    ProgressView("Loading devices...")
                        .foregroundStyle(.white)
                } else if homeKitService.accessories.isEmpty {
                    ContentUnavailableView {
                        Label("No Devices", systemImage: "lightbulb.slash")
                    } description: {
                        Text("No HomeKit devices found in your home.")
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Room filter
                            roomFilterSection

                            // Devices grid
                            devicesGrid
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Devices")
            .searchable(text: $searchText, prompt: "Search devices")
            .refreshable {
                await homeKitService.refreshAll()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Test All Devices") {
                            Task {
                                if let home = homeKitService.currentHome {
                                    await healthService.testAllDevices(in: home)
                                }
                            }
                        }
                        Button("Refresh") {
                            Task { await homeKitService.refreshAll() }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    // MARK: - Room Filter

    private var roomFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(title: "All", isSelected: selectedRoom == nil) {
                    selectedRoom = nil
                }

                ForEach(homeKitService.rooms, id: \.uniqueIdentifier) { room in
                    FilterChip(title: room.name, isSelected: selectedRoom == room.name) {
                        selectedRoom = room.name
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Devices Grid

    private var devicesGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            ForEach(filteredAccessories, id: \.uniqueIdentifier) { accessory in
                DeviceCard(
                    accessory: accessory,
                    healthStatus: healthService.getHealthStatus(for: accessory.uniqueIdentifier)
                ) {
                    Task {
                        try? await homeKitService.toggleAccessory(accessory)
                    }
                }
            }
        }
    }

    // MARK: - Filtering

    private var filteredAccessories: [HMAccessory] {
        var accessories = homeKitService.accessories

        if let room = selectedRoom {
            accessories = accessories.filter { $0.room?.name == room }
        }

        if !searchText.isEmpty {
            accessories = accessories.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        return accessories
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(isSelected ? ModernColors.accent : Color.white.opacity(0.1))
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Device Card

struct DeviceCard: View {
    let accessory: HMAccessory
    let healthStatus: HealthStatus
    let onToggle: () -> Void

    @State private var isOn = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: iconForAccessory)
                        .font(.title2)
                        .foregroundStyle(isOn ? ModernColors.accent : .secondary)

                    Spacer()

                    Circle()
                        .fill(healthStatus.color)
                        .frame(width: 8, height: 8)
                }

                Text(accessory.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let room = accessory.room {
                    Text(room.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack {
                    Text(isOn ? "On" : "Off")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Toggle("", isOn: $isOn)
                        .labelsHidden()
                        .tint(ModernColors.accent)
                        .onChange(of: isOn) { _, _ in
                            onToggle()
                        }
                }
            }
            .padding()
        }
        .frame(height: 160)
        .onAppear {
            updateState()
        }
    }

    private var iconForAccessory: String {
        let category = DeviceCategory.other // Default
        if accessory.services.contains(where: { $0.serviceType == HMServiceTypeLightbulb }) {
            return DeviceCategory.light.icon
        }
        if accessory.services.contains(where: { $0.serviceType == HMServiceTypeSwitch }) {
            return DeviceCategory.switchDevice.icon
        }
        if accessory.services.contains(where: { $0.serviceType == HMServiceTypeOutlet }) {
            return DeviceCategory.outlet.icon
        }
        if accessory.services.contains(where: { $0.serviceType == HMServiceTypeThermostat }) {
            return DeviceCategory.thermostat.icon
        }
        if accessory.services.contains(where: { $0.serviceType == HMServiceTypeLockMechanism }) {
            return DeviceCategory.lock.icon
        }
        return category.icon
    }

    private func updateState() {
        if let service = accessory.services.first(where: { $0.serviceType == HMServiceTypeLightbulb || $0.serviceType == HMServiceTypeSwitch }),
           let powerChar = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypePowerState }) {
            isOn = powerChar.value as? Bool ?? false
        }
    }
}

#Preview {
    iOS_DevicesView()
}
