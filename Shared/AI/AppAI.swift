//
//  AppAI.swift
//  HomekitControl
//
//  The app's one AI object (NovaAIKit 1.0.0), shared by the iOS, macOS and tvOS targets. Settings persist in
//  UserDefaults (no secrets); API keys live only in the Keychain under com.jkoch.homekitcontrol.<backend>.
//
//  Author: Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import NovaAIKit

@MainActor
enum AppAI {
    nonisolated static let appID = "homekitcontrol"
    nonisolated static let appName = "HomekitControl"

    static let shared: NovaAI = {
        let ai = NovaAI(configuration: NovaAIConfiguration(appID: appID, appName: appName))
        AppAI.migrateLegacy(ai)
        return ai
    }()

    /// Footer shown under the AI settings.
    nonisolated static let settingsFooter = "When AI is off or unreachable, the AI Assistant answers from your home data "
        + "with built-in replies (device, scene, room and issue summaries)."
}

// MARK: - Legacy migration (once)

extension AppAI {
    /// Keychain service of the old shared AIService (its OpenAI and Claude keys).
    nonisolated static let legacyService = "com.jordankoch.HomekitControl"
    /// Keychain service of the old macOS-only backend manager.
    nonisolated static let legacyMacService = "com.digitalnoise.HomekitControl"
    /// Old AIService UserDefaults keys → backend URL.
    nonisolated static let legacyURLKeys: [String: NovaAIBackend] = [
        "ollamaEndpoint": .ollama, "tinyLLMEndpoint": .tinyLLM, "tinyChatEndpoint": .tinyChat, "openWebUIEndpoint": .openWebUI,
    ]
    nonisolated static let legacyMarker = "HomekitControl.AI.legacyMigrated.v1"

    /// Imports the pre-NovaAIKit AI settings and keys once:
    /// 1. the macOS backend manager's UserDefaults (URLs, backend, model, on/off; obsolete cloud secrets deleted);
    /// 2. the shared AIService's UserDefaults (`aiProvider`, `ollamaEndpoint`, `ollamaModel`, server URLs);
    /// 3. Keychain: the OpenAI key moves to com.jkoch.homekitcontrol.openai (old item deleted after a verified copy);
    ///    the Claude key and the Google/Azure/AWS/IBM items have no successor backend and are deleted.
    static func migrateLegacy(_ ai: NovaAI, defaults: UserDefaults = .standard) {
        ai.migrateFromLegacyAIBackendManager(defaults: defaults)
        guard !defaults.bool(forKey: legacyMarker) else { return }

        var s = ai.settings
        for (key, backend) in legacyURLKeys {
            if let url = defaults.string(forKey: key), !url.isEmpty { s.setURL(url, for: backend) }
        }
        if let model = defaults.string(forKey: "ollamaModel"), !model.isEmpty { s.setModel(model, for: .ollama) }
        if let raw = defaults.string(forKey: "aiProvider") {
            // "Claude" has no NovaAIKit backend: Auto.
            s.backend = NovaAIBackend(legacyName: raw) ?? .auto
        }
        ai.settings = s

        var ok = true
        for (service, account) in [(legacyService, "HomekitControl_OpenAI_APIKey"), (legacyMacService, "AIBackend_OpenAI_Key")] {
            if ai.migrateLegacyKey(service: service, account: account, to: .openAI, deleteLegacy: true) == .writeFailed { ok = false }
        }
        ai.keys.deleteObsoleteLegacyItems(service: legacyService, accounts: ["HomekitControl_Claude_APIKey"])
        ai.keys.deleteObsoleteLegacyItems(service: legacyMacService, accounts: [
            "AIBackend_GoogleCloud_Key", "AIBackend_Azure_Key", "AIBackend_Azure_Endpoint", "AIBackend_AWS_AccessKey",
            "AIBackend_AWS_SecretKey", "AIBackend_IBM_Key", "AIBackend_IBM_URL",
        ])
        guard ok else { return }   // retry the key copy next launch
        for key in Array(legacyURLKeys.keys) + ["aiProvider", "ollamaModel"] { defaults.removeObject(forKey: key) }
        defaults.set(true, forKey: legacyMarker)
    }
}
