//
//  SceneSchedulingService.swift
//  HomekitControl
//
//  Schedule scenes to run at specific times
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif
#if canImport(CoreLocation)
import CoreLocation
#endif

// MARK: - Schedule Models

struct SceneSchedule: Codable, Identifiable {
    let id: UUID
    var name: String
    var sceneId: UUID?
    var scheduleType: ScheduleType
    var isEnabled: Bool
    var createdAt: Date
    var lastRun: Date?
    var nextRun: Date?

    // Time-based
    var scheduledTime: Date?
    var repeatDays: [Int] // 1=Sunday, 7=Saturday

    // Sun-based
    var sunOffset: Int // minutes before/after sunrise/sunset

    // One-time
    var oneTimeDate: Date?

    enum ScheduleType: String, Codable, CaseIterable {
        case time = "Specific Time"
        case sunrise = "Sunrise"
        case sunset = "Sunset"
        case oneTime = "One Time"

        var icon: String {
            switch self {
            case .time: return "clock.fill"
            case .sunrise: return "sunrise.fill"
            case .sunset: return "sunset.fill"
            case .oneTime: return "calendar.badge.clock"
            }
        }
    }

    init(name: String, sceneId: UUID? = nil, scheduleType: ScheduleType = .time) {
        self.id = UUID()
        self.name = name
        self.sceneId = sceneId
        self.scheduleType = scheduleType
        self.isEnabled = true
        self.createdAt = Date()
        self.repeatDays = []
        self.sunOffset = 0
    }
}

// MARK: - Scene Scheduling Service

@MainActor
class SceneSchedulingService: ObservableObject {
    static let shared = SceneSchedulingService()

    @Published var schedules: [SceneSchedule] = []
    @Published var isRunning = false

