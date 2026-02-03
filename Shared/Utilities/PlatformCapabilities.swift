//
//  PlatformCapabilities.swift
//  HomekitControl
//
//  Platform-specific capability detection
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Defines what features are available on each platform
struct PlatformCapabilities {
    #if os(iOS)
    static let canControlDevices = true
    static let canModifyScenes = true
    static let canRemoveDevices = true
    static let canUseKeychain = true
    static let canAccessFileSystem = true
    static let supportsQRScanning = true
    static let supportsSceneRepair = true
    static let hasNativeHomeKit = true
    static let platformName = "iOS"
    #elseif os(tvOS)
    static let canControlDevices = true
    static let canModifyScenes = false  // tvOS HomeKit is read-only
    static let canRemoveDevices = false
    static let canUseKeychain = false
    static let canAccessFileSystem = false
    static let supportsQRScanning = false
    static let supportsSceneRepair = false
    static let hasNativeHomeKit = true
    static let platformName = "tvOS"
    #elseif os(macOS)
    static let canControlDevices = false  // No native HomeKit on macOS
    static let canModifyScenes = false
    static let canRemoveDevices = false
    static let canUseKeychain = true
    static let canAccessFileSystem = true
    static let supportsQRScanning = false
    static let supportsSceneRepair = false
    static let hasNativeHomeKit = false
    static let platformName = "macOS"
    #endif

    /// Check if we're running on Apple TV
    static var isAppleTV: Bool {
        #if os(tvOS)
        return true
        #else
        return false
        #endif
    }

    /// Check if we're running on iPhone/iPad
    static var isiOS: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }

    /// Check if we're running on Mac
    static var isMacOS: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }
}
