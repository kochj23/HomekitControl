//
//  HomeAIAssistant.swift
//  HomekitControl
//
//  The smart home assistant (iOS chat, macOS chat, tvOS quick questions) on NovaAIKit. Each request carries a
//  summary of the home (devices, reachability, rooms, scenes). When AI is off, every backend is down, or the reply
//  is rejected, the assistant answers from that same home data with built-in replies. Each answer records its
//  source so the UI can show "AI · <backend>" or "Built-in".
//
//  Author: Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import NovaAIKit

@MainActor
final class HomeAIAssistant: ObservableObject {
    static let shared = HomeAIAssistant()

    @Published var isProcessing = false
    @Published var messages: [AIMessage] = []

    let ai: NovaAI
    /// Supplies the current home summary (injectable for tests).
    var snapshotProvider: @MainActor () -> HomeSnapshot

    init(ai: NovaAI? = nil, snapshotProvider: (@MainActor () -> HomeSnapshot)? = nil) {
        self.ai = ai ?? AppAI.shared
        self.snapshotProvider = snapshotProvider ?? { HomeSnapshot.current() }
    }

    nonisolated static let systemPrompt = """
    You are HomekitControl's smart home assistant. Answer questions about the user's home using the HOME DATA \
    provided. Be concise and specific; name devices, rooms and scenes when relevant. If the data does not contain \
    the answer, say so instead of guessing.
    """
    nonisolated static let maxInput = 1000
    nonisolated static let maxReply = 4000
    nonisolated static let historyLimit = 12

    // MARK: - Chat

    /// Adds the user's message and the assistant's answer (AI or built-in) to the transcript.
    func sendMessage(_ text: String) async {
        let question = Self.sanitizedInput(text)
        guard !question.isEmpty else { return }
        messages.append(AIMessage(role: .user, content: question))
        isProcessing = true
        defer { isProcessing = false }

        let snapshot = snapshotProvider()
        var history: [NovaAIMessage] = [.system(Self.systemPrompt + "\n\nHOME DATA:\n" + snapshot.contextText)]
        for m in messages.suffix(Self.historyLimit) {
            history.append(m.role == .user ? .user(m.content) : .assistant(m.content))
        }
        let fallback = Self.builtInAnswer(question, snapshot: snapshot, aiEnabled: ai.isEnabled)
        let result = await ai.text(NovaAIRequest(messages: history, temperature: 0.5, maxTokens: 700),
                                   validate: Self.validateReply) { fallback }
        messages.append(AIMessage(role: .assistant, content: result.value, source: result.source))
    }

    /// One-shot answer (tvOS quick questions): no transcript.
    func answer(_ question: String) async -> NovaAIResult<String> {
        let q = Self.sanitizedInput(question)
        let snapshot = snapshotProvider()
        let fallback = Self.builtInAnswer(q, snapshot: snapshot, aiEnabled: ai.isEnabled)
        guard !q.isEmpty else { return NovaAIResult(value: fallback, source: .fallback(.unavailable("empty question"))) }
        isProcessing = true
        defer { isProcessing = false }
        let request = NovaAIRequest(prompt: q, system: Self.systemPrompt + "\n\nHOME DATA:\n" + snapshot.contextText,
                                    temperature: 0.5, maxTokens: 500)
        return await ai.text(request, validate: Self.validateReply) { fallback }
    }

    func clearChat() {
        messages.removeAll()
    }
}

// MARK: - Validation and built-in answers (pure, testable)

