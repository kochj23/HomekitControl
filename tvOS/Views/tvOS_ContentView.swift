//
//  tvOS_ContentView.swift
//  HomekitControl
//
//  Main content view for tvOS with 10-foot UI
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

struct tvOS_ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            GlassmorphicBackground()
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                tvOS_HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                tvOS_RoomsView()
                    .tabItem {
                        Label("Rooms", systemImage: "square.grid.2x2.fill")
                    }
                    .tag(1)

                tvOS_ScenesView()
                    .tabItem {
                        Label("Scenes", systemImage: "theatermasks.fill")
                    }
                    .tag(2)

                tvOS_AccessoriesView()
                    .tabItem {
                        Label("Accessories", systemImage: "lightbulb.fill")
                    }
                    .tag(3)

                tvOS_NetworkView()
                    .tabItem {
                        Label("Network", systemImage: "network")
                    }
                    .tag(4)

                tvOS_MoreView()
                    .tabItem {
                        Label("More", systemImage: "ellipsis.circle.fill")
                    }
                    .tag(5)
            }
        }
    }
}

// MARK: - Home View

struct tvOS_HomeView: View {
    @StateObject private var homeKitService = HomeKitService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 60) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("HomekitControl")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(homeKitService.currentHome?.name ?? "Smart Home")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "house.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(ModernColors.accent)
                }
                .padding(.horizontal, 80)

                // Stats
                HStack(spacing: 40) {
                    TVStatCard(value: "\(homeKitService.accessories.count)", label: "Devices", icon: "lightbulb.fill", color: ModernColors.accent)
                    TVStatCard(value: "\(homeKitService.scenes.count)", label: "Scenes", icon: "theatermasks.fill", color: ModernColors.cyan)
                    TVStatCard(value: "\(homeKitService.rooms.count)", label: "Rooms", icon: "rectangle.split.3x3", color: ModernColors.magenta)
                }
                .padding(.horizontal, 80)

                // Quick Scenes
                if !homeKitService.scenes.isEmpty {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Quick Scenes")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 80)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 30) {
                                ForEach(homeKitService.scenes.prefix(6), id: \.uniqueIdentifier) { scene in
                                    TVSceneCard(scene: scene) {
                                        Task { try? await homeKitService.executeScene(scene) }
                                    }
                                }
                            }
                            .padding(.horizontal, 80)
                        }
                    }
                }
            }
            .padding(.vertical, 60)
        }
    }
}

// MARK: - Rooms View

struct tvOS_RoomsView: View {
    @StateObject private var homeKitService = HomeKitService.shared

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 40),
                GridItem(.flexible(), spacing: 40),
                GridItem(.flexible(), spacing: 40)
            ], spacing: 40) {
                ForEach(homeKitService.rooms, id: \.uniqueIdentifier) { room in
                    TVRoomCard(room: room)
                }
            }
            .padding(80)
        }
    }
}

// MARK: - Scenes View

struct tvOS_ScenesView: View {
    @StateObject private var homeKitService = HomeKitService.shared

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 40),
                GridItem(.flexible(), spacing: 40),
                GridItem(.flexible(), spacing: 40),
                GridItem(.flexible(), spacing: 40)
            ], spacing: 40) {
                ForEach(homeKitService.scenes, id: \.uniqueIdentifier) { scene in
                    TVSceneCard(scene: scene) {
                        Task { try? await homeKitService.executeScene(scene) }
                    }
                }
            }
            .padding(80)
        }
    }
}

// MARK: - Accessories View

struct tvOS_AccessoriesView: View {
    @StateObject private var homeKitService = HomeKitService.shared
    @StateObject private var healthService = DeviceHealthService.shared

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 40),
                GridItem(.flexible(), spacing: 40),
                GridItem(.flexible(), spacing: 40),
                GridItem(.flexible(), spacing: 40)
            ], spacing: 40) {
                ForEach(homeKitService.accessories, id: \.uniqueIdentifier) { accessory in
                    TVAccessoryCard(
                        accessory: accessory,
                        healthStatus: healthService.getHealthStatus(for: accessory.uniqueIdentifier)
                    ) {
                        Task { try? await homeKitService.toggleAccessory(accessory) }
                    }
                }
            }
            .padding(80)
        }
    }
}

// MARK: - Network View

struct tvOS_NetworkView: View {
    @StateObject private var networkService = NetworkDiscoveryService.shared

