//
//  HomekitControl_macOS.swift
//  HomekitControl
//
//  macOS App Entry Point
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

@main
struct HomekitControl_macOS: App {
    @StateObject private var homeKitService = HomeKitService.shared

    var body: some Scene {
        WindowGroup {
            macOS_ContentView()
                .environmentObject(homeKitService)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Refresh Data") {
                    Task {
                        await homeKitService.refreshAll()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Scan Network") {
                    // Network scan
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandGroup(after: .importExport) {
                Button("Export to CSV...") {
                    // Export
                }
                .keyboardShortcut("e", modifiers: .command)

                Button("Export to JSON...") {
                    // Export
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }

        Settings {
            macOS_SettingsView()
        }
    }
}
