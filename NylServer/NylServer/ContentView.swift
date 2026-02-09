//
//  ContentView.swift
//  NylServer
//
//  Created by Jeremy Spradlin on 2/5/26.
//

import SwiftUI
import NylKit

struct ContentView: View {
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var heartbeatService: HeartbeatService
    @EnvironmentObject var serverService: ServerService
    @EnvironmentObject var bonjourService: BonjourService
    @EnvironmentObject var settingsService: SettingsService
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundStyle(.pink)
                Text("Nyl Server")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // Heartbeat Section
            VStack(alignment: .leading, spacing: 8) {
                Label("Heartbeat", systemImage: "heart.fill")
                    .font(.headline)
                    .foregroundStyle(.pink)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Interval:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatInterval(heartbeatService.interval))
                            .fontWeight(.medium)
                    }
                    
                    if let lastRun = heartbeatService.lastRun {
                        HStack {
                            Text("Last run:")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(lastRun, style: .relative)
                                .fontWeight(.medium)
                        }
                    }
                    
                    if let nextRun = heartbeatService.nextRun {
                        HStack {
                            Text("Next run:")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(nextRun, style: .relative)
                                .fontWeight(.medium)
                        }
                    }
                }
                .font(.caption)
                
                // Heartbeat interval slider
                VStack(alignment: .leading, spacing: 4) {
                    Text("Adjust Interval")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("5m")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Slider(value: $heartbeatService.interval, in: 300...7200, step: 300)
                        Text("2h")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button(action: heartbeatService.triggerNow) {
                    Label("Run Now", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            Divider()
            
            // Weather Section
            VStack(alignment: .leading, spacing: 8) {
                Label("Weather", systemImage: "cloud.sun.fill")
                    .font(.headline)
                    .foregroundStyle(.blue)
                
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(weatherService.temperature))°F")
                            .font(.system(size: 32, weight: .bold))
                        Text(weatherService.condition)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(weatherService.location)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let lastUpdated = weatherService.lastUpdated {
                            Text("Updated \(lastUpdated, style: .relative)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Divider()
            
            // Server Section
            VStack(alignment: .leading, spacing: 8) {
                Label("Server", systemImage: "server.rack")
                    .font(.headline)
                    .foregroundStyle(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Status:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(serverService.isRunning ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(serverService.isRunning ? "Running" : "Stopped")
                                .fontWeight(.medium)
                        }
                    }
                    
                    HStack {
                        Text("Port:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(serverService.port)")
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Bonjour:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(bonjourService.isAdvertising ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(bonjourService.isAdvertising ? "Advertising" : "Off")
                                .fontWeight(.medium)
                        }
                    }
                    
                    if let error = serverService.error {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption)
            }
            
            Divider()
            
            // AI Status (if enabled)
            if settingsService.settings.aiEnabled && settingsService.settings.aiProvider != .disabled {
                VStack(alignment: .leading, spacing: 8) {
                    Label("AI Assistant", systemImage: "brain")
                        .font(.headline)
                        .foregroundStyle(.purple)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Provider:")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(settingsService.settings.aiProvider.rawValue.capitalized)
                                .fontWeight(.medium)
                        }
                        
                        if settingsService.settings.aiProvider == .ollama,
                           let model = settingsService.settings.ollamaModel {
                            HStack {
                                Text("Model:")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(model)
                                    .fontWeight(.medium)
                            }
                        } else if settingsService.settings.aiProvider == .claude {
                            HStack {
                                Text("Model:")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(settingsService.settings.claudeModel)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .font(.caption)
                }
                
                Divider()
            }
            
            // Controls
            HStack {
                Button("Settings...") {
                    openWindow(id: "settings")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .frame(width: 340)
    }
    
    // MARK: - Helper Methods
    
    private func formatInterval(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) hr"
            } else {
                return "\(hours) hr \(remainingMinutes) min"
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WeatherService())
        .environmentObject(HeartbeatService())
        .environmentObject(ServerService())
        .environmentObject(BonjourService())
        .environmentObject(SettingsService())
}
