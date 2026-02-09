//
//  WebSocketClient.swift
//  NylMobile
//
//  Created by Jeremy Spradlin on 2/8/26.
//

import Foundation
import Combine
import NylKit

/// Manages WebSocket connection for real-time updates from NylServer
@MainActor
class WebSocketClient: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    @Published var isConnected: Bool = false
    @Published var lastEvent: WebSocketEvent?
    
    // MARK: - Private Properties
    
    private var webSocket: URLSessionWebSocketTask?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var baseURL: String?
    
    /// Cached JSON decoder for WebSocket messages
    private let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()
    
    // MARK: - Event Handler
    
    var onEventReceived: ((WebSocketEvent) -> Void)?
    
    // MARK: - Connection Management
    
    /// Connect to WebSocket server
    func connect(to baseURL: String) {
        self.baseURL = baseURL
        
        // Convert HTTP URL to WebSocket URL
        let wsURL = baseURL.replacingOccurrences(of: "http://", with: "ws://")
        guard let url = URL(string: "\(wsURL)/ws/updates") else {
            print("❌ Invalid WebSocket URL")
            return
        }
        
        let request = URLRequest(url: url)
        webSocket = URLSession.shared.webSocketTask(with: request)
        webSocket?.resume()
        reconnectAttempts = 0
        
        print("🔌 WebSocket connecting to: \(url)")
        // Note: isConnected will be set to true when we receive the .connected event
        receiveMessage()
    }
    
    /// Disconnect from WebSocket server
    func disconnect() {
        let ws = webSocket
        webSocket = nil
        isConnected = false
        reconnectAttempts = 0
        baseURL = nil
        
        // Cancel in background to avoid MainActor isolation issues
        Task.detached {
            ws?.cancel(with: .goingAway, reason: nil)
        }
        
        print("🔌 WebSocket disconnected")
    }
    
    // MARK: - Private Methods
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleMessage(text)
                        }
                    @unknown default:
                        break
                    }
                    self.receiveMessage() // Continue receiving
                    
                case .failure(let error):
                    print("❌ WebSocket receive error: \(error)")
                    self.handleDisconnect()
                }
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            let event = try decoder.decode(WebSocketEvent.self, from: data)
            print("📩 Received WebSocket event: \(event.type.rawValue)")
            
            // Set connected state when we receive the initial connected event
            if event.type == .connected && !isConnected {
                isConnected = true
                print("✅ WebSocket connection confirmed")
            }
            
            lastEvent = event
            onEventReceived?(event)
        } catch {
            print("❌ Failed to decode WebSocket event: \(error)")
        }
    }
    
    private func handleDisconnect() {
        isConnected = false
        
        // Attempt reconnect with exponential backoff
        guard reconnectAttempts < maxReconnectAttempts, let baseURL = baseURL else {
            print("❌ Max reconnect attempts reached or no base URL")
            return
        }
        
        let delay = pow(2.0, Double(reconnectAttempts))
        reconnectAttempts += 1
        
        print("🔄 Reconnecting in \(delay) seconds (attempt \(reconnectAttempts)/\(maxReconnectAttempts))...")
        
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self.connect(to: baseURL)
        }
    }
    
    deinit {
        // WebSocket cleanup handled in disconnect() - do nothing here
        // deinit cannot safely access @MainActor properties
    }
}
