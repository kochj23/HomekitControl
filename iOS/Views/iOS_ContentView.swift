//
//  iOS_ContentView.swift
//  HomekitControl
//
//  Main content view for iOS with tab-based navigation
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct iOS_ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            GlassmorphicBackground()
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                iOS_HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                iOS_DevicesView()
                    .tabItem {
                        Label("Devices", systemImage: "lightbulb.fill")
                    }
                    .tag(1)

                iOS_ScenesView()
                    .tabItem {
                        Label("Scenes", systemImage: "theatermasks.fill")
                    }
                    .tag(2)

                iOS_NetworkView()
                    .tabItem {
                        Label("Network", systemImage: "network")
                    }
                    .tag(3)

                iOS_AIAssistantView()
                    .tabItem {
                        Label("AI", systemImage: "sparkles")
                    }
                    .tag(4)

                iOS_SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(5)
            }
            .tint(ModernColors.cyan)
        }
    }
}

// MARK: - Home View (Dashboard)

struct iOS_HomeView: View {
    @StateObject private var homeKitService = HomeKitService.shared
    @StateObject private var healthService = DeviceHealthService.shared
    @StateObject private var networkService = NetworkDiscoveryService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphicBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Welcome header
                        welcomeHeader

                        // Quick stats
                        statsSection

                        // Quick actions
                        quickActionsSection

                        // Recent activity
                        if !homeKitService.scenes.isEmpty {
                            recentScenesSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Home")
            .refreshable {
                await homeKitService.refreshAll()
            }
        }
    }

    private var welcomeHeader: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("HomekitControl")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text(homeKitService.currentHome?.name ?? "Smart Home")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "house.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(ModernColors.accent)
            }
            .padding()
        }
    }

    private var statsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(value: "\(homeKitService.accessories.count)", label: "Devices", icon: "lightbulb.fill", color: ModernColors.accent)
            StatCard(value: "\(homeKitService.scenes.count)", label: "Scenes", icon: "theatermasks.fill", color: ModernColors.cyan)
            StatCard(value: "\(homeKitService.rooms.count)", label: "Rooms", icon: "rectangle.split.3x3", color: ModernColors.magenta)
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickActionCard(title: "Scan Network", icon: "antenna.radiowaves.left.and.right", color: ModernColors.cyan) {
                    networkService.startDiscovery()
                }

                QuickActionCard(title: "Test Devices", icon: "heart.fill", color: ModernColors.magenta) {
                    Task {
                        if let home = homeKitService.currentHome {
                            await healthService.testAllDevices(in: home)
                        }
                    }
                }
            }
        }
    }

    private var recentScenesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Scenes")
                .font(.headline)
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(homeKitService.scenes.prefix(5), id: \.uniqueIdentifier) { scene in
                        QuickSceneCard(scene: scene) {
                            Task { try? await homeKitService.executeScene(scene) }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        GlassCard {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)

                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .buttonStyle(.plain)
    }
}

struct QuickSceneCard: View {
    let scene: HMActionSet
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard {
                VStack(spacing: 8) {
                    Image(systemName: sceneIcon)
                        .font(.title2)
                        .foregroundStyle(ModernColors.accent)

                    Text(scene.name)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding()
                .frame(width: 100)
            }
        }
        .buttonStyle(.plain)
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

#if canImport(HomeKit)
import HomeKit
#endif

#Preview {
    iOS_ContentView()
}
