//
//  UsageReportService.swift
//  HomekitControl
//
//  Generate usage reports and summaries
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - Models

struct UsageReport: Codable, Identifiable {
    let id: UUID
    let reportType: ReportType
    let periodStart: Date
    let periodEnd: Date
    let generatedAt: Date
    var sections: [ReportSection]

    enum ReportType: String, Codable, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"

        var periodDays: Int {
            switch self {
            case .daily: return 1
            case .weekly: return 7
            case .monthly: return 30
            }
        }
    }

    init(reportType: ReportType) {
        self.id = UUID()
        self.reportType = reportType
        self.generatedAt = Date()

        let calendar = Calendar.current
        self.periodEnd = Date()
        self.periodStart = calendar.date(byAdding: .day, value: -reportType.periodDays, to: periodEnd)!
        self.sections = []
    }
}

struct ReportSection: Codable, Identifiable {
    let id: UUID
    let title: String
    let items: [ReportItem]

    init(title: String, items: [ReportItem]) {
        self.id = UUID()
        self.title = title
        self.items = items
    }
}

struct ReportItem: Codable, Identifiable {
    let id: UUID
    let label: String
    let value: String
    let trend: Trend?
    let detail: String?

    enum Trend: String, Codable {
        case up = "Up"
        case down = "Down"
        case stable = "Stable"

        var icon: String {
            switch self {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .stable: return "minus"
            }
        }

        var color: Color {
            switch self {
            case .up: return ModernColors.red
            case .down: return ModernColors.accentGreen
            case .stable: return .secondary
            }
        }
    }

    init(label: String, value: String, trend: Trend? = nil, detail: String? = nil) {
        self.id = UUID()
        self.label = label
        self.value = value
        self.trend = trend
        self.detail = detail
    }
}

struct ReportSchedule: Codable, Identifiable {
    let id: UUID
    var reportType: UsageReport.ReportType
    var isEnabled: Bool
    var emailAddress: String?
    var dayOfWeek: Int? // For weekly reports (1-7)
    var dayOfMonth: Int? // For monthly reports (1-31)
    var hour: Int // Hour of day to send (0-23)

    init(reportType: UsageReport.ReportType) {
        self.id = UUID()
        self.reportType = reportType
        self.isEnabled = false
        self.emailAddress = nil
        self.dayOfWeek = 1 // Sunday
        self.dayOfMonth = 1
        self.hour = 8
    }
}

// MARK: - Usage Report Service

@MainActor
class UsageReportService: ObservableObject {
    static let shared = UsageReportService()

    // MARK: - Published Properties

    @Published var reports: [UsageReport] = []
    @Published var schedules: [ReportSchedule] = []
    @Published var isGenerating = false

    // MARK: - Private Properties

    private let storageKey = "HomekitControl_UsageReports"
    private var scheduleTimer: Timer?

    // MARK: - Initialization

    private init() {
        loadData()
        setupDefaultSchedules()
        startScheduleMonitoring()
    }

    // MARK: - Report Generation

    func generateReport(type: UsageReport.ReportType) async -> UsageReport {
        isGenerating = true

        var report = UsageReport(reportType: type)

        // Device Usage Section
        let deviceSection = await generateDeviceUsageSection(for: type)
        report.sections.append(deviceSection)

        // Energy Section
        let energySection = await generateEnergySection(for: type)
        report.sections.append(energySection)

        // Scene Usage Section
        let sceneSection = await generateSceneUsageSection(for: type)
        report.sections.append(sceneSection)

        // Health Section
        let healthSection = await generateHealthSection(for: type)
        report.sections.append(healthSection)

        // Security Section
        let securitySection = await generateSecuritySection(for: type)
        report.sections.append(securitySection)

        // Save report
        reports.insert(report, at: 0)
        trimReports()
        saveData()

        isGenerating = false
        return report
    }

