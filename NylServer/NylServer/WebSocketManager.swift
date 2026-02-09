//
//  WebSocketManager.swift
//  NylServer
//
//  Created by Jeremy Spradlin on 2/8/26.
//

import Foundation
import Combine
import Vapor
import NylKit

/// Manages WebSocket connections and broadcasts updates to connected clients
@MainActor
class WebSocketManager: ObservableObject {
    // MARK: - Properties

    /// Active WebSocket connections
    private var connections: [UUID: WebSocket] = [:]
    
    /// Cached JSON encoder for WebSocket messages
    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }()

    // MARK: - Connection Management

    /// Add a new WebSocket connection
    func addConnection(id: UUID, socket: WebSocket) {
        connections[id] = socket
        print("📱 WebSocket client connected: \(id)")
        print("📱 Total connections: \(connections.count)")
    }

    /// Remove a WebSocket connection
    func removeConnection(id: UUID) {
        connections.removeValue(forKey: id)
        print("📱 WebSocket client disconnected: \(id)")
        print("📱 Total connections: \(connections.count)")
    }

    // MARK: - Broadcasting

    /// Broadcast an event to all connected clients
    func broadcast(_ event: WebSocketEvent) {
        guard let jsonData = try? encoder.encode(event),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("❌ Failed to encode WebSocket event")
            return
        }

        var failedConnections: [UUID] = []
        
        for (id, ws) in connections {
            Task { [weak self] in
                do {
                    try await ws.send(jsonString)
                } catch {
                    print("❌ Failed to send to client \(id): \(error.localizedDescription)")
                    failedConnections.append(id)
                    // Remove dead connection
                    await self?.removeConnection(id: id)
                }
            }
        }

        print("📡 Broadcast \(event.type.rawValue) to \(connections.count) client(s)")
    }
}
