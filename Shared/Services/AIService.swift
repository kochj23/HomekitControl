//
//  AIService.swift
//  HomekitControl
//
//  AI assistant service for smart home insights
//  Supports: Ollama, TinyLLM, TinyChat, OpenWebUI, OpenAI, Claude
//
//  Author: Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//
//  THIRD-PARTY INTEGRATIONS:
//  - TinyLLM by Jason Cox (https://github.com/jasonacox/TinyLLM)
//  - TinyChat by Jason Cox (https://github.com/jasonacox/tinychat)
//  - OpenWebUI Community (https://github.com/open-webui/open-webui)
//

import Foundation
import SwiftUI

/// AI service for smart home insights and assistance
@MainActor
final class AIService: ObservableObject {
    static let shared = AIService()

    // MARK: - Published Properties

    @Published var isProcessing = false
    @Published var messages: [AIMessage] = []
    @Published var selectedProvider: AIProvider = .ollama

    // Backend availability
    @Published var isOllamaAvailable = false
    @Published var isTinyLLMAvailable = false
    @Published var isTinyChatAvailable = false
    @Published var isOpenWebUIAvailable = false

    // MARK: - Configuration

    var ollamaEndpoint = "http://192.168.1.100:11434"
    var ollamaModel = "llama3.1"
    var tinyLLMEndpoint = "http://localhost:8000"
    var tinyChatEndpoint = "http://localhost:8000"
    var openWebUIEndpoint = "http://localhost:8080"
    var openAIKey: String?
    var claudeKey: String?

    // MARK: - Initialization

    private init() {
        loadConfiguration()
        Task {
            await checkBackendAvailability()
        }
    }

    // MARK: - Backend Availability

