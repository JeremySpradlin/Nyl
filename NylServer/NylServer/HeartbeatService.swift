//
//  HeartbeatService.swift
//  NylServer
//
//  Created by Jeremy Spradlin on 2/5/26.
//

import Foundation
import Combine

/// Service that manages periodic heartbeat tasks
@MainActor
class HeartbeatService: ObservableObject {
    // MARK: - Published Properties
    
    @Published var lastRun: Date?
    @Published var nextRun: Date?
    @Published var isRunning: Bool = false
    @Published var interval: TimeInterval = 1800 // 30 minutes default
    
    // MARK: - Private Properties
    
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Dependencies
    
    weak var weatherService: WeatherService?
    
    // MARK: - Initialization
    
    init() {
        loadSettings()
        
        // Observe interval changes to restart timer
        $interval
            .dropFirst() // Ignore initial value
            .sink { [weak self] newInterval in
                self?.saveSettings()
                self?.scheduleNextRun()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Start the heartbeat service
    func start() {
        guard !isRunning else { return }
        
        isRunning = true
        
        // Run immediately on start
        Task {
            await performHeartbeat()
        }
        
        // Schedule periodic runs
        scheduleNextRun()
    }
    
    /// Stop the heartbeat service
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        nextRun = nil
    }
    
    /// Manually trigger a heartbeat
    func triggerNow() {
        Task {
            await performHeartbeat()
            scheduleNextRun()
        }
    }
    
    // MARK: - Private Methods
    
    private func scheduleNextRun() {
        timer?.invalidate()
        
        guard isRunning else { return }
        
        let next = Date().addingTimeInterval(interval)
        nextRun = next
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performHeartbeat()
            }
        }
    }
    
    private func performHeartbeat() async {
        lastRun = Date()
        
        // Fetch weather update
        await weatherService?.fetchWeather()
        
        // Future: Add more heartbeat tasks here
        // - Check messages
        // - Run AI tasks
        // - Sync data
        // etc.
    }
    
    private func loadSettings() {
        if let savedInterval = UserDefaults.standard.object(forKey: "heartbeatInterval") as? TimeInterval {
            interval = savedInterval
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(interval, forKey: "heartbeatInterval")
    }
}
