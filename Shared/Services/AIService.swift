//
//  AIService.swift
//  HomekitControl
//
//  AI assistant service for smart home insights
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// AI service for smart home insights and assistance
@MainActor
final class AIService: ObservableObject {
    static let shared = AIService()

    // MARK: - Published Properties

    @Published var isProcessing = false
    @Published var messages: [AIMessage] = []
    @Published var selectedProvider: AIProvider = .ollama

    // MARK: - Configuration

    var ollamaEndpoint = "http://192.168.1.100:11434"
    var ollamaModel = "llama3.1"
    var openAIKey: String?
    var claudeKey: String?

    // MARK: - Initialization

    private init() {
        loadConfiguration()
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
        if let provider = UserDefaults.standard.string(forKey: "aiProvider"),
           let aiProvider = AIProvider(rawValue: provider) {
            selectedProvider = aiProvider
        }
    }

    func saveConfiguration() {
        UserDefaults.standard.set(ollamaEndpoint, forKey: "ollamaEndpoint")
        UserDefaults.standard.set(ollamaModel, forKey: "ollamaModel")
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
    case openAI = "OpenAI"
    case claude = "Claude"

    var icon: String {
        switch self {
        case .ollama: return "server.rack"
        case .openAI: return "sparkles"
        case .claude: return "brain"
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
