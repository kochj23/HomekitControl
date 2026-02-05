//
//  HomekitControlWidget.swift
//  HomekitControl Widget
//
//  WidgetKit widget for HomekitControl smart home app
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct HomekitControlProvider: TimelineProvider {
    func placeholder(in context: Context) -> HomekitControlEntry {
        .preview
    }

    func getSnapshot(in context: Context, completion: @escaping (HomekitControlEntry) -> Void) {
        if context.isPreview {
            completion(.preview)
        } else {
            let data = SharedDataManager.shared.loadWidgetData()
            completion(HomekitControlEntry(data: data))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HomekitControlEntry>) -> Void) {
        let data = SharedDataManager.shared.loadWidgetData()
        let entry = HomekitControlEntry(data: data)

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }
}

// MARK: - Widget Views

/// Small widget view - shows unreachable count and quick health status
struct SmallWidgetView: View {
    let entry: HomekitControlEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "house.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.cyan)
                Spacer()
                if entry.data.deviceHealth.unreachableCount > 0 {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
            }

            Spacer()

            // Health status
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.data.homeName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                if entry.data.deviceHealth.unreachableCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        Text("\(entry.data.deviceHealth.unreachableCount) offline")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        Text("All Good")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Text("\(entry.data.deviceHealth.totalDevices) devices")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding()
        .widgetURL(WidgetDeepLink.openHealth)
    }
}

/// Medium widget view - shows favorite scenes and health summary
struct MediumWidgetView: View {
    let entry: HomekitControlEntry

    var body: some View {
        HStack(spacing: 12) {
            // Left side - Health summary
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "house.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.cyan)
                    Text(entry.data.homeName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // Health gauge
                HealthGaugeView(health: entry.data.deviceHealth)

                Text(entry.data.deviceHealth.summaryText)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .background(Color.white.opacity(0.2))

            // Right side - Quick scenes
            VStack(alignment: .leading, spacing: 6) {
                Text("Quick Scenes")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))

                ForEach(entry.data.favoriteScenes.prefix(3)) { scene in
                    Link(destination: WidgetDeepLink.executeScene(id: scene.id) ?? URL(string: "homekitcontrol://")!) {
                        SceneRowView(scene: scene)
                    }
                }

                if entry.data.favoriteScenes.isEmpty {
                    Text("No favorites")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
}

/// Large widget view - full dashboard with scenes and device health
struct LargeWidgetView: View {
    let entry: HomekitControlEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "house.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.cyan)
                Text(entry.data.homeName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(entry.data.lastUpdated, style: .relative)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // Device Health Section
            Link(destination: WidgetDeepLink.openHealth ?? URL(string: "homekitcontrol://")!) {
                DeviceHealthSectionView(health: entry.data.deviceHealth)
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // Scenes Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Favorite Scenes")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Link(destination: WidgetDeepLink.openScenes ?? URL(string: "homekitcontrol://")!) {
                        Text("See All")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.cyan)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(entry.data.favoriteScenes.prefix(4)) { scene in
                        Link(destination: WidgetDeepLink.executeScene(id: scene.id) ?? URL(string: "homekitcontrol://")!) {
                            SceneButtonView(scene: scene)
                        }
                    }
                }

                if entry.data.favoriteScenes.isEmpty {
                    HStack {
                        Spacer()
                        Text("No favorite scenes")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Component Views

struct HealthGaugeView: View {
    let health: WidgetDeviceHealth

    var body: some View {
        HStack(spacing: 8) {
            // Circular progress
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: health.overallHealthPercentage / 100)
                    .stroke(healthColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(health.overallHealthPercentage))%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 44, height: 44)

            // Stats
            VStack(alignment: .leading, spacing: 2) {
                StatRow(icon: "checkmark.circle.fill", color: .green, label: "Healthy", count: health.healthyCount)
                if health.warningCount > 0 {
                    StatRow(icon: "exclamationmark.triangle.fill", color: .orange, label: "Warning", count: health.warningCount)
                }
                if health.unreachableCount > 0 {
                    StatRow(icon: "xmark.circle.fill", color: .red, label: "Offline", count: health.unreachableCount)
                }
            }
        }
    }

    var healthColor: Color {
        if health.unreachableCount > 0 { return .red }
        if health.warningCount > 0 { return .orange }
        return .green
    }
}

struct StatRow: View {
    let icon: String
    let color: Color
    let label: String
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundColor(color)
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

struct SceneRowView: View {
    let scene: WidgetScene

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: scene.icon)
                .font(.system(size: 12))
                .foregroundColor(.cyan)
                .frame(width: 20)
            Text(scene.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
            if scene.hasUnreachableDevices {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
        )
    }
}

struct SceneButtonView: View {
    let scene: WidgetScene

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: scene.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(sceneColor)
            Text(scene.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            if scene.hasUnreachableDevices {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
        )
    }

    var sceneColor: Color {
        switch scene.sceneType {
        case "Good Morning": return .yellow
        case "Good Night": return .purple
        case "Arrive": return .green
        case "Leave": return .orange
        default: return .cyan
        }
    }
}

struct DeviceHealthSectionView: View {
    let health: WidgetDeviceHealth

    var body: some View {
        HStack(spacing: 12) {
            // Health icon and status
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(statusColor)
                    Text(statusText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text("\(health.totalDevices) total devices")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Device counts
            HStack(spacing: 16) {
                DeviceCountView(count: health.healthyCount, label: "OK", color: .green)
                if health.warningCount > 0 {
                    DeviceCountView(count: health.warningCount, label: "Warn", color: .orange)
                }
                if health.unreachableCount > 0 {
                    DeviceCountView(count: health.unreachableCount, label: "Off", color: .red)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
    }

    var statusIcon: String {
        if health.unreachableCount > 0 { return "exclamationmark.triangle.fill" }
        if health.warningCount > 0 { return "exclamationmark.circle.fill" }
        return "checkmark.circle.fill"
    }

    var statusColor: Color {
        if health.unreachableCount > 0 { return .red }
        if health.warningCount > 0 { return .orange }
        return .green
    }

    var statusText: String {
        if health.unreachableCount > 0 { return "Devices Offline" }
        if health.warningCount > 0 { return "Warnings" }
        return "All Devices Healthy"
    }
}

struct DeviceCountView: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

// MARK: - Widget Entry View

struct HomekitControlWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: HomekitControlEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            case .systemLarge:
                LargeWidgetView(entry: entry)
            default:
                SmallWidgetView(entry: entry)
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.12, blue: 0.22),
                    Color(red: 0.12, green: 0.18, blue: 0.32)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Widget Configuration

struct HomekitControlWidget: Widget {
    let kind: String = "HomekitControlWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HomekitControlProvider()) { entry in
            HomekitControlWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("HomekitControl")
        .description("View your smart home status and quickly execute favorite scenes.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Widget Bundle

@main
struct HomekitControlWidgetBundle: WidgetBundle {
    var body: some Widget {
        HomekitControlWidget()
    }
}

// MARK: - Previews

#Preview("Small Widget", as: .systemSmall) {
    HomekitControlWidget()
} timeline: {
    HomekitControlEntry.preview
}

#Preview("Medium Widget", as: .systemMedium) {
    HomekitControlWidget()
} timeline: {
    HomekitControlEntry.preview
}

#Preview("Large Widget", as: .systemLarge) {
    HomekitControlWidget()
} timeline: {
    HomekitControlEntry.preview
}
