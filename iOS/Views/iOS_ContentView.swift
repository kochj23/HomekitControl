//
//  iOS_ContentView.swift
//  HomekitControl
//
//  Main content view for iOS with tab-based navigation
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

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

                iOS_AutomationView()
                    .tabItem {
                        Label("Automate", systemImage: "gearshape.2.fill")
                    }
                    .tag(3)

                iOS_MoreView()
                    .tabItem {
                        Label("More", systemImage: "ellipsis.circle.fill")
                    }
                    .tag(4)
            }
            .tint(ModernColors.cyan)
        }
    }
}

// MARK: - More View (Hub for additional features)

struct iOS_MoreView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphicBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Feature Cards - All Clickable
                        NavigationLink {
                            iOS_GroupsView()
                        } label: {
                            MoreFeatureCard(
                                title: "Device Groups",
                                subtitle: "Control multiple devices together",
                                icon: "rectangle.3.group.fill",
                                color: ModernColors.cyan
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            iOS_ScheduleView()
                        } label: {
                            MoreFeatureCard(
                                title: "Scene Scheduling",
                                subtitle: "Schedule scenes by time or sun",
                                icon: "calendar.badge.clock",
                                color: ModernColors.orange
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            iOS_EnergyView()
                        } label: {
                            MoreFeatureCard(
                                title: "Energy Monitor",
                                subtitle: "Track power consumption",
                                icon: "bolt.fill",
                                color: ModernColors.yellow
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            iOS_HealthDashboardView()
                        } label: {
                            MoreFeatureCard(
                                title: "Device Health",
                                subtitle: "Monitor device status",
                                icon: "heart.fill",
                                color: ModernColors.magenta
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            iOS_NotificationsView()
                        } label: {
                            MoreFeatureCard(
                                title: "Notifications",
                                subtitle: "Configure alerts",
                                icon: "bell.fill",
                                color: ModernColors.purple
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            iOS_ShortcutsView()
                        } label: {
                            MoreFeatureCard(
                                title: "Siri Shortcuts",
                                subtitle: "Voice control & widgets",
                                icon: "mic.fill",
                                color: ModernColors.accentBlue
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            iOS_GuestModeView()
                        } label: {
                            MoreFeatureCard(
                                title: "Guest Access",
                                subtitle: "Temporary device access",
                                icon: "person.badge.key.fill",
                                color: ModernColors.teal
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            iOS_BackupView()
                        } label: {
                            MoreFeatureCard(
                                title: "Backup & Restore",
                                subtitle: "Save your configuration",
                                icon: "arrow.down.doc.fill",
                                color: ModernColors.accentGreen
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            iOS_NetworkView()
                        } label: {
                            MoreFeatureCard(
                                title: "Network Scanner",
                                subtitle: "Discover local devices",
                                icon: "network",
                                color: ModernColors.cyan
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            iOS_AIAssistantView()
                        } label: {
                            MoreFeatureCard(
                                title: "AI Assistant",
                                subtitle: "Smart home help",
                                icon: "sparkles",
                                color: ModernColors.magenta
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            iOS_SettingsView()
                        } label: {
                            MoreFeatureCard(
                                title: "Settings",
                                subtitle: "App configuration",
                                icon: "gearshape.fill",
                                color: ModernColors.textSecondary
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                }
            }
            .navigationTitle("More")
        }
    }
}

// MARK: - More Feature Card

struct MoreFeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(subtitle)
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

// MARK: - Home View (Dashboard)

struct iOS_HomeView: View {
    @StateObject private var homeKitService = HomeKitService.shared
    @StateObject private var healthService = DeviceHealthService.shared
    @StateObject private var networkService = NetworkDiscoveryService.shared
    @StateObject private var notificationService = NotificationService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphicBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        welcomeHeader
                        statsSection
                        quickActionsSection

                        if !homeKitService.scenes.isEmpty {
                            recentScenesSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if notificationService.unreadCount > 0 {
                        NavigationLink {
                            iOS_NotificationsView()
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell.fill")
                                Circle()
                                    .fill(ModernColors.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
            }
            .refreshable {
                await homeKitService.refreshAll()
            }
        }
    }

    private var welcomeHeader: some View {
        NavigationLink {
            iOS_SettingsView()
        } label: {
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
        .buttonStyle(.plain)
    }

    private var statsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            NavigationLink {
                iOS_DevicesView()
            } label: {
                StatCard(value: "\(homeKitService.accessories.count)", label: "Devices", icon: "lightbulb.fill", color: ModernColors.accent)
            }
            .buttonStyle(.plain)

            NavigationLink {
                iOS_ScenesView()
            } label: {
                StatCard(value: "\(homeKitService.scenes.count)", label: "Scenes", icon: "theatermasks.fill", color: ModernColors.cyan)
            }
            .buttonStyle(.plain)

            NavigationLink {
                iOS_GroupsView()
            } label: {
                StatCard(value: "\(homeKitService.rooms.count)", label: "Rooms", icon: "rectangle.split.3x3", color: ModernColors.magenta)
            }
            .buttonStyle(.plain)
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink {
                    iOS_NetworkView()
                } label: {
                    QuickActionCard(title: "Scan Network", icon: "antenna.radiowaves.left.and.right", color: ModernColors.cyan) { }
                }
                .buttonStyle(.plain)

                NavigationLink {
                    iOS_HealthDashboardView()
                } label: {
                    QuickActionCard(title: "Device Health", icon: "heart.fill", color: ModernColors.magenta) { }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recentScenesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quick Scenes")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                NavigationLink {
                    iOS_ScenesView()
                } label: {
                    Text("See All")
                        .font(.caption)
                        .foregroundStyle(ModernColors.cyan)
                }
            }

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

#Preview {
    iOS_ContentView()
}
