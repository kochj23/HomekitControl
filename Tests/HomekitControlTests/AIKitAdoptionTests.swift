//
//  AIKitAdoptionTests.swift
//  HomekitControlTests
//
//  HomekitControl's AI contract on NovaAIKit 1.0.0, in the 7 test categories (security, performance, retry, unit,
//  integration, functional, frame/UI state). In-memory settings/keys and a stub URLProtocol only: nothing touches
//  the real Keychain or the network.
//
//  Author: Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
import SwiftUI
import NovaAIKit
@testable import HomekitControl

// MARK: - Support

/// Canned replies; records what was sent. Unhandled requests fail as "cannot connect".
final class AIStubProtocol: URLProtocol, @unchecked Sendable {
    struct Seen { let url: URL; let headers: [String: String]; let body: String }
    enum Reply { case ollama(String), status(Int), fail }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: ((Seen, Int) -> Reply)?
    nonisolated(unsafe) private static var log: [Seen] = []

    static func respond(_ h: @escaping (Seen, Int) -> Reply) { lock.lock(); handler = h; log = []; lock.unlock() }
    static func reset() { lock.lock(); handler = nil; log = []; lock.unlock() }
    static var seen: [Seen] { lock.lock(); defer { lock.unlock() }; return log }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        var body = request.httpBody ?? Data()
        if body.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            var buf = [UInt8](repeating: 0, count: 65536)
            while stream.hasBytesAvailable {
                let n = stream.read(&buf, maxLength: buf.count)
                if n <= 0 { break }
                body.append(buf, count: n)
            }
            stream.close()
        }
        let s = Seen(url: request.url!, headers: request.allHTTPHeaderFields ?? [:], body: String(decoding: body, as: UTF8.self))
        Self.lock.lock()
        Self.log.append(s)
        let n = Self.log.count
        let h = Self.handler
        Self.lock.unlock()
        switch h?(s, n) ?? .fail {
        case .fail:
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
        case .status(let code):
            finish(code, Data("{}".utf8))
        case .ollama(let text):
            let json = try! JSONSerialization.data(withJSONObject: ["model": "stub", "done": true,
                                                                   "message": ["role": "assistant", "content": text]])
            finish(200, json)
        }
    }

    private func finish(_ code: Int, _ data: Data) {
        let resp = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: "HTTP/1.1",
                                   headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}

class AITestCase: XCTestCase {
    var keys: NovaAIMemoryKeyStore!

    override func setUp() {
        super.setUp()
        AIStubProtocol.reset()
        keys = NovaAIMemoryKeyStore()
    }

    override func tearDown() {
        AIStubProtocol.reset()
        super.tearDown()
    }

    /// Ollama only (one candidate, predictable request counts), stubbed network, no sleeping.
    @MainActor
    func makeAI(_ s: NovaAISettings = NovaAISettings(backend: .ollama)) -> NovaAI {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [AIStubProtocol.self]
        return NovaAI(configuration: NovaAIConfiguration(appID: AppAI.appID, appName: AppAI.appName),
                      storage: NovaAIMemoryStorage(s), keyStore: keys,
                      session: URLSession(configuration: cfg), sleep: { _ in })
    }

    @MainActor
    func makeAssistant(_ ai: NovaAI, home: HomeSnapshot = AITestCase.home) -> HomeAIAssistant {
        HomeAIAssistant(ai: ai, snapshotProvider: { home })
    }

    static let home = HomeSnapshot(
        homeName: "Koch House",
        devices: [
            .init(name: "Porch Light", room: "Outside", category: "Lightbulb", reachable: true),
            .init(name: "Garage Door", room: "Garage", category: "Garage Door Opener", reachable: false),
            .init(name: "Thermostat", room: "Hall", category: "Thermostat", reachable: true),
        ],
        rooms: ["Outside", "Garage", "Hall"],
        scenes: ["Good Morning", "Good Night"])

    static let reply = "The Garage Door is unreachable; check its Wi-Fi bridge."

    static var sourceRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
}

// MARK: - Security

final class AISecurityTests: AITestCase {
    func testKeychainServiceNames() {
        let c = NovaAIConfiguration(appID: AppAI.appID, appName: AppAI.appName)
        XCTAssertEqual(c.keychainService(for: .openRouter), "com.jkoch.homekitcontrol.openrouter")
        XCTAssertEqual(c.keychainService(for: .openAI), "com.jkoch.homekitcontrol.openai")
    }

