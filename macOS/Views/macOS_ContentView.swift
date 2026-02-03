//
//  macOS_ContentView.swift
//  HomekitControl
//
//  Main content view for macOS with sidebar navigation
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

enum MacOSSidebarTab: String, CaseIterable, Identifiable {
    case devices = "Devices"
    case codeVault = "Code Vault"
    case network = "Network Scanner"
    case export = "Export"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .devices: return "lightbulb.fill"
        case .codeVault: return "key.fill"
        case .network: return "network"
        case .export: return "square.and.arrow.up"
        case .settings: return "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .devices: return ModernColors.cyan
        case .codeVault: return ModernColors.purple
        case .network: return ModernColors.orange
        case .export: return ModernColors.accentGreen
        case .settings: return ModernColors.textSecondary
        }
    }
}

struct macOS_ContentView: View {
    @State private var selectedTab: MacOSSidebarTab = .devices

    var body: some View {
        ZStack {
            GlassmorphicBackground()
                .ignoresSafeArea()

            NavigationSplitView {
                sidebar
            } detail: {
                mainContent
            }
        }
    }

    private var sidebar: some View {
        List(MacOSSidebarTab.allCases, selection: $selectedTab) { tab in
            Label {
                Text(tab.rawValue)
            } icon: {
                Image(systemName: tab.icon)
                    .foregroundColor(tab.color)
            }
            .tag(tab)
        }
        .listStyle(.sidebar)
        .navigationTitle("HomekitControl")
    }

    @ViewBuilder
    private var mainContent: some View {
        switch selectedTab {
        case .devices:
            macOS_DeviceListView()
        case .codeVault:
            macOS_CodeVaultView()
        case .network:
            macOS_NetworkView()
        case .export:
            macOS_ExportView()
        case .settings:
            macOS_SettingsView()
        }
    }
}

// MARK: - Device List View

struct macOS_DeviceListView: View {
    @StateObject private var homeKitService = HomeKitService.shared
    @State private var searchText = ""
    @State private var showingAddDevice = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Manual Device Inventory")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    showingAddDevice = true
                } label: {
                    Label("Add Device", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color.black.opacity(0.2))

            // Device list
            if homeKitService.manualDevices.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "lightbulb.slash")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text("No Devices")
                        .font(.title2)
                        .foregroundStyle(.white)

                    Text("macOS doesn't have native HomeKit access.\nAdd devices manually to track your inventory.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Add Device") {
                        showingAddDevice = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredDevices) { device in
                        MacDeviceRow(device: device)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            homeKitService.removeManualDevice(filteredDevices[index])
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
        .searchable(text: $searchText)
        .sheet(isPresented: $showingAddDevice) {
            AddDeviceSheet()
        }
    }

    private var filteredDevices: [UnifiedDevice] {
        guard !searchText.isEmpty else { return homeKitService.manualDevices }
        return homeKitService.manualDevices.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Code Vault View

struct macOS_CodeVaultView: View {
    @StateObject private var codeVault = CodeVaultService.shared
    @State private var searchText = ""
    @State private var showingAddCode = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Setup Code Vault")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    showingAddCode = true
                } label: {
                    Label("Add Code", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color.black.opacity(0.2))

            // Code list
            if codeVault.setupCodes.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "key.slash")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text("No Setup Codes")
                        .font(.title2)
                        .foregroundStyle(.white)

                    Text("Store your HomeKit setup codes securely.\nAdd codes to keep them safe.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Add Code") {
                        showingAddCode = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredCodes) { code in
                        MacCodeRow(code: code)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            codeVault.deleteCode(filteredCodes[index])
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
        .searchable(text: $searchText)
        .sheet(isPresented: $showingAddCode) {
            AddCodeSheet()
        }
    }

    private var filteredCodes: [SetupCode] {
        codeVault.search(searchText)
    }
}

// MARK: - Network View

