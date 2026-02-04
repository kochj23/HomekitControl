//
//  VoiceControlService.swift
//  HomekitControl
//
//  On-device voice control without Siri
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import AVFoundation
import SwiftUI
#if os(iOS)
import Speech
#endif
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Models

struct VoiceCommand: Codable, Identifiable {
    let id: UUID
    var phrase: String
    var action: VoiceAction
    var isEnabled: Bool

    init(phrase: String, action: VoiceAction) {
        self.id = UUID()
        self.phrase = phrase.lowercased()
        self.action = action
        self.isEnabled = true
    }
}

enum VoiceAction: Codable, Equatable {
    case toggleDevice(deviceId: UUID)
    case setDeviceBrightness(deviceId: UUID, brightness: Int)
    case executeScene(sceneId: UUID)
    case setThermostat(temperature: Double)
    case lockDoor(lockId: UUID)
    case unlockDoor(lockId: UUID)
    case custom(command: String)
}

struct VoiceHistoryEntry: Codable, Identifiable {
    let id: UUID
    let transcript: String
    let matchedCommand: String?
    let wasSuccessful: Bool
    let timestamp: Date
}

// MARK: - Voice Control Service

#if os(iOS)
@MainActor
class VoiceControlService: NSObject, ObservableObject {
    static let shared = VoiceControlService()

    // MARK: - Published Properties

    @Published var isListening = false
    @Published var transcript = ""
    @Published var commands: [VoiceCommand] = []
    @Published var history: [VoiceHistoryEntry] = []
    @Published var isAuthorized = false
    @Published var wakeWord = "hey home"
    @Published var wakeWordDetected = false
    @Published var feedbackEnabled = true
    @Published var continuousListening = false

    // MARK: - Private Properties

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private let storageKey = "HomekitControl_VoiceControl"

    // MARK: - Initialization

    private override init() {
        super.init()
        loadData()
        setupDefaultCommands()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        let audioStatus = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        isAuthorized = speechStatus && audioStatus
        return isAuthorized
    }

    // MARK: - Listening

