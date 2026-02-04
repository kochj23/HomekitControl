//
//  iOS_AdaptiveLightingView.swift
//  HomekitControl
//
//  Adaptive lighting and circadian rhythm for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct iOS_AdaptiveLightingView: View {
    @StateObject private var lightingService = AdaptiveLightingService.shared
    @State private var showAddProfile = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Current Status
                GlassCard {
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Lighting")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(lightingService.currentColorTempDescription)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: $lightingService.isEnabled)
                                .tint(ModernColors.cyan)
                        }

                        HStack(spacing: 30) {
                            VStack {
                                CircularGauge(
                                    value: Double(lightingService.currentBrightness),
                                    color: ModernColors.yellow,
                                    lineWidth: 8,
                                    size: 80
                                )
                                Text("Brightness")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            VStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(lightingService.currentColorTempColor)
                                    .frame(width: 80, height: 80)
                                    .overlay {
                                        Text("\(lightingService.currentColorTemp)K")
                                            .font(.caption.bold())
                                            .foregroundStyle(.black.opacity(0.7))
                                    }
                                Text("Color Temp")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                }

                // Schedule Preview
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's Schedule")
                            .font(.headline)
                            .foregroundStyle(.white)

                        if let profile = lightingService.profiles.first {
                            ForEach(profile.schedule) { point in
                                HStack {
                                    Text(point.timeString)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(.white)

                                    Spacer()

                                    HStack(spacing: 16) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "sun.max")
                                                .font(.caption)
                                            Text("\(point.brightness)%")
                                        }
                                        .foregroundStyle(ModernColors.yellow)

                                        HStack(spacing: 4) {
                                            Image(systemName: "thermometer")
                                                .font(.caption)
                                            Text("\(point.colorTemperature)K")
                                        }
                                        .foregroundStyle(colorForTemp(point.colorTemperature))
                                    }
                                    .font(.caption)
                                }
                                .padding(.vertical, 4)

                                if point.id != profile.schedule.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding()
                }

                // Profiles
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Lighting Profiles")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Spacer()

                        Button {
                            showAddProfile = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(ModernColors.cyan)
                        }
                    }

                    ForEach(lightingService.profiles) { profile in
                        NavigationLink(destination: ProfileDetailView(profile: profile)) {
                            GlassCard {
                                HStack {
                                    Circle()
                                        .fill(profile.isEnabled ? ModernColors.accentGreen : .secondary)
                                        .frame(width: 12, height: 12)

                                    VStack(alignment: .leading) {
                                        Text(profile.name)
                                            .font(.headline)
                                            .foregroundStyle(.white)

                                        HStack(spacing: 12) {
                                            if profile.motionActivated {
                                                Label("Motion", systemImage: "figure.walk.motion")
                                            }
                                            Label("\(profile.deviceIds.count) lights", systemImage: "lightbulb")
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                            }
                        }
                    }
                }

                // Motion Activity
                if !lightingService.motionEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Motion")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(lightingService.motionEvents.prefix(5)) { event in
                            GlassCard {
                                HStack {
                                    Image(systemName: "figure.walk.motion")
                                        .foregroundStyle(ModernColors.orange)

                                    VStack(alignment: .leading) {
                                        Text(event.sensorName)
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                        Text("\(event.triggeredLights.count) lights activated")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text(event.timestamp, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                            }
                        }
                    }
                }

                // Active Motion Timers
                if lightingService.motionActiveDeviceCount > 0 {
                    GlassCard {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundStyle(ModernColors.cyan)

                            Text("\(lightingService.motionActiveDeviceCount) lights on motion timer")
                                .foregroundStyle(.white)

                            Spacer()
                        }
                        .padding()
                    }
                }
            }
            .padding()
        }
        .background(LinearGradient.modernBackground.ignoresSafeArea())
        .navigationTitle("Adaptive Lighting")
        .onAppear {
            if lightingService.isEnabled {
                lightingService.startAdaptiveLighting()
            }
        }
        .sheet(isPresented: $showAddProfile) {
            AddLightingProfileView()
        }
    }

    private func colorForTemp(_ temp: Int) -> Color {
        if temp < 3000 { return ModernColors.orange }
        if temp < 4500 { return ModernColors.yellow }
        return ModernColors.cyan
    }
}

struct ProfileDetailView: View {
    let profile: LightingProfile
    @StateObject private var lightingService = AdaptiveLightingService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                GlassCard {
                    VStack(spacing: 16) {
                        Image(systemName: "lightbulb.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(ModernColors.yellow)

                        Text(profile.name)
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        Toggle("Enabled", isOn: .constant(profile.isEnabled))
                            .tint(ModernColors.cyan)
                    }
                    .padding()
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Options")
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack {
                            Image(systemName: "figure.walk.motion")
                            Text("Motion Activated")
                            Spacer()
                            Image(systemName: profile.motionActivated ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(profile.motionActivated ? ModernColors.accentGreen : .secondary)
                        }
                        .foregroundStyle(.white)

                        if profile.motionActivated {
                            HStack {
                                Image(systemName: "timer")
                                Text("Timeout: \(Int(profile.motionTimeout / 60)) min")
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Assigned Lights")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text("\(profile.deviceIds.count) devices")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
            .padding()
        }
        .background(LinearGradient.modernBackground.ignoresSafeArea())
        .navigationTitle("Profile Details")
    }
}

struct AddLightingProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var lightingService = AdaptiveLightingService.shared
    @State private var name = ""
    @State private var motionActivated = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $name)
                }

                Section("Options") {
                    Toggle("Motion Activated", isOn: $motionActivated)
                }
            }
            .navigationTitle("Add Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        var profile = LightingProfile(name: name)
                        profile.motionActivated = motionActivated
                        lightingService.addProfile(profile)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
