//
//  GuestModeService.swift
//  HomekitControl
//
//  Temporary access for guests with limited device exposure
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI
import CryptoKit
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Guest Models

struct GuestAccess: Codable, Identifiable {
    let id: UUID
    var name: String
    var accessCode: String
    var allowedDeviceIds: [UUID]
    var allowedSceneIds: [UUID]
    var createdAt: Date
    var expiresAt: Date?
    var isActive: Bool
    var lastUsed: Date?
    var usageCount: Int

    init(name: String, expiresAt: Date? = nil) {
        self.id = UUID()
        self.name = name
        self.accessCode = GuestAccess.generateAccessCode()
        self.allowedDeviceIds = []
        self.allowedSceneIds = []
        self.createdAt = Date()
        self.expiresAt = expiresAt
        self.isActive = true
        self.usageCount = 0
    }

    static func generateAccessCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Excluding confusing chars
        return String((0..<6).map { _ in characters.randomElement()! })
    }

    var isExpired: Bool {
        if let expiresAt = expiresAt {
            return Date() > expiresAt
        }
        return false
    }

    var isValid: Bool {
        isActive && !isExpired
    }
}

struct GuestActivityLog: Codable, Identifiable {
    let id: UUID
    let guestId: UUID
    let guestName: String
    let action: String
    let deviceName: String?
    let timestamp: Date

    init(guestId: UUID, guestName: String, action: String, deviceName: String? = nil) {
        self.id = UUID()
        self.guestId = guestId
        self.guestName = guestName
        self.action = action
        self.deviceName = deviceName
        self.timestamp = Date()
    }
}

// MARK: - Guest Mode Service

@MainActor
class GuestModeService: ObservableObject {
    static let shared = GuestModeService()

    @Published var guests: [GuestAccess] = []
    @Published var activityLogs: [GuestActivityLog] = []
    @Published var isGuestModeActive = false
    @Published var currentGuest: GuestAccess?

    private let storageKey = "HomekitControl_GuestMode"

    private init() {
        loadData()
    }

    // MARK: - Guest Management

    func createGuest(name: String, expiresIn: TimeInterval? = nil) -> GuestAccess {
        let expiresAt = expiresIn.map { Date().addingTimeInterval($0) }
        let guest = GuestAccess(name: name, expiresAt: expiresAt)
        guests.append(guest)
        saveData()

        logActivity(guestId: guest.id, guestName: guest.name, action: "Guest access created")
        return guest
    }

    func updateGuest(_ guest: GuestAccess) {
        if let index = guests.firstIndex(where: { $0.id == guest.id }) {
            guests[index] = guest
            saveData()
        }
    }

    func deleteGuest(_ guest: GuestAccess) {
        guests.removeAll { $0.id == guest.id }
        saveData()
        logActivity(guestId: guest.id, guestName: guest.name, action: "Guest access revoked")
    }

    func regenerateCode(for guest: GuestAccess) {
        if let index = guests.firstIndex(where: { $0.id == guest.id }) {
            guests[index].accessCode = GuestAccess.generateAccessCode()
            saveData()
            logActivity(guestId: guest.id, guestName: guest.name, action: "Access code regenerated")
        }
    }

    func extendAccess(for guest: GuestAccess, by duration: TimeInterval) {
        if let index = guests.firstIndex(where: { $0.id == guest.id }) {
            let currentExpiry = guests[index].expiresAt ?? Date()
            guests[index].expiresAt = currentExpiry.addingTimeInterval(duration)
            saveData()
            logActivity(guestId: guest.id, guestName: guest.name, action: "Access extended")
        }
    }

    // MARK: - Device/Scene Permissions

    func addDeviceToGuest(_ deviceId: UUID, guest: GuestAccess) {
        if let index = guests.firstIndex(where: { $0.id == guest.id }) {
            if !guests[index].allowedDeviceIds.contains(deviceId) {
                guests[index].allowedDeviceIds.append(deviceId)
                saveData()
            }
        }
    }

    func removeDeviceFromGuest(_ deviceId: UUID, guest: GuestAccess) {
        if let index = guests.firstIndex(where: { $0.id == guest.id }) {
            guests[index].allowedDeviceIds.removeAll { $0 == deviceId }
            saveData()
        }
    }

    func addSceneToGuest(_ sceneId: UUID, guest: GuestAccess) {
        if let index = guests.firstIndex(where: { $0.id == guest.id }) {
            if !guests[index].allowedSceneIds.contains(sceneId) {
                guests[index].allowedSceneIds.append(sceneId)
                saveData()
            }
        }
    }

