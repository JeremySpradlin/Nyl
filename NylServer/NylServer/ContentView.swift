//
//  ContentView.swift
//  NylServer
//
//  Created by Jeremy Spradlin on 2/5/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var heartbeatService: HeartbeatService
    
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
            
            // Controls
            HStack {
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .frame(width: 320)
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
}
