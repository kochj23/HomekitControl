//
//  iOS_UsageReportsView.swift
//  HomekitControl
//
//  Usage reports and summaries for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct iOS_UsageReportsView: View {
    @StateObject private var reportService = UsageReportService.shared
    @State private var selectedReportType: UsageReport.ReportType = .weekly

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Generate Report
                GlassCard {
                    VStack(spacing: 16) {
                        Text("Generate Report")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Picker("Type", selection: $selectedReportType) {
                            ForEach(UsageReport.ReportType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        Button {
                            Task {
                                _ = await reportService.generateReport(type: selectedReportType)
                            }
                        } label: {
                            HStack {
                                if reportService.isGenerating {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "doc.text")
                                }
                                Text("Generate \(selectedReportType.rawValue) Report")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ModernColors.cyan)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(reportService.isGenerating)
                    }
                    .padding()
                }

                // Latest Reports
                VStack(alignment: .leading, spacing: 12) {
                    Text("Latest Reports")
                        .font(.headline)
                        .foregroundStyle(.white)

                    if reportService.reports.isEmpty {
                        GlassCard {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                                Text("No reports generated")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        ForEach(reportService.reports.prefix(5)) { report in
                            NavigationLink(destination: ReportDetailView(report: report)) {
                                GlassCard {
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                            .font(.title2)
                                            .foregroundStyle(colorForReportType(report.reportType))

                                        VStack(alignment: .leading) {
                                            Text("\(report.reportType.rawValue) Report")
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            Text(report.generatedAt, style: .relative)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Text("\(report.sections.count) sections")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                }
                            }
                        }
                    }
                }

                // Scheduled Reports
                VStack(alignment: .leading, spacing: 12) {
                    Text("Scheduled Reports")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(reportService.schedules) { schedule in
                        GlassCard {
                            HStack {
                                Circle()
                                    .fill(schedule.isEnabled ? ModernColors.accentGreen : .secondary)
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading) {
                                    Text("\(schedule.reportType.rawValue) Report")
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    if schedule.isEnabled {
                                        Text(scheduleDescription(schedule))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { schedule.isEnabled },
                                    set: { enabled in
                                        var updated = schedule
                                        updated.isEnabled = enabled
                                        reportService.updateSchedule(updated)
                                    }
                                ))
                                .tint(ModernColors.cyan)
                            }
                            .padding()
                        }
                    }
                }

                // Quick Stats
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Stats")
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack {
                            VStack {
                                Text("\(reportService.reports.count)")
                                    .font(.title2.bold())
                                    .foregroundStyle(ModernColors.cyan)
                                Text("Reports")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            VStack {
                                Text("\(reportService.reports.filter { $0.reportType == .daily }.count)")
                                    .font(.title2.bold())
                                    .foregroundStyle(ModernColors.purple)
                                Text("Daily")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            VStack {
                                Text("\(reportService.reports.filter { $0.reportType == .weekly }.count)")
                                    .font(.title2.bold())
                                    .foregroundStyle(ModernColors.orange)
                                Text("Weekly")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
        .background(LinearGradient.modernBackground.ignoresSafeArea())
        .navigationTitle("Reports")
    }

    private func colorForReportType(_ type: UsageReport.ReportType) -> Color {
        switch type {
        case .daily: return ModernColors.purple
        case .weekly: return ModernColors.orange
        case .monthly: return ModernColors.cyan
        }
    }

    private func scheduleDescription(_ schedule: ReportSchedule) -> String {
        switch schedule.reportType {
        case .daily:
            return "Every day at \(schedule.hour):00"
        case .weekly:
            let days = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            return "Every \(days[schedule.dayOfWeek ?? 1]) at \(schedule.hour):00"
        case .monthly:
            return "Day \(schedule.dayOfMonth ?? 1) at \(schedule.hour):00"
        }
    }
}

struct ReportDetailView: View {
    let report: UsageReport
    @StateObject private var reportService = UsageReportService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                GlassCard {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(ModernColors.cyan)

                        Text("\(report.reportType.rawValue) Report")
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        Text("Generated \(report.generatedAt, style: .relative) ago")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("\(formatDate(report.periodStart)) - \(formatDate(report.periodEnd))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }

                // Sections
                ForEach(report.sections) { section in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.title)
                                .font(.headline)
                                .foregroundStyle(.white)

                            ForEach(section.items) { item in
                                HStack {
                                    Text(item.label)
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    HStack(spacing: 4) {
                                        Text(item.value)
                                            .font(.headline)
                                            .foregroundStyle(.white)

                                        if let trend = item.trend {
                                            Image(systemName: trend.icon)
                                                .foregroundStyle(trend.color)
                                        }
                                    }
                                }

                                if let detail = item.detail {
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if item.id != section.items.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                    }
                }

                // Export
                GlassCard {
                    VStack(spacing: 12) {
                        Text("Export")
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack(spacing: 12) {
                            Button {
                                let text = reportService.exportReportAsText(report)
                                UIPasteboard.general.string = text
                            } label: {
                                VStack {
                                    Image(systemName: "doc.on.clipboard")
                                    Text("Copy")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(ModernColors.glassBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                            }

                            ShareLink(item: reportService.exportReportAsText(report)) {
                                VStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(ModernColors.cyan)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
        .background(LinearGradient.modernBackground.ignoresSafeArea())
        .navigationTitle("Report Details")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}