    func removeSceneFromGuest(_ sceneId: UUID, guest: GuestAccess) {
        if let index = guests.firstIndex(where: { $0.id == guest.id }) {
            guests[index].allowedSceneIds.removeAll { $0 == sceneId }
            saveData()
        }
    }

    // MARK: - Authentication

    func authenticateGuest(code: String) -> GuestAccess? {
        guard let guest = guests.first(where: { $0.accessCode.uppercased() == code.uppercased() }) else {
            return nil
        }

        guard guest.isValid else {
            return nil
        }

        // Update usage stats
        if let index = guests.firstIndex(where: { $0.id == guest.id }) {
            guests[index].lastUsed = Date()
            guests[index].usageCount += 1
            saveData()
        }

        currentGuest = guest
        isGuestModeActive = true

        logActivity(guestId: guest.id, guestName: guest.name, action: "Guest logged in")
        return guest
    }

    func endGuestSession() {
        if let guest = currentGuest {
            logActivity(guestId: guest.id, guestName: guest.name, action: "Guest session ended")
        }
        currentGuest = nil
        isGuestModeActive = false
    }

    // MARK: - Access Control

    func canAccessDevice(_ deviceId: UUID) -> Bool {
        guard isGuestModeActive, let guest = currentGuest else {
            return true // Full access when not in guest mode
        }
        return guest.allowedDeviceIds.contains(deviceId)
    }

    func canAccessScene(_ sceneId: UUID) -> Bool {
        guard isGuestModeActive, let guest = currentGuest else {
            return true
        }
        return guest.allowedSceneIds.contains(sceneId)
    }

    func getAccessibleDevices() -> [UUID] {
        guard isGuestModeActive, let guest = currentGuest else {
            #if canImport(HomeKit)
            return HomeKitService.shared.accessories.map { $0.uniqueIdentifier }
            #else
            return []
            #endif
        }
        return guest.allowedDeviceIds
    }

    func getAccessibleScenes() -> [UUID] {
        guard isGuestModeActive, let guest = currentGuest else {
            #if canImport(HomeKit)
            return HomeKitService.shared.scenes.map { $0.uniqueIdentifier }
            #else
            return []
            #endif
        }
        return guest.allowedSceneIds
    }

    // MARK: - Activity Logging

    func logActivity(guestId: UUID, guestName: String, action: String, deviceName: String? = nil) {
        let log = GuestActivityLog(
            guestId: guestId,
            guestName: guestName,
            action: action,
            deviceName: deviceName
        )
        activityLogs.insert(log, at: 0)

        // Keep last 500 logs
        if activityLogs.count > 500 {
            activityLogs = Array(activityLogs.prefix(500))
        }

        saveData()
    }

    func logDeviceAction(_ action: String, deviceName: String) {
        guard let guest = currentGuest else { return }
        logActivity(guestId: guest.id, guestName: guest.name, action: action, deviceName: deviceName)
    }

    func getLogsForGuest(_ guestId: UUID) -> [GuestActivityLog] {
        activityLogs.filter { $0.guestId == guestId }
    }

    func clearLogs() {
        activityLogs.removeAll()
        saveData()
    }

    // MARK: - Cleanup

    func cleanupExpiredGuests() {
        let expiredGuests = guests.filter { $0.isExpired }
        for guest in expiredGuests {
            logActivity(guestId: guest.id, guestName: guest.name, action: "Access expired (auto-cleanup)")
        }
        guests.removeAll { $0.isExpired }
        saveData()
    }

    // MARK: - Persistence

    private func saveData() {
        if let guestsData = try? JSONEncoder().encode(guests) {
            UserDefaults.standard.set(guestsData, forKey: storageKey + "_guests")
        }
        if let logsData = try? JSONEncoder().encode(activityLogs) {
            UserDefaults.standard.set(logsData, forKey: storageKey + "_logs")
        }
    }

    private func loadData() {
        if let guestsData = UserDefaults.standard.data(forKey: storageKey + "_guests"),
           let saved = try? JSONDecoder().decode([GuestAccess].self, from: guestsData) {
            guests = saved
        }
        if let logsData = UserDefaults.standard.data(forKey: storageKey + "_logs"),
           let saved = try? JSONDecoder().decode([GuestActivityLog].self, from: logsData) {
            activityLogs = saved
        }

        // Cleanup expired on load
        cleanupExpiredGuests()
    }
}
