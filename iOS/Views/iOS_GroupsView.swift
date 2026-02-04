//
//  iOS_GroupsView.swift
//  HomekitControl
//
//  Device groups and zones management for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

struct iOS_GroupsView: View {
    @StateObject private var groupService = DeviceGroupService.shared
    @StateObject private var homeKitService = HomeKitService.shared
    @State private var showingAddGroup = false
    @State private var selectedGroup: DeviceGroup?

    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphicBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Quick Controls
                        quickControlsSection

                        // Groups
                        groupsSection

                        // Zones
                        zonesSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Groups")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddGroup = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddGroup) {
                AddGroupSheet()
            }
            .sheet(item: $selectedGroup) { group in
                GroupDetailSheet(group: group)
            }
        }
    }

    private var quickControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Controls")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickGroupButton(title: "All Lights On", icon: "lightbulb.fill", color: ModernColors.yellow) {
                    Task {
                        for group in groupService.groups where group.name.lowercased().contains("light") {
                            try? await groupService.turnOnGroup(group)
                        }
                    }
                }

                QuickGroupButton(title: "All Lights Off", icon: "lightbulb.slash", color: ModernColors.textTertiary) {
                    Task {
                        for group in groupService.groups where group.name.lowercased().contains("light") {
                            try? await groupService.turnOffGroup(group)
                        }
                    }
                }
            }
        }
    }

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Groups")
                .font(.headline)
                .foregroundStyle(.white)

            if groupService.groups.isEmpty {
                GlassCard {
                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.3.group")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No groups created")
                            .foregroundStyle(.secondary)
                        Button("Create Group") {
                            showingAddGroup = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(groupService.groups) { group in
                    GroupCard(group: group) {
                        selectedGroup = group
                    }
                }
            }
        }
    }

    private var zonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Zones")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    _ = groupService.createZone(name: "New Zone")
                } label: {
                    Image(systemName: "plus")
                }
            }

            if groupService.zones.isEmpty {
                GlassCard {
                    Text("Zones let you organize groups by floor or area")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(groupService.zones) { zone in
                    GlassCard {
                        HStack {
                            Image(systemName: zone.icon)
                                .foregroundStyle(ModernColors.purple)
                            Text(zone.name)
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(zone.groupIds.count) groups")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                }
            }
        }
    }
}

// MARK: - Group Card

struct GroupCard: View {
    let group: DeviceGroup
    let onTap: () -> Void
    @StateObject private var groupService = DeviceGroupService.shared

    var body: some View {
        Button(action: onTap) {
            GlassCard {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: group.icon)
                            .font(.title2)
                            .foregroundStyle(colorFromString(group.color))

                        VStack(alignment: .leading) {
                            Text(group.name)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("\(group.deviceCount) devices")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { group.isEnabled },
                            set: { _ in
                                var updated = group
                                updated.isEnabled.toggle()
                                groupService.updateGroup(updated)
                            }
                        ))
                        .labelsHidden()
                        .tint(ModernColors.accent)
                    }

                    // Quick Actions
                    HStack(spacing: 12) {
                        Button {
                            Task { try? await groupService.turnOnGroup(group) }
                        } label: {
                            Label("On", systemImage: "power")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(ModernColors.accentGreen)

                        Button {
                            Task { try? await groupService.turnOffGroup(group) }
                        } label: {
                            Label("Off", systemImage: "power")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(ModernColors.red)
                    }
                }
                .padding()
            }
        }
        .buttonStyle(.plain)
    }

    private func colorFromString(_ name: String) -> Color {
        switch name.lowercased() {
        case "cyan": return ModernColors.cyan
        case "magenta": return ModernColors.magenta
        case "yellow": return ModernColors.yellow
        case "green": return ModernColors.accentGreen
        case "red": return ModernColors.red
        case "purple": return ModernColors.purple
        default: return ModernColors.cyan
        }
    }
}

// MARK: - Quick Group Button

struct QuickGroupButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Group Sheet

struct AddGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var groupService = DeviceGroupService.shared
    @StateObject private var homeKitService = HomeKitService.shared

    @State private var name = ""
    @State private var icon = "rectangle.3.group.fill"
    @State private var color = "cyan"
    @State private var selectedDevices: Set<UUID> = []

    let icons = ["rectangle.3.group.fill", "lightbulb.fill", "switch.2", "fan.fill", "tv.fill", "speaker.wave.2.fill"]
    let colors = ["cyan", "magenta", "yellow", "green", "purple", "red"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Group Details") {
                    TextField("Name", text: $name)

                    Picker("Icon", selection: $icon) {
                        ForEach(icons, id: \.self) { iconName in
                            Image(systemName: iconName).tag(iconName)
                        }
                    }

                    Picker("Color", selection: $color) {
                        ForEach(colors, id: \.self) { colorName in
                            Text(colorName.capitalized).tag(colorName)
                        }
                    }
                }

                Section("Devices (\(selectedDevices.count) selected)") {
                    #if canImport(HomeKit)
                    ForEach(homeKitService.accessories, id: \.uniqueIdentifier) { accessory in
                        HStack {
                            Text(accessory.name)
                            Spacer()
                            if selectedDevices.contains(accessory.uniqueIdentifier) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(ModernColors.accent)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedDevices.contains(accessory.uniqueIdentifier) {
                                selectedDevices.remove(accessory.uniqueIdentifier)
                            } else {
                                selectedDevices.insert(accessory.uniqueIdentifier)
                            }
                        }
                    }
                    #endif
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        var group = groupService.createGroup(name: name.isEmpty ? "New Group" : name, icon: icon, color: color)
                        group.deviceIds = Array(selectedDevices)
                        groupService.updateGroup(group)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Group Detail Sheet

struct GroupDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var groupService = DeviceGroupService.shared

    let group: DeviceGroup
    @State private var brightness: Double = 50

    var body: some View {
        NavigationStack {
            Form {
                Section("Controls") {
                    HStack {
                        Button {
                            Task { try? await groupService.turnOnGroup(group) }
                        } label: {
                            Label("All On", systemImage: "power")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ModernColors.accentGreen)

                        Button {
                            Task { try? await groupService.turnOffGroup(group) }
                        } label: {
                            Label("All Off", systemImage: "power")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ModernColors.red)
                    }

                    VStack(alignment: .leading) {
                        Text("Group Brightness: \(Int(brightness))%")
                        Slider(value: $brightness, in: 0...100, step: 5) { _ in
                            Task {
                                try? await groupService.setGroupBrightness(group, brightness: Int(brightness))
                            }
                        }
                    }
                }

                Section("Devices (\(group.deviceCount))") {
                    #if canImport(HomeKit)
                    let devices = groupService.getDevicesInGroup(group)
                    ForEach(devices, id: \.uniqueIdentifier) { device in
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(device.isReachable ? ModernColors.accent : .secondary)
                            Text(device.name)
                            Spacer()
                            Text(device.isReachable ? "Online" : "Offline")
                                .font(.caption)
                                .foregroundStyle(device.isReachable ? ModernColors.accentGreen : ModernColors.red)
                        }
                    }
                    #endif
                }

                Section {
                    Button("Delete Group", role: .destructive) {
                        groupService.deleteGroup(group)
                        dismiss()
                    }
                }
            }
            .navigationTitle(group.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    iOS_GroupsView()
}
