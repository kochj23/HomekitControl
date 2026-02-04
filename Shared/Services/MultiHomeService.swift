//
//  MultiHomeService.swift
//  HomekitControl
//
//  Multi-home support and cross-home management
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Models

struct HomeInfo: Identifiable {
    let id: UUID
    let name: String
    var isPrimary: Bool
    var accessoryCount: Int
    var roomCount: Int
    var sceneCount: Int
    var isReachable: Bool
    var lastAccessed: Date

    #if canImport(HomeKit)
    let hmHome: HMHome
    #endif
}

struct CrossHomeScene: Codable, Identifiable {
    let id: UUID
    var name: String
    var actions: [CrossHomeAction]
    var isEnabled: Bool

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.actions = []
        self.isEnabled = true
    }
}

struct CrossHomeAction: Codable, Identifiable {
    let id: UUID
    let homeId: UUID
    let homeName: String
    let sceneId: UUID
    let sceneName: String
    var delay: TimeInterval // seconds

    init(homeId: UUID, homeName: String, sceneId: UUID, sceneName: String, delay: TimeInterval = 0) {
        self.id = UUID()
        self.homeId = homeId
        self.homeName = homeName
        self.sceneId = sceneId
        self.sceneName = sceneName
        self.delay = delay
    }
}

struct VacationSettings: Codable, Identifiable {
    let id: UUID
    let homeId: UUID
    var homeName: String
    var isEnabled: Bool
    var lightSimulation: Bool
    var randomizeSchedule: Bool
    var alertOnMotion: Bool
    var alertOnDoorOpen: Bool
    var startDate: Date?
    var endDate: Date?

    init(homeId: UUID, homeName: String) {
        self.id = UUID()
        self.homeId = homeId
        self.homeName = homeName
        self.isEnabled = false
        self.lightSimulation = true
        self.randomizeSchedule = true
        self.alertOnMotion = true
        self.alertOnDoorOpen = true
        self.startDate = nil
        self.endDate = nil
    }
}

// MARK: - Multi Home Service

@MainActor
class MultiHomeService: ObservableObject {
    static let shared = MultiHomeService()

    // MARK: - Published Properties

    @Published var homes: [HomeInfo] = []
    @Published var currentHomeId: UUID?
    @Published var crossHomeScenes: [CrossHomeScene] = []
    @Published var vacationSettings: [VacationSettings] = []
    @Published var isLoading = false

    // MARK: - Private Properties

    private let storageKey = "HomekitControl_MultiHome"
    #if canImport(HomeKit)
    private var homeManager: HMHomeManager?
    #endif

    // MARK: - Initialization

    private init() {
        loadData()
    }

    // MARK: - Home Management

    func refreshHomes() {
        #if canImport(HomeKit)
        isLoading = true
        homes = []

        guard let manager = HomeKitService.shared.getHomeManager else {
            isLoading = false
            return
        }

        for home in manager.homes {
            let info = HomeInfo(
                id: home.uniqueIdentifier,
                name: home.name,
                isPrimary: home.isPrimary,
                accessoryCount: home.accessories.count,
                roomCount: home.rooms.count,
                sceneCount: home.actionSets.count,
                isReachable: true,
                lastAccessed: Date(),
                hmHome: home
            )
            homes.append(info)
        }

        // Set current home if not set
        if currentHomeId == nil, let primaryHome = homes.first(where: { $0.isPrimary }) {
            currentHomeId = primaryHome.id
        } else if currentHomeId == nil, let firstHome = homes.first {
            currentHomeId = firstHome.id
        }

        // Initialize vacation settings for any new homes
        for home in homes {
            if !vacationSettings.contains(where: { $0.homeId == home.id }) {
                let settings = VacationSettings(homeId: home.id, homeName: home.name)
                vacationSettings.append(settings)
            }
        }

        isLoading = false
        saveData()
        #endif
    }

    func switchHome(to homeId: UUID) {
        guard homes.contains(where: { $0.id == homeId }) else { return }
        currentHomeId = homeId

        #if canImport(HomeKit)
        // Update HomeKitService to use this home
        if let home = homes.first(where: { $0.id == homeId }) {
            HomeKitService.shared.setCurrentHome(home.hmHome)
        }
        #endif

        saveData()
    }

    // MARK: - Cross-Home Scenes

    func addCrossHomeScene(_ scene: CrossHomeScene) {
        crossHomeScenes.append(scene)
        saveData()
    }

    func updateCrossHomeScene(_ scene: CrossHomeScene) {
        if let index = crossHomeScenes.firstIndex(where: { $0.id == scene.id }) {
            crossHomeScenes[index] = scene
            saveData()
        }
    }

