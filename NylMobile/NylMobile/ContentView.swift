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
    @State private var isShowingServers = false
    @State private var draftMessage = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, content: "Hi! I’m Nyl. Ask me about your system status or the weather."),
        ChatMessage(role: .user, content: "Is the server running?"),
        ChatMessage(role: .assistant, content: "Yes — it’s running and broadcasting updates.")
    ]
    @State private var streamingAssistantIndex: Int?
    @State private var streamingTextToken = ""
    @State private var lastScrollUpdate = Date.distantPast
    @AppStorage("nylAppearanceMode") private var appearanceMode = AppearanceMode.system
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: backgroundGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar
                    chatList
                    inputBar
                }
            }
            .navigationTitle("Nyl")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingServers = true
                    } label: {
                        Image(systemName: "server.rack")
                    }
                    .accessibilityLabel("Servers")
                }
            }
        }
        .preferredColorScheme(appearanceMode.preferredColorScheme)
        .sheet(isPresented: $isShowingServers) {
            serverSheet
        }
        .onAppear {
            discoveryService.startSearching()
        }
        .onChange(of: discoveryService.discoveredServers) { _, servers in
            autoConnectIfNeeded(servers)
        }
    }
    
    // MARK: - Chat UI

    private var headerBar: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nyl")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(connectionSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    isShowingServers = true
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(connectionColor)
                            .frame(width: 8, height: 8)
                        Text(connectionLabel)
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                }
            }
            .padding(.horizontal)

            if let error = apiService.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        emptyChatState
                    } else {
                        ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                            MessageBubble(message: message)
                                .id(index)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _, _ in
                if let lastIndex = messages.indices.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastIndex, anchor: .bottom)
                    }
                }
            }
            .onChange(of: streamingTextToken) { _, _ in
                if let lastIndex = messages.indices.last {
                    withAnimation(.linear(duration: 0.1)) {
                        proxy.scrollTo(lastIndex, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask Nyl anything...", text: $draftMessage, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .disabled(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || apiService.isChatStreaming)
            }

            HStack {
                Label(currentModelLabel, systemImage: "brain")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if apiService.isLoading || apiService.isChatStreaming {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var emptyChatState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.blue)
            Text("Start a conversation")
                .font(.headline)
            Text("Your server status and weather are available in chat.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(.top, 40)
    }

    private var serverSheet: some View {
        NavigationStack {
            List {
                Section("Nearby Servers") {
                    if discoveryService.discoveredServers.isEmpty {
                        Text("No servers discovered yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(discoveryService.discoveredServers) { server in
                            Button {
                                connect(to: server)
                                isShowingServers = false
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(server.name)
                                        .font(.headline)
                                    Text("\(server.host):\(server.port)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                Section("Connection") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(connectionLabel)
                            .foregroundStyle(.secondary)
                    }

                    if let server = selectedServer {
                        Button("Disconnect") {
                            disconnect()
                            isShowingServers = false
                        }
                        .foregroundStyle(.red)
                        Text("Connected to \(server.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Servers")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isShowingServers = false
                    }
                }
            }
        }
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

    private func autoConnectIfNeeded(_ servers: [DiscoveredServer]) {
        guard selectedServer == nil, let first = servers.first else { return }
        connect(to: first)
    }

    private func sendMessage() {
        let trimmed = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let userMessage = ChatMessage(role: .user, content: trimmed)
        let requestMessages = messages + [userMessage]
        messages.append(userMessage)
        draftMessage = ""

        messages.append(ChatMessage(role: .assistant, content: ""))
        streamingAssistantIndex = messages.count - 1

        apiService.streamChat(messages: requestMessages) { [weak apiService] event in
            guard apiService != nil else { return }
            switch event.type {
            case .delta:
                if let index = streamingAssistantIndex, let delta = event.delta {
                    let current = messages[index].content + delta
                    messages[index] = ChatMessage(role: .assistant, content: current)
                    if Date().timeIntervalSince(lastScrollUpdate) > 0.08 {
                        lastScrollUpdate = Date()
                        streamingTextToken = current
                    }
                }
            case .done:
                streamingAssistantIndex = nil
                streamingTextToken = ""
            case .error:
                streamingAssistantIndex = nil
                streamingTextToken = ""
                if let message = event.error {
                    apiService.error = message
                }
            }
        }
    }

    private var connectionLabel: String {
        if selectedServer == nil {
            return discoveryService.isSearching ? "Searching..." : "Disconnected"
        }
        return apiService.isWebSocketConnected ? "Live" : "Connected"
    }

    private var connectionSubtitle: String {
        if let server = selectedServer {
            return "\(server.name) • \(server.host):\(server.port)"
        }
        return "Looking for a nearby server"
    }

    private var connectionColor: Color {
        if selectedServer == nil {
            return discoveryService.isSearching ? .orange : .gray
        }
        return apiService.isWebSocketConnected ? .green : .yellow
    }

    private var currentModelLabel: String {
        if let model = apiService.modelsResponse?.selectedModel {
            return model
        }
        return "Default model"
    }

    private var backgroundGradientColors: [Color] {
        switch appearanceMode {
        case .dark:
            return [Color(red: 0.07, green: 0.08, blue: 0.12), Color(red: 0.12, green: 0.12, blue: 0.18)]
        case .light:
            return [Color(white: 0.97), Color(white: 0.93)]
        case .system:
            if colorScheme == .dark {
                return [Color(red: 0.07, green: 0.08, blue: 0.12), Color(red: 0.12, green: 0.12, blue: 0.18)]
            }
            return [Color(white: 0.97), Color(white: 0.93)]
        }
    }
}

#Preview {
    ContentView()
}
private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .assistant {
                bubble
                Spacer()
            } else {
                Spacer()
                bubble
            }
        }
    }

    private var bubble: some View {
        Text(message.content)
            .font(.body)
            .foregroundColor(message.role == .assistant ? .primary : .white)
            .padding(12)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            .frame(maxWidth: 280, alignment: message.role == .assistant ? .leading : .trailing)
    }

    private var bubbleBackground: some View {
        if message.role == .assistant {
            return AnyView(Color(uiColor: .secondarySystemBackground))
        }

        return AnyView(
            LinearGradient(
                colors: [Color.blue.opacity(0.85), Color.indigo.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
