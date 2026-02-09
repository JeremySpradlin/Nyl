//
//  OllamaClient.swift
//  NylServer
//
//  Created by Jeremy Spradlin on 2/8/26.
//

import Foundation
import NylKit

/// Client for communicating with Ollama API
class OllamaClient {
    // MARK: - Properties
    
    private let baseURL: String
    private let session: URLSession
    
    // MARK: - Initialization
    
    init(baseURL: String) {
        self.baseURL = baseURL
        self.session = URLSession.shared
    }
    
    // MARK: - API Methods
    
    /// Fetch list of available models from Ollama
    func listModels() async throws -> [OllamaModel] {
        // Ollama's model list endpoint is at /api/tags
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            throw OllamaError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw OllamaError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let modelResponse = try decoder.decode(OllamaModelsResponse.self, from: data)
        return modelResponse.models
    }
    
    /// Test connection to Ollama by attempting to list models
    func testConnection() async throws -> Bool {
        let models = try await listModels()
        return !models.isEmpty
    }

    /// Chat with Ollama using the /api/chat endpoint (non-streaming).
    func chat(model: String, messages: [ChatMessage], temperature: Double?) async throws -> ChatResponse {
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw OllamaError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let payload = OllamaChatRequest(
            model: model,
            messages: messages.map { OllamaChatMessage(role: $0.role.rawValue, content: $0.content) },
            stream: false,
            options: temperature.map { ["temperature": $0] }
        )

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw OllamaError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let chatResponse = try decoder.decode(OllamaChatResponse.self, from: data)

        let message = ChatMessage(role: .assistant, content: chatResponse.message.content)
        return ChatResponse(
            id: UUID().uuidString,
            message: message,
            model: chatResponse.model,
            createdAt: chatResponse.createdAt
        )
    }

    /// Stream chat responses from Ollama and forward deltas.
    func streamChat(
        model: String,
        messages: [ChatMessage],
        temperature: Double?,
        onDelta: @escaping (String) async throws -> Void
    ) async throws {
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw OllamaError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let payload = OllamaChatRequest(
            model: model,
            messages: messages.map { OllamaChatMessage(role: $0.role.rawValue, content: $0.content) },
            stream: true,
            options: temperature.map { ["temperature": $0] }
        )

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw OllamaError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }

            guard let data = trimmed.data(using: .utf8) else { continue }
            if let chunk = try? decoder.decode(OllamaChatStreamChunk.self, from: data) {
                if let content = chunk.message?.content, !content.isEmpty {
                    try await onDelta(content)
                }
            }
        }
    }
}

// MARK: - Models

/// Response from Ollama's /api/tags endpoint
struct OllamaModelsResponse: Codable {
    let models: [OllamaModel]
}

struct OllamaChatRequest: Codable {
    let model: String
    let messages: [OllamaChatMessage]
    let stream: Bool
    let options: [String: Double]?
}

struct OllamaChatMessage: Codable {
    let role: String
    let content: String
}

struct OllamaChatResponse: Codable {
    let model: String
    let createdAt: Date
    let message: OllamaChatMessage

    enum CodingKeys: String, CodingKey {
        case model
        case createdAt = "created_at"
        case message
    }
}

struct OllamaChatStreamChunk: Codable {
    let message: OllamaChatMessage?
    let done: Bool?
}

/// Ollama model information
struct OllamaModel: Codable, Identifiable {
    let name: String
    let size: Int64
    let modifiedAt: Date
    
    var id: String { name }
    
    enum CodingKeys: String, CodingKey {
        case name
        case size
        case modifiedAt = "modified_at"
    }
    
    /// Human-readable size string
    var sizeString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Errors

enum OllamaError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Ollama URL"
        case .invalidResponse:
            return "Invalid response from Ollama"
        case .httpError(let statusCode):
            return "HTTP error \(statusCode)"
        }
    }
}
