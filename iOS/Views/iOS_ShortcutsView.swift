//
//  iOS_ShortcutsView.swift
//  HomekitControl
//
//  Siri Shortcuts and widget management for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

struct iOS_ShortcutsView: View {
    @StateObject private var shortcutsService = SiriShortcutsService.shared
    @StateObject private var homeKitService = HomeKitService.shared
    @State private var showingAddShortcut = false
    @State private var selectedShortcut: ShortcutAction?

    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphicBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Quick Setup
                        quickSetupSection

                        // Widget Favorites
                        widgetSection

                        // Shortcuts List
                        shortcutsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Shortcuts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddShortcut = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddShortcut) {
                AddShortcutSheet()
            }
            .sheet(item: $selectedShortcut) { shortcut in
                ShortcutDetailSheet(shortcut: shortcut)
            }
        }
    }

    private var quickSetupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Setup")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                Button {
                    shortcutsService.createDeviceShortcuts()
                } label: {
                    GlassCard {
                        VStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(ModernColors.yellow)
                            Text("Device Shortcuts")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                        .padding()
                    }
                }
                .buttonStyle(.plain)

                Button {
                    shortcutsService.createSceneShortcuts()
                } label: {
                    GlassCard {
                        VStack(spacing: 8) {
                            Image(systemName: "theatermasks.fill")
                                .foregroundStyle(ModernColors.cyan)
                            Text("Scene Shortcuts")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                        .padding()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var widgetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Widget Favorites")
                .font(.headline)
                .foregroundStyle(.white)

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "square.grid.2x2.fill")
                            .foregroundStyle(ModernColors.purple)
                        Text("Home Screen Widgets")
                            .foregroundStyle(.white)
                        Spacer()
                    }

                    Divider()

                    HStack {
                        Text("Favorite Devices")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(shortcutsService.widgetData.favoriteDevices.count)")
                            .foregroundStyle(.white)
                    }

                    HStack {
                        Text("Favorite Scenes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(shortcutsService.widgetData.favoriteScenes.count)")
                            .foregroundStyle(.white)
                    }

                    Button {
                        shortcutsService.updateWidgetData()
                    } label: {
                        Text("Update Widget Data")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
    }

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Siri Shortcuts")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text("\(shortcutsService.shortcuts.count) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if shortcutsService.shortcuts.isEmpty {
                GlassCard {
                    VStack(spacing: 12) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No shortcuts created")
                            .foregroundStyle(.secondary)
                        Text("Create shortcuts to control your home with Siri")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(shortcutsService.shortcuts) { shortcut in
                    Button {
                        selectedShortcut = shortcut
                    } label: {
                        ShortcutCard(shortcut: shortcut)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Shortcut Card

struct ShortcutCard: View {
    let shortcut: ShortcutAction

    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: shortcut.iconName)
                    .foregroundStyle(colorFromString(shortcut.iconColor))

                VStack(alignment: .leading, spacing: 4) {
                    Text(shortcut.name)
                        .foregroundStyle(.white)

                    HStack {
                        Text(shortcut.actionType.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let phrase = shortcut.phrase {
                            Text("• \"\(phrase)\"")
                                .font(.caption)
                                .foregroundStyle(ModernColors.cyan)
                        }
                    }
                }

                Spacer()

                if shortcut.isEnabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ModernColors.accentGreen)
                }

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
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

// MARK: - Add Shortcut Sheet

struct AddShortcutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var shortcutsService = SiriShortcutsService.shared
    @StateObject private var homeKitService = HomeKitService.shared

    @State private var name = ""
    @State private var actionType: ShortcutAction.ActionType = .toggleDevice
    @State private var selectedTargetId: UUID?
    @State private var phrase = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Shortcut Info") {
                    TextField("Name", text: $name)

                    Picker("Action", selection: $actionType) {
                        ForEach(ShortcutAction.ActionType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }

                Section("Target") {
                    if actionType == .executeScene {
                        Picker("Scene", selection: $selectedTargetId) {
                            Text("None").tag(nil as UUID?)
                            #if canImport(HomeKit)
                            ForEach(homeKitService.scenes, id: \.uniqueIdentifier) { scene in
                                Text(scene.name).tag(scene.uniqueIdentifier as UUID?)
                            }
                            #endif
                        }
                    } else {
                        Picker("Device", selection: $selectedTargetId) {
                            Text("None").tag(nil as UUID?)
                            #if canImport(HomeKit)
                            ForEach(homeKitService.accessories, id: \.uniqueIdentifier) { accessory in
                                Text(accessory.name).tag(accessory.uniqueIdentifier as UUID?)
                            }
                            #endif
                        }
                    }
                }

                Section("Siri Phrase (Optional)") {
                    TextField("e.g., \"Turn on lights\"", text: $phrase)
                }
            }
            .navigationTitle("New Shortcut")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let targetName = getTargetName()
                        var shortcut = shortcutsService.createShortcut(
                            name: name.isEmpty ? actionType.rawValue : name,
                            actionType: actionType,
                            targetId: selectedTargetId,
                            targetName: targetName
                        )
                        if !phrase.isEmpty {
                            shortcutsService.setPhrase(for: shortcut, phrase: phrase)
                        }
                        dismiss()
                    }
                }
            }
        }
    }

    private func getTargetName() -> String {
        guard let targetId = selectedTargetId else { return "" }

        #if canImport(HomeKit)
        if actionType == .executeScene {
            return homeKitService.scenes.first { $0.uniqueIdentifier == targetId }?.name ?? ""
        } else {
            return homeKitService.accessories.first { $0.uniqueIdentifier == targetId }?.name ?? ""
        }
        #else
        return ""
        #endif
    }
}

// MARK: - Shortcut Detail Sheet

struct ShortcutDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var shortcutsService = SiriShortcutsService.shared

    let shortcut: ShortcutAction
    @State private var newPhrase = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    LabeledContent("Name", value: shortcut.name)
                    LabeledContent("Action", value: shortcut.actionType.rawValue)
                    LabeledContent("Target", value: shortcut.targetName)
                    LabeledContent("Enabled", value: shortcut.isEnabled ? "Yes" : "No")
                }

                Section("Siri Phrase") {
                    if let phrase = shortcut.phrase {
                        Text("\"\(phrase)\"")
                            .foregroundStyle(ModernColors.cyan)
                    } else {
                        Text("No phrase set")
                            .foregroundStyle(.secondary)
                    }

                    TextField("New phrase", text: $newPhrase)

                    if !newPhrase.isEmpty {
                        Button("Update Phrase") {
                            shortcutsService.setPhrase(for: shortcut, phrase: newPhrase)
                        }
                    }
                }

                Section {
                    Button {
                        Task {
                            try? await shortcutsService.executeShortcut(shortcut)
                        }
                    } label: {
                        Label("Test Shortcut", systemImage: "play.fill")
                    }

                    Button("Delete Shortcut", role: .destructive) {
                        shortcutsService.deleteShortcut(shortcut)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Shortcut Details")
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
    iOS_ShortcutsView()
}