    private func generateDeviceUsageSection(for type: UsageReport.ReportType) async -> ReportSection {
        var items: [ReportItem] = []

        #if canImport(HomeKit)
        let totalDevices = HomeKitService.shared.accessories.count
        let reachableDevices = HomeKitService.shared.accessories.filter { $0.isReachable }.count

        items.append(ReportItem(
            label: "Total Devices",
            value: "\(totalDevices)",
            trend: nil,
            detail: "\(reachableDevices) currently online"
        ))

        items.append(ReportItem(
            label: "Availability",
            value: String(format: "%.1f%%", Double(reachableDevices) / Double(max(totalDevices, 1)) * 100),
            trend: .stable,
            detail: nil
        ))
        #endif

        return ReportSection(title: "Device Overview", items: items)
    }

    private func generateEnergySection(for type: UsageReport.ReportType) async -> ReportSection {
        var items: [ReportItem] = []

        let energyService = EnergyMonitoringService.shared

        items.append(ReportItem(
            label: "Total Usage",
            value: String(format: "%.1f kWh", energyService.todayUsage * Double(type.periodDays)),
            trend: nil,
            detail: nil
        ))

        items.append(ReportItem(
            label: "Estimated Cost",
            value: String(format: "$%.2f", energyService.estimatedMonthlyCost / 30 * Double(type.periodDays)),
            trend: nil,
            detail: "At $\(String(format: "%.2f", energyService.utilityRate))/kWh"
        ))

        items.append(ReportItem(
            label: "Peak Power",
            value: String(format: "%.0f W", energyService.currentTotalPower),
            trend: nil,
            detail: nil
        ))

        return ReportSection(title: "Energy Usage", items: items)
    }

    private func generateSceneUsageSection(for type: UsageReport.ReportType) async -> ReportSection {
        var items: [ReportItem] = []

        #if canImport(HomeKit)
        let totalScenes = HomeKitService.shared.scenes.count

        items.append(ReportItem(
            label: "Total Scenes",
            value: "\(totalScenes)",
            trend: nil,
            detail: nil
        ))
        #endif

        let automations = AutomationService.shared.automations.count
        items.append(ReportItem(
            label: "Active Automations",
            value: "\(automations)",
            trend: nil,
            detail: nil
        ))

        let schedules = SceneSchedulingService.shared.schedules.filter { $0.isEnabled }.count
        items.append(ReportItem(
            label: "Active Schedules",
            value: "\(schedules)",
            trend: nil,
            detail: nil
        ))

        return ReportSection(title: "Scenes & Automations", items: items)
    }

    private func generateHealthSection(for type: UsageReport.ReportType) async -> ReportSection {
        var items: [ReportItem] = []

        let healthService = DeviceHealthService.shared
        let records = healthService.deviceHealth

        var healthyCount = 0
        var warningCount = 0
        var criticalCount = 0

        for (_, record) in records {
            // Derive status from reliability score
            if record.reliabilityScore >= 90 {
                healthyCount += 1
            } else if record.reliabilityScore >= 70 {
                warningCount += 1
            } else {
                criticalCount += 1
            }
        }

        items.append(ReportItem(
            label: "Healthy Devices",
            value: "\(healthyCount)",
            trend: nil,
            detail: nil
        ))

        items.append(ReportItem(
            label: "Devices with Warnings",
            value: "\(warningCount)",
            trend: warningCount > 0 ? .up : .stable,
            detail: nil
        ))

        items.append(ReportItem(
            label: "Critical Issues",
            value: "\(criticalCount)",
            trend: criticalCount > 0 ? .up : .stable,
            detail: nil
        ))

        return ReportSection(title: "Device Health", items: items)
    }

    private func generateSecuritySection(for type: UsageReport.ReportType) async -> ReportSection {
        var items: [ReportItem] = []

        let securityService = SecurityService.shared

        items.append(ReportItem(
            label: "Security Mode",
            value: securityService.currentMode.rawValue,
            trend: nil,
            detail: nil
        ))

        items.append(ReportItem(
            label: "Security Events",
            value: "\(securityService.events.count)",
            trend: nil,
            detail: "This period"
        ))

        items.append(ReportItem(
            label: "Status",
            value: securityService.isSecure ? "Secure" : "Attention Needed",
            trend: securityService.isSecure ? .stable : .up,
            detail: nil
        ))

        return ReportSection(title: "Security Summary", items: items)
    }

