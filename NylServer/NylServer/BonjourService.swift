//
//  BonjourService.swift
//  NylServer
//
//  Created by Jeremy Spradlin on 2/6/26.
//

import Foundation
import Combine

/// Service that advertises the Nyl server via Bonjour
@MainActor
class BonjourService: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    @Published var isAdvertising: Bool = false
    
    // MARK: - Private Properties
    
    private var netService: NetService?
    private let serviceType = "_nyl._tcp"
    private let serviceDomain = ""
    
    // MARK: - Public Methods
    
    /// Start advertising the service via Bonjour
    func startAdvertising(port: Int, name: String = "Nyl Server") {
        guard !isAdvertising, netService == nil else { 
            print("Bonjour already advertising or service exists")
            return 
        }
        
        let service = NetService(domain: serviceDomain, type: serviceType, name: name, port: Int32(port))
        service.delegate = self
        
        // Publish the service (just advertise, don't listen - HTTP server handles connections)
        service.publish()
        
        netService = service
        // isAdvertising will be set to true in netServiceDidPublish delegate method
    }
    
    /// Stop advertising the service
    func stopAdvertising() {
        guard isAdvertising else { return }
        
        netService?.stop()
        netService = nil
        isAdvertising = false
    }
    
    deinit {
        netService?.stop()
    }
}

// MARK: - NetServiceDelegate

extension BonjourService: NetServiceDelegate {
    nonisolated func netServiceDidPublish(_ sender: NetService) {
        Task { @MainActor in
            print("Bonjour service published: \(sender.name)")
            isAdvertising = true
        }
    }
    
    nonisolated func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        Task { @MainActor in
            let errorCode = errorDict["NSNetServicesErrorCode"]?.intValue ?? -1
            print("❌ Bonjour service failed to publish (error \(errorCode)): \(errorDict)")
            isAdvertising = false
            netService = nil
        }
    }
    
    nonisolated func netServiceDidStop(_ sender: NetService) {
        Task { @MainActor in
            print("Bonjour service stopped")
            isAdvertising = false
        }
    }
}
