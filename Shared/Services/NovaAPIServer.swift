//
//  NovaAPIServer.swift
//  HomekitControl
//
//  Nova/Claude API — port 37432
//
//  Endpoints:
//    GET  /api/status              → app status, authorization state
//    GET  /api/homes               → list all homes
//    GET  /api/homes/:id/rooms     → rooms in a home
//    GET  /api/accessories         → all accessories
//    GET  /api/accessories/:id     → accessory detail + state
//    POST /api/accessories/:id/toggle       → toggle power
//    POST /api/accessories/:id/power        → set power {"on": true|false}
//    POST /api/accessories/:id/brightness   → set brightness {"value": 0-100}
//    GET  /api/scenes              → all scenes
//    POST /api/scenes/:id/execute  → execute a scene
//    GET  /api/climate             → climate/thermostat status
//
//  Created by Jordan Koch on 2026.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Network
import HomeKit

@MainActor
class NovaAPIServer {
    static let shared = NovaAPIServer()
    let port: UInt16 = 37432
    private var listener: NWListener?
    private let startTime = Date()
    private init() {}

    func start() {
        do {
            let params = NWParameters.tcp
            params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
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
        let hk = HomeKitService.shared

        switch (req.method, req.path) {

        case ("GET", "/api/status"):
            return json(200, [
                "status": "running", "app": "HomekitControl", "version": "1.0", "port": "\(port)",
                "isAuthorized": hk.isAuthorized,
                "homeCount": hk.homes.count,
                "accessoryCount": hk.accessories.count,
                "sceneCount": hk.scenes.count,
                "uptimeSeconds": Int(Date().timeIntervalSince(startTime))
            ])

        case ("GET", "/api/homes"):
            let homes = hk.homes.map { h -> [String: Any] in
                ["id": h.uniqueIdentifier.uuidString, "name": h.name,
                 "isPrimary": h.isPrimary, "roomCount": h.rooms.count]
            }
            return jsonArray(200, homes)

        case ("GET", "/api/accessories"):
            let accessories = hk.accessories.map { a -> [String: Any] in
                var info: [String: Any] = [
                    "id": a.uniqueIdentifier.uuidString,
                    "name": a.name,
                    "room": a.room?.name ?? "",
                    "category": a.category.description,
                    "isReachable": a.isReachable,
                    "isBlocked": a.isBlocked
                ]
                return info
            }
            return jsonArray(200, accessories)

        case ("POST", _) where req.path.hasSuffix("/toggle"):
            let idStr = req.path.components(separatedBy: "/").dropLast().last ?? ""
            guard let uuid = UUID(uuidString: idStr),
                  let accessory = hk.accessories.first(where: { $0.uniqueIdentifier == uuid }) else {
                return json(404, ["error": "Accessory not found"])
            }
            try? await hk.toggleAccessory(accessory)
            return json(200, ["status": "toggled", "name": accessory.name])

        case ("POST", _) where req.path.hasSuffix("/power"):
            let idStr = req.path.components(separatedBy: "/").dropLast().last ?? ""
            guard let uuid = UUID(uuidString: idStr),
                  let accessory = hk.accessories.first(where: { $0.uniqueIdentifier == uuid }),
                  let body = req.bodyJSON(),
                  let on = body["on"] as? Bool else {
                return json(400, ["error": "Accessory not found or missing 'on' field"])
            }
            try? await hk.setAccessoryPower(accessory, on: on)
            return json(200, ["status": on ? "on" : "off", "name": accessory.name])

        case ("POST", _) where req.path.hasSuffix("/brightness"):
            let idStr = req.path.components(separatedBy: "/").dropLast().last ?? ""
            guard let uuid = UUID(uuidString: idStr),
                  let accessory = hk.accessories.first(where: { $0.uniqueIdentifier == uuid }),
                  let body = req.bodyJSON(),
                  let value = body["value"] as? Int else {
                return json(400, ["error": "Accessory not found or missing 'value' field"])
            }
            try? await hk.setBrightness(accessory, value: value)
            return json(200, ["status": "set", "brightness": value, "name": accessory.name])

        case ("GET", "/api/scenes"):
            let scenes = hk.scenes.map { s -> [String: Any] in
                ["id": s.uniqueIdentifier.uuidString, "name": s.name,
                 "type": s.actionSetType.rawValue]
            }
            return jsonArray(200, scenes)

        case ("POST", _) where req.path.hasSuffix("/execute") && req.path.contains("/scenes/"):
            let idStr = req.path.components(separatedBy: "/").dropLast().last ?? ""
            guard let uuid = UUID(uuidString: idStr),
                  let scene = hk.scenes.first(where: { $0.uniqueIdentifier == uuid }) else {
                return json(404, ["error": "Scene not found"])
            }
            try? await hk.executeScene(scene)
            return json(200, ["status": "executed", "scene": scene.name])

        default:
            return json(404, ["error": "Not found: \(req.method) \(req.path)"])
        }
    }

    private struct NovaRequest {
        let method: String; let path: String; let body: String
        func bodyJSON() -> [String: Any]? { guard let d = body.data(using: .utf8) else { return nil }; return try? JSONSerialization.jsonObject(with: d) as? [String: Any] }
        init?(_ data: Data) {
            guard let raw = String(data: data, encoding: .utf8), raw.contains("\r\n\r\n") else { return nil }
            let parts = raw.components(separatedBy: "\r\n\r\n"); let lines = parts[0].components(separatedBy: "\r\n")
            guard let rl = lines.first else { return nil }; let tokens = rl.components(separatedBy: " "); guard tokens.count >= 2 else { return nil }
            var hdrs: [String: String] = []; for l in lines.dropFirst() { let kv = l.components(separatedBy: ": "); if kv.count >= 2 { hdrs[kv[0].lowercased()] = kv.dropFirst().joined(separator: ": ") } }
            let rawBody = parts.dropFirst().joined(separator: "\r\n\r\n")
            if let cl = hdrs["content-length"], let n = Int(cl), rawBody.utf8.count < n { return nil }
            method = tokens[0]; path = tokens[1].components(separatedBy: "?").first ?? tokens[1]; body = rawBody
        }
    }
    private func json(_ s: Int, _ d: [String: Any]) -> String { guard let data = try? JSONSerialization.data(withJSONObject: d, options: .prettyPrinted), let body = String(data: data, encoding: .utf8) else { return http(500, "") }; return http(s, body, "application/json") }
    private func jsonArray(_ s: Int, _ a: [[String: Any]]) -> String { guard let data = try? JSONSerialization.data(withJSONObject: a, options: .prettyPrinted), let body = String(data: data, encoding: .utf8) else { return http(500, "") }; return http(s, body, "application/json") }
    private func http(_ s: Int, _ body: String, _ ct: String = "text/plain") -> String { let st = [200:"OK",201:"Created",400:"Bad Request",404:"Not Found",500:"Internal Server Error"][s] ?? "Unknown"; return "HTTP/1.1 \(s) \(st)\r\nContent-Type: \(ct); charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(body)" }
}