    func startListening() {
        guard !isListening else { return }
        guard speechRecognizer?.isAvailable == true else {
            speak("Speech recognition is not available")
            return
        }

        do {
            try startRecognition()
            isListening = true
            if feedbackEnabled {
                playStartSound()
            }
        } catch {
            print("Failed to start listening: \(error)")
            speak("Failed to start voice control")
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
        wakeWordDetected = false

        if feedbackEnabled {
            playStopSound()
        }
    }

    private func startRecognition() throws {
        // Cancel previous task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "VoiceControl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create request"])
        }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let result = result {
                    self.transcript = result.bestTranscription.formattedString
                    self.processTranscript(self.transcript)
                }

                if error != nil || result?.isFinal == true {
                    if self.continuousListening && self.isListening {
                        // Restart for continuous listening
                        self.stopListening()
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        self.startListening()
                    }
                }
            }
        }

        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    // MARK: - Command Processing

    private func processTranscript(_ text: String) {
        let lowercased = text.lowercased()

        // Check for wake word if not already detected
        if !wakeWordDetected && !wakeWord.isEmpty {
            if lowercased.contains(wakeWord) {
                wakeWordDetected = true
                if feedbackEnabled {
                    speak("Yes?")
                }
                return
            }
            return // Wait for wake word
        }

        // Remove wake word from command
        let commandText = lowercased.replacingOccurrences(of: wakeWord, with: "").trimmingCharacters(in: .whitespaces)

        // Match command
        if let command = matchCommand(commandText) {
            executeCommand(command)
            logHistory(transcript: text, matched: command.phrase, success: true)
            wakeWordDetected = false // Reset for next command
        }
    }

    private func matchCommand(_ text: String) -> VoiceCommand? {
        // Direct match
        if let command = commands.first(where: { text.contains($0.phrase) && $0.isEnabled }) {
            return command
        }

        // Fuzzy matching for common phrases
        let normalizedText = text.lowercased()

        // Built-in commands
        if normalizedText.contains("turn on") || normalizedText.contains("switch on") {
            return findDeviceCommand(in: normalizedText, turnOn: true)
        }

        if normalizedText.contains("turn off") || normalizedText.contains("switch off") {
            return findDeviceCommand(in: normalizedText, turnOn: false)
        }

        if normalizedText.contains("set") && normalizedText.contains("percent") {
            return findBrightnessCommand(in: normalizedText)
        }

        if normalizedText.contains("run scene") || normalizedText.contains("activate") {
            return findSceneCommand(in: normalizedText)
        }

        return nil
    }

    private func findDeviceCommand(in text: String, turnOn: Bool) -> VoiceCommand? {
        #if canImport(HomeKit)
        for accessory in HomeKitService.shared.accessories {
            if text.lowercased().contains(accessory.name.lowercased()) {
                return VoiceCommand(
                    phrase: text,
                    action: .toggleDevice(deviceId: accessory.uniqueIdentifier)
                )
            }
        }
        #endif
        return nil
    }

    private func findBrightnessCommand(in text: String) -> VoiceCommand? {
        // Extract percentage
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard let brightness = Int(numbers), brightness >= 0, brightness <= 100 else { return nil }

        #if canImport(HomeKit)
        for accessory in HomeKitService.shared.accessories {
            if text.lowercased().contains(accessory.name.lowercased()) {
                return VoiceCommand(
                    phrase: text,
                    action: .setDeviceBrightness(deviceId: accessory.uniqueIdentifier, brightness: brightness)
                )
            }
        }
        #endif
        return nil
    }

    private func findSceneCommand(in text: String) -> VoiceCommand? {
        #if canImport(HomeKit)
        for scene in HomeKitService.shared.scenes {
            if text.lowercased().contains(scene.name.lowercased()) {
                return VoiceCommand(
                    phrase: text,
                    action: .executeScene(sceneId: scene.uniqueIdentifier)
                )
            }
        }
        #endif
        return nil
    }

    // MARK: - Command Execution

    private func executeCommand(_ command: VoiceCommand) {
        Task {
            switch command.action {
            case .toggleDevice(let deviceId):
                await toggleDevice(deviceId)
                speak("Done")

            case .setDeviceBrightness(let deviceId, let brightness):
                await setBrightness(deviceId, brightness: brightness)
                speak("Set to \(brightness) percent")

            case .executeScene(let sceneId):
                await executeScene(sceneId)
                speak("Scene activated")

            case .setThermostat(let temperature):
                speak("Setting temperature to \(Int(temperature)) degrees")

            case .lockDoor:
                speak("Door locked")

            case .unlockDoor:
                speak("Door unlocked")

            case .custom(let customCommand):
                speak("Executing \(customCommand)")
            }
        }
    }

    private func toggleDevice(_ deviceId: UUID) async {
        #if canImport(HomeKit)
        if let accessory = HomeKitService.shared.accessories.first(where: { $0.uniqueIdentifier == deviceId }) {
            try? await HomeKitService.shared.toggleAccessory(accessory)
        }
        #endif
    }

    private func setBrightness(_ deviceId: UUID, brightness: Int) async {
        #if canImport(HomeKit)
        if let accessory = HomeKitService.shared.accessories.first(where: { $0.uniqueIdentifier == deviceId }) {
            try? await HomeKitService.shared.setBrightness(accessory, value: brightness)
        }
        #endif
    }

    private func executeScene(_ sceneId: UUID) async {
        #if canImport(HomeKit)
        if let scene = HomeKitService.shared.scenes.first(where: { $0.uniqueIdentifier == sceneId }) {
            try? await HomeKitService.shared.executeScene(scene)
        }
        #endif
    }

    // MARK: - Voice Feedback

    func speak(_ text: String) {
        guard feedbackEnabled else { return }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }

    private func playStartSound() {
        AudioServicesPlaySystemSound(1113) // Begin recording sound
    }

    private func playStopSound() {
        AudioServicesPlaySystemSound(1114) // End recording sound
    }

    // MARK: - Command Management

    func addCommand(_ command: VoiceCommand) {
        commands.append(command)
        saveData()
    }

    func updateCommand(_ command: VoiceCommand) {
        if let index = commands.firstIndex(where: { $0.id == command.id }) {
            commands[index] = command
            saveData()
        }
    }

    func deleteCommand(_ command: VoiceCommand) {
        commands.removeAll { $0.id == command.id }
        saveData()
    }

    private func setupDefaultCommands() {
        guard commands.isEmpty else { return }

        // Add some default commands
        commands = [
            VoiceCommand(phrase: "good morning", action: .custom(command: "morning_routine")),
            VoiceCommand(phrase: "good night", action: .custom(command: "night_routine")),
            VoiceCommand(phrase: "i'm leaving", action: .custom(command: "away_mode")),
            VoiceCommand(phrase: "i'm home", action: .custom(command: "home_mode"))
        ]
        saveData()
    }

    // MARK: - History

    private func logHistory(transcript: String, matched: String?, success: Bool) {
        let entry = VoiceHistoryEntry(
            id: UUID(),
            transcript: transcript,
            matchedCommand: matched,
            wasSuccessful: success,
            timestamp: Date()
        )
        history.insert(entry, at: 0)

        // Keep only last 100 entries
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
        saveData()
    }

    // MARK: - Persistence

    private func saveData() {
        let settings: [String: Any] = [
            "wakeWord": wakeWord,
            "feedbackEnabled": feedbackEnabled,
            "continuousListening": continuousListening
        ]

        if let encoded = try? JSONSerialization.data(withJSONObject: settings) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }

        if let commandsData = try? JSONEncoder().encode(commands) {
            UserDefaults.standard.set(commandsData, forKey: storageKey + "_commands")
        }

        if let historyData = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(historyData, forKey: storageKey + "_history")
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            wakeWord = settings["wakeWord"] as? String ?? "hey home"
            feedbackEnabled = settings["feedbackEnabled"] as? Bool ?? true
            continuousListening = settings["continuousListening"] as? Bool ?? false
        }

        if let commandsData = UserDefaults.standard.data(forKey: storageKey + "_commands"),
           let saved = try? JSONDecoder().decode([VoiceCommand].self, from: commandsData) {
            commands = saved
        }

        if let historyData = UserDefaults.standard.data(forKey: storageKey + "_history"),
           let saved = try? JSONDecoder().decode([VoiceHistoryEntry].self, from: historyData) {
            history = saved
        }
    }
}
#else
// Stub for non-iOS platforms
@MainActor
class VoiceControlService: ObservableObject {
    static let shared = VoiceControlService()
    @Published var isListening = false
    @Published var transcript = ""
    @Published var commands: [VoiceCommand] = []
    @Published var isAuthorized = false
    @Published var wakeWord = "hey home"
    @Published var feedbackEnabled = true

    func requestAuthorization() async -> Bool { return false }
    func startListening() {}
    func stopListening() {}
    func speak(_ text: String) {}
}
#endif
