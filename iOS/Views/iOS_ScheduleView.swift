//
//  iOS_ScheduleView.swift
//  HomekitControl
//
//  Scene scheduling interface for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

struct iOS_ScheduleView: View {
    @StateObject private var scheduleService = SceneSchedulingService.shared
    @StateObject private var homeKitService = HomeKitService.shared
    @State private var showingAddSchedule = false
    @State private var selectedSchedule: SceneSchedule?

    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphicBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Sun Times
                        sunTimesCard

                        // Upcoming Schedules
                        upcomingSection

                        // All Schedules
                        allSchedulesSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Schedules")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSchedule = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddSchedule) {
                AddScheduleSheet()
            }
            .sheet(item: $selectedSchedule) { schedule in
                ScheduleDetailSheet(schedule: schedule)
            }
        }
    }

    private var sunTimesCard: some View {
        GlassCard {
            HStack(spacing: 30) {
                VStack {
                    Image(systemName: "sunrise.fill")
                        .font(.title)
                        .foregroundStyle(ModernColors.orange)
                    Text("Sunrise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(scheduleService.todaySunrise, style: .time)
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                Divider()
                    .frame(height: 60)

                VStack {
                    Image(systemName: "sunset.fill")
                        .font(.title)
                        .foregroundStyle(ModernColors.purple)
                    Text("Sunset")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(scheduleService.todaySunset, style: .time)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }

    private var upcomingSection: some View {
        let upcoming = scheduleService.getUpcomingSchedules()

        return Group {
            if !upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Upcoming", systemImage: "clock.fill")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(upcoming) { schedule in
                        UpcomingScheduleCard(schedule: schedule) {
                            selectedSchedule = schedule
                        }
                    }
                }
            }
        }
    }

    private var allSchedulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Schedules")
                .font(.headline)
                .foregroundStyle(.white)

            if scheduleService.schedules.isEmpty {
                GlassCard {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No schedules created")
                            .foregroundStyle(.secondary)
                        Button("Create Schedule") {
                            showingAddSchedule = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(scheduleService.schedules) { schedule in
                    ScheduleCard(schedule: schedule) {
                        selectedSchedule = schedule
                    }
                }
            }
        }
    }
}

// MARK: - Upcoming Schedule Card

struct UpcomingScheduleCard: View {
    let schedule: SceneSchedule
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GlassCard {
                HStack {
                    Image(systemName: schedule.scheduleType.icon)
                        .font(.title2)
                        .foregroundStyle(ModernColors.cyan)

                    VStack(alignment: .leading) {
                        Text(schedule.name)
                            .foregroundStyle(.white)

                        if let nextRun = schedule.nextRun {
                            Text(nextRun, style: .relative)
                                .font(.caption)
                                .foregroundStyle(ModernColors.accent)
                        }
                    }

                    Spacer()

                    if let nextRun = schedule.nextRun {
                        Text(nextRun, style: .time)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
                .padding()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Schedule Card

struct ScheduleCard: View {
    let schedule: SceneSchedule
    let onTap: () -> Void
    @StateObject private var scheduleService = SceneSchedulingService.shared

    var body: some View {
        Button(action: onTap) {
            GlassCard {
                HStack {
                    Image(systemName: schedule.scheduleType.icon)
                        .foregroundStyle(ModernColors.cyan)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(schedule.name)
                            .foregroundStyle(.white)

                        HStack {
                            Text(schedule.scheduleType.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if !schedule.repeatDays.isEmpty {
                                Text("• Repeats")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { schedule.isEnabled },
                        set: { _ in scheduleService.toggleSchedule(schedule) }
                    ))
                    .labelsHidden()
                    .tint(ModernColors.accent)
                }
                .padding()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Schedule Sheet

struct AddScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scheduleService = SceneSchedulingService.shared
    @StateObject private var homeKitService = HomeKitService.shared

    @State private var name = ""
    @State private var scheduleType: SceneSchedule.ScheduleType = .time
    @State private var selectedTime = Date()
    @State private var selectedSceneId: UUID?
    @State private var sunOffset: Int = 0
    @State private var repeatDays: Set<Int> = []

    let weekdays = [
        (1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"),
        (5, "Thu"), (6, "Fri"), (7, "Sat")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Schedule Details") {
                    TextField("Name", text: $name)

                    Picker("Type", selection: $scheduleType) {
                        ForEach(SceneSchedule.ScheduleType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }

                Section("Scene") {
                    Picker("Select Scene", selection: $selectedSceneId) {
                        Text("None").tag(nil as UUID?)
                        #if canImport(HomeKit)
                        ForEach(homeKitService.scenes, id: \.uniqueIdentifier) { scene in
                            Text(scene.name).tag(scene.uniqueIdentifier as UUID?)
                        }
                        #endif
                    }
                }

                if scheduleType == .time {
                    Section("Time") {
                        DatePicker("Run at", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    }

                    Section("Repeat") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                            ForEach(weekdays, id: \.0) { day in
                                Button {
                                    if repeatDays.contains(day.0) {
                                        repeatDays.remove(day.0)
                                    } else {
                                        repeatDays.insert(day.0)
                                    }
                                } label: {
                                    Text(day.1)
                                        .font(.caption)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(repeatDays.contains(day.0) ? ModernColors.accent : Color.gray.opacity(0.3))
                                        .foregroundStyle(repeatDays.contains(day.0) ? .black : .white)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if scheduleType == .sunrise || scheduleType == .sunset {
                    Section("Offset") {
                        Stepper("Offset: \(sunOffset) minutes", value: $sunOffset, in: -60...60, step: 5)
                    }
                }

                if scheduleType == .oneTime {
                    Section("Date & Time") {
                        DatePicker("Run at", selection: $selectedTime)
                    }
                }
            }
            .navigationTitle("New Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        var schedule = scheduleService.createSchedule(
                            name: name.isEmpty ? "New Schedule" : name,
                            sceneId: selectedSceneId,
                            scheduleType: scheduleType
                        )
                        schedule.scheduledTime = selectedTime
                        schedule.sunOffset = sunOffset
                        schedule.repeatDays = Array(repeatDays)
                        if scheduleType == .oneTime {
                            schedule.oneTimeDate = selectedTime
                        }
                        scheduleService.updateSchedule(schedule)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Schedule Detail Sheet

struct ScheduleDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scheduleService = SceneSchedulingService.shared

    let schedule: SceneSchedule

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    LabeledContent("Name", value: schedule.name)
                    LabeledContent("Type", value: schedule.scheduleType.rawValue)
                    LabeledContent("Enabled", value: schedule.isEnabled ? "Yes" : "No")
                }

                if let nextRun = schedule.nextRun {
                    Section("Next Run") {
                        LabeledContent("Date", value: nextRun, format: .dateTime)
                        LabeledContent("In", value: nextRun, format: .relative(presentation: .named))
                    }
                }

                if let lastRun = schedule.lastRun {
                    Section("Last Run") {
                        LabeledContent("Date", value: lastRun, format: .dateTime)
                    }
                }

                Section {
                    Button("Delete Schedule", role: .destructive) {
                        scheduleService.deleteSchedule(schedule)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Schedule Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    iOS_ScheduleView()
}
