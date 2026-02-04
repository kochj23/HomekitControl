//
//  iOS_IntegrationHubView.swift
//  HomekitControl
//
//  Integration hub for Matter, Thread, and other protocols
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct iOS_IntegrationHubView: View {
    @StateObject private var hubService = IntegrationHubService.shared
    @State private var showPairingSheet = false
    @State private var setupCode = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overview
                GlassCard {
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Integration Hub")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Connect devices across protocols")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "point.3.connected.trianglepath.dotted")
                                .font(.title)
                                .foregroundStyle(ModernColors.cyan)
                        }

                        HStack(spacing: 20) {
                            VStack {
                                Text("\(hubService.totalIntegratedDevices)")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                Text("Devices")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            VStack {
                                Text("\(hubService.activeProtocolsCount)")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                Text("Protocols")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            VStack {
                                Text("\(hubService.threadNetworks.count)")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                Text("Networks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                }

                // Pairing Session
                if let session = hubService.currentPairingSession {
                    GlassCard {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Pairing: \(session.deviceName)")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(session.status.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(session.status.color)
                            }

                            ProgressView(value: session.progress)
                                .tint(session.status.color)

                            if let error = session.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(ModernColors.red)
                            }
                        }
                        .padding()
                    }
                }

                // Protocols
                VStack(alignment: .leading, spacing: 12) {
                    Text("Protocols")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(hubService.protocols) { proto in
                        GlassCard {
                            HStack {
                                Image(systemName: proto.protocolType.icon)
                                    .font(.title2)
                                    .foregroundStyle(proto.protocolType.color)
                                    .frame(width: 40)

                                VStack(alignment: .leading) {
                                    Text(proto.name)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text(proto.protocolType.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing) {
                                    Text("\(proto.deviceCount)")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text("devices")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Toggle("", isOn: Binding(
                                    get: { proto.isEnabled },
                                    set: { hubService.toggleProtocol(proto.id, enabled: $0) }
                                ))
                                .tint(proto.protocolType.color)
                            }
                            .padding()
                        }
                    }
                }

                // Matter Devices
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Matter Devices")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Spacer()

                        Button {
                            showPairingSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(ModernColors.cyan)
                        }
                    }

                    if hubService.matterDevices.isEmpty {
                        GlassCard {
                            VStack(spacing: 12) {
                                Image(systemName: "point.3.connected.trianglepath.dotted")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                                Text("No Matter devices")
                                    .foregroundStyle(.secondary)
                                Button("Add Matter Device") {
                                    showPairingSheet = true
                                }
                                .font(.subheadline)
                                .foregroundStyle(ModernColors.cyan)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        ForEach(hubService.matterDevices) { device in
                            GlassCard {
                                HStack {
                                    Image(systemName: device.deviceType.icon)
                                        .font(.title2)
                                        .foregroundStyle(ModernColors.cyan)

                                    VStack(alignment: .leading) {
                                        Text(device.name)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Text(device.deviceType.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if device.isCommissioned {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(ModernColors.accentGreen)
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                }

                // Thread Networks
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Thread Networks")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Spacer()

                        Button {
                            Task {
                                await hubService.scanForThreadNetworks()
                            }
                        } label: {
                            if hubService.isScanning {
                                ProgressView()
                                    .tint(ModernColors.cyan)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(ModernColors.cyan)
                            }
                        }
                        .disabled(hubService.isScanning)
                    }

                    if hubService.threadNetworks.isEmpty {
                        GlassCard {
                            VStack(spacing: 12) {
                                Image(systemName: "network")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                                Text("No Thread networks found")
                                    .foregroundStyle(.secondary)
                                Button("Scan for Networks") {
                                    Task {
                                        await hubService.scanForThreadNetworks()
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(ModernColors.cyan)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        ForEach(hubService.threadNetworks) { network in
                            GlassCard {
                                HStack {
                                    Circle()
                                        .fill(network.isActive ? ModernColors.accentGreen : .secondary)
                                        .frame(width: 10, height: 10)

                                    VStack(alignment: .leading) {
                                        Text(network.networkName)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Text("\(network.totalDevices) devices")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing) {
                                        Text("\(network.borderRouters) BR")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("\(network.endDevices) ED")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    if !network.isActive {
                                        Button("Join") {
                                            hubService.joinThreadNetwork(network.id)
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(ModernColors.cyan)
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                }

                // Discovered Devices
                if !hubService.discoveredDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Discovered Devices")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(hubService.discoveredDevices) { device in
                            GlassCard {
                                HStack {
                                    Image(systemName: device.deviceType.icon)
                                        .font(.title2)
                                        .foregroundStyle(ModernColors.orange)

                                    VStack(alignment: .leading) {
                                        Text(device.name)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Text("Ready to pair")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Button {
                                        Task {
                                            await hubService.commissionDevice(device)
                                        }
                                    } label: {
                                        Text("Pair")
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(ModernColors.cyan)
                                            .clipShape(Capsule())
                                    }
                                    .disabled(hubService.isPairing)
                                }
                                .padding()
                            }
                        }
                    }
                }

                // Scan Button
                GlassCard {
                    Button {
                        Task {
                            await hubService.startDeviceScan()
                        }
                    } label: {
                        HStack {
                            if hubService.isScanning {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                            }
                            Text(hubService.isScanning ? "Scanning..." : "Scan for Devices")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ModernColors.cyan)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(hubService.isScanning)
                    .padding()
                }
            }
            .padding()
        }
        .background(LinearGradient.modernBackground.ignoresSafeArea())
        .navigationTitle("Integration Hub")
        .sheet(isPresented: $showPairingSheet) {
            MatterPairingView(setupCode: $setupCode)
        }
    }
}

struct MatterPairingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var hubService = IntegrationHubService.shared
    @Binding var setupCode: String

    var body: some View {
        NavigationStack {
            Form {
                Section("Matter Setup Code") {
                    TextField("Setup Code (e.g., 123-45-678)", text: $setupCode)
                        .keyboardType(.numberPad)

                    Text("Enter the 11-digit setup code found on your device or packaging")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Or Scan QR Code") {
                    Button {
                        // QR Scanner would go here
                    } label: {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Scan QR Code")
                        }
                    }
                }
            }
            .navigationTitle("Add Matter Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Pair") {
                        Task {
                            await hubService.startMatterPairing(setupCode: setupCode)
                            dismiss()
                        }
                    }
                    .disabled(setupCode.count < 8)
                }
            }
        }
    }
}
