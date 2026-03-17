//
//  HomekitControl_tvOS.swift
//  HomekitControl
//
//  tvOS App Entry Point
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

@main
struct HomekitControl_tvOS: App {
    @StateObject private var homeKitService = HomeKitService.shared

    init() {
        NovaAPIServer.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            tvOS_ContentView()
                .environmentObject(homeKitService)
                .preferredColorScheme(.dark)
        }
    }
}
