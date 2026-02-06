//
//  NylServerApp.swift
//  NylServer
//
//  Created by Jeremy Spradlin on 2/5/26.
//

import SwiftUI

@main
struct NylServerApp: App {
    @StateObject private var weatherService = WeatherService()
    @StateObject private var heartbeatService = HeartbeatService()
    
    init() {
        // Initialize services on app launch
    }
    
    var body: some Scene {
        MenuBarExtra("Nyl", systemImage: "heart.text.square.fill") {
            ContentView()
                .environmentObject(weatherService)
                .environmentObject(heartbeatService)
                .onAppear {
                    // Connect services
                    heartbeatService.weatherService = weatherService
                    
                    // Start heartbeat service
                    heartbeatService.start()
                    
                    // Request location for weather
                    weatherService.requestLocationAndFetchWeather()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