    /// Legacy Keychain items: OpenAI key moved (old item deleted), Claude and cloud-backend items deleted.
    @MainActor
    func testLegacyKeychainItemsMigrated() throws {
        let suite = "HomekitControlTests.legacy.\(UUID().uuidString)"
        let d = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { d.removePersistentDomain(forName: suite) }
        XCTAssertTrue(keys.write("test-openai-placeholder", service: AppAI.legacyService, account: "HomekitControl_OpenAI_APIKey"))
        XCTAssertTrue(keys.write("test-claude-placeholder", service: AppAI.legacyService, account: "HomekitControl_Claude_APIKey"))
        XCTAssertTrue(keys.write("test-aws-placeholder", service: AppAI.legacyMacService, account: "AIBackend_AWS_SecretKey"))
        XCTAssertTrue(keys.write("keep-me", service: AppAI.legacyService, account: "HomekitControl_Nova_APIToken"))
        let ai = makeAI(NovaAISettings())
        AppAI.migrateLegacy(ai, defaults: d)
        XCTAssertEqual(keys.read(service: "com.jkoch.homekitcontrol.openai", account: NovaAIConfiguration.keychainAccount),
                       "test-openai-placeholder")
        XCTAssertNil(keys.read(service: AppAI.legacyService, account: "HomekitControl_OpenAI_APIKey"))
        XCTAssertNil(keys.read(service: AppAI.legacyService, account: "HomekitControl_Claude_APIKey"))
        XCTAssertNil(keys.read(service: AppAI.legacyMacService, account: "AIBackend_AWS_SecretKey"))
        XCTAssertEqual(keys.read(service: AppAI.legacyService, account: "HomekitControl_Nova_APIToken"), "keep-me",
                       "non-AI secrets must stay")
        XCTAssertTrue(d.bool(forKey: AppAI.legacyMarker))
    }

    /// Security fix carried by the kit: plaintext keys in UserDefaults leave UserDefaults.
    @MainActor
    func testPlaintextDefaultsKeysRemoved() throws {
        let suite = "HomekitControlTests.plain.\(UUID().uuidString)"
        let d = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { d.removePersistentDomain(forName: suite) }
        d.set("test-openai-placeholder", forKey: "AIBackend_OpenAI_Key")
        d.set("test-google-placeholder", forKey: "AIBackend_GoogleCloud_Key")
        let ai = makeAI(NovaAISettings())
        AppAI.migrateLegacy(ai, defaults: d)
        XCTAssertNil(d.object(forKey: "AIBackend_OpenAI_Key"))
        XCTAssertNil(d.object(forKey: "AIBackend_GoogleCloud_Key"))
        XCTAssertTrue(ai.hasAPIKey(for: .openAI))
    }

    @MainActor
    func testKeyNeverSentOverHTTP() async {
        var s = NovaAISettings(backend: .openAI)
        s.setURL("http://api.example.invalid/v1", for: .openAI)
        let ai = makeAI(s)
        ai.setAPIKey("test-key-placeholder", for: .openAI)
        AIStubProtocol.respond { _, _ in .ollama("should not be reached") }
        let r = await makeAssistant(ai).answer("Any device issues?")
        XCTAssertFalse(r.isAI)
        XCTAssertTrue(AIStubProtocol.seen.allSatisfy { $0.headers["Authorization"] == nil })
    }

    func testInputSanitizedAndCapped() {
        let s = HomeAIAssistant.sanitizedInput("  hi\u{0007}\u{001B}[31m " + String(repeating: "x", count: 5000))
        XCTAssertFalse(s.contains("\u{0007}"))
        XCTAssertFalse(s.contains("\u{001B}"))
        XCTAssertEqual(s.count, HomeAIAssistant.maxInput)
    }

