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
    
    // MARK: - Private Properties
    
    private var baseURL: String?
    private let session: URLSession
    
    // MARK: - Initialization
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Public Methods
    
    /// Connect to a discovered server
    func connect(to server: DiscoveredServer) {
        baseURL = server.baseURL
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
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
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
        baseURL = nil
        status = nil
        error = nil
        lastUpdated = nil
    }
    
    deinit {
        session.invalidateAndCancel()
    }
}
