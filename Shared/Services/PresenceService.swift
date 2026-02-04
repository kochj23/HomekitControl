//
//  PresenceService.swift
//  HomekitControl
//
//  Presence detection and geofencing service
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import CoreLocation
import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Models

struct GeofenceRegion: Codable, Identifiable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var radius: Double // meters
    var triggerOnEntry: Bool
    var triggerOnExit: Bool
    var entrySceneId: UUID?
    var exitSceneId: UUID?
    var isEnabled: Bool

    init(name: String, latitude: Double, longitude: Double, radius: Double = 100) {
        self.id = UUID()
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.triggerOnEntry = true
        self.triggerOnExit = true
        self.entrySceneId = nil
        self.exitSceneId = nil
        self.isEnabled = true
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct FamilyMember: Codable, Identifiable {
    let id: UUID
    var name: String
    var isHome: Bool
    var lastSeen: Date?
    var lastLocation: String?
    var trackingEnabled: Bool
    var color: String // Hex color for map display

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.isHome = false
        self.lastSeen = nil
        self.lastLocation = nil
        self.trackingEnabled = true
        self.color = "#3BDCFC"
    }
}

struct PresenceEvent: Codable, Identifiable {
    let id: UUID
    let memberId: UUID?
    let memberName: String
    let eventType: PresenceEventType
    let regionName: String
    let timestamp: Date
    let triggeredSceneId: UUID?

    enum PresenceEventType: String, Codable {
        case arrived = "Arrived"
        case departed = "Departed"
        case detected = "Detected"
    }
}

// MARK: - Presence Service

#if os(iOS)
@MainActor
class PresenceService: NSObject, ObservableObject {
    static let shared = PresenceService()

    // MARK: - Published Properties

    @Published var regions: [GeofenceRegion] = []
    @Published var familyMembers: [FamilyMember] = []
    @Published var presenceEvents: [PresenceEvent] = []
    @Published var currentLocation: CLLocation?
    @Published var isMonitoring = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isHome = false

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()
    private let storageKey = "HomekitControl_Presence"

