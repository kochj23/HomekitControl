//
//  iOS_GuestModeView.swift
//  HomekitControl
//
//  Guest access management for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

struct iOS_GuestModeView: View {
    @StateObject private var guestService = GuestModeService.shared
    @StateObject private var homeKitService = HomeKitService.shared
    @State private var showingAddGuest = false
    @State private var selectedGuest: GuestAccess?
    @State private var showingActivityLogs = false

    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphicBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Guest Mode Status
                        if guestService.isGuestModeActive {
                            activeGuestCard
                        }

                        // Guests List
                        guestsSection

                        // Activity Logs
                        activitySection
                    }
                    .padding()
                }
            }
            .navigationTitle("Guest Access")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddGuest = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddGuest) {
                AddGuestSheet()
            }
            .sheet(item: $selectedGuest) { guest in
                GuestDetailSheet(guest: guest)
            }
            .sheet(isPresented: $showingActivityLogs) {
                ActivityLogsSheet()
            }
        }
    }

    private var activeGuestCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "person.badge.clock.fill")
                        .font(.title)
                        .foregroundStyle(ModernColors.accentGreen)

                    VStack(alignment: .leading) {
                        Text("Guest Mode Active")
                            .font(.headline)
                            .foregroundStyle(.white)

                        if let guest = guestService.currentGuest {
                            Text(guest.name)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }

                Button {
                    guestService.endGuestSession()
                } label: {
                    Text("End Guest Session")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(ModernColors.red)
            }
            .padding()
        }
    }

    private var guestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Guest Accounts")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text("\(guestService.guests.filter { $0.isValid }.count) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if guestService.guests.isEmpty {
                GlassCard {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No guests")
                            .foregroundStyle(.secondary)
                        Button("Add Guest") {
                            showingAddGuest = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(guestService.guests) { guest in
                    Button {
                        selectedGuest = guest
                    } label: {
                        GuestCard(guest: guest)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button("View All") {
                    showingActivityLogs = true
                }
                .font(.caption)
            }

            if guestService.activityLogs.isEmpty {
                GlassCard {
                    Text("No activity logged")
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(guestService.activityLogs.prefix(5)) { log in
                    ActivityLogCard(log: log)
                }
            }
        }
    }
}

// MARK: - Guest Card

struct GuestCard: View {
    let guest: GuestAccess

    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: guest.isValid ? "person.fill.checkmark" : "person.fill.xmark")
                    .foregroundStyle(guest.isValid ? ModernColors.accentGreen : ModernColors.red)

                VStack(alignment: .leading, spacing: 4) {
                    Text(guest.name)
                        .foregroundStyle(.white)

                    HStack {
                        Text("Code: \(guest.accessCode)")
                            .font(.caption)
                            .foregroundStyle(ModernColors.cyan)

                        if let expires = guest.expiresAt {
                            Text("• Expires \(expires, style: .relative)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("\(guest.allowedDeviceIds.count)")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("devices")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

// MARK: - Activity Log Card

struct ActivityLogCard: View {
    let log: GuestActivityLog

    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(log.guestName)
                            .font(.subheadline)
                            .foregroundStyle(.white)

                        Text("•")
                            .foregroundStyle(.secondary)

                        Text(log.action)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let device = log.deviceName {
                        Text(device)
                            .font(.caption)
                            .foregroundStyle(ModernColors.cyan)
                    }
                }

                Spacer()

                Text(log.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
    }
}

// MARK: - Add Guest Sheet

struct AddGuestSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var guestService = GuestModeService.shared
    @StateObject private var homeKitService = HomeKitService.shared

    @State private var name = ""
    @State private var expiresIn: ExpirationOption = .oneDay
    @State private var selectedDevices: Set<UUID> = []
    @State private var selectedScenes: Set<UUID> = []

    enum ExpirationOption: String, CaseIterable {
        case oneHour = "1 Hour"
        case fourHours = "4 Hours"
        case oneDay = "1 Day"
        case oneWeek = "1 Week"
        case never = "Never"

        var interval: TimeInterval? {
            switch self {
            case .oneHour: return 3600
            case .fourHours: return 14400
            case .oneDay: return 86400
            case .oneWeek: return 604800
            case .never: return nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Guest Info") {
                    TextField("Name", text: $name)

                    Picker("Access Expires", selection: $expiresIn) {
                        ForEach(ExpirationOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                }

                Section("Allowed Devices (\(selectedDevices.count))") {
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

                Section("Allowed Scenes (\(selectedScenes.count))") {
                    #if canImport(HomeKit)
                    ForEach(homeKitService.scenes, id: \.uniqueIdentifier) { scene in
                        HStack {
                            Text(scene.name)
                            Spacer()
                            if selectedScenes.contains(scene.uniqueIdentifier) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(ModernColors.accent)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedScenes.contains(scene.uniqueIdentifier) {
                                selectedScenes.remove(scene.uniqueIdentifier)
                            } else {
                                selectedScenes.insert(scene.uniqueIdentifier)
                            }
                        }
                    }
                    #endif
                }
            }
            .navigationTitle("New Guest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        var guest = guestService.createGuest(
                            name: name.isEmpty ? "Guest" : name,
                            expiresIn: expiresIn.interval
                        )
                        for deviceId in selectedDevices {
                            guestService.addDeviceToGuest(deviceId, guest: guest)
                        }
                        for sceneId in selectedScenes {
                            guestService.addSceneToGuest(sceneId, guest: guest)
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Guest Detail Sheet

struct GuestDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var guestService = GuestModeService.shared

    let guest: GuestAccess

    var body: some View {
        NavigationStack {
            Form {
                Section("Guest Info") {
                    LabeledContent("Name", value: guest.name)
                    LabeledContent("Access Code", value: guest.accessCode)
                    LabeledContent("Status", value: guest.isValid ? "Active" : "Expired")
                    LabeledContent("Created", value: guest.createdAt, format: .dateTime)

                    if let expires = guest.expiresAt {
                        LabeledContent("Expires", value: expires, format: .dateTime)
                    }
                }

                Section("Usage") {
                    LabeledContent("Times Used", value: "\(guest.usageCount)")
                    if let lastUsed = guest.lastUsed {
                        LabeledContent("Last Used", value: lastUsed, format: .dateTime)
                    }
                }

                Section("Access") {
                    LabeledContent("Devices", value: "\(guest.allowedDeviceIds.count)")
                    LabeledContent("Scenes", value: "\(guest.allowedSceneIds.count)")
                }

                Section {
                    Button("Regenerate Code") {
                        guestService.regenerateCode(for: guest)
                    }

                    Button("Extend Access (+1 day)") {
                        guestService.extendAccess(for: guest, by: 86400)
                    }

                    Button("Delete Guest", role: .destructive) {
                        guestService.deleteGuest(guest)
                        dismiss()
                    }
                }
            }
            .navigationTitle(guest.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Activity Logs Sheet

struct ActivityLogsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var guestService = GuestModeService.shared

    var body: some View {
        NavigationStack {
            List {
                ForEach(guestService.activityLogs) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(log.guestName)
                                .fontWeight(.medium)
                            Spacer()
                            Text(log.timestamp, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(log.action)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let device = log.deviceName {
                            Text(device)
                                .font(.caption)
                                .foregroundStyle(ModernColors.cyan)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Activity Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear All") {
                        guestService.clearLogs()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    iOS_GuestModeView()
}
