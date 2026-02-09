//
//  ServerService.swift
//  NylServer
//
//  Created by Jeremy Spradlin on 2/6/26.
//

import Foundation
import Vapor
import Combine
import NylKit

/// Service that manages the HTTP server using Vapor
@MainActor
class ServerService: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isRunning: Bool = false
    @Published var port: Int = 8080
    @Published var error: String?
    
    // MARK: - Private Properties
    
    private var application: Application?
    private let startTime = Date()
    
    // MARK: - Dependencies
    
    weak var heartbeatService: HeartbeatService?
    weak var weatherService: WeatherService?
    
    // MARK: - Public Methods
    
    /// Start the HTTP server
    func start() async throws {
        guard !isRunning, application == nil else {
            return
        }
        
        // Create Vapor application - use detect() like standard Vapor apps
        let env = try Environment.detect()
        let app = try Application(env)
        
        // Configure server - bind to all interfaces for LAN access
        app.http.server.configuration.hostname = "0.0.0.0"
        app.http.server.configuration.port = port
        
        // Configure JSON encoder
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        ContentConfiguration.global.use(encoder: encoder, for: .json)
        
        // Configure routes
        configureRoutes(app)
        
        // Store application
        self.application = app
        isRunning = true
        
        // Start the server using Vapor's async boot + run pattern
        try await app.asyncBoot()
        
        // Start server in detached task so it doesn't block
        Task.detached {
            try await app.server.start(address: .hostname(app.http.server.configuration.hostname, port: app.http.server.configuration.port))
        }
    }
    
    /// Stop the HTTP server
    func stop() async {
        guard isRunning else { return }
        
        application?.shutdown()
        application = nil
        isRunning = false
    }
    
    // MARK: - Private Methods
    
    private func configureRoutes(_ app: Application) {
        // Add middleware for logging
        app.middleware.use(RouteLoggingMiddleware())
        
        // Root endpoint
        app.get { req -> String in
            return "Nyl Server v1.0.0"
        }
        
        // API v1 routes
        let v1 = app.grouped("v1")
        
        v1.get("status") { [weak self] req async throws -> Response in
            guard let self = self else {
                throw Abort(.internalServerError)
            }
            
            let status = await self.getStatus()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let json = try encoder.encode(status)
            return Response(status: .ok, headers: ["Content-Type": "application/json"], body: .init(data: json))
        }
    }
    
    private func getStatus() async -> StatusResponse {
        let serverInfo = ServerInfo(
            version: "1.0.0",
            uptime: Date().timeIntervalSince(startTime),
            port: port
        )
        
        let heartbeatInfo = HeartbeatInfo(
            interval: heartbeatService?.interval ?? 1800,
            lastRun: heartbeatService?.lastRun,
            nextRun: heartbeatService?.nextRun,
            isRunning: heartbeatService?.isRunning ?? false
        )
        
        let weatherInfo: WeatherInfo? = {
            guard let weather = weatherService,
                  let lastUpdated = weather.lastUpdated else {
                return nil
            }
            
            return WeatherInfo(
                temperature: weather.temperature,
                condition: weather.condition,
                location: weather.location,
                lastUpdated: lastUpdated
            )
        }()
        
        return StatusResponse(
            server: serverInfo,
            heartbeat: heartbeatInfo,
            weather: weatherInfo
        )
    }
}

// MARK: - Middleware

/// Simple middleware for logging requests
struct RouteLoggingMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        print("📨 Request: \(request.method) \(request.url.path)")
        let response = try await next.respond(to: request)
        print("📤 Response: \(response.status.code)")
        return response
    }
}
