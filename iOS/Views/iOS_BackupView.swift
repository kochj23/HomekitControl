//
//  iOS_BackupView.swift
//  HomekitControl
//
//  Backup and restore interface for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct iOS_BackupView: View {
    @StateObject private var backupService = BackupService.shared
    @State private var showingBackupDetail: HomeKitBackup?
    @State private var isCreatingBackup = false

    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphicBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Create Backup Button
                        createBackupCard

                        // Last Backup Info
                        lastBackupCard

                        // Backup List
                        backupListSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Backup")
            .sheet(item: $showingBackupDetail) { backup in
                BackupDetailSheet(backup: backup)
            }
        }
    }

    private var createBackupCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(ModernColors.cyan)

                Text("Create Backup")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Save your HomeKit configuration, custom automations, groups, and schedules")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    Task {
                        isCreatingBackup = true
                        _ = try? await backupService.createBackup()
                        isCreatingBackup = false
                    }
                } label: {
                    HStack {
                        if isCreatingBackup {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "plus")
                        }
                        Text("Create Backup Now")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(ModernColors.accent)
                .disabled(isCreatingBackup)
            }
            .padding()
        }
    }

    private var lastBackupCard: some View {
        GlassCard {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(ModernColors.purple)

                VStack(alignment: .leading) {
                    Text("Last Backup")
                        .font(.subheadline)
                        .foregroundStyle(.white)

                    if let lastBackup = backupService.lastBackup {
                        Text(lastBackup, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Never")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("\(backupService.backups.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private var backupListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved Backups")
                .font(.headline)
                .foregroundStyle(.white)

            if backupService.backups.isEmpty {
                GlassCard {
                    Text("No backups yet")
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(backupService.backups) { backup in
                    Button {
                        showingBackupDetail = backup
                    } label: {
                        BackupCard(backup: backup)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Backup Card

struct BackupCard: View {
    let backup: HomeKitBackup

    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: "doc.zipper")
                    .foregroundStyle(ModernColors.cyan)

                VStack(alignment: .leading, spacing: 4) {
                    Text(backup.name)
                        .foregroundStyle(.white)

                    Text(backup.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("\(backup.homeData.accessories.count)")
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

// MARK: - Backup Detail Sheet

struct BackupDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var backupService = BackupService.shared

    let backup: HomeKitBackup
    @State private var isRestoring = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Backup Info") {
                    LabeledContent("Name", value: backup.name)
                    LabeledContent("Created", value: backup.createdAt, format: .dateTime)
                    LabeledContent("Version", value: backup.version)
                }

                Section("HomeKit Data") {
                    LabeledContent("Home Name", value: backup.homeData.homeName)
                    LabeledContent("Rooms", value: "\(backup.homeData.rooms.count)")
                    LabeledContent("Accessories", value: "\(backup.homeData.accessories.count)")
                    LabeledContent("Scenes", value: "\(backup.homeData.scenes.count)")
                }

                Section("Custom Data") {
                    LabeledContent("Automations", value: "\(backup.automationData.count)")
                    LabeledContent("Has Groups", value: backup.customData.deviceGroups != nil ? "Yes" : "No")
                    LabeledContent("Has Schedules", value: backup.customData.schedules != nil ? "Yes" : "No")
                }

                Section {
                    Button {
                        Task {
                            isRestoring = true
                            try? await backupService.restoreBackup(backup)
                            isRestoring = false
                            dismiss()
                        }
                    } label: {
                        HStack {
                            if isRestoring {
                                ProgressView()
                            }
                            Text("Restore This Backup")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isRestoring)

                    if let data = backupService.exportBackup(backup) {
                        ShareLink(item: data, preview: SharePreview(backup.name, icon: "doc.zipper")) {
                            Label("Export Backup", systemImage: "square.and.arrow.up")
                        }
                    }

                    Button("Delete Backup", role: .destructive) {
                        backupService.deleteBackup(backup)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Backup Details")
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
    iOS_BackupView()
}
