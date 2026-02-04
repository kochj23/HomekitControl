//
//  iOS_SecurityView.swift
//  HomekitControl
//
//  Security dashboard for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct iOS_SecurityView: View {
    @StateObject private var securityService = SecurityService.shared
    @State private var showModeSelector = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                securityModeCard
                statusOverview
                locksSection
                contactSensorsSection
                recentEventsSection
            }
            .padding()
        }
        .background(LinearGradient.modernBackground.ignoresSafeArea())
        .navigationTitle("Security")
        .onAppear {
            securityService.startMonitoring()
        }
    }

    private var securityModeCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Security Mode")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(securityService.isSecure ? "All secure" : "Attention needed")
                            .font(.subheadline)
                            .foregroundStyle(securityService.isSecure ? ModernColors.accentGreen : ModernColors.orange)
                    }

                    Spacer()

                    Button {
                        showModeSelector = true
                    } label: {
                        HStack {
                            Image(systemName: securityService.currentMode.icon)
                            Text(securityService.currentMode.rawValue)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(securityService.currentMode.color)
                        .clipShape(Capsule())
                        .foregroundStyle(.white)
                    }
                }

                // Quick Mode Buttons
                HStack(spacing: 12) {
                    ForEach(SecurityMode.allCases, id: \.self) { mode in
                        Button {
                            securityService.setSecurityMode(mode)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: mode.icon)
                                    .font(.title2)
                                Text(mode.rawValue)
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(securityService.currentMode == mode ? mode.color : ModernColors.glassBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var statusOverview: some View {
        HStack(spacing: 12) {
            SecurityStatusCard(
                title: "Locks",
                count: securityService.locks.count,
                alert: securityService.unlockedDoors.count,
                icon: "lock.fill",
                color: securityService.unlockedDoors.isEmpty ? ModernColors.accentGreen : ModernColors.red
            )

            SecurityStatusCard(
                title: "Sensors",
                count: securityService.securityDevices.filter { $0.type == .contactSensor }.count,
                alert: securityService.openContacts.count,
                icon: "door.left.hand.closed",
                color: securityService.openContacts.isEmpty ? ModernColors.accentGreen : ModernColors.orange
            )

            SecurityStatusCard(
                title: "Motion",
                count: securityService.motionSensors.count,
                alert: securityService.activeMotionSensors.count,
                icon: "figure.walk.motion",
                color: securityService.activeMotionSensors.isEmpty ? ModernColors.accentGreen : ModernColors.cyan
            )
        }
    }

    @ViewBuilder
    private var locksSection: some View {
        if !securityService.locks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Locks")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        Task { await securityService.lockAllDoors() }
                    } label: {
                        Text("Lock All")
                            .font(.caption)
                            .foregroundStyle(ModernColors.cyan)
                    }
                }

                ForEach(securityService.locks) { device in
                    LockRowView(device: device, securityService: securityService)
                }
            }
        }
    }

    @ViewBuilder
    private var contactSensorsSection: some View {
        let contactSensors = securityService.securityDevices.filter { $0.type == .contactSensor }
        if !contactSensors.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Doors & Windows")
                    .font(.headline)
                    .foregroundStyle(.white)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(contactSensors) { device in
                        ContactSensorCard(device: device)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentEventsSection: some View {
        if !securityService.events.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Events")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(securityService.recentEvents) { event in
                    EventRowView(event: event)
                }
            }
        }
    }
}

// MARK: - Helper Views

struct SecurityStatusCard: View {
    let title: String
    let count: Int
    let alert: Int
    let icon: String
    let color: Color

    var body: some View {
        GlassCard {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)

                Text("\(count)")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if alert > 0 {
                    Text("\(alert) alert\(alert > 1 ? "s" : "")")
                        .font(.caption2)
                        .foregroundStyle(color)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
}

struct LockRowView: View {
    let device: SecurityDevice
    @ObservedObject var securityService: SecurityService

    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: device.state == .locked ? "lock.fill" : "lock.open.fill")
                    .font(.title2)
                    .foregroundStyle(device.state == .locked ? ModernColors.accentGreen : ModernColors.red)
                    .frame(width: 40)

                VStack(alignment: .leading) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(device.state.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task {
                        if device.state == .locked {
                            await securityService.unlockDoor(device.id)
                        } else {
                            await securityService.lockDoor(device.id)
                        }
                    }
                } label: {
                    Text(device.state == .locked ? "Unlock" : "Lock")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(device.state == .locked ? ModernColors.orange : ModernColors.accentGreen)
                        .clipShape(Capsule())
                        .foregroundStyle(.white)
                }
            }
            .padding()
        }
    }
}

struct ContactSensorCard: View {
    let device: SecurityDevice

    var body: some View {
        GlassCard {
            VStack(spacing: 8) {
                Image(systemName: device.state == .closed ? "door.left.hand.closed" : "door.left.hand.open")
                    .font(.title)
                    .foregroundStyle(device.state == .closed ? ModernColors.accentGreen : ModernColors.orange)

                Text(device.name)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(device.state.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

struct EventRowView: View {
    let event: SecurityEvent

    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: iconForEventType(event.eventType))
                    .foregroundStyle(colorForEventType(event.eventType))

                VStack(alignment: .leading) {
                    Text(event.eventType.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Text(event.deviceName)
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

    private func iconForEventType(_ type: SecurityEvent.SecurityEventType) -> String {
        switch type {
        case .motionDetected: return "figure.walk.motion"
        case .doorOpened: return "door.left.hand.open"
        case .doorClosed: return "door.left.hand.closed"
        case .lockLocked: return "lock.fill"
        case .lockUnlocked: return "lock.open.fill"
        case .alarmTriggered: return "bell.badge.fill"
        case .smokeDetected: return "smoke.fill"
        case .coDetected: return "exclamationmark.triangle.fill"
        case .waterDetected: return "drop.fill"
        case .deviceOffline: return "wifi.slash"
        case .deviceOnline: return "wifi"
        case .lowBattery: return "battery.25"
        }
    }

    private func colorForEventType(_ type: SecurityEvent.SecurityEventType) -> Color {
        switch type {
        case .motionDetected: return ModernColors.cyan
        case .doorOpened, .lockUnlocked: return ModernColors.orange
        case .doorClosed, .lockLocked, .deviceOnline: return ModernColors.accentGreen
        case .alarmTriggered, .smokeDetected, .coDetected: return ModernColors.red
        case .waterDetected: return ModernColors.accentBlue
        case .deviceOffline, .lowBattery: return ModernColors.yellow
        }
    }
}
