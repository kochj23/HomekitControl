//
//  WebSocketDeviceAPI.swift
//  HomekitControl
//
//  Real-Time WebSocket Device API — broadcasts device state changes in real-time
//  Enterprise Feature: Extends NovaAPIServer with WebSocket upgrade on port 37433
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Network
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - WebSocket Message Types

enum WebSocketMessageType: String, Codable {
    case deviceStateChange = "device_state_change"
    case deviceReachabilityChange = "device_reachability_change"
    case sceneExecuted = "scene_executed"
    case heartbeat = "heartbeat"
    case subscribe = "subscribe"
    case unsubscribe = "unsubscribe"
    case error = "error"
}

struct WebSocketMessage: Codable {
    let type: WebSocketMessageType
    let timestamp: Date
    let payload: [String: AnyCodableValue]
}

/// Type-erased Codable wrapper for heterogeneous dictionaries
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode(Int.self) { self = .int(value) }
        else if let value = try? container.decode(Double.self) { self = .double(value) }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }

    static func from(_ value: Any) -> AnyCodableValue {
        switch value {
        case let s as String: return .string(s)
        case let i as Int: return .int(i)
        case let d as Double: return .double(d)
        case let b as Bool: return .bool(b)
        default: return .string(String(describing: value))
        }
    }
}

// MARK: - WebSocket Connection Wrapper

private final class WebSocketClient: @unchecked Sendable {
    let id: UUID
    let connection: NWConnection
    var subscribedDevices: Set<UUID> = []
    var isAlive = true
    let connectedAt = Date()

    init(connection: NWConnection) {
        self.id = UUID()
        self.connection = connection
    }

    func send(data: Data) {
        // Build WebSocket frame
        let frame = buildWebSocketFrame(payload: data, opcode: 0x01) // Text frame
        connection.send(content: frame, completion: .contentProcessed { error in
            if error != nil {
                self.isAlive = false
            }
        })
    }

    private func buildWebSocketFrame(payload: Data, opcode: UInt8) -> Data {
        var frame = Data()
        frame.append(0x80 | opcode) // FIN + opcode

        let length = payload.count
        if length < 126 {
            frame.append(UInt8(length))
        } else if length < 65536 {
            frame.append(126)
            frame.append(UInt8((length >> 8) & 0xFF))
            frame.append(UInt8(length & 0xFF))
        } else {
            frame.append(127)
            for shift in stride(from: 56, through: 0, by: -8) {
                frame.append(UInt8((length >> shift) & 0xFF))
            }
        }

        frame.append(payload)
        return frame
    }
}

// MARK: - WebSocket Device API Server

@MainActor
class WebSocketDeviceAPI: ObservableObject {
    static let shared = WebSocketDeviceAPI()

    let port: UInt16 = 37433
    @Published var connectedClients: Int = 0
    @Published var isRunning = false
    @Published var totalMessagesSent: Int = 0

    private var listener: NWListener?
    private var clients: [UUID: WebSocketClient] = [:]
    private var heartbeatTimer: Timer?

    #if canImport(HomeKit)
    private var accessoryDelegate: WebSocketAccessoryDelegate?
    #endif

    private init() {}

    // MARK: - Server Lifecycle

    func start() {
        guard !isRunning else { return }

        do {
            let params = NWParameters.tcp
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                NSLog("[WebSocketAPI] Invalid port \(port)")
                return
            }
            params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: nwPort)
            listener = try NWListener(using: params)

