//
//  NovaAPIServer.swift
//  HomekitControl
//
//  Nova/Claude API — port 37432
//
//  Endpoints:
//    GET  /api/status          → authorized, home count, accessory count, scene count
//    GET  /api/ping            → health check
//    GET  /api/homes           → home names and ids
//    GET  /api/accessories     → accessory names, rooms, reachability
//    GET  /api/scenes          → scene names and ids
//    POST /api/scenes/execute  → execute scene by name {"name":"Good Morning"}
//    POST /api/refresh         → trigger HomeKit data refresh
//
//  On macOS (no native HomeKit.framework), endpoints proxy through
//  the macOS Shortcuts CLI. Requires these Shortcuts in Shortcuts.app:
//    - "Nova HomeKit Status"    → outputs JSON array of accessories
//    - "List HomeKit Scenes"    → outputs JSON array of scene names
//    - "Execute HomeKit Scene"  → takes scene name as input, executes it
//
//  Created by Jordan Koch on 2026.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Network
#if canImport(HomeKit)
import HomeKit
#endif

@MainActor
class NovaAPIServer {
    static let shared = NovaAPIServer()
    let port: UInt16 = 37432
    private var listener: NWListener?
    private let startTime = Date()

    /// Local-only anti-CSRF bearer token stored in Keychain (prevents drive-by POST from browser JS)
    private let apiToken: String = {
        if let existing = KeychainService.shared.load(key: KeychainService.Keys.novaAPIToken), !existing.isEmpty {
            return existing
        }
        let token = UUID().uuidString
        KeychainService.shared.save(key: KeychainService.Keys.novaAPIToken, value: token)
        return token
    }()

    private init() {}

