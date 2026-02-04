//
//  iOS_FloorPlanView.swift
//  HomekitControl
//
//  Floor plan visualization for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct iOS_FloorPlanView: View {
    @StateObject private var floorPlanService = FloorPlanService.shared
    @State private var showAddPlan = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Floor Plan Selector
                if !floorPlanService.floorPlans.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(floorPlanService.floorPlans) { plan in
                                Button {
                                    floorPlanService.selectedPlanId = plan.id
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: "square.split.2x2")
                                            .font(.title2)
                                        Text(plan.name)
                                            .font(.caption)
                                    }
                                    .padding()
                                    .background(floorPlanService.selectedPlanId == plan.id ? ModernColors.cyan : ModernColors.glassBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(.white)
                                }
                            }

                            Button {
                                showAddPlan = true
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.title2)
                                    Text("Add")
                                        .font(.caption)
                                }
                                .padding()
                                .background(ModernColors.glassBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Floor Plan View
                if let plan = floorPlanService.selectedPlan {
                    GlassCard {
                        VStack(spacing: 16) {
                            Text(plan.name)
                                .font(.headline)
                                .foregroundStyle(.white)

                            // Floor plan canvas
                            ZStack {
                                // Background
                                if let imageData = plan.imageData,
                                   let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(ModernColors.glassBackground)
                                        .aspectRatio(plan.width / plan.height, contentMode: .fit)
                                        .overlay {
                                            VStack {
                                                Image(systemName: "photo")
                                                    .font(.largeTitle)
                                                    .foregroundStyle(.secondary)
                                                Text("Add floor plan image")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                }

                                // Device markers
                                GeometryReader { geo in
                                    ForEach(plan.devices) { device in
                                        let status = floorPlanService.getDeviceStatus(deviceId: device.deviceId)

                                        Button {
                                            // Toggle device
                                        } label: {
                                            VStack(spacing: 2) {
                                                Image(systemName: device.deviceType.icon)
                                                    .font(.title3)
                                                    .foregroundStyle(status.isOn ? device.deviceType.color : .secondary)
                                                    .padding(8)
                                                    .background(status.isReachable ? ModernColors.glassBackground : ModernColors.red.opacity(0.3))
                                                    .clipShape(Circle())

                                                Text(device.deviceName)
                                                    .font(.system(size: 8))
                                                    .foregroundStyle(.white)
                                                    .lineLimit(1)
                                            }
                                        }
                                        .position(
                                            x: device.x * geo.size.width,
                                            y: device.y * geo.size.height
                                        )
                                    }
                                }
                            }
                            .frame(height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            // Edit mode toggle
                            Toggle(isOn: $floorPlanService.isEditMode) {
                                Label("Edit Mode", systemImage: "pencil")
                                    .foregroundStyle(.white)
                            }
                            .tint(ModernColors.cyan)
                        }
                        .padding()
                    }

                    // Placed Devices
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Devices on Plan")
                            .font(.headline)
                            .foregroundStyle(.white)

                        if plan.devices.isEmpty {
                            GlassCard {
                                HStack {
                                    Image(systemName: "lightbulb.slash")
                                        .foregroundStyle(.secondary)
                                    Text("No devices placed")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(plan.devices) { device in
                                    let status = floorPlanService.getDeviceStatus(deviceId: device.deviceId)

                                    GlassCard {
                                        VStack(spacing: 8) {
                                            Image(systemName: device.deviceType.icon)
                                                .font(.title2)
                                                .foregroundStyle(status.isOn ? device.deviceType.color : .secondary)

                                            Text(device.deviceName)
                                                .font(.caption)
                                                .foregroundStyle(.white)
                                                .lineLimit(1)

                                            Circle()
                                                .fill(status.isReachable ? ModernColors.accentGreen : ModernColors.red)
                                                .frame(width: 8, height: 8)
                                        }
                                        .padding()
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // No floor plan
                    GlassCard {
                        VStack(spacing: 16) {
                            Image(systemName: "square.split.2x2")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary)

                            Text("No Floor Plan")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Text("Create a floor plan to visualize your devices")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Button {
                                showAddPlan = true
                            } label: {
                                Text("Create Floor Plan")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .padding()
                                    .background(ModernColors.cyan)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }
                }

                // Unplaced Devices
                if !floorPlanService.unplacedDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Unplaced Devices")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(floorPlanService.unplacedDevices) { device in
                                    GlassCard {
                                        VStack(spacing: 8) {
                                            Image(systemName: device.type.icon)
                                                .font(.title2)
                                                .foregroundStyle(device.type.color)

                                            Text(device.name)
                                                .font(.caption)
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                        }
                                        .padding()
                                        .frame(width: 100)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(LinearGradient.modernBackground.ignoresSafeArea())
        .navigationTitle("Floor Plan")
        .onAppear {
            floorPlanService.refreshUnplacedDevices()
        }
        .sheet(isPresented: $showAddPlan) {
            AddFloorPlanView()
        }
    }
}

struct AddFloorPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var floorPlanService = FloorPlanService.shared
    @State private var name = ""
    @State private var level = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Floor Plan") {
                    TextField("Name", text: $name)

                    Picker("Level", selection: $level) {
                        Text("Basement").tag(-1)
                        Text("Ground Floor").tag(0)
                        Text("First Floor").tag(1)
                        Text("Second Floor").tag(2)
                    }
                }
            }
            .navigationTitle("Add Floor Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let plan = FloorPlan(name: name, level: level)
                        floorPlanService.addFloorPlan(plan)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