    /// No old AI client code left in any target's sources.
    func testNoLegacyAIClientInSources() throws {
        let fm = FileManager.default
        var files: [URL] = []
        for dir in ["Shared", "iOS", "macOS", "tvOS"] {
            let root = Self.sourceRoot.appendingPathComponent(dir)
            guard let e = fm.enumerator(at: root, includingPropertiesForKeys: nil) else { continue }
            files += e.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        }
        guard !files.isEmpty else { throw XCTSkip("sources not available") }
        for f in files {
            let text = try String(contentsOf: f, encoding: .utf8)
                .replacingOccurrences(of: "migrateFromLegacyAIBackendManager", with: "")
            for banned in ["AIBackendManager", "EthicalAIGuardian", "AIBackendStatusMenu", "OPENAI_API_KEY",
                           "/api/generate", "chat/completions", "api.anthropic.com", "x-api-key"] {
                XCTAssertFalse(text.contains(banned), "\(f.lastPathComponent) still contains \(banned)")
            }
        }
    }
}

// MARK: - Performance

final class AIPerformanceTests: AITestCase {
    func testBuiltInAnswersAreFast() {
        let big = HomeSnapshot(homeName: "Big", devices: (0..<500).map {
            .init(name: "Device \($0)", room: "Room \($0 % 20)", category: "Lightbulb", reachable: $0 % 7 != 0)
        }, rooms: (0..<20).map { "Room \($0)" }, scenes: (0..<50).map { "Scene \($0)" })
        measure {
            for q in ["Any device issues?", "What scenes do I have?", "Devices by room", "How many devices are online?", "hello"] {
                _ = HomeAIAssistant.builtInAnswer(q, snapshot: big, aiEnabled: true)
            }
            _ = big.contextText
        }
    }

    func testContextIsBounded() {
        let big = HomeSnapshot(homeName: nil, devices: (0..<1000).map {
            .init(name: "D\($0)", room: nil, category: "Other", reachable: true)
        })
        let lines = big.contextText.components(separatedBy: "\n")
        XCTAssertLessThan(lines.count, HomeSnapshot.maxDevicesInContext + 10)
        XCTAssertTrue(big.contextText.contains("850 more devices not listed"))
    }

    @MainActor
    func testOfflineAnswerDoesNotHang() async {
        let a = makeAssistant(makeAI(NovaAISettings()))   // Auto: every backend refused
        let start = Date()
        let r = await a.answer("Any device issues?")
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
        XCTAssertFalse(r.isAI)
    }
}

// MARK: - Retry

final class AIRetryTests: AITestCase {
    @MainActor
    func testTransientFailureIsRetried() async {
        AIStubProtocol.respond { _, n in n == 1 ? .status(503) : .ollama(Self.reply) }
        let r = await makeAssistant(makeAI()).answer("Any device issues?")
        XCTAssertTrue(r.isAI)
        XCTAssertEqual(r.response?.attempts, 2)
        XCTAssertEqual(r.value, Self.reply)
    }

    /// Empty reply → asked once more → still empty → built-in answer.
    @MainActor
    func testEmptyRepliesFallBackAfterOneRetry() async {
        AIStubProtocol.respond { _, _ in .ollama("   ") }
        let r = await makeAssistant(makeAI()).answer("Any device issues?")
        XCTAssertFalse(r.isAI)
        XCTAssertTrue(r.value.contains("Garage Door"))
        XCTAssertLessThanOrEqual(AIStubProtocol.seen.count, 4)
    }

    @MainActor
    func testServerErrorsFallBack() async {
        AIStubProtocol.respond { _, _ in .status(500) }
        let r = await makeAssistant(makeAI()).answer("What scenes do I have?")
        XCTAssertFalse(r.isAI)
        XCTAssertTrue(r.value.contains("Good Morning"))
        guard case .fallback(.unavailable) = r.source else { return XCTFail("expected unavailable, got \(r.source)") }
    }
}

// MARK: - Unit

final class AIUnitTests: AITestCase {
    func testBackends() {
        XCTAssertEqual(NovaAIBackend.allCases.count, 9)
        XCTAssertEqual(NovaAIBackend(legacyName: "TinyLLM"), .tinyLLM)
        XCTAssertEqual(NovaAIBackend(legacyName: "OpenWebUI"), .openWebUI)
        XCTAssertNil(NovaAIBackend(legacyName: "Claude"))
    }

