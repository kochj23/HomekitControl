//
//  tvOS_ScheduleView.swift
//  HomekitControl
//
//  Scene scheduling view for tvOS with 10-foot UI
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

struct tvOS_ScheduleView: View {
    @StateObject private var scheduleService = SceneSchedulingService.shared
    @StateObject private var homeKitService = HomeKitService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 60) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scene Schedules")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.white)

                        Text("\(scheduleService.schedules.count) schedules")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 60))
                        .foregroundStyle(ModernColors.orange)
                }
                .padding(.horizontal, 80)

                // Sun Times Card
                GlassCard {
                    HStack(spacing: 80) {
                        VStack(spacing: 12) {
                            Image(systemName: "sunrise.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(ModernColors.orange)
                            Text("Sunrise")
                                .font(.system(size: 22))
                                .foregroundStyle(.secondary)
                            Text(scheduleService.todaySunrise, style: .time)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        Divider()
                            .frame(height: 100)

                        VStack(spacing: 12) {
                            Image(systemName: "sunset.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(ModernColors.purple)
                            Text("Sunset")
                                .font(.system(size: 22))
                                .foregroundStyle(.secondary)
                            Text(scheduleService.todaySunset, style: .time)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(50)
                }
                .padding(.horizontal, 80)

                // Upcoming Schedules
                let upcoming = scheduleService.getUpcomingSchedules()
                if !upcoming.isEmpty {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(ModernColors.cyan)
                            Text("Upcoming")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 80)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 30) {
                                ForEach(upcoming) { schedule in
                                    TVUpcomingScheduleCard(schedule: schedule)
                                }
                            }
                            .padding(.horizontal, 80)
                        }
                    }
                }

                // All Schedules
                VStack(alignment: .leading, spacing: 24) {
                    Text("All Schedules")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 80)

                    if scheduleService.schedules.isEmpty {
                        GlassCard {
                            VStack(spacing: 20) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.secondary)
                                Text("No schedules created")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.secondary)
                                Text("Create schedules on your iPhone or iPad")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(50)
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 80)
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 30),
                            GridItem(.flexible(), spacing: 30),
                            GridItem(.flexible(), spacing: 30)
                        ], spacing: 30) {
                            ForEach(scheduleService.schedules) { schedule in
                                TVScheduleCard(schedule: schedule)
                            }
                        }
                        .padding(.horizontal, 80)
                    }
                }
            }
            .padding(.vertical, 60)
        }
    }
}

// MARK: - TV Upcoming Schedule Card

struct TVUpcomingScheduleCard: View {
    let schedule: SceneSchedule
    @FocusState private var isFocused: Bool

    var body: some View {
        Button { } label: {
            GlassCard {
                VStack(spacing: 16) {
                    Image(systemName: schedule.scheduleType.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(ModernColors.cyan)

                    Text(schedule.name)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if let nextRun = schedule.nextRun {
                        Text(nextRun, style: .time)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(ModernColors.accent)

                        Text(nextRun, style: .relative)
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(30)
                .frame(width: 280, height: 220)
            }
        }
        .buttonStyle(.card)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - TV Schedule Card

struct TVScheduleCard: View {
    let schedule: SceneSchedule
    @StateObject private var scheduleService = SceneSchedulingService.shared
    @FocusState private var isFocused: Bool

    var body: some View {
        Button {
            scheduleService.toggleSchedule(schedule)
        } label: {
            GlassCard {
                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(schedule.isEnabled ? ModernColors.accentGreen : .secondary)
                            .frame(width: 14, height: 14)
                    }

                    Image(systemName: schedule.scheduleType.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(ModernColors.orange)

                    Text(schedule.name)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text(schedule.scheduleType.rawValue)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)

                    if !schedule.repeatDays.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                                let index = ["S", "M", "T", "W", "T", "F", "S"].firstIndex(of: day)! + 1
                                Text(day)
                                    .font(.system(size: 12))
                                    .foregroundStyle(schedule.repeatDays.contains(index) ? ModernColors.cyan : ModernColors.textTertiary)
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.card)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

#Preview {
    tvOS_ScheduleView()
}
