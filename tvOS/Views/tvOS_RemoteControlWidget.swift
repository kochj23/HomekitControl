//
//  tvOS_RemoteControlWidget.swift
//  HomekitControl
//
//  Quick control overlay widget for tvOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Remote Control Overlay

struct tvOS_RemoteControlWidget: View {
    @Binding var isPresented: Bool
    @StateObject private var homeKitService = HomeKitService.shared
    @StateObject private var groupService = DeviceGroupService.shared
    @FocusState private var focusedSection: ControlSection?

    enum ControlSection: Hashable {
        case scenes
        case groups
        case quickActions
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { isPresented = false }
                }

            VStack(spacing: 50) {
                // Header
                HStack {
                    Text("Quick Controls")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        withAnimation { isPresented = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.card)
                }
                .padding(.horizontal, 80)

                // Quick Actions Row
                VStack(alignment: .leading, spacing: 20) {
                    Text("Quick Actions")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 80)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 30) {
                            TVQuickActionButton(
                                icon: "lightbulb.fill",
                                label: "All Lights On",
                                color: ModernColors.yellow
                            ) {
                                Task {
                                    for group in groupService.groups where group.name.lowercased().contains("light") {
                                        try? await groupService.turnOnGroup(group)
                                    }
                                }
                            }

                            TVQuickActionButton(
                                icon: "lightbulb.slash",
                                label: "All Lights Off",
                                color: ModernColors.red
                            ) {
                                Task {
                                    for group in groupService.groups where group.name.lowercased().contains("light") {
                                        try? await groupService.turnOffGroup(group)
                                    }
                                }
                            }

                            TVQuickActionButton(
                                icon: "moon.fill",
                                label: "Dim 50%",
                                color: ModernColors.purple
                            ) {
                                Task {
                                    for group in groupService.groups where group.name.lowercased().contains("light") {
                                        try? await groupService.setGroupBrightness(group, brightness: 50)
                                    }
                                }
                            }

                            TVQuickActionButton(
                                icon: "sun.max.fill",
                                label: "Full Bright",
                                color: ModernColors.orange
                            ) {
                                Task {
                                    for group in groupService.groups where group.name.lowercased().contains("light") {
                                        try? await groupService.setGroupBrightness(group, brightness: 100)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 80)
                    }
                }
                .focused($focusedSection, equals: .quickActions)

                // Favorite Scenes
                VStack(alignment: .leading, spacing: 20) {
                    Text("Scenes")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 80)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 30) {
                            ForEach(homeKitService.scenes.prefix(8), id: \.uniqueIdentifier) { scene in
                                TVQuickSceneButton(scene: scene) {
                                    Task {
                                        try? await homeKitService.executeScene(scene)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 80)
                    }
                }
                .focused($focusedSection, equals: .scenes)

                // Device Groups
                VStack(alignment: .leading, spacing: 20) {
                    Text("Groups")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 80)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 30) {
                            ForEach(groupService.groups.prefix(6)) { group in
                                TVQuickGroupButton(group: group)
                            }
                        }
                        .padding(.horizontal, 80)
                    }
                }
                .focused($focusedSection, equals: .groups)

                Spacer()
            }
            .padding(.vertical, 60)
        }
    }
}

// MARK: - TV Quick Action Button

struct TVQuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    @FocusState private var isFocused: Bool
    @State private var isProcessing = false

    var body: some View {
        Button {
            isProcessing = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isProcessing = false
            }
        } label: {
            GlassCard {
                VStack(spacing: 16) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(1.2)
                            .frame(width: 50, height: 50)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 50))
                            .foregroundStyle(color)
                    }

                    Text(label)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(30)
                .frame(width: 180, height: 160)
            }
        }
        .buttonStyle(.card)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - TV Quick Scene Button

struct TVQuickSceneButton: View {
    let scene: HMActionSet
    let action: () -> Void

    @FocusState private var isFocused: Bool
    @State private var isExecuting = false

    var body: some View {
        Button {
            isExecuting = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                isExecuting = false
            }
        } label: {
            GlassCard {
                VStack(spacing: 12) {
                    if isExecuting {
                        ProgressView()
                            .scaleEffect(1.2)
                            .frame(width: 40, height: 40)
                    } else {
                        Image(systemName: sceneIcon)
                            .font(.system(size: 40))
                            .foregroundStyle(ModernColors.accent)
                    }

                    Text(scene.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(width: 160, height: 140)
            }
        }
        .buttonStyle(.card)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }

    private var sceneIcon: String {
        let name = scene.name.lowercased()
        if name.contains("morning") { return "sun.max.fill" }
        if name.contains("night") { return "moon.stars.fill" }
        if name.contains("away") { return "figure.walk" }
        if name.contains("home") { return "house.fill" }
        if name.contains("movie") { return "tv.fill" }
        if name.contains("dinner") { return "fork.knife" }
        return "sparkles"
    }
}

// MARK: - TV Quick Group Button

struct TVQuickGroupButton: View {
    let group: DeviceGroup
    @StateObject private var groupService = DeviceGroupService.shared
    @FocusState private var isFocused: Bool
    @State private var isOn = true

    var body: some View {
        Button {
            Task {
                if isOn {
                    try? await groupService.turnOffGroup(group)
                } else {
                    try? await groupService.turnOnGroup(group)
                }
                isOn.toggle()
            }
        } label: {
            GlassCard {
                VStack(spacing: 12) {
                    Image(systemName: group.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(isOn ? colorFromString(group.color) : .secondary)

                    Text(group.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text("\(group.deviceCount) devices")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(width: 160, height: 150)
            }
        }
        .buttonStyle(.card)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.1 : 1.0)
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

// MARK: - Ambient Mode View

struct tvOS_AmbientModeView: View {
    @Binding var isPresented: Bool
    @StateObject private var homeKitService = HomeKitService.shared
    @State private var currentTime = Date()
    @State private var showingQuickControls = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    ModernColors.darkBackground,
                    ModernColors.darkBackground.opacity(0.8),
                    ModernColors.accent.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Clock
                Text(currentTime, style: .time)
                    .font(.system(size: 180, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(.white)

                Text(currentTime, style: .date)
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.secondary)

                Spacer()

                // Status Bar
                HStack(spacing: 60) {
                    // Devices Online
                    HStack(spacing: 12) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(ModernColors.accentGreen)
                        Text("\(homeKitService.accessories.filter { $0.isReachable }.count) online")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                    }

                    // Scenes
                    HStack(spacing: 12) {
                        Image(systemName: "theatermasks.fill")
                            .foregroundStyle(ModernColors.cyan)
                        Text("\(homeKitService.scenes.count) scenes")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                    }

                    // Home
                    HStack(spacing: 12) {
                        Image(systemName: "house.fill")
                            .foregroundStyle(ModernColors.accent)
                        Text(homeKitService.currentHome?.name ?? "Home")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                    }
                }

                // Hint
                Text("Press Menu to exit • Press Select for controls")
                    .font(.system(size: 18))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 40)
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .onExitCommand {
            isPresented = false
        }
        .onPlayPauseCommand {
            showingQuickControls = true
        }
        .fullScreenCover(isPresented: $showingQuickControls) {
            tvOS_RemoteControlWidget(isPresented: $showingQuickControls)
        }
    }
}

#Preview {
    tvOS_RemoteControlWidget(isPresented: .constant(true))
}
