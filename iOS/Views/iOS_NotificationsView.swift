//
//  iOS_NotificationsView.swift
//  HomekitControl
//
//  Notification center and alert management for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct iOS_NotificationsView: View {
    @StateObject private var notificationService = NotificationService.shared
    @State private var showingAddRule = false

    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphicBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Authorization Status
                        if !notificationService.isAuthorized {
                            authorizationCard
                        }

                        // Quiet Hours
                        quietHoursCard

                        // Notification Rules
                        rulesSection

                        // Recent Notifications
                        logsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddRule = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddRule) {
                AddNotificationRuleSheet()
            }
        }
    }

    private var authorizationCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(ModernColors.statusHigh)

                Text("Notifications Disabled")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Enable notifications to receive alerts about your smart home")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Enable Notifications") {
                    Task {
                        await notificationService.requestAuthorization()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ModernColors.accent)
            }
            .padding()
        }
    }

    private var quietHoursCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $notificationService.quietHoursEnabled) {
                    Label("Quiet Hours", systemImage: "moon.fill")
                        .foregroundStyle(.white)
                }
                .tint(ModernColors.purple)

                if notificationService.quietHoursEnabled {
                    HStack {
                        DatePicker("Start", selection: $notificationService.quietHoursStart, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Text("to")
                            .foregroundStyle(.secondary)
                        DatePicker("End", selection: $notificationService.quietHoursEnd, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
            }
            .padding()
        }
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alert Rules")
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(notificationService.rules) { rule in
                NotificationRuleCard(rule: rule)
            }
        }
    }

    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Alerts")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                if notificationService.unreadCount > 0 {
                    Button("Mark All Read") {
                        notificationService.markAllAsRead()
                    }
                    .font(.caption)
                }
            }

            if notificationService.logs.isEmpty {
                GlassCard {
                    Text("No recent notifications")
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(notificationService.logs.prefix(20)) { log in
                    NotificationLogCard(log: log)
                }
            }
        }
    }
}

// MARK: - Notification Rule Card

struct NotificationRuleCard: View {
    let rule: NotificationRule
    @StateObject private var notificationService = NotificationService.shared

    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: rule.eventType.icon)
                    .foregroundStyle(ModernColors.cyan)

                VStack(alignment: .leading) {
                    Text(rule.name)
                        .foregroundStyle(.white)
                    Text(rule.eventType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { rule.isEnabled },
                    set: { _ in notificationService.toggleRule(rule) }
                ))
                .labelsHidden()
                .tint(ModernColors.accent)
            }
            .padding()
        }
    }
}

// MARK: - Notification Log Card

struct NotificationLogCard: View {
    let log: NotificationLog
    @StateObject private var notificationService = NotificationService.shared

    var body: some View {
        GlassCard {
            HStack(alignment: .top) {
                Circle()
                    .fill(log.isRead ? Color.clear : ModernColors.accent)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(log.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)

                    Text(log.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(log.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture {
                notificationService.markAsRead(log)
            }
        }
    }
}

// MARK: - Add Rule Sheet

struct AddNotificationRuleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationService = NotificationService.shared

    @State private var name = ""
    @State private var eventType: NotificationRule.EventType = .stateChange

    var body: some View {
        NavigationStack {
            Form {
                Section("Rule Details") {
                    TextField("Name", text: $name)

                    Picker("Event Type", selection: $eventType) {
                        ForEach(NotificationRule.EventType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }
            }
            .navigationTitle("New Alert Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        _ = notificationService.createRule(name: name.isEmpty ? eventType.rawValue : name, eventType: eventType)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    iOS_NotificationsView()
}