    func start() {
        do {
            let params = NWParameters.tcp
            guard let nwPort = NWEndpoint.Port(rawValue: port) else { print("NovaAPI [HomekitControl]: invalid port \(port)"); return }
            params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: nwPort)
            listener = try NWListener(using: params)
            listener?.newConnectionHandler = { [weak self] conn in Task { @MainActor in self?.handle(conn) } }
            listener?.stateUpdateHandler = { if case .ready = $0 { print("NovaAPI [HomekitControl]: port \(self.port)") } }
            listener?.start(queue: .main)
        } catch { print("NovaAPI [HomekitControl]: failed — \(error)") }
    }
    func stop() { listener?.cancel(); listener = nil }

    private func handle(_ c: NWConnection) { c.start(queue: .main); receive(c, Data()) }
    private func receive(_ c: NWConnection, _ buf: Data) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, done, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                var b = buf; if let d = data { b.append(d) }
                if let req = NovaRequest(b) {
                    let resp = await self.route(req)
                    c.send(content: resp.data(using: .utf8), completion: .contentProcessed { _ in c.cancel() })
                } else if !done { self.receive(c, b) } else { c.cancel() }
            }
        }
    }

    private func route(_ req: NovaRequest) async -> String {
        if req.method == "OPTIONS" { return http(200, "") }

        // Require bearer token for all POST requests (anti-CSRF)
        if req.method == "POST" {
            guard let auth = req.headers["authorization"], auth == "Bearer \(apiToken)" else {
                return json(401, ["error": "Unauthorized — missing or invalid Bearer token"] as [String: Any])
            }
        }

        switch (req.method, req.path) {

        case ("GET", "/api/status"):
            #if canImport(HomeKit)
            let hk = HomeKitService.shared
            return json(200, [
                "status": "running", "app": "HomekitControl", "version": "1.3.0", "port": "\(port)",
                "platform": "native", "backend": "HomeKit.framework",
                "uptimeSeconds": Int(Date().timeIntervalSince(startTime)),
                "homes": hk.homes.count, "accessories": hk.accessories.count, "scenes": hk.scenes.count
            ] as [String: Any])
            #elseif os(macOS)
            return json(200, [
                "status": "running", "app": "HomekitControl", "version": "1.3.0", "port": "\(port)",
                "platform": "macOS", "backend": "Shortcuts CLI proxy",
                "uptimeSeconds": Int(Date().timeIntervalSince(startTime))
            ] as [String: Any])
            #else
            return json(200, [
                "status": "running", "app": "HomekitControl", "version": "1.3.0", "port": "\(port)",
                "uptimeSeconds": Int(Date().timeIntervalSince(startTime))
            ] as [String: Any])
            #endif

        case ("GET", "/api/ping"):
            return json(200, ["pong": "true"] as [String: Any])

        case ("GET", "/api/homes"):
            #if canImport(HomeKit)
            let hk = HomeKitService.shared
            if hk.homes.isEmpty {
                return json(200, ["homes": [], "note": "No homes loaded yet — HomeKit may still be initializing"] as [String: Any])
            }
            let homes = hk.homes.map { ["id": $0.uniqueIdentifier.uuidString, "name": $0.name] as [String: Any] }
            return jsonArray(200, homes)
            #elseif os(macOS)
            return json(200, ["note": "Home listing not available via Shortcuts proxy — use /api/accessories"] as [String: Any])
            #else
            return json(200, ["note": "HomeKit not available on this platform"] as [String: Any])
            #endif

        case ("GET", "/api/accessories"):
            #if canImport(HomeKit)
            let hk = HomeKitService.shared
            if hk.accessories.isEmpty {
                return json(200, ["accessories": [], "note": "No accessories loaded — HomeKit may still be initializing"] as [String: Any])
            }
            let home = hk.currentHome
            let roomMap: [UUID: String] = {
                var m: [UUID: String] = [:]
                guard let h = home else { return m }
                for room in h.rooms {
                    for acc in room.accessories { m[acc.uniqueIdentifier] = room.name }
                }
                return m
            }()
            let accessories = hk.accessories.map { acc -> [String: Any] in
                let services = acc.services.map { svc -> [String: Any] in
                    let chars = svc.characteristics.map { c -> [String: Any] in
                        var entry: [String: Any] = ["type": c.localizedDescription, "uuid": c.characteristicType]
                        if let v = c.value { entry["value"] = v }
                        return entry
                    }
                    return ["type": svc.serviceType, "name": svc.name, "characteristics": chars] as [String: Any]
                }
                return [
                    "name": acc.name,
                    "room": roomMap[acc.uniqueIdentifier] ?? "Unknown",
                    "reachable": acc.isReachable,
                    "services": services
                ] as [String: Any]
            }
            return jsonArray(200, accessories)
            #elseif os(macOS)
            let output = await runShortcut("Nova HomeKit Status")
            if let data = output.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) {
                if let array = parsed as? [[String: Any]] {
                    return jsonArray(200, array)
                } else if let dict = parsed as? [String: Any], let accs = dict["accessories"] as? [[String: Any]] {
                    return jsonArray(200, accs)
                }
            }
            return json(200, ["accessories": [], "note": "Shortcuts query returned no data — ensure 'Nova HomeKit Status' Shortcut exists"] as [String: Any])
            #else
            return json(200, ["note": "HomeKit not available on this platform"] as [String: Any])
            #endif

        case ("GET", "/api/scenes"):
            #if canImport(HomeKit)
            let hk = HomeKitService.shared
            let scenes = hk.scenes.map { ["id": $0.uniqueIdentifier.uuidString, "name": $0.name] as [String: Any] }
            return jsonArray(200, scenes)
            #elseif os(macOS)
            let output = await runShortcut("List HomeKit Scenes")
            if let data = output.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) {
                if let array = parsed as? [[String: Any]] {
                    return jsonArray(200, array)
                } else if let names = parsed as? [String] {
                    let scenes = names.map { ["name": $0] as [String: Any] }
                    return jsonArray(200, scenes)
                }
            }
            return json(200, ["scenes": [], "note": "Shortcuts query returned no data — ensure 'List HomeKit Scenes' Shortcut exists"] as [String: Any])
            #else
            return json(200, ["note": "HomeKit not available on this platform"] as [String: Any])
            #endif

        case ("POST", "/api/scenes/execute"):
            guard let body = req.bodyJSON(), let sceneName = body["name"] as? String else {
                return json(400, ["error": "Missing 'name' in request body. Usage: {\"name\": \"Good Morning\"}"] as [String: Any])
            }
            #if canImport(HomeKit)
            let hk = HomeKitService.shared
            guard let scene = hk.scenes.first(where: { $0.name.lowercased() == sceneName.lowercased() }) else {
                let available = hk.scenes.map { $0.name }
                return json(404, ["error": "Scene '\(sceneName)' not found", "available_scenes": available] as [String: Any])
            }
            do {
                try await hk.executeScene(scene)
                return json(200, ["status": "executed", "scene": scene.name] as [String: Any])
            } catch {
                return json(500, ["error": "Failed to execute scene '\(scene.name)': \(error.localizedDescription)"] as [String: Any])
            }
            #elseif os(macOS)
            let output = await runShortcut("Execute HomeKit Scene", input: sceneName)
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.lowercased().contains("error") || trimmed.lowercased().contains("not found") {
                return json(500, ["error": "Scene execution failed", "scene": sceneName, "output": trimmed] as [String: Any])
            }
            return json(200, ["status": "executed", "scene": sceneName, "backend": "Shortcuts CLI"] as [String: Any])
            #else
            return json(200, ["note": "HomeKit not available on this platform"] as [String: Any])
            #endif

        case ("POST", "/api/refresh"):
            #if canImport(HomeKit)
            Task { await HomeKitService.shared.refreshAll() }
            #endif
            return json(200, ["status": "refresh triggered"] as [String: Any])

        default:
            return json(404, ["error": "Not found: \(req.method) \(req.path)"] as [String: Any])
        }
    }

    // MARK: - macOS Shortcuts CLI Bridge

    #if os(macOS)
    /// Run a macOS Shortcut via the `shortcuts` CLI and return its stdout output.
    private func runShortcut(_ name: String, input: String? = nil) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
                var args = ["run", name, "--output-type", "public.plain-text"]

                let outPipe = Pipe()
                let errPipe = Pipe()
                proc.standardOutput = outPipe
                proc.standardError = errPipe

                if let input = input {
                    let inPipe = Pipe()
                    inPipe.fileHandleForWriting.write(input.data(using: .utf8) ?? Data())
                    inPipe.fileHandleForWriting.closeFile()
                    proc.standardInput = inPipe
                    args += ["--input-type", "public.plain-text"]
                }

                proc.arguments = args

                do {
                    try proc.run()
                    proc.waitUntilExit()
                    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } catch {
                    NSLog("[NovaAPI] Shortcut '\(name)' failed: \(error)")
                    continuation.resume(returning: "")
                }
            }
        }
    }
    #endif

    // MARK: - HTTP Helpers

    private struct NovaRequest {
        let method: String; let path: String; let body: String; let headers: [String: String]
        func bodyJSON() -> [String: Any]? { guard let d = body.data(using: .utf8) else { return nil }; return try? JSONSerialization.jsonObject(with: d) as? [String: Any] }
        init?(_ data: Data) {
            guard let raw = String(data: data, encoding: .utf8), raw.contains("\r\n\r\n") else { return nil }
            let parts = raw.components(separatedBy: "\r\n\r\n"); let lines = parts[0].components(separatedBy: "\r\n")
            guard let rl = lines.first else { return nil }; let tokens = rl.components(separatedBy: " "); guard tokens.count >= 2 else { return nil }
            var hdrs: [String: String] = [:]; for l in lines.dropFirst() { let kv = l.components(separatedBy: ": "); if kv.count >= 2 { hdrs[kv[0].lowercased()] = kv.dropFirst().joined(separator: ": ") } }
            let rawBody = parts.dropFirst().joined(separator: "\r\n\r\n")
            if let cl = hdrs["content-length"], let n = Int(cl), rawBody.utf8.count < n { return nil }
            method = tokens[0]; path = tokens[1].components(separatedBy: "?").first ?? tokens[1]; body = rawBody; headers = hdrs
        }
    }
    private func json(_ s: Int, _ d: [String: Any]) -> String {
        let safe = sanitizeForJSON(d) as? [String: Any] ?? [:]
        guard JSONSerialization.isValidJSONObject(safe),
              let data = try? JSONSerialization.data(withJSONObject: safe, options: .prettyPrinted),
              let body = String(data: data, encoding: .utf8) else { return http(500, "{\"error\":\"JSON serialization failed\"}") }
        return http(s, body, "application/json")
    }
    private func jsonArray(_ s: Int, _ a: [[String: Any]]) -> String {
        let safe = a.map { sanitizeForJSON($0) as? [String: Any] ?? [:] }
        guard JSONSerialization.isValidJSONObject(safe),
              let data = try? JSONSerialization.data(withJSONObject: safe, options: .prettyPrinted),
              let body = String(data: data, encoding: .utf8) else { return http(500, "{\"error\":\"JSON serialization failed\"}") }
        return http(s, body, "application/json")
    }
    private func sanitizeForJSON(_ value: Any) -> Any {
        switch value {
        case let str as String: return str
        case let num as NSNumber: return num
        case let bool as Bool: return bool
        case let dict as [String: Any]: return dict.mapValues { sanitizeForJSON($0) }
        case let arr as [Any]: return arr.map { sanitizeForJSON($0) }
        case is NSNull: return NSNull()
        default: return String(describing: value)
        }
    }
    private func http(_ s: Int, _ body: String, _ ct: String = "text/plain") -> String { let st = [200:"OK",201:"Created",400:"Bad Request",401:"Unauthorized",404:"Not Found",500:"Internal Server Error"][s] ?? "Unknown"; return "HTTP/1.1 \(s) \(st)\r\nContent-Type: \(ct); charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)" }
}