    var body: some View {
        VStack(spacing: 40) {
            HStack {
                Text("Network Devices")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Button {
                    networkService.startDiscovery()
                } label: {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text(networkService.isScanning ? "Scanning..." : "Scan")
                    }
                    .font(.system(size: 24))
                }
                .disabled(networkService.isScanning)
            }
            .padding(.horizontal, 80)

            if networkService.discoveredDevices.isEmpty && !networkService.isScanning {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 80))
                        .foregroundStyle(.secondary)
                    Text("No devices found")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Press Scan to discover devices")
                        .font(.system(size: 20))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 30),
                        GridItem(.flexible(), spacing: 30),
                        GridItem(.flexible(), spacing: 30)
                    ], spacing: 30) {
                        ForEach(networkService.discoveredDevices) { device in
                            TVNetworkDeviceCard(device: device)
                        }
                    }
                    .padding(.horizontal, 80)
                }
            }
        }
        .padding(.vertical, 60)
    }
}

// MARK: - More View

struct tvOS_MoreView: View {
    @StateObject private var aiService = AIService.shared
    @State private var showingRemoteControl = false
    @State private var showingAmbientMode = false

    var body: some View {
        ScrollView {
            VStack(spacing: 50) {
                // Quick Access Row
                HStack(spacing: 40) {
                    TVMoreFeatureCard(
                        title: "Quick Controls",
                        subtitle: "Remote widget",
                        icon: "hand.tap.fill",
                        color: ModernColors.accent
                    ) {
                        showingRemoteControl = true
                    }

                    TVMoreFeatureCard(
                        title: "Ambient Mode",
                        subtitle: "Clock screensaver",
                        icon: "clock.fill",
                        color: ModernColors.purple
                    ) {
                        showingAmbientMode = true
                    }
                }
                .padding(.horizontal, 80)

                // Feature Grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 40),
                    GridItem(.flexible(), spacing: 40),
                    GridItem(.flexible(), spacing: 40)
                ], spacing: 40) {
                    NavigationLink {
                        tvOS_GroupsView()
                    } label: {
                        TVMoreCard(
                            title: "Device Groups",
                            subtitle: "Control multiple devices",
                            icon: "rectangle.3.group.fill",
                            color: ModernColors.cyan
                        )
                    }
                    .buttonStyle(.card)

                    NavigationLink {
                        tvOS_EnergyView()
                    } label: {
                        TVMoreCard(
                            title: "Energy Monitor",
                            subtitle: "Power consumption",
                            icon: "bolt.fill",
                            color: ModernColors.yellow
                        )
                    }
                    .buttonStyle(.card)

                    NavigationLink {
                        tvOS_HealthView()
                    } label: {
                        TVMoreCard(
                            title: "Device Health",
                            subtitle: "Monitor status",
                            icon: "heart.fill",
                            color: ModernColors.magenta
                        )
                    }
                    .buttonStyle(.card)

                    NavigationLink {
                        tvOS_ScheduleView()
                    } label: {
                        TVMoreCard(
                            title: "Schedules",
                            subtitle: "Scene scheduling",
                            icon: "calendar.badge.clock",
                            color: ModernColors.orange
                        )
                    }
                    .buttonStyle(.card)

                    NavigationLink {
                        tvOS_AutomationView()
                    } label: {
                        TVMoreCard(
                            title: "Automations",
                            subtitle: "Custom automations",
                            icon: "gearshape.2.fill",
                            color: ModernColors.purple
                        )
                    }
                    .buttonStyle(.card)

                    NavigationLink {
                        tvOS_AIAssistantView()
                    } label: {
                        TVMoreCard(
                            title: "AI Assistant",
                            subtitle: "Smart home help",
                            icon: "sparkles",
                            color: ModernColors.accentBlue
                        )
                    }
                    .buttonStyle(.card)
                }
                .padding(.horizontal, 80)

                // App Info
                GlassCard {
                    VStack(spacing: 20) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(ModernColors.accent)

                        Text("HomekitControl")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Version 1.0.0")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)

                        Text("Created by Jordan Koch")
                            .font(.system(size: 18))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(40)
                }
                .padding(.horizontal, 80)
            }
            .padding(.vertical, 60)
        }
        .fullScreenCover(isPresented: $showingRemoteControl) {
            tvOS_RemoteControlWidget(isPresented: $showingRemoteControl)
        }
        .fullScreenCover(isPresented: $showingAmbientMode) {
            tvOS_AmbientModeView(isPresented: $showingAmbientMode)
        }
    }
}

// MARK: - TV More Feature Card (Interactive)

struct TVMoreFeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            GlassCard {
                VStack(spacing: 16) {
                    Image(systemName: icon)
                        .font(.system(size: 50))
                        .foregroundStyle(color)

                    Text(title)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .padding(40)
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.card)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - TV More Card (Navigation)

struct TVMoreCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    @FocusState private var isFocused: Bool

    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 50))
                    .foregroundStyle(color)

                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .padding(30)
            .frame(maxWidth: .infinity)
        }
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - TV AI Assistant View

