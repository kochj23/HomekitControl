//
//  NetworkDiscoveryService.swift
//  HomekitControl
//
//  Service for discovering smart home devices via Bonjour/mDNS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Network

/// Service for discovering devices on the local network
@MainActor
final class NetworkDiscoveryService: ObservableObject {
    static let shared = NetworkDiscoveryService()

    // MARK: - Published Properties

    @Published var isScanning = false
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var statusMessage = ""

    // MARK: - Service Types

    private let serviceTypes: [String] = [
        "_hap._tcp",           // HomeKit
        "_matterc._udp",       // Matter Commissioning
        "_matter._tcp",        // Matter
        "_googlecast._tcp",    // Google Cast
        "_hue._tcp",           // Philips Hue
        "_nanoleaf._tcp",      // Nanoleaf
        "_sonos._tcp",         // Sonos
        "_airplay._tcp",       // AirPlay
        "_raop._tcp",          // AirPlay Audio
        "_homekit._tcp"        // HomeKit alternate
    ]

    // MARK: - Private Properties

    private var browsers: [NWBrowser] = []
    private var scanTask: Task<Void, Never>?

    // MARK: - Initialization

    private init() {}

    // MARK: - Discovery

    func startDiscovery() {
        guard !isScanning else { return }

        isScanning = true
        discoveredDevices = []
        statusMessage = "Starting network scan..."

        for serviceType in serviceTypes {
            startBrowsing(for: serviceType)
        }

        // Auto-stop after 30 seconds
        scanTask = Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            await stopDiscovery()
        }
    }

    func stopDiscovery() {
        scanTask?.cancel()
        scanTask = nil

        for browser in browsers {
            browser.cancel()
        }
        browsers.removeAll()

        isScanning = false
        statusMessage = "Scan complete. Found \(discoveredDevices.count) devices."

        // Clear status after 3 seconds
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            statusMessage = ""
        }
    }

    // MARK: - Private Methods

    private func startBrowsing(for serviceType: String) {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: serviceType, domain: "local."), using: parameters)

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.statusMessage = "Scanning for \(serviceType)..."
                case .failed(let error):
                    NSLog("[NetworkDiscovery] Browser failed for \(serviceType): \(error)")
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.processResults(results, serviceType: serviceType)
            }
        }

        browser.start(queue: .main)
        browsers.append(browser)
    }

    private func processResults(_ results: Set<NWBrowser.Result>, serviceType: String) {
        for result in results {
            switch result.endpoint {
            case .service(let name, let type, let domain, _):
                let txtRecords = extractTXTRecords(from: result.metadata)
                let device = createDevice(name: name, type: type, domain: domain, serviceType: serviceType, txtRecords: txtRecords)

                // Add or update device
                if let index = discoveredDevices.firstIndex(where: { $0.name == device.name }) {
                    discoveredDevices[index].lastSeen = Date()
                    discoveredDevices[index].serviceNames.append(serviceType)
                } else {
                    discoveredDevices.append(device)
                }
            default:
                break
            }
        }

        statusMessage = "Found \(discoveredDevices.count) devices..."
    }

    private func extractTXTRecords(from metadata: NWBrowser.Result.Metadata?) -> [String: String] {
        guard case .bonjour(let txtRecord) = metadata else { return [:] }

        // Extract TXT record entries as strings
        var records: [String: String] = [:]
        let dict = txtRecord.dictionary

        for key in dict.keys {
            // NWTXTRecord.Entry raw value access - use string interpolation as fallback
            if let entry = dict[key] {
                records[key] = "\(entry)"
            }
        }
        return records
    }

    private func createDevice(name: String, type: String, domain: String, serviceType: String, txtRecords: [String: String]) -> DiscoveredDevice {
        let manufacturer = Manufacturer.detect(from: name + (txtRecords["md"] ?? "") + (txtRecords["manufacturer"] ?? ""))
        let category = detectCategory(from: serviceType, name: name, txtRecords: txtRecords)
        let protocolType = detectProtocol(from: serviceType)

        return DiscoveredDevice(
            name: name,
            hostname: "\(name).\(type)\(domain)",
            discoverySource: .bonjour,
            serviceType: serviceType,
            txtRecords: txtRecords,
            manufacturer: manufacturer,
            deviceType: category,
            protocolType: protocolType,
            model: txtRecords["md"],
            firmwareVersion: txtRecords["fw"] ?? txtRecords["v"],
            serviceNames: [serviceType],
            discoveredAt: Date(),
            lastSeen: Date()
        )
    }

    private func detectCategory(from serviceType: String, name: String, txtRecords: [String: String]) -> DeviceCategory {
        let combined = (name + (txtRecords["md"] ?? "")).lowercased()

        if serviceType.contains("hue") || combined.contains("light") || combined.contains("bulb") || combined.contains("lamp") {
            return .light
        }
        if combined.contains("thermostat") || combined.contains("ecobee") || combined.contains("nest") {
            return .thermostat
        }
        if combined.contains("lock") || combined.contains("schlage") || combined.contains("yale") {
            return .lock
        }
        if combined.contains("camera") || combined.contains("cam") {
            return .camera
        }
        if combined.contains("speaker") || combined.contains("sonos") || combined.contains("homepod") {
            return .speaker
        }
        if combined.contains("switch") {
            return .switchDevice
        }
        if combined.contains("plug") || combined.contains("outlet") {
            return .outlet
        }
        if combined.contains("sensor") {
            return .sensor
        }
        if combined.contains("bridge") || combined.contains("hub") {
            return .bridge
        }

        return .other
    }

    private func detectProtocol(from serviceType: String) -> DeviceProtocol {
        if serviceType.contains("matter") {
            return .matter
        }
        if serviceType.contains("hap") || serviceType.contains("homekit") {
            return .wifi
        }
        if serviceType.contains("thread") {
            return .thread
        }
        return .wifi
    }
}
