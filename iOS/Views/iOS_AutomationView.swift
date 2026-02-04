//
//  iOS_AutomationView.swift
//  HomekitControl
//
//  Visual automation builder for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

struct iOS_AutomationView: View {
    @StateObject private var automationService = AutomationService.shared
    @StateObject private var homeKitService = HomeKitService.shared
    @State private var showingAddAutomation = false
    @State private var selectedAutomation: CustomAutomation?

    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphicBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Header Stats
                        HStack(spacing: 12) {
                            StatBadge(value: "\(automationService.automations.count)", label: "Total", icon: "gearshape.2.fill", color: ModernColors.cyan)
                            StatBadge(value: "\(automationService.automations.filter { $0.isEnabled }.count)", label: "Active", icon: "checkmark.circle.fill", color: ModernColors.accentGreen)
                        }
                        .padding(.horizontal)

                        // Automations List
                        if automationService.automations.isEmpty {
                            emptyState
                        } else {
                            ForEach(automationService.automations) { automation in
                                AutomationCard(automation: automation) {
                                    selectedAutomation = automation
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Automations")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddAutomation = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddAutomation) {
                AddAutomationSheet()
            }
            .sheet(item: $selectedAutomation) { automation in
                AutomationDetailSheet(automation: automation)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 60))
                .foregroundStyle(ModernColors.textTertiary)

            Text("No Automations")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Create automations to control your devices automatically")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingAddAutomation = true
            } label: {
                Label("Create Automation", systemImage: "plus")
                    .padding()
                    .background(ModernColors.accent)
                    .foregroundStyle(.black)
                    .cornerRadius(12)
            }
        }
        .padding(40)
    }
}

// MARK: - Automation Card

struct AutomationCard: View {
    let automation: CustomAutomation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(automation.name)
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack(spacing: 8) {
                            Label("\(automation.triggers.count) triggers", systemImage: "bolt.fill")
                            Label("\(automation.actions.count) actions", systemImage: "play.fill")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if let lastRun = automation.lastTriggered {
                            Text("Last run: \(lastRun, style: .relative) ago")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { automation.isEnabled },
                        set: { _ in AutomationService.shared.toggleAutomation(automation) }
                    ))
                    .labelsHidden()
                    .tint(ModernColors.accent)
                }
                .padding()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Automation Sheet

struct AddAutomationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var automationService = AutomationService.shared

    @State private var name = ""
    @State private var selectedTriggerType: TriggerType = .time
    @State private var selectedTime = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Automation Name") {
                    TextField("Name", text: $name)
                }

                Section("Trigger") {
                    Picker("Trigger Type", selection: $selectedTriggerType) {
                        ForEach(TriggerType.allCases) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }

                    if selectedTriggerType == .time {
                        DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section {
                    Button("Create Automation") {
                        var automation = automationService.createAutomation(name: name.isEmpty ? "New Automation" : name)
                        var trigger = AutomationTrigger(type: selectedTriggerType)
                        if selectedTriggerType == .time {
                            trigger.timeValue = selectedTime
                        }
                        automation.triggers.append(trigger)
                        automationService.updateAutomation(automation)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .navigationTitle("New Automation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Automation Detail Sheet

struct AutomationDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var automationService = AutomationService.shared
    @StateObject private var homeKitService = HomeKitService.shared

    let automation: CustomAutomation
    @State private var editedAutomation: CustomAutomation
    @State private var showingAddAction = false

    init(automation: CustomAutomation) {
        self.automation = automation
        _editedAutomation = State(initialValue: automation)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $editedAutomation.name)

                    Toggle("Enabled", isOn: $editedAutomation.isEnabled)
                }

                Section("Triggers (\(editedAutomation.triggers.count))") {
                    ForEach(editedAutomation.triggers) { trigger in
                        HStack {
                            Image(systemName: trigger.type.icon)
                                .foregroundStyle(ModernColors.cyan)
                            Text(trigger.type.rawValue)
                            Spacer()
                            if let time = trigger.timeValue {
                                Text(time, style: .time)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        editedAutomation.triggers.remove(atOffsets: indexSet)
                    }
                }

                Section("Actions (\(editedAutomation.actions.count))") {
                    ForEach(editedAutomation.actions) { action in
                        HStack {
                            Image(systemName: "play.fill")
                                .foregroundStyle(ModernColors.magenta)
                            Text(action.actionType.rawValue)
                            Spacer()
                            if action.delay > 0 {
                                Text("+\(Int(action.delay))s delay")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        editedAutomation.actions.remove(atOffsets: indexSet)
                    }

                    Button {
                        showingAddAction = true
                    } label: {
                        Label("Add Action", systemImage: "plus")
                    }
                }

                Section("Statistics") {
                    LabeledContent("Run Count", value: "\(automation.runCount)")
                    if let lastRun = automation.lastTriggered {
                        LabeledContent("Last Run", value: lastRun, format: .dateTime)
                    }
                    LabeledContent("Created", value: automation.createdAt, format: .dateTime)
                }

                Section {
                    Button("Run Now") {
                        Task {
                            try? await automationService.executeAutomation(editedAutomation)
                        }
                    }

                    Button("Delete Automation", role: .destructive) {
                        automationService.deleteAutomation(automation)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit Automation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        automationService.updateAutomation(editedAutomation)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddAction) {
                AddActionSheet(automation: $editedAutomation)
            }
        }
    }
}

// MARK: - Add Action Sheet

struct AddActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var automation: CustomAutomation
    @StateObject private var homeKitService = HomeKitService.shared

    @State private var actionType: AutomationAction.ActionType = .turnOn
    @State private var selectedDeviceId: UUID?
    @State private var delay: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Action Type") {
                    Picker("Type", selection: $actionType) {
                        ForEach(AutomationAction.ActionType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                if actionType != .wait && actionType != .executeScene {
                    Section("Device") {
                        Picker("Select Device", selection: $selectedDeviceId) {
                            Text("None").tag(nil as UUID?)
                            #if canImport(HomeKit)
                            ForEach(homeKitService.accessories, id: \.uniqueIdentifier) { accessory in
                                Text(accessory.name).tag(accessory.uniqueIdentifier as UUID?)
                            }
                            #endif
                        }
                    }
                }

                Section("Delay") {
                    HStack {
                        Text("Delay: \(Int(delay)) seconds")
                        Slider(value: $delay, in: 0...60, step: 1)
                    }
                }
            }
            .navigationTitle("Add Action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        var action = AutomationAction(
                            actionType: actionType,
                            delay: delay,
                            order: automation.actions.count
                        )
                        action.deviceId = selectedDeviceId
                        automation.actions.append(action)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatBadge: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                VStack(alignment: .leading) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
}

#Preview {
    iOS_AutomationView()
}
