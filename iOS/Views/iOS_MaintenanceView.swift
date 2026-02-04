//
//  iOS_MaintenanceView.swift
//  HomekitControl
//
//  Device maintenance reminders for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct iOS_MaintenanceView: View {
    @StateObject private var maintenanceService = MaintenanceService.shared
    @State private var showAddTask = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overview
                GlassCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Maintenance")
                                .font(.headline)
                                .foregroundStyle(.white)

                            if maintenanceService.overdueTasks.isEmpty {
                                Text("All up to date")
                                    .font(.subheadline)
                                    .foregroundStyle(ModernColors.accentGreen)
                            } else {
                                Text("\(maintenanceService.overdueTasks.count) overdue")
                                    .font(.subheadline)
                                    .foregroundStyle(ModernColors.red)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("This Month")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("$\(String(format: "%.2f", maintenanceService.thisMonthCost))")
                                .font(.title2.bold())
                                .foregroundStyle(ModernColors.cyan)
                        }
                    }
                    .padding()
                }

                // Overdue
                if !maintenanceService.overdueTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(ModernColors.red)
                            Text("Overdue")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }

                        ForEach(maintenanceService.overdueTasks) { task in
                            TaskCard(task: task)
                        }
                    }
                }

                // Due Soon
                if !maintenanceService.dueSoonTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(ModernColors.orange)
                            Text("Due Soon")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }

                        ForEach(maintenanceService.dueSoonTasks) { task in
                            TaskCard(task: task)
                        }
                    }
                }

                // All Tasks
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("All Tasks")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Spacer()

                        Button {
                            showAddTask = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(ModernColors.cyan)
                        }
                    }

                    if maintenanceService.tasks.isEmpty {
                        GlassCard {
                            VStack(spacing: 12) {
                                Image(systemName: "wrench.and.screwdriver")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                                Text("No maintenance tasks")
                                    .foregroundStyle(.secondary)

                                Button {
                                    maintenanceService.generateDefaultTasks()
                                } label: {
                                    Text("Generate Default Tasks")
                                        .font(.subheadline)
                                        .foregroundStyle(ModernColors.cyan)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        ForEach(maintenanceService.upcomingTasks.prefix(10)) { task in
                            TaskCard(task: task)
                        }
                    }
                }

                // Recent Activity
                if !maintenanceService.recentLogs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Activity")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(maintenanceService.recentLogs.prefix(5)) { log in
                            GlassCard {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(ModernColors.accentGreen)

                                    VStack(alignment: .leading) {
                                        Text(log.taskName)
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                        Text(log.deviceName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing) {
                                        Text(log.completedDate, style: .relative)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        if let cost = log.cost {
                                            Text("$\(String(format: "%.2f", cost))")
                                                .font(.caption)
                                                .foregroundStyle(ModernColors.cyan)
                                        }
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                }

                // Stats
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Statistics")
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack {
                            VStack {
                                Text("\(maintenanceService.tasks.count)")
                                    .font(.title2.bold())
                                    .foregroundStyle(ModernColors.cyan)
                                Text("Tasks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            VStack {
                                Text("\(maintenanceService.logs.count)")
                                    .font(.title2.bold())
                                    .foregroundStyle(ModernColors.accentGreen)
                                Text("Completed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            VStack {
                                Text("$\(String(format: "%.0f", maintenanceService.totalMaintenanceCost))")
                                    .font(.title2.bold())
                                    .foregroundStyle(ModernColors.purple)
                                Text("Total Cost")
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
        .navigationTitle("Maintenance")
        .sheet(isPresented: $showAddTask) {
            AddMaintenanceTaskView()
        }
    }
}

struct TaskCard: View {
    let task: MaintenanceTask
    @StateObject private var maintenanceService = MaintenanceService.shared
    @State private var showComplete = false

    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: task.taskType.icon)
                    .font(.title2)
                    .foregroundStyle(task.taskType.color)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.description)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(task.deviceName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let daysUntil = task.daysUntilDue {
                        Text(daysUntil < 0 ? "Overdue by \(-daysUntil) days" : "Due in \(daysUntil) days")
                            .font(.caption)
                            .foregroundStyle(daysUntil < 0 ? ModernColors.red : (daysUntil <= 7 ? ModernColors.orange : .secondary))
                    } else {
                        Text("Never completed")
                            .font(.caption)
                            .foregroundStyle(ModernColors.yellow)
                    }
                }

                Spacer()

                Button {
                    showComplete = true
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundStyle(ModernColors.accentGreen)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showComplete) {
            CompleteTaskView(task: task)
        }
    }
}

struct CompleteTaskView: View {
    let task: MaintenanceTask
    @Environment(\.dismiss) private var dismiss
    @StateObject private var maintenanceService = MaintenanceService.shared
    @State private var notes = ""
    @State private var cost: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    Text(task.description)
                    Text(task.deviceName)
                        .foregroundStyle(.secondary)
                }

                Section("Details") {
                    TextField("Notes (optional)", text: $notes)

                    HStack {
                        Text("Cost")
                        Spacer()
                        TextField("$0.00", value: $cost, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Complete Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Complete") {
                        maintenanceService.completeTask(
                            task.id,
                            notes: notes.isEmpty ? nil : notes,
                            cost: cost > 0 ? cost : nil
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AddMaintenanceTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var maintenanceService = MaintenanceService.shared
    @State private var deviceName = ""
    @State private var description = ""
    @State private var taskType: MaintenanceTask.TaskType = .custom
    @State private var intervalDays = 90

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Device Name", text: $deviceName)

                    Picker("Type", selection: $taskType) {
                        ForEach(MaintenanceTask.TaskType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }

                    TextField("Description", text: $description)
                }

                Section("Schedule") {
                    Stepper("Every \(intervalDays) days", value: $intervalDays, in: 7...365, step: 7)
                }
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        var task = MaintenanceTask(
                            deviceName: deviceName,
                            taskType: taskType,
                            description: description.isEmpty ? taskType.rawValue : description
                        )
                        task.intervalDays = intervalDays
                        maintenanceService.addTask(task)
                        dismiss()
                    }
                    .disabled(deviceName.isEmpty)
                }
            }
            .onChange(of: taskType) { _, newValue in
                if description.isEmpty {
                    description = newValue.rawValue
                }
                intervalDays = newValue.defaultInterval
            }
        }
    }
}
