//
//  ClaudeClient.swift
//  NylServer
//
//  Created by Jeremy Spradlin on 2/8/26.
//

import Foundation
import NylKit

/// Client for communicating with Anthropic's Claude API
class ClaudeClient {
    // MARK: - Properties
    
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com"
    private let session: URLSession
    
    // MARK: - Initialization
    
    init(apiKey: String) {
        self.apiKey = apiKey
        self.session = URLSession.shared
    }
    
    // MARK: - API Methods
    
    /// Test connection to Claude API by making a minimal messages request
    func testConnection(model: String) async throws -> Bool {
        print("🧪 Testing Claude API connection...")
        print("🤖 Model: \(model)")
        
        guard let url = URL(string: "\(baseURL)/v1/messages") else {
            print("❌ Invalid URL")
            throw ClaudeError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        
        // Minimal test message
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1,
            "messages": [
                ["role": "user", "content": "hi"]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("📤 Sending request to \(url)")
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            throw ClaudeError.invalidResponse
        }
        
        print("📥 Received response: HTTP \(httpResponse.statusCode)")
        
        // Check for successful response (200-299)
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to parse error message
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Error response body: \(responseString)")
            }
            
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorResponse["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("❌ API Error: \(message)")
                throw ClaudeError.apiError(message: message)
            }
            print("❌ HTTP Error: \(httpResponse.statusCode)")
            throw ClaudeError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Verify we got a valid response structure
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let responseId = json["id"] as? String {
            print("✅ Connection successful! Response ID: \(responseId)")
            return true
        }
        
        print("❌ Invalid response structure")
        if let responseString = String(data: data, encoding: .utf8) {
            print("Response body: \(responseString)")
        }
        throw ClaudeError.invalidResponse
    }

    /// Send a chat request to Claude (non-streaming).
    func chat(
        model: String,
        messages: [ChatMessage],
        systemPrompt: String,
        temperature: Double?
    ) async throws -> ChatResponse {
        guard let url = URL(string: "\(baseURL)/v1/messages") else {
            throw ClaudeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let normalizedMessages = messages.compactMap { message -> ClaudeMessage? in
            switch message.role {
            case .user:
                return ClaudeMessage(role: "user", content: message.content)
            case .assistant:
                return ClaudeMessage(role: "assistant", content: message.content)
            case .system:
                return nil
            }
        }

        let combinedSystemPrompt = buildSystemPrompt(systemPrompt, messages: messages)

        let payload = ClaudeChatRequest(
            model: model,
            maxTokens: 512,
            messages: normalizedMessages,
            system: combinedSystemPrompt.isEmpty ? nil : combinedSystemPrompt,
            temperature: temperature
        )

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorResponse["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw ClaudeError.apiError(message: message)
            }
            throw ClaudeError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let responseBody = try decoder.decode(ClaudeChatResponse.self, from: data)

        let contentText = responseBody.content
            .filter { $0.type == "text" }
            .map { $0.text }
            .joined()

        let message = ChatMessage(role: .assistant, content: contentText)
        return ChatResponse(
            id: responseBody.id,
            message: message,
            model: responseBody.model,
            createdAt: responseBody.createdAt ?? Date()
        )
    }

    private func buildSystemPrompt(_ prompt: String, messages: [ChatMessage]) -> String {
        let extraSystemMessages = messages
            .filter { $0.role == .system }
            .map { $0.content }
            .joined(separator: "\n")

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPrompt.isEmpty {
            return extraSystemMessages
        }

        if extraSystemMessages.isEmpty {
            return trimmedPrompt
        }

        return "\(trimmedPrompt)\n\(extraSystemMessages)"
    }
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case apiError(message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Claude API URL"
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .httpError(let statusCode):
            return "HTTP error \(statusCode)"
        case .apiError(let message):
            return message
        }
    }
}

// MARK: - Models

struct ClaudeChatRequest: Codable {
    let model: String
    let maxTokens: Int
    let messages: [ClaudeMessage]
    let system: String?
    let temperature: Double?

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
        case system
        case temperature
    }
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeContentBlock: Codable {
    let type: String
    let text: String
}

struct ClaudeChatResponse: Codable {
    let id: String
    let model: String
    let content: [ClaudeContentBlock]
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case model
        case content
        case createdAt = "created_at"
    }
}