    func testReplyValidator() throws {
        XCTAssertThrowsError(try HomeAIAssistant.validateReply(""))
        XCTAssertThrowsError(try HomeAIAssistant.validateReply(" \n "))
        XCTAssertEqual(try HomeAIAssistant.validateReply("  ok then \u{0007}"), "ok then")
        XCTAssertEqual(try HomeAIAssistant.validateReply(String(repeating: "a", count: 9000)).count, HomeAIAssistant.maxReply)
    }

    func testBuiltInAnswers() {
        let h = Self.home
        XCTAssertTrue(HomeAIAssistant.builtInAnswer("Any device issues?", snapshot: h, aiEnabled: true).contains("1 of 3 devices are unreachable: Garage Door"))
        XCTAssertTrue(HomeAIAssistant.builtInAnswer("How many devices are online?", snapshot: h, aiEnabled: true).hasPrefix("2 of 3 devices are reachable."))
        XCTAssertEqual(HomeAIAssistant.builtInAnswer("What scenes do I have?", snapshot: h, aiEnabled: true), "You have 2 scenes: Good Morning, Good Night.")
        XCTAssertTrue(HomeAIAssistant.builtInAnswer("Devices by room", snapshot: h, aiEnabled: true).contains("Garage (1)"))
        XCTAssertTrue(HomeAIAssistant.builtInAnswer("hello", snapshot: h, aiEnabled: true).hasPrefix("Koch House has 3 devices (2 reachable)"))
        XCTAssertTrue(HomeAIAssistant.builtInAnswer("hello", snapshot: h, aiEnabled: false).hasSuffix("(AI is off: built-in answer.)"))
        XCTAssertTrue(HomeAIAssistant.builtInAnswer("Any device issues?", snapshot: HomeSnapshot(), aiEnabled: true).contains("No devices or scenes"))
    }

    func testSnapshotSummary() {
        XCTAssertEqual(Self.home.summary, "Koch House has 3 devices (2 reachable), 3 rooms, 2 scenes.")
        XCTAssertTrue(Self.home.contextText.contains("- Garage Door | Garage | Garage Door Opener | UNREACHABLE"))
        XCTAssertEqual(HomeSnapshot(devices: [.init(name: "A", room: nil, category: "x", reachable: true)]).summary,
                       "Your home has 1 device (1 reachable), 0 scenes.")
    }
}

// MARK: - Integration

final class AIIntegrationTests: AITestCase {
    /// The request carries the system prompt, the home data and the conversation.
    @MainActor
    func testChatThroughOllamaCarriesHomeContext() async throws {
        AIStubProtocol.respond { _, _ in .ollama(Self.reply) }
        let ai = makeAI()
        let a = makeAssistant(ai)
        await a.sendMessage("Any issues?")
        await a.sendMessage("And scenes?")
        XCTAssertEqual(a.messages.count, 4)
        XCTAssertEqual(a.messages[1].content, Self.reply)
        XCTAssertEqual(a.messages[1].source?.isAI, true)
        let last = try XCTUnwrap(AIStubProtocol.seen.last)
        XCTAssertEqual(last.url.path, "/api/chat")
        XCTAssertTrue(last.body.contains("Garage Door"))
        XCTAssertTrue(last.body.contains("Any issues?"))
        XCTAssertTrue(last.body.contains("And scenes?"))
        XCTAssertEqual(ai.status.activeBackend, .ollama)
    }

    /// Old AIService settings import once, then are removed.
    @MainActor
    func testLegacyAIServiceSettingsMigrate() throws {
        let suite = "HomekitControlTests.settings.\(UUID().uuidString)"
        let d = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { d.removePersistentDomain(forName: suite) }
        d.set("TinyLLM", forKey: "aiProvider")
        d.set("http://nova-core.digitalnoise.net:11434", forKey: "ollamaEndpoint")
        d.set("qwen3:8b", forKey: "ollamaModel")
        d.set("http://nova-core.digitalnoise.net:8000", forKey: "tinyLLMEndpoint")
        let ai = makeAI(NovaAISettings())
        AppAI.migrateLegacy(ai, defaults: d)
        XCTAssertEqual(ai.settings.backend, .tinyLLM)
        XCTAssertEqual(ai.settings.url(for: .ollama), "http://nova-core.digitalnoise.net:11434")
        XCTAssertEqual(ai.settings.model(for: .ollama), "qwen3:8b")
        XCTAssertEqual(ai.settings.url(for: .tinyLLM), "http://nova-core.digitalnoise.net:8000")
        XCTAssertNil(d.object(forKey: "aiProvider"))
        // Once only.
        ai.settings.backend = .ollama
        d.set("OpenWebUI", forKey: "aiProvider")
        AppAI.migrateLegacy(ai, defaults: d)
        XCTAssertEqual(ai.settings.backend, .ollama)
    }

