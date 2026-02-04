//
//  tvOS_AutomationView.swift
//  HomekitControl
//
//  Automation viewing for tvOS with 10-foot UI
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct tvOS_AutomationView: View {
    @StateObject private var automationService = AutomationService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 60) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Automations")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.white)

                        Text("\(automationService.automations.count) automations")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(ModernColors.purple)
                }
                .padding(.horizontal, 80)

                // Active Automations
                let activeAutomations = automationService.automations.filter { $0.isEnabled }
                if !activeAutomations.isEmpty {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(ModernColors.accentGreen)
                            Text("Active")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 80)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 30),
                            GridItem(.flexible(), spacing: 30),
                            GridItem(.flexible(), spacing: 30)
                        ], spacing: 30) {
                            ForEach(activeAutomations) { automation in
                                TVAutomationCard(automation: automation)
                            }
                        }
                        .padding(.horizontal, 80)
                    }
                }

                // All Automations
                VStack(alignment: .leading, spacing: 24) {
                    Text("All Automations")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 80)

                    if automationService.automations.isEmpty {
                        GlassCard {
                            VStack(spacing: 20) {
                                Image(systemName: "gearshape.2")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.secondary)
                                Text("No automations created")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.secondary)
                                Text("Create automations on your iPhone or iPad")
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
                            GridItem(.flexible(), spacing: 30),
                            GridItem(.flexible(), spacing: 30)
                        ], spacing: 30) {
                            ForEach(automationService.automations) { automation in
                                TVAutomationCard(automation: automation)
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

// MARK: - TV Automation Card

struct TVAutomationCard: View {
    let automation: CustomAutomation
    @StateObject private var automationService = AutomationService.shared
    @FocusState private var isFocused: Bool
    @State private var isExecuting = false

    var body: some View {
        Button {
            Task {
                isExecuting = true
                try? await automationService.executeAutomation(automation)
                isExecuting = false
            }
        } label: {
            GlassCard {
                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        if isExecuting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Circle()
                                .fill(automation.isEnabled ? ModernColors.accentGreen : .secondary)
                                .frame(width: 14, height: 14)
                        }
                    }

                    Image(systemName: automation.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(ModernColors.purple)

                    Text(automation.name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Label("\(automation.triggers.count)", systemImage: "bolt")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)

                        Label("\(automation.actions.count)", systemImage: "play")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }

                    if let lastRun = automation.lastRun {
                        Text(lastRun, style: .relative)
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
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
    tvOS_AutomationView()
}
