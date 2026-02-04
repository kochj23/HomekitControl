//
//  FloorPlanService.swift
//  HomekitControl
//
//  Floor plan visualization with device placement
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Models

struct FloorPlan: Codable, Identifiable {
    let id: UUID
    var name: String
    var level: Int // Floor number (0 = ground, 1 = first, -1 = basement)
    var imagePath: String? // Local image path
    var imageData: Data? // Embedded image data
    var width: Double // In feet or meters
    var height: Double
    var devices: [PlacedDevice]

    init(name: String, level: Int = 0, width: Double = 50, height: Double = 30) {
        self.id = UUID()
        self.name = name
        self.level = level
        self.imagePath = nil
        self.imageData = nil
        self.width = width
        self.height = height
        self.devices = []
    }
}

struct PlacedDevice: Codable, Identifiable {
    let id: UUID
    let deviceId: UUID
    var deviceName: String
    var deviceType: DeviceType
    var x: Double // Position as percentage of floor plan width (0-1)
    var y: Double // Position as percentage of floor plan height (0-1)
    var rotation: Double // Degrees
    var roomName: String?

    enum DeviceType: String, Codable, CaseIterable {
        case light = "Light"
        case outlet = "Outlet"
        case switchDevice = "Switch"
        case thermostat = "Thermostat"
        case lock = "Lock"
        case motionSensor = "Motion Sensor"
        case contactSensor = "Contact Sensor"
        case camera = "Camera"
        case speaker = "Speaker"
        case fan = "Fan"
        case blind = "Blind"
        case garage = "Garage"
        case other = "Other"

        var icon: String {
            switch self {
            case .light: return "lightbulb.fill"
            case .outlet: return "poweroutlet.type.b"
            case .switchDevice: return "switch.2"
            case .thermostat: return "thermometer"
            case .lock: return "lock.fill"
            case .motionSensor: return "figure.walk.motion"
            case .contactSensor: return "door.left.hand.closed"
            case .camera: return "video.fill"
            case .speaker: return "hifispeaker.fill"
            case .fan: return "fan.fill"
            case .blind: return "blinds.horizontal.closed"
            case .garage: return "car.fill"
            case .other: return "questionmark.circle"
            }
        }

        var color: Color {
            switch self {
            case .light: return ModernColors.yellow
            case .outlet: return ModernColors.orange
            case .switchDevice: return ModernColors.cyan
            case .thermostat: return ModernColors.red
            case .lock: return ModernColors.purple
            case .motionSensor: return ModernColors.accentGreen
            case .contactSensor: return ModernColors.teal
            case .camera: return ModernColors.magenta
            case .speaker: return ModernColors.accentBlue
            case .fan: return ModernColors.cyan
            case .blind: return ModernColors.orange
            case .garage: return ModernColors.purple
            case .other: return .secondary
            }
        }
    }

    init(deviceId: UUID, deviceName: String, deviceType: DeviceType, x: Double, y: Double) {
        self.id = UUID()
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.deviceType = deviceType
        self.x = x
        self.y = y
        self.rotation = 0
        self.roomName = nil
    }
}

// MARK: - Floor Plan Service

@MainActor
class FloorPlanService: ObservableObject {
    static let shared = FloorPlanService()

    // MARK: - Published Properties

    @Published var floorPlans: [FloorPlan] = []
    @Published var selectedPlanId: UUID?
    @Published var isEditMode = false
    @Published var unplacedDevices: [UnplacedDevice] = []

    struct UnplacedDevice: Identifiable {
        let id: UUID
        let name: String
        let type: PlacedDevice.DeviceType
    }

    // MARK: - Private Properties

    private let storageKey = "HomekitControl_FloorPlans"

    // MARK: - Initialization

    private init() {
        loadData()
    }

    // MARK: - Floor Plan Management

    func addFloorPlan(_ plan: FloorPlan) {
        floorPlans.append(plan)
        if selectedPlanId == nil {
            selectedPlanId = plan.id
        }
        saveData()
    }

    func updateFloorPlan(_ plan: FloorPlan) {
        if let index = floorPlans.firstIndex(where: { $0.id == plan.id }) {
            floorPlans[index] = plan
            saveData()
        }
    }

    func deleteFloorPlan(_ plan: FloorPlan) {
        floorPlans.removeAll { $0.id == plan.id }
        if selectedPlanId == plan.id {
            selectedPlanId = floorPlans.first?.id
        }
        saveData()
    }

    func setFloorPlanImage(_ planId: UUID, imageData: Data) {
        if let index = floorPlans.firstIndex(where: { $0.id == planId }) {
            floorPlans[index].imageData = imageData
            saveData()
        }
    }

