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
    weak var settingsService: SettingsService?
    let wsManager = WebSocketManager()
    
    // MARK: - Public Methods
    
    /// Start the HTTP server
    func start() async throws {
        guard !isRunning, application == nil else {
            return
        }
        error = nil
        
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
        
        // Start the server using Vapor's async boot + run pattern
        try await app.asyncBoot()
        
        // Start server in detached task so it doesn't block
        Task { [weak self] in
            do {
                try await app.server.start(address: .hostname(app.http.server.configuration.hostname, port: app.http.server.configuration.port))
                await MainActor.run {
                    self?.isRunning = true
                }
            } catch {
                await MainActor.run {
                    self?.error = "Failed to start server: \(error.localizedDescription)"
                    self?.isRunning = false
                    self?.application = nil
                }
                app.shutdown()
            }
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
        app.middleware.use(LocalNetworkOnlyMiddleware())
        
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

        // Models endpoint
        v1.get("models") { [weak self] req async throws -> Response in
            guard let self = self else {
                throw Abort(.internalServerError)
            }
            let response = try await self.getModelsResponse()
            return try self.jsonResponse(response)
        }

        v1.put("models", "selected") { [weak self] req async throws -> Response in
            guard let self = self else {
                throw Abort(.internalServerError)
            }
            let payload = try req.content.decode(SelectModelRequest.self)
            try self.updateSelectedModel(payload.model)
            let response = try await self.getModelsResponse()
            return try self.jsonResponse(response)
        }

        // Chat endpoints
        v1.post("chat") { [weak self] req async throws -> Response in
            guard let self = self else {
                throw Abort(.internalServerError)
            }
            let payload = try req.content.decode(ChatRequest.self)
            let chatResponse = try await self.handleChat(payload)
            return try self.jsonResponse(chatResponse)
        }

        v1.post("chat", "stream") { [weak self] req async throws -> Response in
            guard let self = self else {
                throw Abort(.internalServerError)
            }
            let payload = try req.content.decode(ChatRequest.self)
            return self.handleChatStream(payload, req: req)
        }

        // WebSocket endpoint for real-time updates
        app.webSocket("ws", "updates") { [weak self] req, ws async in
            guard let self = self else { return }

            let clientID = UUID()
            await self.wsManager.addConnection(id: clientID, socket: ws)

            // Send initial connection confirmation
            let connectedEvent = WebSocketEvent(
                type: .connected,
                timestamp: Date(),
                payload: await self.getStatus()
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(connectedEvent),
               let json = String(data: data, encoding: .utf8) {
                try? await ws.send(json)
            }

            // Handle client disconnect
            ws.onClose.whenComplete { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.wsManager.removeConnection(id: clientID)
                }
            }
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

    /// Broadcast a status update to all connected WebSocket clients
    func broadcastStatusUpdate() async {
        let status = await getStatus()
        let event = WebSocketEvent(
            type: .statusUpdate,
            timestamp: Date(),
            payload: status
        )
        wsManager.broadcast(event)
    }

    // MARK: - Models

    private func getModelsResponse() async throws -> ModelsResponse {
        guard let settingsService = settingsService else {
            throw Abort(.internalServerError, reason: "Settings unavailable")
        }

        let provider = settingsService.settings.aiProvider
        let selectedModel = selectedModel(for: provider)

        switch provider {
        case .ollama:
            let client = OllamaClient(baseURL: settingsService.settings.ollamaBaseURL)
            let models = try await client.listModels()
            let modelInfos = models.map {
                ModelInfo(
                    id: $0.name,
                    name: $0.name,
                    provider: .ollama,
                    sizeBytes: $0.size,
                    modifiedAt: $0.modifiedAt
                )
            }
            return ModelsResponse(provider: provider, selectedModel: selectedModel, models: modelInfos)
        case .claude:
            let modelInfos = claudeModelOptions().map { modelId in
                ModelInfo(id: modelId, name: modelId, provider: .claude)
            }
            return ModelsResponse(provider: provider, selectedModel: selectedModel, models: modelInfos)
        case .disabled:
            return ModelsResponse(provider: provider, selectedModel: nil, models: [])
        }
    }

    private func updateSelectedModel(_ model: String) throws {
        guard let settingsService = settingsService else {
            throw Abort(.internalServerError, reason: "Settings unavailable")
        }

        switch settingsService.settings.aiProvider {
        case .ollama:
            settingsService.settings.ollamaModel = model
        case .claude:
            settingsService.settings.claudeModel = model
        case .disabled:
            throw Abort(.forbidden, reason: "AI provider disabled")
        }
    }

    private func selectedModel(for provider: AIProviderType) -> String? {
        guard let settingsService = settingsService else { return nil }

        switch provider {
        case .ollama:
            return settingsService.settings.ollamaModel
        case .claude:
            return settingsService.settings.claudeModel
        case .disabled:
            return nil
        }
    }

    private func claudeModelOptions() -> [String] {
        return [
            "claude-opus-4-5-20251101",
            "claude-sonnet-4-5-20250929",
            "claude-3-5-sonnet-20241022",
            "claude-3-5-haiku-20241022"
        ]
    }

    // MARK: - Chat

    private func handleChat(_ request: ChatRequest) async throws -> ChatResponse {
        guard let settingsService = settingsService else {
            throw Abort(.internalServerError, reason: "Settings unavailable")
        }

        guard settingsService.settings.aiEnabled,
              settingsService.settings.aiProvider != .disabled else {
            throw Abort(.forbidden, reason: "AI features are disabled")
        }

        let provider = settingsService.settings.aiProvider
        let model = request.model ?? selectedModel(for: provider)
        guard let model = model, !model.isEmpty else {
            throw Abort(.badRequest, reason: "Model is required")
        }

        switch provider {
        case .ollama:
            let client = OllamaClient(baseURL: settingsService.settings.ollamaBaseURL)
            let response = try await client.chat(
                model: model,
                messages: mergedMessages(request.messages, systemPrompt: settingsService.settings.systemPrompt),
                temperature: request.temperature
            )
            return response
        case .claude:
            guard let apiKey = settingsService.loadClaudeAPIKey(), !apiKey.isEmpty else {
                throw Abort(.badRequest, reason: "Claude API key not configured")
            }
            let client = ClaudeClient(apiKey: apiKey)
            let response = try await client.chat(
                model: model,
                messages: request.messages,
                systemPrompt: settingsService.settings.systemPrompt,
                temperature: request.temperature
            )
            return response
        case .disabled:
            throw Abort(.forbidden, reason: "AI provider disabled")
        }
    }

    private func handleChatStream(_ request: ChatRequest, req: Request) -> Response {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let response = Response(status: .ok)
        response.headers.replaceOrAdd(name: .contentType, value: "text/event-stream")
        response.headers.replaceOrAdd(name: "Cache-Control", value: "no-cache")
        response.headers.replaceOrAdd(name: "Connection", value: "keep-alive")

        response.body = .init(stream: { writer in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                do {
                    try await self.streamChat(request, encoder: encoder) { event in
                        let json = try encoder.encode(event)
                        var buffer = ByteBufferAllocator().buffer(capacity: json.count + 8)
                        buffer.writeString("data: ")
                        buffer.writeBytes(json)
                        buffer.writeString("\n\n")
                        try await writer.write(.buffer(buffer))
                    }
                } catch {
                    let event = ChatStreamEvent(type: .error, error: error.localizedDescription)
                    if let json = try? encoder.encode(event) {
                        var buffer = ByteBufferAllocator().buffer(capacity: json.count + 8)
                        buffer.writeString("data: ")
                        buffer.writeBytes(json)
                        buffer.writeString("\n\n")
                        try? await writer.write(.buffer(buffer))
                    }
                }

                try? await writer.write(.end)
            }
        })

        return response
    }

    private func streamChat(
        _ request: ChatRequest,
        encoder: JSONEncoder,
        sendEvent: @escaping (ChatStreamEvent) async throws -> Void
    ) async throws {
        guard let settingsService = settingsService else {
            throw Abort(.internalServerError, reason: "Settings unavailable")
        }

        guard settingsService.settings.aiEnabled,
              settingsService.settings.aiProvider != .disabled else {
            throw Abort(.forbidden, reason: "AI features are disabled")
        }

        let provider = settingsService.settings.aiProvider
        let model = request.model ?? selectedModel(for: provider)
        guard let model = model, !model.isEmpty else {
            throw Abort(.badRequest, reason: "Model is required")
        }

        switch provider {
        case .ollama:
            let client = OllamaClient(baseURL: settingsService.settings.ollamaBaseURL)
            try await client.streamChat(
                model: model,
                messages: mergedMessages(request.messages, systemPrompt: settingsService.settings.systemPrompt),
                temperature: request.temperature
            ) { delta in
                try await sendEvent(ChatStreamEvent(type: .delta, delta: delta))
            }
            try await sendEvent(ChatStreamEvent(type: .done))
        case .claude:
            guard let apiKey = settingsService.loadClaudeAPIKey(), !apiKey.isEmpty else {
                throw Abort(.badRequest, reason: "Claude API key not configured")
            }
            let client = ClaudeClient(apiKey: apiKey)
            let response = try await client.chat(
                model: model,
                messages: request.messages,
                systemPrompt: settingsService.settings.systemPrompt,
                temperature: request.temperature
            )
            try await sendEvent(ChatStreamEvent(type: .delta, delta: response.message.content))
            try await sendEvent(ChatStreamEvent(type: .done))
        case .disabled:
            throw Abort(.forbidden, reason: "AI provider disabled")
        }
    }

    private func mergedMessages(_ messages: [ChatMessage], systemPrompt: String) -> [ChatMessage] {
        let prompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if prompt.isEmpty {
            return messages
        }

        return [ChatMessage(role: .system, content: prompt)] + messages
    }

    private func jsonResponse<T: Encodable>(_ value: T) throws -> Response {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let json = try encoder.encode(value)
        return Response(status: .ok, headers: ["Content-Type": "application/json"], body: .init(data: json))
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
