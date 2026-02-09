//
//  ClaudeClient.swift
//  NylServer
//
//  Created by Jeremy Spradlin on 2/8/26.
//

import Foundation

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
        guard let url = URL(string: "\(baseURL)/v1/messages") else {
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
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }
        
        // Check for successful response (200-299)
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to parse error message
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorResponse["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw ClaudeError.apiError(message: message)
            }
            throw ClaudeError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Verify we got a valid response structure
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let _ = json["id"] as? String {
            return true
        }
        
        throw ClaudeError.invalidResponse
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
