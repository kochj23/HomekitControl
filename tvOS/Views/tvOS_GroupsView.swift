//
//  tvOS_GroupsView.swift
//  HomekitControl
//
//  Device groups view for tvOS with 10-foot UI
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

struct tvOS_GroupsView: View {
    @StateObject private var groupService = DeviceGroupService.shared
    @StateObject private var homeKitService = HomeKitService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 60) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Device Groups")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.white)

                        Text("\(groupService.groups.count) groups")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "rectangle.3.group.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(ModernColors.cyan)
                }
                .padding(.horizontal, 80)

                // Groups Grid
                if groupService.groups.isEmpty {
                    VStack(spacing: 30) {
                        Image(systemName: "rectangle.3.group")
                            .font(.system(size: 80))
                            .foregroundStyle(.secondary)
                        Text("No groups created")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 40),
                        GridItem(.flexible(), spacing: 40),
                        GridItem(.flexible(), spacing: 40)
                    ], spacing: 40) {
                        ForEach(groupService.groups) { group in
                            TVGroupCard(group: group)
                        }
                    }
                    .padding(.horizontal, 80)
                }
            }
            .padding(.vertical, 60)
        }
    }
}

// MARK: - TV Group Card

struct TVGroupCard: View {
    let group: DeviceGroup
    @StateObject private var groupService = DeviceGroupService.shared
    @FocusState private var isFocused: Bool
    @State private var isProcessing = false

    var body: some View {
        Button {
            Task {
                isProcessing = true
                try? await groupService.turnOnGroup(group)
                isProcessing = false
            }
        } label: {
            GlassCard {
                VStack(spacing: 20) {
                    HStack {
                        Spacer()
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Circle()
                                .fill(group.isEnabled ? ModernColors.accentGreen : .secondary)
                                .frame(width: 14, height: 14)
                        }
                    }

                    Image(systemName: group.icon)
                        .font(.system(size: 50))
                        .foregroundStyle(colorFromString(group.color))

                    Text(group.name)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text("\(group.deviceCount) devices")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)

                    // Quick control buttons
                    HStack(spacing: 20) {
                        Button {
                            Task { try? await groupService.turnOnGroup(group) }
                        } label: {
                            Image(systemName: "power")
                                .font(.system(size: 24))
                                .foregroundStyle(ModernColors.accentGreen)
                        }
                        .buttonStyle(.card)

                        Button {
                            Task { try? await groupService.turnOffGroup(group) }
                        } label: {
                            Image(systemName: "power.circle")
                                .font(.system(size: 24))
                                .foregroundStyle(ModernColors.red)
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(30)
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.card)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
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

#Preview {
    tvOS_GroupsView()
}
