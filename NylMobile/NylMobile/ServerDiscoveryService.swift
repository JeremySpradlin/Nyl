//
//  ServerDiscoveryService.swift
//  NylMobile
//
//  Created by Jeremy Spradlin on 2/8/26.
//

import Foundation
import Combine
import Network

/// Service that discovers NylServer via Bonjour using Network framework
@MainActor
class ServerDiscoveryService: ObservableObject {
    // MARK: - Published Properties
    
    @Published var discoveredServers: [DiscoveredServer] = []
    @Published var isSearching: Bool = false
    
    // MARK: - Private Properties
    
    private var browser: NWBrowser?
    private var discoveredEndpoints: [NWEndpoint: NWBrowser.Result] = [:]
    private var activeConnections: [NWEndpoint: NWConnection] = [:]
    private var endpointToServer: [NWEndpoint: DiscoveredServer] = [:]
    
    // MARK: - Public Methods
    
    /// Start searching for Nyl servers on the network
    func startSearching() {
        guard !isSearching else { 
            print("🔍 Already searching, skipping")
            return 
        }
        
        print("🔍 Starting Bonjour search for _nyl._tcp services using Network framework")
        isSearching = true
        discoveredServers.removeAll()
        discoveredEndpoints.removeAll()
        endpointToServer.removeAll()
        
        // Create browser parameters for Bonjour service discovery
        let parameters = NWParameters()
        parameters.includePeerToPeer = false // We're not using peer-to-peer
        
        // Create browser descriptor for the service type
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: "_nyl._tcp", domain: nil), using: parameters)
        
        // Set up state change handler
        browser.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor [weak self] in
                self?.handleBrowserStateChange(newState)
            }
        }
        
        // Set up browse results handler
        browser.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor [weak self] in
                self?.handleBrowseResults(results, changes: changes)
            }
        }
        
        // Start browsing on main queue
        browser.start(queue: .main)
        self.browser = browser
        
        print("🔍 NWBrowser created and searching")
    }
    
    /// Stop searching for servers
    func stopSearching() {
        browser?.cancel()
        browser = nil
        isSearching = false
        discoveredEndpoints.removeAll()
        endpointToServer.removeAll()
        
        // Cancel all active connections
        for connection in activeConnections.values {
            connection.cancel()
        }
        activeConnections.removeAll()
    }
    
    // MARK: - Private Handlers
    
    private func handleBrowserStateChange(_ state: NWBrowser.State) {
        print("🔍 Browser state changed: \(state)")
        
        switch state {
        case .ready:
            print("✅ Browser is ready")
        case .failed(let error):
            print("❌ Browser failed: \(error)")
            // Check if it's a policy denied error (no local network permission)
            if case .dns(let dnsError) = error, dnsError == kDNSServiceErr_PolicyDenied {
                print("❌ Local network access denied - check Settings → Privacy → Local Network")
            }
            isSearching = false
        case .cancelled:
            print("⚠️ Browser cancelled")
            isSearching = false
        case .waiting(let error):
            print("⏳ Browser waiting: \(error)")
        @unknown default:
            break
        }
    }
    
    private func handleBrowseResults(_ results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        print("📡 Browse results changed. Total results: \(results.count), Changes: \(changes.count)")
        
        for change in changes {
            switch change {
            case .added(let result):
                print("✅ Service added: \(result.endpoint)")
                handleServiceAdded(result)
            case .removed(let result):
                print("❌ Service removed: \(result.endpoint)")
                handleServiceRemoved(result)
            case .identical:
                break
            @unknown default:
                break
            }
        }
    }
    
    private func handleServiceAdded(_ result: NWBrowser.Result) {
        guard case .service(let name, let type, let domain, _) = result.endpoint else {
            print("⚠️ Endpoint is not a Bonjour service")
            return
        }
        
        print("🔧 Resolving service: \(name)")
        discoveredEndpoints[result.endpoint] = result
        
        // Cancel any existing connection for this endpoint
        if let existingConnection = activeConnections[result.endpoint] {
            existingConnection.cancel()
        }
        
        // Extract connection details from the endpoint
        // For Bonjour services, we need to create a connection to resolve the address
        let connection = NWConnection(to: result.endpoint, using: .tcp)
        activeConnections[result.endpoint] = connection
        
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            Task { @MainActor [weak self] in
                guard let self = self, let connection = connection else { return }
                if case .ready = state {
                    if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                       case .hostPort(let host, let port) = innerEndpoint {
                        var hostString = "\(host)"
                        
                        // Strip IPv6 zone identifier (e.g., %en0) if present
                        if let percentIndex = hostString.firstIndex(of: "%") {
                            hostString = String(hostString[..<percentIndex])
                        }
                        
                        let portInt = Int(port.rawValue)
                        
                        let server = DiscoveredServer(
                            name: name,
                            host: hostString,
                            port: portInt
                        )
                        
                        print("✅ Resolved server: \(server.name) at \(server.host):\(server.port)")
                        
                        if !self.discoveredServers.contains(where: { $0.host == server.host && $0.port == server.port }) {
                            self.discoveredServers.append(server)
                            self.endpointToServer[result.endpoint] = server
                            self.isSearching = false // Stop showing spinner once we find a server
                            print("✅ Added server to list. Total servers: \(self.discoveredServers.count)")
                        }
                    }
                    // Clean up connection after resolution
                    connection.cancel()
                    self.activeConnections.removeValue(forKey: result.endpoint)
                } else if case .failed(_) = state {
                    connection.cancel()
                    self.activeConnections.removeValue(forKey: result.endpoint)
                }
            }
        }
        
        connection.start(queue: .main)
    }
    
    private func handleServiceRemoved(_ result: NWBrowser.Result) {
        guard case .service(let name, _, _, _) = result.endpoint else { return }
        
        // Cancel any active connection for this endpoint
        if let connection = activeConnections[result.endpoint] {
            connection.cancel()
            activeConnections.removeValue(forKey: result.endpoint)
        }
        
        discoveredEndpoints.removeValue(forKey: result.endpoint)
        if let server = endpointToServer.removeValue(forKey: result.endpoint) {
            discoveredServers.removeAll { $0.host == server.host && $0.port == server.port }
        } else {
            discoveredServers.removeAll { $0.name == name }
        }
        print("🗑️ Removed server: \(name)")
    }
}

// MARK: - Models

struct DiscoveredServer: Identifiable {
    let id = UUID()
    let name: String
    let host: String
    let port: Int
    
    var baseURL: String {
        "http://\(host):\(port)"
    }
}
