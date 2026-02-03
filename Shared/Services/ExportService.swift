//
//  ExportService.swift
//  HomekitControl
//
//  Service for exporting device and scene data
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Service for exporting device and scene data to various formats
@MainActor
final class ExportService: ObservableObject {
    static let shared = ExportService()

    // MARK: - Published Properties

    @Published var isExporting = false
    @Published var statusMessage = ""

    // MARK: - Initialization

    private init() {}

    // MARK: - Device Export

    func exportDevicesAsJSON(_ devices: [UnifiedDevice]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(devices)
    }

    func exportDevicesAsCSV(_ devices: [UnifiedDevice]) -> String {
        var csv = "Name,Room,Home,Manufacturer,Category,Protocol,Health,Reliability,IP Address,MAC Address,Last Seen\n"

        for device in devices {
            let row = [
                escapeCSV(device.name),
                escapeCSV(device.room ?? ""),
                escapeCSV(device.home ?? ""),
                escapeCSV(device.manufacturer.rawValue),
                escapeCSV(device.category.rawValue),
                escapeCSV(device.protocolType.rawValue),
                escapeCSV(device.healthStatus.rawValue),
                String(format: "%.1f", device.reliabilityScore),
                escapeCSV(device.ipAddress ?? ""),
                escapeCSV(device.macAddress ?? ""),
                device.lastSeen?.ISO8601Format() ?? ""
            ].joined(separator: ",")
            csv += row + "\n"
        }

        return csv
    }

    // MARK: - Scene Export

    func exportScenesAsJSON(_ scenes: [UnifiedScene]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(scenes)
    }

    func exportScenesAsCSV(_ scenes: [UnifiedScene]) -> String {
        var csv = "Name,Home,Room,Accessory Count,Action Count,Health,Has Unreachable,Unreachable Devices,Last Executed\n"

        for scene in scenes {
            let row = [
                escapeCSV(scene.name),
                escapeCSV(scene.home ?? ""),
                escapeCSV(scene.roomName ?? ""),
                String(scene.accessoryCount),
                String(scene.actionCount),
                escapeCSV(scene.healthStatus.rawValue),
                scene.hasUnreachableDevices ? "Yes" : "No",
                escapeCSV(scene.unreachableDeviceNames.joined(separator: "; ")),
                scene.lastExecuted?.ISO8601Format() ?? ""
            ].joined(separator: ",")
            csv += row + "\n"
        }

        return csv
    }

    // MARK: - Discovered Devices Export

    func exportDiscoveredDevicesAsJSON(_ devices: [DiscoveredDevice]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(devices)
    }

    func exportDiscoveredDevicesAsCSV(_ devices: [DiscoveredDevice]) -> String {
        var csv = "Name,IP Address,MAC Address,Hostname,Discovery Source,Service Type,Manufacturer,Category,Protocol,Open Ports,HomeKit Match,Confidence\n"

        for device in devices {
            let row = [
                escapeCSV(device.name),
                escapeCSV(device.ipAddress ?? ""),
                escapeCSV(device.macAddress ?? ""),
                escapeCSV(device.hostname ?? ""),
                escapeCSV(device.discoverySource.rawValue),
                escapeCSV(device.serviceType ?? ""),
                escapeCSV(device.manufacturer.rawValue),
                escapeCSV(device.deviceType.rawValue),
                escapeCSV(device.protocolType.rawValue),
                escapeCSV(device.openPorts.map { String($0) }.joined(separator: ";")),
                device.homeKitMatch ? "Yes" : "No",
                String(format: "%.0f%%", device.matchConfidence * 100)
            ].joined(separator: ",")
            csv += row + "\n"
        }

        return csv
    }

    // MARK: - Setup Codes Export

    func exportSetupCodesAsJSON(_ codes: [SetupCode]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(codes)
    }

    func exportSetupCodesAsCSV(_ codes: [SetupCode]) -> String {
        var csv = "Device Name,Code,Manufacturer,Category,Room,Serial Number,Model,Notes,Created\n"

        for code in codes {
            let row = [
                escapeCSV(code.deviceName),
                escapeCSV(code.formattedCode),
                escapeCSV(code.manufacturer.rawValue),
                escapeCSV(code.category.rawValue),
                escapeCSV(code.room ?? ""),
                escapeCSV(code.serialNumber ?? ""),
                escapeCSV(code.model ?? ""),
                escapeCSV(code.notes ?? ""),
                code.createdAt.ISO8601Format()
            ].joined(separator: ",")
            csv += row + "\n"
        }

        return csv
    }

    // MARK: - File Saving (macOS)

    #if os(macOS)
    func saveToFile(data: Data, filename: String, fileExtension: String) -> URL? {
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        guard let directory = downloadsURL else { return nil }

        let fileURL = directory.appendingPathComponent("\(filename).\(fileExtension)")

        do {
            try data.write(to: fileURL)
            statusMessage = "Exported to \(fileURL.lastPathComponent)"
            clearStatusMessage()
            return fileURL
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
            clearStatusMessage()
            return nil
        }
    }
    #endif

    // MARK: - Helpers

    private func escapeCSV(_ value: String) -> String {
        var escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            escaped = "\"\(escaped)\""
        }
        return escaped
    }

    private func clearStatusMessage() {
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            statusMessage = ""
        }
    }
}

// MARK: - Export Format

enum ExportFormat: String, CaseIterable {
    case json = "JSON"
    case csv = "CSV"

    var fileExtension: String {
        rawValue.lowercased()
    }

    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .csv: return "text/csv"
        }
    }
}
