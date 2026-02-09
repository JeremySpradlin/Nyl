//
//  OllamaClient.swift
//  NylServer
//
//  Created by Jeremy Spradlin on 2/8/26.
//

import Foundation

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
        // Ollama's model list endpoint is at /api/tags (not under /v1)
        let ollamaAPIURL = baseURL.replacingOccurrences(of: "/v1", with: "")
        guard let url = URL(string: "\(ollamaAPIURL)/api/tags") else {
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
}

// MARK: - Models

/// Response from Ollama's /api/tags endpoint
struct OllamaModelsResponse: Codable {
    let models: [OllamaModel]
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