    // MARK: - Scheduling

    private func setupDefaultSchedules() {
        guard schedules.isEmpty else { return }

        schedules = [
            ReportSchedule(reportType: .daily),
            ReportSchedule(reportType: .weekly),
            ReportSchedule(reportType: .monthly)
        ]
        saveData()
    }

    func updateSchedule(_ schedule: ReportSchedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
            saveData()
        }
    }

    private func startScheduleMonitoring() {
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkSchedules()
            }
        }
    }

    private func checkSchedules() async {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentDayOfWeek = calendar.component(.weekday, from: now)
        let currentDayOfMonth = calendar.component(.day, from: now)

        for schedule in schedules where schedule.isEnabled {
            var shouldGenerate = false

            switch schedule.reportType {
            case .daily:
                shouldGenerate = currentHour == schedule.hour

            case .weekly:
                shouldGenerate = currentDayOfWeek == schedule.dayOfWeek && currentHour == schedule.hour

            case .monthly:
                shouldGenerate = currentDayOfMonth == schedule.dayOfMonth && currentHour == schedule.hour
            }

            if shouldGenerate {
                let report = await generateReport(type: schedule.reportType)

                // Send email if configured
                if let email = schedule.emailAddress, !email.isEmpty {
                    await sendReportEmail(report: report, to: email)
                }
            }
        }
    }

    private func sendReportEmail(report: UsageReport, to email: String) async {
        // In a real implementation, this would send an email
        // For now, just log it
        print("Would send \(report.reportType.rawValue) report to \(email)")
    }

    // MARK: - Export

    func exportReportAsText(_ report: UsageReport) -> String {
        var text = """
        HomekitControl \(report.reportType.rawValue) Report
        Generated: \(formatDate(report.generatedAt))
        Period: \(formatDate(report.periodStart)) - \(formatDate(report.periodEnd))

        """

        for section in report.sections {
            text += "\n\(section.title)\n"
            text += String(repeating: "-", count: section.title.count) + "\n"

            for item in section.items {
                text += "\(item.label): \(item.value)"
                if let detail = item.detail {
                    text += " (\(detail))"
                }
                text += "\n"
            }
        }

        return text
    }

    func exportReportAsJSON(_ report: UsageReport) -> Data? {
        try? JSONEncoder().encode(report)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Computed Properties

    var latestDailyReport: UsageReport? {
        reports.first { $0.reportType == .daily }
    }

    var latestWeeklyReport: UsageReport? {
        reports.first { $0.reportType == .weekly }
    }

    var latestMonthlyReport: UsageReport? {
        reports.first { $0.reportType == .monthly }
    }

    // MARK: - Persistence

    private func trimReports() {
        // Keep last 30 daily, 12 weekly, 12 monthly
        let dailyReports = reports.filter { $0.reportType == .daily }.prefix(30)
        let weeklyReports = reports.filter { $0.reportType == .weekly }.prefix(12)
        let monthlyReports = reports.filter { $0.reportType == .monthly }.prefix(12)

        reports = Array(dailyReports) + Array(weeklyReports) + Array(monthlyReports)
        reports.sort { $0.generatedAt > $1.generatedAt }
    }

    private func saveData() {
        if let schedulesData = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(schedulesData, forKey: storageKey + "_schedules")
        }

        if let reportsData = try? JSONEncoder().encode(reports) {
            UserDefaults.standard.set(reportsData, forKey: storageKey + "_reports")
        }
    }

    private func loadData() {
        if let schedulesData = UserDefaults.standard.data(forKey: storageKey + "_schedules"),
           let saved = try? JSONDecoder().decode([ReportSchedule].self, from: schedulesData) {
            schedules = saved
        }

        if let reportsData = UserDefaults.standard.data(forKey: storageKey + "_reports"),
           let saved = try? JSONDecoder().decode([UsageReport].self, from: reportsData) {
            reports = saved
        }
    }
}