            listener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleNewConnection(connection)
                }
            }

            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    if case .ready = state {
                        self?.isRunning = true
                        NSLog("[WebSocketAPI] Listening on port \(self?.port ?? 0)")
                    }
                }
            }

            listener?.start(queue: .main)

            // Start heartbeat timer (every 30 seconds)
            heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.sendHeartbeat()
                    self?.pruneDeadClients()
                }
            }

            #if canImport(HomeKit)
            setupAccessoryDelegates()
            #endif

        } catch {
            NSLog("[WebSocketAPI] Failed to start: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil

        for client in clients.values {
            client.connection.cancel()
        }
        clients.removeAll()
        isRunning = false
        connectedClients = 0
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        receiveHTTPUpgrade(connection)
    }

    private func receiveHTTPUpgrade(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, error in
            Task { @MainActor in
                guard let self, let data, error == nil else {
                    connection.cancel()
                    return
                }

                guard let request = String(data: data, encoding: .utf8),
                      request.contains("Upgrade: websocket") || request.contains("upgrade: websocket") else {
                    // Not a WebSocket upgrade, send 400
                    let response = "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                    connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                    return
                }

                // Extract Sec-WebSocket-Key
                guard let keyLine = request.components(separatedBy: "\r\n").first(where: { $0.lowercased().hasPrefix("sec-websocket-key:") }),
                      let key = keyLine.components(separatedBy: ": ").last?.trimmingCharacters(in: .whitespaces) else {
                    connection.cancel()
                    return
                }

                // Perform WebSocket handshake
                self.performHandshake(connection: connection, key: key)
            }
        }
    }

    private func performHandshake(connection: NWConnection, key: String) {
        let magicString = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let combined = key + magicString
        let acceptKey = sha1Base64(combined)

        let response = """
        HTTP/1.1 101 Switching Protocols\r\n\
        Upgrade: websocket\r\n\
        Connection: Upgrade\r\n\
        Sec-WebSocket-Accept: \(acceptKey)\r\n\
        \r\n
        """

        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { [weak self] error in
            Task { @MainActor in
                guard error == nil else {
                    connection.cancel()
                    return
                }

                let client = WebSocketClient(connection: connection)
                self?.clients[client.id] = client
                self?.connectedClients = self?.clients.count ?? 0
                self?.startReceiving(client: client)

                NSLog("[WebSocketAPI] Client connected: \(client.id)")
            }
        })
    }

    private func startReceiving(client: WebSocketClient) {
        client.connection.receive(minimumIncompleteLength: 2, maximumLength: 65536) { [weak self] data, _, _, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    NSLog("[WebSocketAPI] Receive error: \(error)")
                    self.removeClient(client.id)
                    return
                }

                if let data {
                    self.handleWebSocketFrame(client: client, data: data)
                }

                if client.isAlive {
                    self.startReceiving(client: client)
                }
            }
        }
    }

    private func handleWebSocketFrame(client: WebSocketClient, data: Data) {
        guard data.count >= 2 else { return }

        let opcode = data[0] & 0x0F
        let isMasked = (data[1] & 0x80) != 0

        switch opcode {
        case 0x08: // Close
            removeClient(client.id)
        case 0x09: // Ping
            sendPong(client: client, data: data)
        case 0x01, 0x02: // Text or Binary
            if let payload = decodePayload(data: data, isMasked: isMasked) {
                handleClientMessage(client: client, payload: payload)
            }
        default:
            break
        }
    }

    private func decodePayload(data: Data, isMasked: Bool) -> Data? {
        guard data.count >= 2 else { return nil }

        var offset = 2
        var payloadLength = Int(data[1] & 0x7F)

        if payloadLength == 126 {
            guard data.count >= 4 else { return nil }
            payloadLength = Int(data[2]) << 8 | Int(data[3])
            offset = 4
        } else if payloadLength == 127 {
            guard data.count >= 10 else { return nil }
            payloadLength = 0
            for i in 0..<8 {
                payloadLength = payloadLength << 8 | Int(data[2 + i])
            }
            offset = 10
        }

        var mask: [UInt8] = []
        if isMasked {
            guard data.count >= offset + 4 else { return nil }
            mask = Array(data[offset..<offset + 4])
            offset += 4
        }

        guard data.count >= offset + payloadLength else { return nil }

        var payload = Data(data[offset..<offset + payloadLength])
        if isMasked {
            for i in 0..<payload.count {
                payload[i] ^= mask[i % 4]
            }
        }

        return payload
    }

    private func handleClientMessage(client: WebSocketClient, payload: Data) {
        guard let message = try? JSONDecoder().decode(WebSocketMessage.self, from: payload) else { return }

        switch message.type {
        case .subscribe:
            if case .string(let deviceId) = message.payload["deviceId"],
               let uuid = UUID(uuidString: deviceId) {
                clients[client.id]?.subscribedDevices.insert(uuid)
            }
        case .unsubscribe:
            if case .string(let deviceId) = message.payload["deviceId"],
               let uuid = UUID(uuidString: deviceId) {
                clients[client.id]?.subscribedDevices.remove(uuid)
            }
        default:
            break
        }
    }

    private func sendPong(client: WebSocketClient, data: Data) {
        var pongFrame = Data()
        pongFrame.append(0x8A) // FIN + Pong
        pongFrame.append(0x00) // No payload
        client.connection.send(content: pongFrame, completion: .contentProcessed { _ in })
    }

    // MARK: - Broadcasting

    /// Broadcast a device state change to all subscribed clients
    func broadcastDeviceStateChange(deviceId: UUID, deviceName: String, characteristic: String, value: Any) {
        let message = WebSocketMessage(
            type: .deviceStateChange,
            timestamp: Date(),
            payload: [
                "deviceId": .string(deviceId.uuidString),
                "deviceName": .string(deviceName),
                "characteristic": .string(characteristic),
                "value": AnyCodableValue.from(value)
            ]
        )

        broadcast(message, forDevice: deviceId)
    }

    /// Broadcast reachability change
    func broadcastReachabilityChange(deviceId: UUID, deviceName: String, isReachable: Bool) {
        let message = WebSocketMessage(
            type: .deviceReachabilityChange,
            timestamp: Date(),
            payload: [
                "deviceId": .string(deviceId.uuidString),
                "deviceName": .string(deviceName),
                "isReachable": .bool(isReachable)
            ]
        )

        broadcast(message, forDevice: deviceId)
    }

    /// Broadcast scene execution
    func broadcastSceneExecuted(sceneName: String, sceneId: UUID) {
        let message = WebSocketMessage(
            type: .sceneExecuted,
            timestamp: Date(),
            payload: [
                "sceneId": .string(sceneId.uuidString),
                "sceneName": .string(sceneName)
            ]
        )

        broadcast(message, forDevice: nil)
    }

    private func broadcast(_ message: WebSocketMessage, forDevice deviceId: UUID?) {
        guard let data = try? JSONEncoder().encode(message) else { return }

        for client in clients.values where client.isAlive {
            // Send to all clients if no device filter, or only to subscribed clients
            if deviceId == nil || client.subscribedDevices.isEmpty || client.subscribedDevices.contains(deviceId!) {
                client.send(data: data)
                totalMessagesSent += 1
            }
        }
    }

    private func sendHeartbeat() {
        let message = WebSocketMessage(
            type: .heartbeat,
            timestamp: Date(),
            payload: [
                "clients": .int(connectedClients),
                "uptime": .int(Int(Date().timeIntervalSince(Date())))
            ]
        )
        broadcast(message, forDevice: nil)
    }

    private func pruneDeadClients() {
        let deadClients = clients.filter { !$0.value.isAlive }
        for (id, _) in deadClients {
            removeClient(id)
        }
    }

    private func removeClient(_ id: UUID) {
        clients[id]?.connection.cancel()
        clients.removeValue(forKey: id)
        connectedClients = clients.count
    }

    // MARK: - SHA-1 for WebSocket Handshake

    private func sha1Base64(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return "" }
        var digest = [UInt8](repeating: 0, count: 20)

        data.withUnsafeBytes { bytes in
            _ = CC_SHA1(bytes.baseAddress, CC_LONG(data.count), &digest)
        }

        return Data(digest).base64EncodedString()
    }

    // MARK: - HomeKit Delegate Integration

    #if canImport(HomeKit)
    private func setupAccessoryDelegates() {
        accessoryDelegate = WebSocketAccessoryDelegate(api: self)

        // Register delegate for all accessories
        for accessory in HomeKitService.shared.accessories {
            accessory.delegate = accessoryDelegate
        }
    }
    #endif
}

// MARK: - CommonCrypto Import

import CommonCrypto

// MARK: - HomeKit Accessory Delegate for Real-Time Updates

#if canImport(HomeKit)
class WebSocketAccessoryDelegate: NSObject, HMAccessoryDelegate {
    private weak var api: WebSocketDeviceAPI?

    init(api: WebSocketDeviceAPI) {
        self.api = api
        super.init()
    }

    nonisolated func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) {
        Task { @MainActor in
            self.api?.broadcastDeviceStateChange(
                deviceId: accessory.uniqueIdentifier,
                deviceName: accessory.name,
                characteristic: characteristic.localizedDescription,
                value: characteristic.value ?? "null"
            )
        }
    }

    nonisolated func accessoryDidUpdateReachability(_ accessory: HMAccessory) {
        Task { @MainActor in
            self.api?.broadcastReachabilityChange(
                deviceId: accessory.uniqueIdentifier,
                deviceName: accessory.name,
                isReachable: accessory.isReachable
            )
        }
    }
}
#endif
