//
//  NylAPIService.swift
//  NylMobile
//
//  Created by Jeremy Spradlin on 2/8/26.
//

import Foundation
import Combine
import NylKit

/// Service for communicating with NylServer API
@MainActor
class NylAPIService: ObservableObject {
    // MARK: - Published Properties
    
    @Published var status: StatusResponse?
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var lastUpdated: Date?
    @Published var isWebSocketConnected: Bool = false
    @Published var lastWebSocketEvent: WebSocketEventType?
    
    // MARK: - Private Properties
    
    private var baseURL: String?
    private let session: URLSession
    private let wsClient = WebSocketClient()
    private var cancellables = Set<AnyCancellable>()
    
    /// Cached JSON decoder for API responses
    private let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()
    
    // MARK: - Initialization
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Public Methods
    
    /// Connect to a discovered server
    func connect(to server: DiscoveredServer) {
        // Clear old subscriptions to prevent accumulation
        cancellables.removeAll()
        
        baseURL = server.baseURL
        
        // Observe WebSocket connection state
        wsClient.$isConnected
            .sink { [weak self] isConnected in
                self?.isWebSocketConnected = isConnected
            }
            .store(in: &cancellables)
        
        // Set up WebSocket event handler
        wsClient.onEventReceived = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleWebSocketEvent(event)
            }
        }
        
        // Connect WebSocket
        wsClient.connect(to: server.baseURL)
        
        // Fetch initial status via HTTP
        Task {
            await fetchStatus()
        }
    }
    
    /// Fetch current status from server
    func fetchStatus() async {
        guard let baseURL = baseURL else {
            error = "No server connected"
            return
        }
        
        guard let url = URL(string: "\(baseURL)/v1/status") else {
            error = "Invalid URL"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Invalid response"
                isLoading = false
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                error = "Server error: \(httpResponse.statusCode)"
                isLoading = false
                return
            }
            
            let statusResponse = try decoder.decode(StatusResponse.self, from: data)
            
            self.status = statusResponse
            self.lastUpdated = Date()
            self.error = nil
            
        } catch {
            self.error = "Failed to fetch status: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Disconnect from server
    func disconnect() {
        wsClient.disconnect()
        cancellables.removeAll()
        baseURL = nil
        status = nil
        error = nil
        lastUpdated = nil
        isWebSocketConnected = false
        lastWebSocketEvent = nil
    }
    
    deinit {
        // WebSocketClient will clean up in its own deinit
        session.invalidateAndCancel()
    }
    
    // MARK: - Private Methods
    
    /// Handle incoming WebSocket events
    private func handleWebSocketEvent(_ event: WebSocketEvent) {
        // Track the last event type for UI indicator
        lastWebSocketEvent = event.type
        
        // Clear the event indicator after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.lastWebSocketEvent = nil
        }
        
        switch event.type {
        case .connected:
            print("✅ WebSocket connected")
            if let payload = event.payload {
                self.status = payload
                self.lastUpdated = Date()
            }
            
        case .statusUpdate:
            if let payload = event.payload {
                self.status = payload
                self.lastUpdated = Date()
                print("🔄 Status updated via WebSocket")
            }
            
        case .heartbeatFired, .weatherUpdated:
            // Server sends these events without payload
            // Fetch fresh status via HTTP
            Task {
                await fetchStatus()
            }
        }
    }
}
