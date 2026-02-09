//
//  NylServerApp.swift
//  NylServer
//
//  Created by Jeremy Spradlin on 2/5/26.
//

import SwiftUI
import Combine

// Coordinator to manage service initialization (Singleton)
@MainActor
class AppCoordinator: ObservableObject {
    static let shared = AppCoordinator()
    
    let weatherService = WeatherService()
    let heartbeatService = HeartbeatService()
    let serverService = ServerService()
    let bonjourService = BonjourService()
    let settingsService = SettingsService()
    
    private var hasInitialized = false
    
    private init() {
        print("📦 AppCoordinator singleton created")
        // DO NOT start initialization here - will be called from AppDelegate
    }
    
    func initialize() async {
        guard !hasInitialized else { 
            print("⚠️ Services already initialized, skipping...")
            return 
        }
        hasInitialized = true
        
        print("🚀 Initializing services...")
        
        // Connect services
        heartbeatService.weatherService = weatherService
        heartbeatService.serverService = serverService
        weatherService.serverService = serverService
        serverService.heartbeatService = heartbeatService
        serverService.weatherService = weatherService
        serverService.settingsService = settingsService
        
        // Start heartbeat service
        heartbeatService.start()
        
        // Request location for weather
        weatherService.requestLocationAndFetchWeather()
        
        // Start HTTP server
        do {
            try await serverService.start()
            
            // Start Bonjour advertising
            bonjourService.startAdvertising(port: serverService.port)
        } catch {
            print("❌ Failed to start server: \(error)")
        }
    }
}

@main
struct NylServerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let coordinator = AppCoordinator.shared
    
    var body: some Scene {
        MenuBarExtra("Nyl", systemImage: "heart.text.square.fill") {
            ContentView()
                .environmentObject(coordinator.weatherService)
                .environmentObject(coordinator.heartbeatService)
                .environmentObject(coordinator.serverService)
                .environmentObject(coordinator.bonjourService)
                .environmentObject(coordinator.settingsService)
        }
        .menuBarExtraStyle(.window)
        
        // Settings window
        Window("Settings", id: "settings") {
            SettingsView(settingsService: coordinator.settingsService)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
