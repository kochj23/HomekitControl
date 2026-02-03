//
//  HomekitControl_iOS.swift
//  HomekitControl
//
//  iOS App Entry Point
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

@main
struct HomekitControl_iOS: App {
    @StateObject private var homeKitService = HomeKitService.shared

    var body: some Scene {
        WindowGroup {
            iOS_ContentView()
                .environmentObject(homeKitService)
                .preferredColorScheme(.dark)
        }
    }
}
