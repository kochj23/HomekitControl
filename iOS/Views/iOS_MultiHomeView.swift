//
//  iOS_MultiHomeView.swift
//  HomekitControl
//
//  Multi-home management for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct iOS_MultiHomeView: View {
    @StateObject private var multiHomeService = MultiHomeService.shared
    @State private var showAddCrossHomeScene = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Current Home
                if let currentHome = multiHomeService.currentHome {
                    GlassCard {
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "house.fill")
                                    .font(.title)
                                    .foregroundStyle(ModernColors.cyan)

                                VStack(alignment: .leading) {
                                    Text("Current Home")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(currentHome.name)
                                        .font(.title2.bold())
                                        .foregroundStyle(.white)
                                }

                                Spacer()

                                if currentHome.isPrimary {
                                    Text("Primary")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(ModernColors.accentGreen.opacity(0.3))
                                        .clipShape(Capsule())
                                        .foregroundStyle(ModernColors.accentGreen)
                                }
                            }

                            HStack(spacing: 20) {
                                VStack {
                                    Text("\(currentHome.accessoryCount)")
                                        .font(.title2.bold())
                                        .foregroundStyle(.white)
                                    Text("Devices")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                VStack {
                                    Text("\(currentHome.roomCount)")
                                        .font(.title2.bold())
                                        .foregroundStyle(.white)
                                    Text("Rooms")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                VStack {
                                    Text("\(currentHome.sceneCount)")
                                        .font(.title2.bold())
                                        .foregroundStyle(.white)
                                    Text("Scenes")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                    }
                }

                // All Homes
                if multiHomeService.hasMultipleHomes {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("All Homes")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(multiHomeService.homes) { home in
                            Button {
                                multiHomeService.switchHome(to: home.id)
                            } label: {
                                GlassCard {
                                    HStack {
                                        Image(systemName: home.isPrimary ? "house.fill" : "house")
                                            .foregroundStyle(multiHomeService.currentHomeId == home.id ? ModernColors.cyan : .secondary)

                                        VStack(alignment: .leading) {
                                            Text(home.name)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            Text("\(home.accessoryCount) devices • \(home.roomCount) rooms")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        if multiHomeService.currentHomeId == home.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(ModernColors.accentGreen)
                                        }
                                    }
                                    .padding()
                                }
                            }
                        }
                    }
                }

                // Cross-Home Scenes
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Cross-Home Scenes")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Spacer()

                        Button {
                            showAddCrossHomeScene = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(ModernColors.cyan)
                        }
                    }

                    if multiHomeService.crossHomeScenes.isEmpty {
                        GlassCard {
                            VStack(spacing: 12) {
                                Image(systemName: "arrow.triangle.2.circlepath.circle")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                                Text("No cross-home scenes")
                                    .foregroundStyle(.secondary)
                                Text("Create scenes that trigger actions across multiple homes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        ForEach(multiHomeService.crossHomeScenes) { scene in
                            GlassCard {
                                HStack {
                                    Circle()
                                        .fill(scene.isEnabled ? ModernColors.accentGreen : .secondary)
                                        .frame(width: 10, height: 10)

                                    VStack(alignment: .leading) {
                                        Text(scene.name)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Text("\(scene.actions.count) actions")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Button {
                                        Task {
                                            await multiHomeService.executeCrossHomeScene(scene)
                                        }
                                    } label: {
                                        Image(systemName: "play.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(ModernColors.cyan)
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                }

                // Vacation Mode
                VStack(alignment: .leading, spacing: 12) {
                    Text("Vacation Mode")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(multiHomeService.vacationSettings) { settings in
                        GlassCard {
                            HStack {
                                Image(systemName: settings.isEnabled ? "airplane.circle.fill" : "airplane.circle")
                                    .font(.title2)
                                    .foregroundStyle(settings.isEnabled ? ModernColors.orange : .secondary)

                                VStack(alignment: .leading) {
                                    Text(settings.homeName)
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    if settings.isEnabled {
                                        HStack(spacing: 8) {
                                            if settings.lightSimulation {
                                                Label("Lights", systemImage: "lightbulb")
                                            }
                                            if settings.alertOnMotion {
                                                Label("Motion", systemImage: "figure.walk.motion")
                                            }
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { settings.isEnabled },
                                    set: { enabled in
                                        if enabled {
                                            multiHomeService.enableVacationMode(for: settings.homeId)
                                        } else {
                                            multiHomeService.disableVacationMode(for: settings.homeId)
                                        }
                                    }
                                ))
                                .tint(ModernColors.orange)
                            }
                            .padding()
                        }
                    }
                }

                // Stats
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Summary")
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack {
                            VStack {
                                Text("\(multiHomeService.homes.count)")
                                    .font(.title2.bold())
                                    .foregroundStyle(ModernColors.cyan)
                                Text("Homes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            VStack {
                                Text("\(multiHomeService.totalAccessories)")
                                    .font(.title2.bold())
                                    .foregroundStyle(ModernColors.purple)
                                Text("Total Devices")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            VStack {
                                Text("\(multiHomeService.totalScenes)")
                                    .font(.title2.bold())
                                    .foregroundStyle(ModernColors.orange)
                                Text("Total Scenes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
        .background(LinearGradient.modernBackground.ignoresSafeArea())
        .navigationTitle("Multi-Home")
        .onAppear {
            multiHomeService.refreshHomes()
        }
        .sheet(isPresented: $showAddCrossHomeScene) {
            AddCrossHomeSceneView()
        }
    }
}

struct AddCrossHomeSceneView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var multiHomeService = MultiHomeService.shared
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Scene") {
                    TextField("Name", text: $name)
                }

                Section("Actions") {
                    Text("Add actions from different homes")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Cross-Home Scene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let scene = CrossHomeScene(name: name)
                        multiHomeService.addCrossHomeScene(scene)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
