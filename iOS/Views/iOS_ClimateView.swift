//
//  iOS_ClimateView.swift
//  HomekitControl
//
//  Climate zones and thermostat control for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct iOS_ClimateView: View {
    @StateObject private var climateService = ClimateService.shared
    @State private var showAddZone = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overview Card
                GlassCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Home Climate")
                                .font(.headline)
                                .foregroundStyle(.white)

                            HStack(spacing: 4) {
                                Image(systemName: "thermometer")
                                Text(climateService.formatTemperature(climateService.averageTemperature))
                                    .font(.title.bold())
                            }
                            .foregroundStyle(.white)

                            if let humidity = climateService.averageHumidity {
                                HStack(spacing: 4) {
                                    Image(systemName: "humidity")
                                    Text("\(Int(humidity))%")
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 8) {
                            Toggle("Away Mode", isOn: Binding(
                                get: { climateService.awayModeEnabled },
                                set: { enabled in
                                    Task {
                                        if enabled {
                                            await climateService.enableAwayMode()
                                        } else {
                                            await climateService.disableAwayMode()
                                        }
                                    }
                                }
                            ))
                            .tint(ModernColors.cyan)

                            if !climateService.activelyHeating.isEmpty {
                                Label("Heating", systemImage: "flame.fill")
                                    .font(.caption)
                                    .foregroundStyle(ModernColors.orange)
                            }

                            if !climateService.activelyCooling.isEmpty {
                                Label("Cooling", systemImage: "snowflake")
                                    .font(.caption)
                                    .foregroundStyle(ModernColors.cyan)
                            }
                        }
                    }
                    .padding()
                }

                // Thermostats
                if !climateService.thermostats.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Thermostats")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(climateService.thermostats) { thermostat in
                            NavigationLink(destination: ThermostatDetailView(thermostat: thermostat)) {
                                GlassCard {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(thermostat.name)
                                                .font(.headline)
                                                .foregroundStyle(.white)

                                            HStack {
                                                if thermostat.isHeating {
                                                    Label("Heating", systemImage: "flame.fill")
                                                        .foregroundStyle(ModernColors.orange)
                                                } else if thermostat.isCooling {
                                                    Label("Cooling", systemImage: "snowflake")
                                                        .foregroundStyle(ModernColors.cyan)
                                                } else {
                                                    Label("Idle", systemImage: "minus")
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            .font(.caption)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(climateService.formatTemperature(thermostat.currentTemperature))
                                                .font(.title2.bold())
                                                .foregroundStyle(.white)

                                            HStack(spacing: 4) {
                                                Image(systemName: "target")
                                                Text(climateService.formatTemperature(thermostat.targetTemperature))
                                            }
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        }

                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                }
                            }
                        }
                    }
                }

                // Climate Zones
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Climate Zones")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Spacer()

                        Button {
                            showAddZone = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(ModernColors.cyan)
                        }
                    }

                    if climateService.zones.isEmpty {
                        GlassCard {
                            HStack {
                                Image(systemName: "rectangle.3.group")
                                    .foregroundStyle(.secondary)
                                Text("No zones configured")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        ForEach(climateService.zones) { zone in
                            NavigationLink(destination: ZoneDetailView(zone: zone)) {
                                GlassCard {
                                    HStack {
                                        Circle()
                                            .fill(zone.isEnabled ? ModernColors.accentGreen : .secondary)
                                            .frame(width: 12, height: 12)

                                        VStack(alignment: .leading) {
                                            Text(zone.name)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            Text("\(zone.thermostatIds.count) thermostats")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Text(climateService.formatTemperature(zone.targetTemperature))
                                            .font(.title3.bold())
                                            .foregroundStyle(ModernColors.cyan)

                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                }
                            }
                        }
                    }
                }

                // Temperature Unit
                GlassCard {
                    HStack {
                        Text("Temperature Unit")
                            .foregroundStyle(.white)

                        Spacer()

                        Picker("Unit", selection: $climateService.temperatureUnit) {
                            ForEach(ClimateService.TemperatureUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                    .padding()
                }
            }
            .padding()
        }
        .background(LinearGradient.modernBackground.ignoresSafeArea())
        .navigationTitle("Climate")
        .onAppear {
            climateService.startMonitoring()
        }
        .sheet(isPresented: $showAddZone) {
            AddClimateZoneView()
        }
    }
}

struct ThermostatDetailView: View {
    let thermostat: ThermostatStatus
    @StateObject private var climateService = ClimateService.shared
    @State private var targetTemp: Double = 72

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Temperature Control
                GlassCard {
                    VStack(spacing: 20) {
                        Text(climateService.formatTemperature(thermostat.currentTemperature))
                            .font(.system(size: 60, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Current Temperature")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Divider()

                        VStack(spacing: 12) {
                            Text("Target: \(climateService.formatTemperature(targetTemp))")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Slider(value: $targetTemp, in: 60...85, step: 1)
                                .tint(ModernColors.cyan)

                            Button {
                                Task {
                                    await climateService.setTemperature(targetTemp, for: thermostat.id)
                                }
                            } label: {
                                Text("Set Temperature")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(ModernColors.cyan)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding()
                }

                // Mode Selection
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mode")
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack(spacing: 12) {
                            ForEach(ThermostatMode.allCases, id: \.self) { mode in
                                Button {
                                    Task {
                                        await climateService.setMode(mode, for: thermostat.id)
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: mode.icon)
                                            .font(.title2)
                                        Text(mode.rawValue)
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(thermostat.mode == mode ? mode.color : ModernColors.glassBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                    .padding()
                }

                // Status
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Status")
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack {
                            Text("Connection")
                            Spacer()
                            HStack {
                                Circle()
                                    .fill(thermostat.isReachable ? ModernColors.accentGreen : ModernColors.red)
                                    .frame(width: 8, height: 8)
                                Text(thermostat.isReachable ? "Online" : "Offline")
                            }
                            .foregroundStyle(thermostat.isReachable ? ModernColors.accentGreen : ModernColors.red)
                        }

                        if let humidity = thermostat.humidity {
                            HStack {
                                Text("Humidity")
                                Spacer()
                                Text("\(Int(humidity))%")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
        .background(LinearGradient.modernBackground.ignoresSafeArea())
        .navigationTitle(thermostat.name)
        .onAppear {
            targetTemp = thermostat.targetTemperature
        }
    }
}

struct ZoneDetailView: View {
    let zone: ClimateZone
    @StateObject private var climateService = ClimateService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                GlassCard {
                    VStack(spacing: 16) {
                        Image(systemName: "rectangle.3.group.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(ModernColors.cyan)

                        Text(zone.name)
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        Toggle("Enabled", isOn: .constant(zone.isEnabled))
                            .tint(ModernColors.cyan)
                    }
                    .padding()
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Target Temperature")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(climateService.formatTemperature(zone.targetTemperature))
                            .font(.largeTitle.bold())
                            .foregroundStyle(ModernColors.cyan)
                    }
                    .padding()
                }
            }
            .padding()
        }
        .background(LinearGradient.modernBackground.ignoresSafeArea())
        .navigationTitle("Zone Details")
    }
}

struct AddClimateZoneView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var climateService = ClimateService.shared
    @State private var name = ""
    @State private var targetTemp: Double = 72

    var body: some View {
        NavigationStack {
            Form {
                Section("Zone") {
                    TextField("Name", text: $name)
                }

                Section("Target Temperature") {
                    Slider(value: $targetTemp, in: 60...85, step: 1)
                    Text(climateService.formatTemperature(targetTemp))
                }
            }
            .navigationTitle("Add Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        var zone = ClimateZone(name: name)
                        zone.targetTemperature = targetTemp
                        climateService.addZone(zone)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
