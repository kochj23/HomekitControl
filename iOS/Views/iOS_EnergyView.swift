//
//  iOS_EnergyView.swift
//  HomekitControl
//
//  Energy monitoring dashboard for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import Charts

struct iOS_EnergyView: View {
    @StateObject private var energyService = EnergyMonitoringService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphicBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Today's Summary
                        todaySummaryCard

                        // Weekly Chart
                        weeklyChartCard

                        // Cost Projection
                        costCard

                        // Settings
                        settingsCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Energy")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if energyService.isMonitoring {
                            energyService.stopMonitoring()
                        } else {
                            energyService.startMonitoring()
                        }
                    } label: {
                        Image(systemName: energyService.isMonitoring ? "pause.fill" : "play.fill")
                    }
                }
            }
        }
    }

    private var todaySummaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Today's Usage", systemImage: "bolt.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    if energyService.isMonitoring {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(ModernColors.accentGreen)
                                .frame(width: 8, height: 8)
                            Text("Live")
                                .font(.caption)
                                .foregroundStyle(ModernColors.accentGreen)
                        }
                    }
                }

                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text(String(format: "%.2f", energyService.getTodayUsage()))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(ModernColors.cyan)
                        Text("kWh")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                        .frame(height: 50)

                    VStack(alignment: .leading) {
                        Text(String(format: "$%.2f", energyService.getTodayUsage() * energyService.utilityRate))
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Estimated Cost")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
    }

    private var weeklyChartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("This Week", systemImage: "chart.bar.fill")
                    .font(.headline)
                    .foregroundStyle(.white)

                let weekData = energyService.getWeekUsage()

                if weekData.isEmpty {
                    Text("No data available")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    Chart(weekData) { day in
                        BarMark(
                            x: .value("Day", day.date, unit: .day),
                            y: .value("kWh", day.totalKWh)
                        )
                        .foregroundStyle(ModernColors.cyan.gradient)
                        .cornerRadius(4)
                    }
                    .frame(height: 150)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let kWh = value.as(Double.self) {
                                    Text("\(Int(kWh))")
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var costCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Monthly Projection", systemImage: "dollarsign.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)

                let monthCost = energyService.getMonthCost()
                let budget = energyService.monthlyBudget
                let progress = min(monthCost / budget, 1.0)

                HStack {
                    VStack(alignment: .leading) {
                        Text(String(format: "$%.2f", monthCost))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(progress > 0.8 ? ModernColors.statusHigh : .white)

                        Text("of $\(Int(budget)) budget")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    CircularGauge(value: progress * 100, color: progress > 0.8 ? ModernColors.statusHigh : ModernColors.cyan, lineWidth: 6, size: 60)
                }

                ProgressView(value: progress)
                    .tint(progress > 0.8 ? ModernColors.statusHigh : ModernColors.cyan)
            }
            .padding()
        }
    }

    private var settingsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Settings", systemImage: "gearshape.fill")
                    .font(.headline)
                    .foregroundStyle(.white)

                VStack(spacing: 12) {
                    HStack {
                        Text("Utility Rate")
                            .foregroundStyle(.white)
                        Spacer()
                        TextField("Rate", value: $energyService.utilityRate, format: .currency(code: "USD"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Monthly Budget")
                            .foregroundStyle(.white)
                        Spacer()
                        TextField("Budget", value: $energyService.monthlyBudget, format: .currency(code: "USD"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("High Usage Alert")
                            .foregroundStyle(.white)
                        Spacer()
                        TextField("Watts", value: $energyService.highUsageThreshold, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                        Text("W")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
    }
}

#Preview {
    iOS_EnergyView()
}