extension HomeAIAssistant {
    /// Trimmed, control characters removed (newlines kept), capped.
    nonisolated static func sanitizedInput(_ s: String) -> String {
        let scalars = s.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) || $0 == "\n" }
        let t = String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespacesAndNewlines)
        return String(t.prefix(maxInput))
    }

    /// Replies must be non-empty, are stripped of control characters and capped.
    nonisolated static let validateReply: @Sendable (String) throws -> String = { raw in
        let t = try NovaAI.nonEmpty(raw)
        let scalars = t.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) || $0 == "\n" || $0 == "\t" }
        let clean = String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else { throw NovaAIValidationError("reply too short") }
        return String(clean.prefix(maxReply))
    }

    /// Answers common questions from the home data alone.
    nonisolated static func builtInAnswer(_ question: String, snapshot s: HomeSnapshot, aiEnabled: Bool) -> String {
        let q = question.lowercased()
        let unreachable = s.devices.filter { !$0.reachable }
        func list(_ items: [String], max: Int = 12) -> String {
            let shown = items.prefix(max).joined(separator: ", ")
            return items.count > max ? "\(shown) and \(items.count - max) more" : shown
        }
        let body: String
        if s.devices.isEmpty && s.scenes.isEmpty {
            body = "No devices or scenes are loaded yet. Add devices (or allow HomeKit access) and ask again."
        } else if q.contains("scene") {
            body = s.scenes.isEmpty ? "You have no scenes." : "You have \(s.scenes.count) scene\(s.scenes.count == 1 ? "" : "s"): \(list(s.scenes))."
        } else if q.contains("room") {
            let rooms = Dictionary(grouping: s.devices, by: { $0.room ?? "No room" })
                .map { "\($0.key) (\($0.value.count))" }.sorted()
            body = rooms.isEmpty ? "No rooms with devices." : "Devices by room: \(list(rooms))."
        } else if q.contains("issue") || q.contains("problem") || q.contains("offline") || q.contains("unreachable")
                    || q.contains("health") || q.contains("wrong") {
            body = unreachable.isEmpty
                ? "No issues found: all \(s.devices.count) devices are reachable."
                : "\(unreachable.count) of \(s.devices.count) devices are unreachable: \(list(unreachable.map(\.name))). Check their power and network connection."
        } else if q.contains("online") || q.contains("how many") || q.contains("device") {
            body = "\(s.devices.count - unreachable.count) of \(s.devices.count) devices are reachable."
                + (unreachable.isEmpty ? "" : " Unreachable: \(list(unreachable.map(\.name))).")
        } else if q.contains("energy") || q.contains("power") {
            body = "Open Energy Monitor for usage estimates per device. \(s.devices.count) devices are tracked."
        } else if q.contains("secur") {
            body = "Security checklist: keep hubs and devices on current firmware, put IoT devices on their own network or VLAN, "
                + "use unique Wi-Fi and account passwords, remove unused devices and guest access, and review automations that unlock doors."
        } else {
            body = s.summary
        }
        let note = aiEnabled ? "" : " (AI is off: built-in answer.)"
        return body + note
    }
}

// MARK: - Home snapshot

/// What the assistant knows about the home (names and states only; no setup codes or credentials).
struct HomeSnapshot: Sendable, Equatable {
    struct Device: Sendable, Equatable {
        var name: String
        var room: String?
        var category: String
        var reachable: Bool
    }

    var homeName: String?
    var devices: [Device] = []
    var rooms: [String] = []
    var scenes: [String] = []

    static let maxDevicesInContext = 150

    var summary: String {
        let reachable = devices.filter(\.reachable).count
        var parts = ["\(homeName ?? "Your home") has \(devices.count) device\(devices.count == 1 ? "" : "s") (\(reachable) reachable)"]
        if !rooms.isEmpty { parts.append("\(rooms.count) room\(rooms.count == 1 ? "" : "s")") }
        parts.append("\(scenes.count) scene\(scenes.count == 1 ? "" : "s")")
        return parts.joined(separator: ", ") + "."
    }

    /// Compact text for the AI prompt.
    var contextText: String {
        var lines = [summary]
        if !rooms.isEmpty { lines.append("Rooms: " + rooms.joined(separator: ", ")) }
        if !scenes.isEmpty { lines.append("Scenes: " + scenes.joined(separator: ", ")) }
        lines.append("Devices (name | room | category | status):")
        for d in devices.prefix(Self.maxDevicesInContext) {
            lines.append("- \(d.name) | \(d.room ?? "-") | \(d.category) | \(d.reachable ? "reachable" : "UNREACHABLE")")
        }
        if devices.count > Self.maxDevicesInContext { lines.append("(\(devices.count - Self.maxDevicesInContext) more devices not listed)") }
        return lines.joined(separator: "\n")
    }

    @MainActor
    static func current() -> HomeSnapshot {
        let service = HomeKitService.shared
        #if canImport(HomeKit)
        return HomeSnapshot(
            homeName: service.currentHome?.name,
            devices: service.accessories.map {
                Device(name: $0.name, room: $0.room?.name, category: $0.category.localizedDescription, reachable: $0.isReachable)
            },
            rooms: service.rooms.map(\.name),
            scenes: service.scenes.map(\.name))
        #else
        let devices = service.manualDevices.map {
            Device(name: $0.name, room: $0.room, category: $0.category.rawValue, reachable: $0.isReachable)
        }
        return HomeSnapshot(homeName: nil, devices: devices,
                            rooms: Array(Set(devices.compactMap(\.room))).sorted(), scenes: [])
        #endif
    }
}

// MARK: - Transcript

struct AIMessage: Identifiable, Equatable {
    let id = UUID()
    let role: AIRole
    let content: String
    let timestamp = Date()
    /// Where an assistant message came from (nil for user messages).
    var source: NovaAISource?
}

enum AIRole: String, Codable {
    case user
    case assistant
    case system
}
