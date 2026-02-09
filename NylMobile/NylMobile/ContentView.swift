//
//  ContentView.swift
//  NylMobile
//
//  Created by Jeremy Spradlin on 2/8/26.
//

import SwiftUI
import NylKit

struct ContentView: View {
    @StateObject private var discoveryService = ServerDiscoveryService()
    @StateObject private var apiService = NylAPIService()
    @State private var selectedServer: DiscoveredServer?
    
    var body: some View {
        NavigationStack {
            Group {
                if let selectedServer = selectedServer {
                    // Connected view
                    connectedView
                } else {
                    // Discovery view
                    discoveryView
                }
            }
            .navigationTitle("Nyl")
            .toolbar {
                if selectedServer != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Disconnect") {
                            disconnect()
                        }
                    }
                }
            }
        }
        .onAppear {
            discoveryService.startSearching()
        }
    }
    
    // MARK: - Discovery View
    
    private var discoveryView: some View {
        VStack(spacing: 20) {
            if discoveryService.isSearching {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Searching for Nyl Server...")
                    .foregroundStyle(.secondary)
            }
            
            if discoveryService.discoveredServers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    Text("No servers found")
                        .font(.headline)
                    Text("Make sure NylServer is running on your Mac")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // Manual connection can be added here if needed for debugging
                }
                .padding()
            } else {
                List(discoveryService.discoveredServers) { server in
                    Button {
                        connect(to: server)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(server.name)
                                .font(.headline)
                            Text("\(server.host):\(server.port)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }
    
    // MARK: - Connected View
    
    private var connectedView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Connection status
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                        Text("Connected to \(selectedServer?.name ?? "Server")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    
                    // WebSocket status indicator
                    HStack(spacing: 8) {
                        Image(systemName: apiService.isWebSocketConnected ? "wifi" : "wifi.slash")
                            .foregroundStyle(apiService.isWebSocketConnected ? .green : .red)
                            .font(.caption)
                        
                        Text(apiService.isWebSocketConnected ? "Live updates active" : "Live updates offline")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // Event indicator
                        if let eventType = apiService.lastWebSocketEvent {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 6, height: 6)
                                Text(eventType.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                            .transition(.opacity)
                        }
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                
                if apiService.isLoading {
                    ProgressView()
                        .padding()
                }
                
                if let error = apiService.error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding()
                }
                
                if let status = apiService.status {
                    // Server Info
                    statusCard(title: "Server", icon: "server.rack", color: .blue) {
                        infoRow(label: "Version", value: status.server.version)
                        infoRow(label: "Port", value: "\(status.server.port)")
                        infoRow(label: "Uptime", value: formatUptime(status.server.uptime))
                    }
                    
                    // Heartbeat Info
                    statusCard(title: "Heartbeat", icon: "heart.fill", color: .pink) {
                        infoRow(label: "Status", value: status.heartbeat.isRunning ? "Running" : "Stopped")
                        infoRow(label: "Interval", value: formatInterval(status.heartbeat.interval))
                        if let lastRun = status.heartbeat.lastRun {
                            infoRowWithDate(label: "Last Run", date: lastRun)
                        }
                        if let nextRun = status.heartbeat.nextRun {
                            infoRowWithDate(label: "Next Run", date: nextRun)
                        }
                    }
                    
                    // Weather Info
                    if let weather = status.weather {
                        statusCard(title: "Weather", icon: "cloud.sun.fill", color: .orange) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(Int(weather.temperature))°F")
                                        .font(.system(size: 48, weight: .bold))
                                    Text(weather.condition)
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(weather.location)
                                        .font(.caption)
                                    HStack(spacing: 2) {
                                        Text("Updated")
                                        Text(weather.lastUpdated, style: .relative)
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    
                    if let lastUpdated = apiService.lastUpdated {
                        HStack(spacing: 4) {
                            Text("Last updated")
                            Text(lastUpdated, style: .relative)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
                
                // Refresh button
                Button {
                    Task {
                        await apiService.fetchStatus()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiService.isLoading)
            }
            .padding()
        }
    }
    
    // MARK: - Helper Views
    
    private func statusCard<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
            
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
    
    private func infoRowWithDate(label: String, date: Date) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(date, style: .relative)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
    
    // MARK: - Actions
    
    private func connect(to server: DiscoveredServer) {
        selectedServer = server
        apiService.connect(to: server)
        discoveryService.stopSearching()
    }
    
    private func disconnect() {
        selectedServer = nil
        apiService.disconnect()
        discoveryService.startSearching()
    }
    
    // MARK: - Formatters
    
    private func formatUptime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    ContentView()
}