struct tvOS_AIAssistantView: View {
    @StateObject private var aiService = AIService.shared
    @State private var query = ""
    @State private var response = ""
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 40) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("AI Assistant")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Powered by \(aiService.selectedProvider.rawValue)")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundStyle(ModernColors.accent)
            }
            .padding(.horizontal, 80)

            // Chat Display
            GlassCard {
                VStack(alignment: .leading, spacing: 20) {
                    if !response.isEmpty {
                        ScrollView {
                            Text(response)
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                        }
                        .frame(maxHeight: 400)
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                            Text("Ask about your smart home")
                                .font(.system(size: 24))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(40)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 80)

            // Quick Questions
            VStack(alignment: .leading, spacing: 20) {
                Text("Quick Questions")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 80)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 30) {
                        TVQuickQuestionButton(question: "How many devices are online?") { q in
                            askQuestion(q)
                        }

                        TVQuickQuestionButton(question: "What scenes do I have?") { q in
                            askQuestion(q)
                        }

                        TVQuickQuestionButton(question: "Any device issues?") { q in
                            askQuestion(q)
                        }

                        TVQuickQuestionButton(question: "Energy usage today?") { q in
                            askQuestion(q)
                        }
                    }
                    .padding(.horizontal, 80)
                }
            }
        }
        .padding(.vertical, 60)
    }

    private func askQuestion(_ question: String) {
        isProcessing = true
        Task {
            response = await aiService.getResponse(question)
            isProcessing = false
        }
    }
}

struct TVQuickQuestionButton: View {
    let question: String
    let action: (String) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button {
            action(question)
        } label: {
            GlassCard {
                Text(question)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .frame(width: 220, height: 100)
            }
        }
        .buttonStyle(.card)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - TV Cards

struct TVStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 50))
                    .foregroundStyle(color)

                Text(value)
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.white)

                Text(label)
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
    }
}

struct TVSceneCard: View {
    let scene: HMActionSet
    let action: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            GlassCard {
                VStack(spacing: 20) {
                    Image(systemName: sceneIcon)
                        .font(.system(size: 50))
                        .foregroundStyle(ModernColors.accent)

                    Text(scene.name)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text("\(scene.actions.count) actions")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .padding(30)
                .frame(width: 250, height: 200)
            }
        }
        .buttonStyle(.card)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }

    private var sceneIcon: String {
        let name = scene.name.lowercased()
        if name.contains("morning") { return "sun.max.fill" }
        if name.contains("night") { return "moon.stars.fill" }
        if name.contains("away") { return "figure.walk" }
        if name.contains("home") { return "house.fill" }
        return "sparkles"
    }
}

struct TVRoomCard: View {
    let room: HMRoom
    @FocusState private var isFocused: Bool

    var body: some View {
        Button { } label: {
            GlassCard {
                VStack(spacing: 20) {
                    Image(systemName: "rectangle.split.3x3")
                        .font(.system(size: 50))
                        .foregroundStyle(ModernColors.cyan)

                    Text(room.name)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("\(room.accessories.count) accessories")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .padding(40)
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.card)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

struct TVAccessoryCard: View {
    let accessory: HMAccessory
    let healthStatus: HealthStatus
    let action: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            GlassCard {
                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(healthStatus.color)
                            .frame(width: 12, height: 12)
                    }

                    Image(systemName: accessoryIcon)
                        .font(.system(size: 50))
                        .foregroundStyle(accessory.isReachable ? ModernColors.accent : .secondary)

                    Text(accessory.name)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text(accessory.isReachable ? "Reachable" : "Unreachable")
                        .font(.system(size: 16))
                        .foregroundStyle(accessory.isReachable ? ModernColors.statusLow : ModernColors.statusCritical)
                }
                .padding(24)
                .frame(width: 220, height: 200)
            }
        }
        .buttonStyle(.card)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }

    private var accessoryIcon: String {
        if accessory.services.contains(where: { $0.serviceType == HMServiceTypeLightbulb }) {
            return DeviceCategory.light.icon
        }
        if accessory.services.contains(where: { $0.serviceType == HMServiceTypeSwitch }) {
            return DeviceCategory.switchDevice.icon
        }
        return DeviceCategory.other.icon
    }
}

struct TVNetworkDeviceCard: View {
    let device: DiscoveredDevice

    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: device.deviceType.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(ModernColors.accent)

                Text(device.name)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(device.manufacturer.rawValue)
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)

                if let ip = device.ipAddress {
                    Text(ip)
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    tvOS_ContentView()
}