    /// The removed Claude provider maps to Auto.
    @MainActor
    func testClaudeProviderMapsToAuto() throws {
        let suite = "HomekitControlTests.claude.\(UUID().uuidString)"
        let d = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { d.removePersistentDomain(forName: suite) }
        d.set("Claude", forKey: "aiProvider")
        let ai = makeAI(NovaAISettings(backend: .ollama))
        AppAI.migrateLegacy(ai, defaults: d)
        XCTAssertEqual(ai.settings.backend, .auto)
    }
}

// MARK: - Functional

final class AIFunctionalTests: AITestCase {
    /// AI off: the assistant still answers from home data and sends nothing.
    @MainActor
    func testAssistantWorksWithAIOff() async {
        AIStubProtocol.respond { _, _ in .ollama(Self.reply) }
        let a = makeAssistant(makeAI(NovaAISettings(enabled: false)))
        await a.sendMessage("Any device issues?")
        XCTAssertEqual(a.messages.last?.source, .fallback(.disabled))
        XCTAssertTrue(a.messages.last?.content.contains("Garage Door") == true)
        let r = await a.answer("What scenes do I have?")
        XCTAssertEqual(r.source, .fallback(.disabled))
        XCTAssertTrue(r.value.contains("Good Night"))
        XCTAssertTrue(AIStubProtocol.seen.isEmpty)
    }

    /// Every backend down: built-in answers, transcript stays usable.
    @MainActor
    func testAssistantFallsBackWhenOffline() async {
        let a = makeAssistant(makeAI())
        await a.sendMessage("How many devices are online?")
        await a.sendMessage("What scenes do I have?")
        XCTAssertEqual(a.messages.count, 4)
        XCTAssertEqual(a.messages[1].source?.isAI, false)
        XCTAssertTrue(a.messages[3].content.contains("Good Morning"))
        XCTAssertNotNil(a.ai.status.lastError)
    }

    @MainActor
    func testBlankMessageIgnored() async {
        let a = makeAssistant(makeAI())
        await a.sendMessage("   \n ")
        XCTAssertTrue(a.messages.isEmpty)
        XCTAssertTrue(AIStubProtocol.seen.isEmpty)
    }
}

// MARK: - Frame / UI state

final class AIFrameTests: AITestCase {
    @MainActor
    func testProcessingStateAndClear() async {
        let a = makeAssistant(makeAI(NovaAISettings(enabled: false)))
        XCTAssertFalse(a.isProcessing)
        await a.sendMessage("hello")
        XCTAssertFalse(a.isProcessing)
        XCTAssertEqual(a.messages.map(\.role), [.user, .assistant])
        XCTAssertNil(a.messages[0].source)
        a.clearChat()
        XCTAssertTrue(a.messages.isEmpty)
        XCTAssertEqual(a.ai.status.state, .off)
    }

    @MainActor
    func testViewsRender() {
        let ai = makeAI()
        let settings = NSHostingView(rootView: NovaAISettingsView(ai: ai, footer: AppAI.settingsFooter))
        settings.frame = NSRect(x: 0, y: 0, width: 560, height: 600)
        settings.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(settings.fittingSize.height, 0)
        let indicator = NSHostingView(rootView: NovaAIStatusIndicator(ai: ai, showsLabel: false, checksOnAppear: false))
        XCTAssertGreaterThan(indicator.fittingSize.width, 0)
        let bubble = NSHostingView(rootView: MessageBubble(message: AIMessage(role: .assistant, content: "Hi", source: .fallback(.disabled))))
        XCTAssertGreaterThan(bubble.fittingSize.height, 0)
        XCTAssertEqual(NovaAISource.fallback(.disabled).label, "Built-in")
    }

    func testSidebarHasAssistantTab() {
        XCTAssertTrue(MacOSSidebarTab.allCases.contains(.assistant))
        XCTAssertEqual(MacOSSidebarTab.assistant.icon, "sparkles")
    }
}