    func checkBackendAvailability() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.checkOllama() }
            group.addTask { await self.checkTinyLLM() }
            group.addTask { await self.checkTinyChat() }
            group.addTask { await self.checkOpenWebUI() }
        }
    }

    private func checkOllama() async {
        guard let url = URL(string: "\(ollamaEndpoint)/api/tags") else {
            isOllamaAvailable = false
            return
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                isOllamaAvailable = true
            } else {
                isOllamaAvailable = false
            }
        } catch {
            isOllamaAvailable = false
        }
    }

    private func checkTinyLLM() async {
        guard let url = URL(string: "\(tinyLLMEndpoint)/v1/models") else {
            isTinyLLMAvailable = false
            return
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                isTinyLLMAvailable = true
            } else {
                isTinyLLMAvailable = false
            }
        } catch {
            isTinyLLMAvailable = false
        }
    }

    private func checkTinyChat() async {
        guard let url = URL(string: "\(tinyChatEndpoint)/api/health") else {
            isTinyChatAvailable = false
            return
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                isTinyChatAvailable = true
            } else {
                isTinyChatAvailable = false
            }
        } catch {
            isTinyChatAvailable = false
        }
    }

    private func checkOpenWebUI() async {
        guard let url = URL(string: "\(openWebUIEndpoint)/api/models") else {
            isOpenWebUIAvailable = false
            return
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                isOpenWebUIAvailable = true
            } else {
                isOpenWebUIAvailable = false
            }
        } catch {
            isOpenWebUIAvailable = false
        }
    }

    // MARK: - Chat

    func sendMessage(_ text: String) async {
        guard !text.isEmpty else { return }

        let userMessage = AIMessage(role: .user, content: text)
        messages.append(userMessage)

        isProcessing = true

        do {
            let response = try await generateResponse(for: text)
            let assistantMessage = AIMessage(role: .assistant, content: response)
            messages.append(assistantMessage)
        } catch {
            let errorMessage = AIMessage(role: .assistant, content: "Error: \(error.localizedDescription)")
            messages.append(errorMessage)
        }

        isProcessing = false
    }

    func clearChat() {
        messages.removeAll()
    }

    // MARK: - Analysis Helpers

    func analyzeDevice(_ device: UnifiedDevice) async -> String {
        let prompt = """
        Analyze this smart home device:
        - Name: \(device.name)
        - Manufacturer: \(device.manufacturer.rawValue)
        - Category: \(device.category.rawValue)
        - Health: \(device.healthStatus.rawValue)
        - Reliability: \(device.reliabilityScore)%
        - Protocol: \(device.protocolType.rawValue)

        Provide insights about this device's performance and any recommendations.
        """

        isProcessing = true
        defer { isProcessing = false }

        do {
            return try await generateResponse(for: prompt)
        } catch {
            return "Unable to analyze device: \(error.localizedDescription)"
        }
    }

    func analyzeScene(_ scene: UnifiedScene) async -> String {
        let prompt = """
        Analyze this HomeKit scene:
        - Name: \(scene.name)
        - Accessories: \(scene.accessoryCount)
        - Has unreachable devices: \(scene.hasUnreachableDevices)
        - Unreachable devices: \(scene.unreachableDeviceNames.joined(separator: ", "))
        - Health: \(scene.healthStatus.rawValue)

        Provide recommendations for improving this scene's reliability.
        """

        isProcessing = true
        defer { isProcessing = false }

        do {
            return try await generateResponse(for: prompt)
        } catch {
            return "Unable to analyze scene: \(error.localizedDescription)"
        }
    }

    // MARK: - Quick Response

    func getResponse(_ query: String) async -> String {
        isProcessing = true
        defer { isProcessing = false }

        do {
            return try await generateResponse(for: query)
        } catch {
            return "I couldn't process that request: \(error.localizedDescription)"
        }
    }

    // MARK: - Network Analysis

    func analyzeNetwork(_ devices: [DiscoveredDevice]) async -> String {
        let deviceList = devices.map { "\($0.name) - \($0.manufacturer.rawValue) - \($0.protocolType.rawValue)" }.joined(separator: "\n")

        let prompt = """
        Analyze this smart home network:
        Total devices: \(devices.count)

        Devices:
        \(deviceList)

        Provide insights about:
        1. Network security considerations
        2. Device organization recommendations
        3. Protocol diversity and potential issues
        """

        isProcessing = true
        defer { isProcessing = false }

        do {
            return try await generateResponse(for: prompt)
        } catch {
            return "Unable to analyze network: \(error.localizedDescription)"
        }
    }

    // MARK: - Private Methods

    private func generateResponse(for prompt: String) async throws -> String {
        switch selectedProvider {
        case .ollama:
            return try await callOllama(prompt: prompt)
        case .tinyLLM:
            return try await callTinyLLM(prompt: prompt)
        case .tinyChat:
            return try await callTinyChat(prompt: prompt)
        case .openWebUI:
            return try await callOpenWebUI(prompt: prompt)
        case .openAI:
            return try await callOpenAI(prompt: prompt)
        case .claude:
            return try await callClaude(prompt: prompt)
        }
    }

    private func callOllama(prompt: String) async throws -> String {
        guard let url = URL(string: "\(ollamaEndpoint)/api/generate") else {
            throw AIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": ollamaModel,
            "prompt": prompt,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = json["response"] as? String else {
            throw AIError.invalidResponse
        }

        return response
    }

    // MARK: - TinyLLM Implementation
    // TinyLLM by Jason Cox: https://github.com/jasonacox/TinyLLM

    private func callTinyLLM(prompt: String) async throws -> String {
        guard let url = URL(string: "\(tinyLLMEndpoint)/v1/chat/completions") else {
            throw AIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let messages: [[String: String]] = [
            ["role": "system", "content": "You are a helpful smart home assistant."],
            ["role": "user", "content": prompt]
        ]

        let body: [String: Any] = [
            "messages": messages,
            "max_tokens": 1024,
            "temperature": 0.7,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        struct TinyLLMResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let response = try JSONDecoder().decode(TinyLLMResponse.self, from: data)
        return response.choices.first?.message.content ?? ""
    }

    // MARK: - TinyChat Implementation
    // TinyChat by Jason Cox: https://github.com/jasonacox/tinychat

    private func callTinyChat(prompt: String) async throws -> String {
        guard let url = URL(string: "\(tinyChatEndpoint)/api/chat/stream") else {
            throw AIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let messages: [[String: String]] = [
            ["role": "system", "content": "You are a helpful smart home assistant."],
            ["role": "user", "content": prompt]
        ]

        let body: [String: Any] = [
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 1024,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        struct TinyChatResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let response = try JSONDecoder().decode(TinyChatResponse.self, from: data)
        return response.choices.first?.message.content ?? ""
    }

    // MARK: - OpenWebUI Implementation
    // OpenWebUI: https://github.com/open-webui/open-webui

    private func callOpenWebUI(prompt: String) async throws -> String {
        guard let url = URL(string: "\(openWebUIEndpoint)/api/chat/completions") else {
            throw AIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let messages: [[String: String]] = [
            ["role": "system", "content": "You are a helpful smart home assistant."],
            ["role": "user", "content": prompt]
        ]

        let body: [String: Any] = [
            "messages": messages,
            "max_tokens": 1024,
            "temperature": 0.7,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        struct OpenWebUIResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let response = try JSONDecoder().decode(OpenWebUIResponse.self, from: data)
        return response.choices.first?.message.content ?? ""
    }

    private func callOpenAI(prompt: String) async throws -> String {
        guard let apiKey = openAIKey else {
            throw AIError.missingAPIKey
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "You are a helpful smart home assistant."],
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.invalidResponse
        }

        return content
    }

    private func callClaude(prompt: String) async throws -> String {
        guard let apiKey = claudeKey else {
            throw AIError.missingAPIKey
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 1024,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw AIError.invalidResponse
        }

        return text
    }

    // MARK: - Configuration

    private func loadConfiguration() {
        if let endpoint = UserDefaults.standard.string(forKey: "ollamaEndpoint") {
            ollamaEndpoint = endpoint
        }
        if let model = UserDefaults.standard.string(forKey: "ollamaModel") {
            ollamaModel = model
        }
        if let tinyLLM = UserDefaults.standard.string(forKey: "tinyLLMEndpoint") {
            tinyLLMEndpoint = tinyLLM
        }
        if let tinyChat = UserDefaults.standard.string(forKey: "tinyChatEndpoint") {
            tinyChatEndpoint = tinyChat
        }
        if let openWebUI = UserDefaults.standard.string(forKey: "openWebUIEndpoint") {
            openWebUIEndpoint = openWebUI
        }
        if let provider = UserDefaults.standard.string(forKey: "aiProvider"),
           let aiProvider = AIProvider(rawValue: provider) {
            selectedProvider = aiProvider
        }
    }

    func saveConfiguration() {
        UserDefaults.standard.set(ollamaEndpoint, forKey: "ollamaEndpoint")
        UserDefaults.standard.set(ollamaModel, forKey: "ollamaModel")
        UserDefaults.standard.set(tinyLLMEndpoint, forKey: "tinyLLMEndpoint")
        UserDefaults.standard.set(tinyChatEndpoint, forKey: "tinyChatEndpoint")
        UserDefaults.standard.set(openWebUIEndpoint, forKey: "openWebUIEndpoint")
        UserDefaults.standard.set(selectedProvider.rawValue, forKey: "aiProvider")
    }
}

// MARK: - Supporting Types

struct AIMessage: Identifiable, Equatable {
    let id = UUID()
    let role: AIRole
    let content: String
    let timestamp = Date()
}

enum AIRole: String, Codable {
    case user
    case assistant
    case system
}

enum AIProvider: String, CaseIterable {
    case ollama = "Ollama"
    case tinyLLM = "TinyLLM"
    case tinyChat = "TinyChat"
    case openWebUI = "OpenWebUI"
    case openAI = "OpenAI"
    case claude = "Claude"

    var icon: String {
        switch self {
        case .ollama: return "server.rack"
        case .tinyLLM: return "cube"
        case .tinyChat: return "bubble.left.and.bubble.right.fill"
        case .openWebUI: return "globe"
        case .openAI: return "sparkles"
        case .claude: return "brain"
        }
    }

    var description: String {
        switch self {
        case .ollama: return "Local Ollama server"
        case .tinyLLM: return "TinyLLM by Jason Cox"
        case .tinyChat: return "TinyChat by Jason Cox"
        case .openWebUI: return "OpenWebUI self-hosted platform"
        case .openAI: return "OpenAI GPT-4"
        case .claude: return "Anthropic Claude"
        }
    }

    var attribution: String? {
        switch self {
        case .tinyLLM: return "https://github.com/jasonacox/TinyLLM"
        case .tinyChat: return "https://github.com/jasonacox/tinychat"
        case .openWebUI: return "https://github.com/open-webui/open-webui"
        default: return nil
        }
    }
}

enum AIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case missingAPIKey
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .invalidResponse: return "Invalid response from AI service"
        case .missingAPIKey: return "API key not configured"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Settings View

struct AISettingsView: View {
    @ObservedObject var aiService = AIService.shared
    @State private var isChecking = false

    var body: some View {
        Form {
            Section(header: Text("AI Provider")) {
                Picker("Provider", selection: $aiService.selectedProvider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        HStack {
                            Image(systemName: provider.icon)
                            Text(provider.rawValue)
                        }
                        .tag(provider)
                    }
                }
                .onChange(of: aiService.selectedProvider) { _ in
                    aiService.saveConfiguration()
                }

                Text(aiService.selectedProvider.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Backend Status")) {
                StatusRow(name: "Ollama", icon: "server.rack", isAvailable: aiService.isOllamaAvailable)
                StatusRow(name: "TinyLLM", icon: "cube", isAvailable: aiService.isTinyLLMAvailable)
                StatusRow(name: "TinyChat", icon: "bubble.left.and.bubble.right.fill", isAvailable: aiService.isTinyChatAvailable)
                StatusRow(name: "OpenWebUI", icon: "globe", isAvailable: aiService.isOpenWebUIAvailable)

                Button("Refresh Status") {
                    isChecking = true
                    Task {
                        await aiService.checkBackendAvailability()
                        isChecking = false
                    }
                }
                .disabled(isChecking)
            }

            Section(header: Text("Local Servers")) {
                TextField("Ollama URL", text: $aiService.ollamaEndpoint)
                    .onChange(of: aiService.ollamaEndpoint) { _ in aiService.saveConfiguration() }

                TextField("Ollama Model", text: $aiService.ollamaModel)
                    .onChange(of: aiService.ollamaModel) { _ in aiService.saveConfiguration() }

                TextField("TinyLLM URL", text: $aiService.tinyLLMEndpoint)
                    .onChange(of: aiService.tinyLLMEndpoint) { _ in aiService.saveConfiguration() }

                TextField("TinyChat URL", text: $aiService.tinyChatEndpoint)
                    .onChange(of: aiService.tinyChatEndpoint) { _ in aiService.saveConfiguration() }

                TextField("OpenWebUI URL", text: $aiService.openWebUIEndpoint)
                    .onChange(of: aiService.openWebUIEndpoint) { _ in aiService.saveConfiguration() }
            }

            Section(header: Text("Credits")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Third-Party Integrations:")
                        .font(.headline)

                    Link("TinyLLM by Jason Cox", destination: URL(string: "https://github.com/jasonacox/TinyLLM")!)
                    Link("TinyChat by Jason Cox", destination: URL(string: "https://github.com/jasonacox/tinychat")!)
                    Link("OpenWebUI Community", destination: URL(string: "https://github.com/open-webui/open-webui")!)
                }
                .font(.caption)
            }
        }
    }
}

private struct StatusRow: View {
    let name: String
    let icon: String
    let isAvailable: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(name)
            Spacer()
            Text(isAvailable ? "Available" : "Unavailable")
                .foregroundColor(isAvailable ? .green : .secondary)
        }
    }
}