    // MARK: - Initialization

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        loadData()
    }

    // MARK: - Authorization

    func requestAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    // MARK: - Region Management

    func addRegion(_ region: GeofenceRegion) {
        regions.append(region)
        startMonitoringRegion(region)
        saveData()
    }

    func updateRegion(_ region: GeofenceRegion) {
        if let index = regions.firstIndex(where: { $0.id == region.id }) {
            stopMonitoringRegion(regions[index])
            regions[index] = region
            if region.isEnabled {
                startMonitoringRegion(region)
            }
            saveData()
        }
    }

    func deleteRegion(_ region: GeofenceRegion) {
        stopMonitoringRegion(region)
        regions.removeAll { $0.id == region.id }
        saveData()
    }

    private func startMonitoringRegion(_ region: GeofenceRegion) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }

        let clRegion = CLCircularRegion(
            center: region.coordinate,
            radius: min(region.radius, locationManager.maximumRegionMonitoringDistance),
            identifier: region.id.uuidString
        )
        clRegion.notifyOnEntry = region.triggerOnEntry
        clRegion.notifyOnExit = region.triggerOnExit

        locationManager.startMonitoring(for: clRegion)
    }

    private func stopMonitoringRegion(_ region: GeofenceRegion) {
        for monitoredRegion in locationManager.monitoredRegions {
            if monitoredRegion.identifier == region.id.uuidString {
                locationManager.stopMonitoring(for: monitoredRegion)
                break
            }
        }
    }

    // MARK: - Family Members

    func addFamilyMember(_ member: FamilyMember) {
        familyMembers.append(member)
        saveData()
    }

    func updateFamilyMember(_ member: FamilyMember) {
        if let index = familyMembers.firstIndex(where: { $0.id == member.id }) {
            familyMembers[index] = member
            saveData()
        }
    }

    func deleteFamilyMember(_ member: FamilyMember) {
        familyMembers.removeAll { $0.id == member.id }
        saveData()
    }

    func setMemberHome(_ memberId: UUID, isHome: Bool, location: String? = nil) {
        if let index = familyMembers.firstIndex(where: { $0.id == memberId }) {
            familyMembers[index].isHome = isHome
            familyMembers[index].lastSeen = Date()
            familyMembers[index].lastLocation = location
            saveData()

            // Update overall home status
            updateHomeStatus()
        }
    }

    private func updateHomeStatus() {
        isHome = familyMembers.contains { $0.isHome }
    }

    // MARK: - Monitoring

    func startMonitoring() {
        #if os(macOS)
        guard authorizationStatus == .authorizedAlways else {
            requestAuthorization()
            return
        }
        #else
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            requestAuthorization()
            return
        }
        #endif

        isMonitoring = true
        locationManager.startUpdatingLocation()

        // Start monitoring all enabled regions
        for region in regions where region.isEnabled {
            startMonitoringRegion(region)
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        locationManager.stopUpdatingLocation()

        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
    }

    // MARK: - Scene Triggering

    private func handleRegionEntry(_ regionId: String) {
        guard let region = regions.first(where: { $0.id.uuidString == regionId }) else { return }

        // Log event
        let event = PresenceEvent(
            id: UUID(),
            memberId: nil,
            memberName: "You",
            eventType: .arrived,
            regionName: region.name,
            timestamp: Date(),
            triggeredSceneId: region.entrySceneId
        )
        presenceEvents.insert(event, at: 0)

        // Trigger scene
        if let sceneId = region.entrySceneId {
            triggerScene(sceneId)
        }

        // Update home status if this is home region
        if region.name.lowercased().contains("home") {
            isHome = true
        }

        saveData()
    }

    private func handleRegionExit(_ regionId: String) {
        guard let region = regions.first(where: { $0.id.uuidString == regionId }) else { return }

        // Log event
        let event = PresenceEvent(
            id: UUID(),
            memberId: nil,
            memberName: "You",
            eventType: .departed,
            regionName: region.name,
            timestamp: Date(),
            triggeredSceneId: region.exitSceneId
        )
        presenceEvents.insert(event, at: 0)

        // Trigger scene
        if let sceneId = region.exitSceneId {
            triggerScene(sceneId)
        }

        // Update home status if this is home region
        if region.name.lowercased().contains("home") {
            isHome = false
        }

        saveData()
    }

    private func triggerScene(_ sceneId: UUID) {
        #if canImport(HomeKit)
        Task {
            if let scene = HomeKitService.shared.scenes.first(where: { $0.uniqueIdentifier == sceneId }) {
                try? await HomeKitService.shared.executeScene(scene)
            }
        }
        #endif
    }

    // MARK: - Computed Properties

    var homeRegion: GeofenceRegion? {
        regions.first { $0.name.lowercased().contains("home") }
    }

    var membersAtHome: [FamilyMember] {
        familyMembers.filter { $0.isHome }
    }

    var membersAway: [FamilyMember] {
        familyMembers.filter { !$0.isHome }
    }

    var recentEvents: [PresenceEvent] {
        Array(presenceEvents.prefix(50))
    }

    // MARK: - Persistence

    private func saveData() {
        let data: [String: Any] = [
            "isMonitoring": isMonitoring
        ]

        if let encoded = try? JSONSerialization.data(withJSONObject: data) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }

        if let regionsData = try? JSONEncoder().encode(regions) {
            UserDefaults.standard.set(regionsData, forKey: storageKey + "_regions")
        }

        if let membersData = try? JSONEncoder().encode(familyMembers) {
            UserDefaults.standard.set(membersData, forKey: storageKey + "_members")
        }

        if let eventsData = try? JSONEncoder().encode(Array(presenceEvents.prefix(100))) {
            UserDefaults.standard.set(eventsData, forKey: storageKey + "_events")
        }
    }

    private func loadData() {
        if let regionsData = UserDefaults.standard.data(forKey: storageKey + "_regions"),
           let saved = try? JSONDecoder().decode([GeofenceRegion].self, from: regionsData) {
            regions = saved
        }

        if let membersData = UserDefaults.standard.data(forKey: storageKey + "_members"),
           let saved = try? JSONDecoder().decode([FamilyMember].self, from: membersData) {
            familyMembers = saved
        }

        if let eventsData = UserDefaults.standard.data(forKey: storageKey + "_events"),
           let saved = try? JSONDecoder().decode([PresenceEvent].self, from: eventsData) {
            presenceEvents = saved
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension PresenceService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            self.handleRegionEntry(region.identifier)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            self.handleRegionExit(region.identifier)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
    }
}
#else
// Stub for non-iOS platforms
@MainActor
class PresenceService: ObservableObject {
    static let shared = PresenceService()
    @Published var regions: [GeofenceRegion] = []
    @Published var familyMembers: [FamilyMember] = []
    @Published var presenceEvents: [PresenceEvent] = []
    @Published var isMonitoring = false
    @Published var isHome = false

    func requestAuthorization() {}
    func startMonitoring() {}
    func stopMonitoring() {}
    func addRegion(_ region: GeofenceRegion) {}
    func removeRegion(_ regionId: UUID) {}
}
#endif