    // Sun times (would use CoreLocation in production)
    @Published var todaySunrise: Date = Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: Date()) ?? Date()
    @Published var todaySunset: Date = Calendar.current.date(bySettingHour: 18, minute: 30, second: 0, of: Date()) ?? Date()

    private let storageKey = "HomekitControl_SceneSchedules"
    private var schedulerTask: Task<Void, Never>?

    private init() {
        loadData()
        startScheduler()
        updateSunTimes()
    }

    // MARK: - Scheduler

    func startScheduler() {
        schedulerTask?.cancel()

        schedulerTask = Task {
            while !Task.isCancelled {
                await checkSchedules()
                try? await Task.sleep(nanoseconds: 60_000_000_000) // Check every minute
            }
        }
    }

    func stopScheduler() {
        schedulerTask?.cancel()
    }

    private func checkSchedules() async {
        let now = Date()
        let calendar = Calendar.current

        for schedule in schedules where schedule.isEnabled {
            guard let nextRun = schedule.nextRun else { continue }

            // Check if it's time to run (within 1 minute window)
            let diff = calendar.dateComponents([.minute], from: nextRun, to: now)
            if let minutes = diff.minute, minutes >= 0 && minutes < 1 {
                await executeSchedule(schedule)
            }
        }
    }

    private func executeSchedule(_ schedule: SceneSchedule) async {
        guard let sceneId = schedule.sceneId else { return }

        #if canImport(HomeKit)
        if let scene = HomeKitService.shared.scenes.first(where: { $0.uniqueIdentifier == sceneId }) {
            do {
                try await HomeKitService.shared.executeScene(scene)
                print("Executed scheduled scene: \(schedule.name)")

                // Update last run and calculate next run
                if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
                    schedules[index].lastRun = Date()
                    schedules[index].nextRun = calculateNextRun(for: schedules[index])
                    saveData()
                }
            } catch {
                print("Failed to execute scheduled scene: \(error)")
            }
        }
        #endif
    }

    // MARK: - Schedule CRUD

    func createSchedule(name: String, sceneId: UUID?, scheduleType: SceneSchedule.ScheduleType) -> SceneSchedule {
        var schedule = SceneSchedule(name: name, sceneId: sceneId, scheduleType: scheduleType)
        schedule.nextRun = calculateNextRun(for: schedule)
        schedules.append(schedule)
        saveData()
        return schedule
    }

    func updateSchedule(_ schedule: SceneSchedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            var updated = schedule
            updated.nextRun = calculateNextRun(for: schedule)
            schedules[index] = updated
            saveData()
        }
    }

    func deleteSchedule(_ schedule: SceneSchedule) {
        schedules.removeAll { $0.id == schedule.id }
        saveData()
    }

    func toggleSchedule(_ schedule: SceneSchedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index].isEnabled.toggle()
            if schedules[index].isEnabled {
                schedules[index].nextRun = calculateNextRun(for: schedules[index])
            }
            saveData()
        }
    }

    // MARK: - Next Run Calculation

    func calculateNextRun(for schedule: SceneSchedule) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        switch schedule.scheduleType {
        case .time:
            guard let scheduledTime = schedule.scheduledTime else { return nil }

            let timeComponents = calendar.dateComponents([.hour, .minute], from: scheduledTime)
            var nextDate = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                         minute: timeComponents.minute ?? 0,
                                         second: 0,
                                         of: now)

            // If time has passed today, move to tomorrow
            if let next = nextDate, next <= now {
                nextDate = calendar.date(byAdding: .day, value: 1, to: next)
            }

            // If repeat days specified, find next valid day
            if !schedule.repeatDays.isEmpty, let next = nextDate {
                var checkDate = next
                for _ in 0..<7 {
                    let weekday = calendar.component(.weekday, from: checkDate)
                    if schedule.repeatDays.contains(weekday) {
                        return checkDate
                    }
                    checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate
                }
            }

            return nextDate

        case .sunrise:
            var nextSunrise = todaySunrise
            if nextSunrise <= now {
                nextSunrise = calendar.date(byAdding: .day, value: 1, to: nextSunrise) ?? nextSunrise
            }
            return calendar.date(byAdding: .minute, value: schedule.sunOffset, to: nextSunrise)

        case .sunset:
            var nextSunset = todaySunset
            if nextSunset <= now {
                nextSunset = calendar.date(byAdding: .day, value: 1, to: nextSunset) ?? nextSunset
            }
            return calendar.date(byAdding: .minute, value: schedule.sunOffset, to: nextSunset)

        case .oneTime:
            guard let oneTimeDate = schedule.oneTimeDate, oneTimeDate > now else { return nil }
            return oneTimeDate
        }
    }

    // MARK: - Sun Times

    private func updateSunTimes() {
        // In production, would use CoreLocation and solar calculation
        // For now, use approximate times
        let calendar = Calendar.current
        let today = Date()

        // Approximate based on month (Northern Hemisphere)
        let month = calendar.component(.month, from: today)
        let sunriseHour: Int
        let sunsetHour: Int

        switch month {
        case 1, 2, 11, 12: // Winter
            sunriseHour = 7
            sunsetHour = 17
        case 3, 4, 9, 10: // Spring/Fall
            sunriseHour = 6
            sunsetHour = 18
        default: // Summer
            sunriseHour = 5
            sunsetHour = 20
        }

        todaySunrise = calendar.date(bySettingHour: sunriseHour, minute: 30, second: 0, of: today) ?? today
        todaySunset = calendar.date(bySettingHour: sunsetHour, minute: 30, second: 0, of: today) ?? today
    }

    // MARK: - Helpers

    func getSchedulesForScene(_ sceneId: UUID) -> [SceneSchedule] {
        schedules.filter { $0.sceneId == sceneId }
    }

    func getUpcomingSchedules(limit: Int = 5) -> [SceneSchedule] {
        schedules
            .filter { $0.isEnabled && $0.nextRun != nil }
            .sorted { ($0.nextRun ?? .distantFuture) < ($1.nextRun ?? .distantFuture) }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Persistence

    private func saveData() {
        if let data = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([SceneSchedule].self, from: data) {
            schedules = saved
            // Recalculate next runs on load
            for index in schedules.indices {
                schedules[index].nextRun = calculateNextRun(for: schedules[index])
            }
        }
    }
}
