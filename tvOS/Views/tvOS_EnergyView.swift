//
//  tvOS_EnergyView.swift
//  HomekitControl
//
//  Energy monitoring view for tvOS with 10-foot UI
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct tvOS_EnergyView: View {
    @StateObject private var energyService = EnergyMonitoringService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 60) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Energy Monitor")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Power consumption overview")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "bolt.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(ModernColors.yellow)
                }
                .padding(.horizontal, 80)

                // Current Stats
                HStack(spacing: 40) {
                    TVEnergyStatCard(
                        value: String(format: "%.1f", energyService.currentTotalPower),
                        unit: "W",
                        label: "Current Power",
                        icon: "bolt.fill",
                        color: ModernColors.yellow
                    )

                    TVEnergyStatCard(
                        value: String(format: "%.2f", energyService.todayUsage),
                        unit: "kWh",
                        label: "Today",
                        icon: "calendar",
                        color: ModernColors.cyan
                    )

                    TVEnergyStatCard(
                        value: "$\(String(format: "%.2f", energyService.estimatedMonthlyCost))",
                        unit: "/mo",
                        label: "Est. Cost",
                        icon: "dollarsign.circle.fill",
                        color: ModernColors.accentGreen
                    )
                }
                .padding(.horizontal, 80)

                // Weekly Usage Chart
                VStack(alignment: .leading, spacing: 24) {
                    Text("Weekly Usage")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 80)

                    GlassCard {
                        #if canImport(Charts)
                        if #available(tvOS 16.0, *) {
                            Chart(energyService.weeklyUsage) { day in
                                BarMark(
                                    x: .value("Day", day.date, unit: .day),
                                    y: .value("Usage", day.totalKWh)
                                )
                                .foregroundStyle(ModernColors.cyan.gradient)
                            }
                            .frame(height: 300)
                            .padding(40)
                        } else {
                            Text("Charts require tvOS 16+")
                                .foregroundStyle(.secondary)
                                .padding(40)
                        }
                        #else
                        Text("Charts not available")
                            .foregroundStyle(.secondary)
                            .padding(40)
                        #endif
                    }
                    .padding(.horizontal, 80)
                }

                // Top Consumers
                VStack(alignment: .leading, spacing: 24) {
                    Text("Top Power Consumers")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 80)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 30),
                        GridItem(.flexible(), spacing: 30),
                        GridItem(.flexible(), spacing: 30),
                        GridItem(.flexible(), spacing: 30)
                    ], spacing: 30) {
                        ForEach(energyService.topConsumers.prefix(8)) { consumer in
                            TVConsumerCard(consumer: consumer)
                        }
                    }
                    .padding(.horizontal, 80)
                }
            }
            .padding(.vertical, 60)
        }
        .onAppear {
            energyService.startMonitoring()
        }
    }
}

// MARK: - TV Energy Stat Card

struct TVEnergyStatCard: View {
    let value: String
    let unit: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(color)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                    Text(unit)
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }

                Text(label)
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - TV Consumer Card

struct TVConsumerCard: View {
    let consumer: DevicePowerUsage
    @FocusState private var isFocused: Bool

    var body: some View {
        Button { } label: {
            GlassCard {
                VStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(ModernColors.yellow)

                    Text(consumer.deviceName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text(String(format: "%.1f W", consumer.currentWatts))
                        .font(.system(size: 18))
                        .foregroundStyle(ModernColors.cyan)

                    Text(String(format: "%.2f kWh today", consumer.todayKWh))
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(20)
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
    tvOS_EnergyView()
}