    func deleteCrossHomeScene(_ scene: CrossHomeScene) {
        crossHomeScenes.removeAll { $0.id == scene.id }
        saveData()
    }

    func executeCrossHomeScene(_ scene: CrossHomeScene) async {
        guard scene.isEnabled else { return }

        for action in scene.actions {
            if action.delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(action.delay * 1_000_000_000))
            }

            await executeSceneInHome(sceneId: action.sceneId, homeId: action.homeId)
        }
    }

    private func executeSceneInHome(sceneId: UUID, homeId: UUID) async {
        #if canImport(HomeKit)
        guard let home = homes.first(where: { $0.id == homeId }),
              let scene = home.hmHome.actionSets.first(where: { $0.uniqueIdentifier == sceneId }) else {
            return
        }

        do {
            try await home.hmHome.executeActionSet(scene)
        } catch {
            print("Failed to execute scene: \(error)")
        }
        #endif
    }

    // MARK: - Vacation Mode

    func enableVacationMode(for homeId: UUID) {
        if let index = vacationSettings.firstIndex(where: { $0.homeId == homeId }) {
            vacationSettings[index].isEnabled = true
            saveData()

            // Start vacation mode behaviors
            if vacationSettings[index].lightSimulation {
                startLightSimulation(for: homeId)
            }
        }
    }

    func disableVacationMode(for homeId: UUID) {
        if let index = vacationSettings.firstIndex(where: { $0.homeId == homeId }) {
            vacationSettings[index].isEnabled = false
            saveData()

            // Stop vacation mode behaviors
            stopLightSimulation(for: homeId)
        }
    }

    private func startLightSimulation(for homeId: UUID) {
        // Implement light simulation
        // This would randomly turn lights on/off to simulate occupancy
    }

    private func stopLightSimulation(for homeId: UUID) {
        // Stop light simulation
    }

    func updateVacationSettings(_ settings: VacationSettings) {
        if let index = vacationSettings.firstIndex(where: { $0.id == settings.id }) {
            vacationSettings[index] = settings
            saveData()
        }
    }

    // MARK: - Computed Properties

    var currentHome: HomeInfo? {
        homes.first { $0.id == currentHomeId }
    }

    var primaryHome: HomeInfo? {
        homes.first { $0.isPrimary }
    }

    var hasMultipleHomes: Bool {
        homes.count > 1
    }

    var totalAccessories: Int {
        homes.map { $0.accessoryCount }.reduce(0, +)
    }

    var totalScenes: Int {
        homes.map { $0.sceneCount }.reduce(0, +)
    }

    var activeVacationModes: [VacationSettings] {
        vacationSettings.filter { $0.isEnabled }
    }

    // MARK: - Quick Access

    func getScenes(for homeId: UUID) -> [SceneInfo] {
        #if canImport(HomeKit)
        guard let home = homes.first(where: { $0.id == homeId }) else { return [] }

        return home.hmHome.actionSets.map { scene in
            SceneInfo(
                id: scene.uniqueIdentifier,
                name: scene.name,
                homeId: homeId,
                homeName: home.name
            )
        }
        #else
        return []
        #endif
    }

    struct SceneInfo: Identifiable {
        let id: UUID
        let name: String
        let homeId: UUID
        let homeName: String
    }

    // MARK: - Persistence

    private func saveData() {
        let settings: [String: Any] = [
            "currentHomeId": currentHomeId?.uuidString ?? ""
        ]

        if let encoded = try? JSONSerialization.data(withJSONObject: settings) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }

        if let scenesData = try? JSONEncoder().encode(crossHomeScenes) {
            UserDefaults.standard.set(scenesData, forKey: storageKey + "_crossHomeScenes")
        }

        if let vacationData = try? JSONEncoder().encode(vacationSettings) {
            UserDefaults.standard.set(vacationData, forKey: storageKey + "_vacation")
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let homeIdStr = settings["currentHomeId"] as? String,
               let homeId = UUID(uuidString: homeIdStr) {
                currentHomeId = homeId
            }
        }

        if let scenesData = UserDefaults.standard.data(forKey: storageKey + "_crossHomeScenes"),
           let saved = try? JSONDecoder().decode([CrossHomeScene].self, from: scenesData) {
            crossHomeScenes = saved
        }

        if let vacationData = UserDefaults.standard.data(forKey: storageKey + "_vacation"),
           let saved = try? JSONDecoder().decode([VacationSettings].self, from: vacationData) {
            vacationSettings = saved
        }
    }
}