    // MARK: - Device Placement

    func placeDevice(_ device: PlacedDevice, on planId: UUID) {
        if let index = floorPlans.firstIndex(where: { $0.id == planId }) {
            floorPlans[index].devices.append(device)
            saveData()
        }
    }

    func updateDevicePosition(deviceId: UUID, on planId: UUID, x: Double, y: Double) {
        if let planIndex = floorPlans.firstIndex(where: { $0.id == planId }),
           let deviceIndex = floorPlans[planIndex].devices.firstIndex(where: { $0.id == deviceId }) {
            floorPlans[planIndex].devices[deviceIndex].x = x
            floorPlans[planIndex].devices[deviceIndex].y = y
            saveData()
        }
    }

    func removeDevice(deviceId: UUID, from planId: UUID) {
        if let index = floorPlans.firstIndex(where: { $0.id == planId }) {
            floorPlans[index].devices.removeAll { $0.id == deviceId }
            saveData()
        }
    }

    func rotateDevice(deviceId: UUID, on planId: UUID, degrees: Double) {
        if let planIndex = floorPlans.firstIndex(where: { $0.id == planId }),
           let deviceIndex = floorPlans[planIndex].devices.firstIndex(where: { $0.id == deviceId }) {
            floorPlans[planIndex].devices[deviceIndex].rotation = degrees
            saveData()
        }
    }

    // MARK: - Device Discovery

    func refreshUnplacedDevices() {
        #if canImport(HomeKit)
        let placedDeviceIds = Set(floorPlans.flatMap { $0.devices.map { $0.deviceId } })

        unplacedDevices = HomeKitService.shared.accessories.compactMap { accessory in
            guard !placedDeviceIds.contains(accessory.uniqueIdentifier) else { return nil }

            let deviceType = determineDeviceType(for: accessory)
            return UnplacedDevice(
                id: accessory.uniqueIdentifier,
                name: accessory.name,
                type: deviceType
            )
        }
        #endif
    }

    #if canImport(HomeKit)
    private func determineDeviceType(for accessory: HMAccessory) -> PlacedDevice.DeviceType {
        for service in accessory.services {
            switch service.serviceType {
            case HMServiceTypeLightbulb: return .light
            case HMServiceTypeOutlet: return .outlet
            case HMServiceTypeSwitch: return .switchDevice
            case HMServiceTypeThermostat: return .thermostat
            case HMServiceTypeLockMechanism: return .lock
            case HMServiceTypeMotionSensor: return .motionSensor
            case HMServiceTypeContactSensor: return .contactSensor
            case HMServiceTypeFan: return .fan
            case HMServiceTypeGarageDoorOpener: return .garage
            case HMServiceTypeWindowCovering: return .blind
            default: continue
            }
        }
        return .other
    }
    #endif

    // MARK: - Computed Properties

    var selectedPlan: FloorPlan? {
        floorPlans.first { $0.id == selectedPlanId }
    }

    var totalPlacedDevices: Int {
        floorPlans.map { $0.devices.count }.reduce(0, +)
    }

    var floorPlansByLevel: [Int: [FloorPlan]] {
        Dictionary(grouping: floorPlans) { $0.level }
    }

    // MARK: - Device Status

    func getDeviceStatus(deviceId: UUID) -> (isOn: Bool, isReachable: Bool) {
        #if canImport(HomeKit)
        guard let accessory = HomeKitService.shared.accessories.first(where: { $0.uniqueIdentifier == deviceId }) else {
            return (false, false)
        }

        var isOn = false
        if let service = accessory.services.first(where: {
            [HMServiceTypeLightbulb, HMServiceTypeSwitch, HMServiceTypeOutlet].contains($0.serviceType)
        }),
           let powerState = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypePowerState }),
           let value = powerState.value as? Bool {
            isOn = value
        }

        return (isOn, accessory.isReachable)
        #else
        return (false, false)
        #endif
    }

    // MARK: - Persistence

    private func saveData() {
        let settings: [String: Any] = [
            "selectedPlanId": selectedPlanId?.uuidString ?? ""
        ]

        if let encoded = try? JSONSerialization.data(withJSONObject: settings) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }

        if let plansData = try? JSONEncoder().encode(floorPlans) {
            UserDefaults.standard.set(plansData, forKey: storageKey + "_plans")
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let planIdStr = settings["selectedPlanId"] as? String,
               let planId = UUID(uuidString: planIdStr) {
                selectedPlanId = planId
            }
        }

        if let plansData = UserDefaults.standard.data(forKey: storageKey + "_plans"),
           let saved = try? JSONDecoder().decode([FloorPlan].self, from: plansData) {
            floorPlans = saved
        }
    }
}