struct macOS_NetworkView: View {
    @StateObject private var networkService = NetworkDiscoveryService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Network Discovery")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    if networkService.isScanning {
                        networkService.stopDiscovery()
                    } else {
                        networkService.startDiscovery()
                    }
                } label: {
                    Label(networkService.isScanning ? "Stop" : "Scan", systemImage: "antenna.radiowaves.left.and.right")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color.black.opacity(0.2))

            // Results
            if networkService.discoveredDevices.isEmpty && !networkService.isScanning {
                VStack(spacing: 20) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text("No Devices Found")
                        .font(.title2)
                        .foregroundStyle(.white)

                    Text("Click Scan to discover devices on your network")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button("Start Scan") {
                        networkService.startDiscovery()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(networkService.discoveredDevices) { device in
                        MacNetworkDeviceRow(device: device)
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
        .overlay {
            if networkService.isScanning && networkService.discoveredDevices.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Scanning network...")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Export View

struct macOS_ExportView: View {
    @StateObject private var exportService = ExportService.shared
    @StateObject private var homeKitService = HomeKitService.shared
    @StateObject private var codeVault = CodeVaultService.shared
    @StateObject private var networkService = NetworkDiscoveryService.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Export Data")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding()
            .background(Color.black.opacity(0.2))

            ScrollView {
                VStack(spacing: 20) {
                    // Devices
                    ExportCard(
                        title: "Devices",
                        icon: "lightbulb.fill",
                        count: homeKitService.manualDevices.count
                    ) { format in
                        exportDevices(format: format)
                    }

                    // Setup Codes
                    ExportCard(
                        title: "Setup Codes",
                        icon: "key.fill",
                        count: codeVault.setupCodes.count
                    ) { format in
                        exportCodes(format: format)
                    }

                    // Network Devices
                    ExportCard(
                        title: "Network Devices",
                        icon: "network",
                        count: networkService.discoveredDevices.count
                    ) { format in
                        exportNetwork(format: format)
                    }
                }
                .padding()
            }
        }
    }

    private func exportDevices(format: ExportFormat) {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "devices_\(timestamp)"
        if format == .json {
            if let data = exportService.exportDevicesAsJSON(homeKitService.manualDevices) {
                _ = exportService.saveToFile(data: data, filename: filename, fileExtension: "json")
            }
        } else {
            let csv = exportService.exportDevicesAsCSV(homeKitService.manualDevices)
            if let data = csv.data(using: .utf8) {
                _ = exportService.saveToFile(data: data, filename: filename, fileExtension: "csv")
            }
        }
    }

    private func exportCodes(format: ExportFormat) {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "setup_codes_\(timestamp)"
        if format == .json {
            if let data = exportService.exportSetupCodesAsJSON(codeVault.setupCodes) {
                _ = exportService.saveToFile(data: data, filename: filename, fileExtension: "json")
            }
        } else {
            let csv = exportService.exportSetupCodesAsCSV(codeVault.setupCodes)
            if let data = csv.data(using: .utf8) {
                _ = exportService.saveToFile(data: data, filename: filename, fileExtension: "csv")
            }
        }
    }

    private func exportNetwork(format: ExportFormat) {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "network_devices_\(timestamp)"
        if format == .json {
            if let data = exportService.exportDiscoveredDevicesAsJSON(networkService.discoveredDevices) {
                _ = exportService.saveToFile(data: data, filename: filename, fileExtension: "json")
            }
        } else {
            let csv = exportService.exportDiscoveredDevicesAsCSV(networkService.discoveredDevices)
            if let data = csv.data(using: .utf8) {
                _ = exportService.saveToFile(data: data, filename: filename, fileExtension: "csv")
            }
        }
    }
}

// MARK: - Settings View

struct macOS_SettingsView: View {
    @StateObject private var aiService = AIService.shared
    @AppStorage("ollamaEndpoint") private var ollamaEndpoint = "http://192.168.1.100:11434"
    @AppStorage("ollamaModel") private var ollamaModel = "llama3.1"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding()
            .background(Color.black.opacity(0.2))

            Form {
                Section("AI Assistant") {
                    Picker("Provider", selection: $aiService.selectedProvider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }

                    if aiService.selectedProvider == .ollama {
                        TextField("Ollama Endpoint", text: $ollamaEndpoint)
                        TextField("Model Name", text: $ollamaModel)
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "1")
                    LabeledContent("Author", value: "Jordan Koch")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }
}

// MARK: - Supporting Views

struct MacDeviceRow: View {
    let device: UnifiedDevice

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: device.category.icon)
                .font(.title2)
                .foregroundStyle(ModernColors.accent)
                .frame(width: 40)

            VStack(alignment: .leading) {
                Text(device.name)
                    .font(.headline)

                Text("\(device.manufacturer.rawValue) • \(device.category.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(device.healthStatus.color)
                .frame(width: 10, height: 10)
        }
        .padding(.vertical, 4)
    }
}

struct MacCodeRow: View {
    let code: SetupCode

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: code.category.icon)
                .font(.title2)
                .foregroundStyle(ModernColors.accent)
                .frame(width: 40)

            VStack(alignment: .leading) {
                Text(code.deviceName)
                    .font(.headline)

                Text(code.formattedCode)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(code.manufacturer.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct MacNetworkDeviceRow: View {
    let device: DiscoveredDevice

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: device.deviceType.icon)
                .font(.title2)
                .foregroundStyle(ModernColors.accent)
                .frame(width: 40)

            VStack(alignment: .leading) {
                Text(device.name)
                    .font(.headline)

                HStack {
                    Text(device.manufacturer.rawValue)
                    if let ip = device.ipAddress {
                        Text("•")
                        Text(ip)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if device.homeKitMatch {
                Label("HomeKit", systemImage: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundStyle(ModernColors.statusLow)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ExportCard: View {
    let title: String
    let icon: String
    let count: Int
    let onExport: (ExportFormat) -> Void

    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(ModernColors.accent)

                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(count) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu("Export") {
                    Button("JSON") { onExport(.json) }
                    Button("CSV") { onExport(.csv) }
                }
                .disabled(count == 0)
            }
            .padding()
        }
    }
}

// MARK: - Sheet Views

struct AddDeviceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var homeKitService = HomeKitService.shared

    @State private var name = ""
    @State private var category: DeviceCategory = .light
    @State private var manufacturer: Manufacturer = .unknown
    @State private var room = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Device")
                .font(.title2)
                .fontWeight(.bold)

            Form {
                TextField("Device Name", text: $name)
                Picker("Category", selection: $category) {
                    ForEach(DeviceCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                Picker("Manufacturer", selection: $manufacturer) {
                    ForEach(Manufacturer.allCases, id: \.self) { mfr in
                        Text(mfr.rawValue).tag(mfr)
                    }
                }
                TextField("Room (optional)", text: $room)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)

                Button("Add") {
                    let device = UnifiedDevice(
                        name: name,
                        room: room.isEmpty ? nil : room,
                        manufacturer: manufacturer,
                        category: category
                    )
                    homeKitService.addManualDevice(device)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
    }
}

struct AddCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var codeVault = CodeVaultService.shared

    @State private var deviceName = ""
    @State private var code = ""
    @State private var category: DeviceCategory = .light
    @State private var manufacturer: Manufacturer = .unknown

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Setup Code")
                .font(.title2)
                .fontWeight(.bold)

            Form {
                TextField("Device Name", text: $deviceName)
                TextField("Setup Code (8 digits)", text: $code)
                Picker("Category", selection: $category) {
                    ForEach(DeviceCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                Picker("Manufacturer", selection: $manufacturer) {
                    ForEach(Manufacturer.allCases, id: \.self) { mfr in
                        Text(mfr.rawValue).tag(mfr)
                    }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)

                Button("Add") {
                    let setupCode = SetupCode(
                        deviceName: deviceName,
                        code: code,
                        manufacturer: manufacturer,
                        category: category
                    )
                    codeVault.addCode(setupCode)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(deviceName.isEmpty || code.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
    }
}

#Preview {
    macOS_ContentView()
}
