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
    @State private var messages: [ChatMessage] = []
    @State private var streamingAssistantIndex: Int?
    @AppStorage("nylAppearanceMode") private var appearanceMode = AppearanceMode.system
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // iOS-native system background
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                // Chat content
                chatContent
                
                // Liquid Glass input bar
                inputBar
            }
            .navigationTitle("Nyl")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    connectionButton
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 0)
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
    
    private var chatContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if messages.isEmpty {
                        emptyChatState
                    } else {
                        ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                            MessageBubble(message: message)
                                .id(index)
                                .onChange(of: message.content) { _, _ in
                                    // Scroll when any message content changes (streaming)
                                    if index == messages.count - 1 {
                                        proxy.scrollTo(index, anchor: .bottom)
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 100) // Space for input bar
            }
            .onChange(of: messages.count) { _, newCount in
                // Scroll when new message is added
                if newCount > 0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        proxy.scrollTo(newCount - 1, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var inputBar: some View {
        VStack(spacing: 0) {
            // Error banner
            if let error = apiService.error {
                errorBanner(error)
            }
            
            Divider()
                .overlay(.quaternary)
            
            VStack(spacing: 8) {
                // Main input row
                HStack(alignment: .bottom, spacing: 12) {
                    // Text field
                    TextField("Message", text: $draftMessage, axis: .vertical)
                        .lineLimit(1...5)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.regularMaterial)
                                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                        }
                        .onSubmit {
                            sendMessage()
                        }
                    
                    // Send button
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(canSendMessage ? .blue : .secondary)
                    }
                    .disabled(!canSendMessage)
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: messages.count)
                }
                
                // Status row
                HStack(spacing: 8) {
                    // Model indicator
                    Label {
                        Text(currentModelLabel)
                            .font(.caption)
                    } icon: {
                        Image(systemName: "cpu")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // Streaming indicator
                    if apiService.isChatStreaming {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.mini)
                            Text("Streaming")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 10, y: -5)
            }
        }
    }
    
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button {
                apiService.error = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
    
    private var connectionButton: some View {
        Button {
            isShowingServers = true
        } label: {
            Label {
                Text(connectionLabel)
                    .font(.subheadline.weight(.medium))
            } icon: {
                Image(systemName: connectionSymbol)
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.variableColor, isActive: discoveryService.isSearching)
            }
            .foregroundStyle(connectionColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var emptyChatState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "message.badge.waveform.fill")
                .font(.system(size: 60))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)
            
            VStack(spacing: 8) {
                Text("Start a Conversation")
                    .font(.title2.weight(.semibold))
                
                Text("Ask about weather, server status, or anything else.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Example prompts
            VStack(spacing: 10) {
                examplePromptButton("What's the weather?")
                examplePromptButton("Is the server running?")
                examplePromptButton("System status")
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }
    
    private func examplePromptButton(_ prompt: String) -> some View {
        Button {
            draftMessage = prompt
        } label: {
            Text(prompt)
                .font(.subheadline)
                .foregroundStyle(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.blue.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private var serverSheet: some View {
        NavigationStack {
            List {
                Section("Nearby Servers") {
                    if discoveryService.discoveredServers.isEmpty {
                        ContentUnavailableView(
                            "No Servers Found",
                            systemImage: "antenna.radiowaves.left.and.right.slash",
                            description: Text("Make sure your server is running on the same network.")
                        )
                        .listRowBackground(Color.clear)
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
                            }
                        }
                    }
                }
                
                Section("Connection") {
                    LabeledContent("Status") {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(connectionColor)
                                .frame(width: 8, height: 8)
                            Text(connectionLabel)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let server = selectedServer {
                        LabeledContent("Server") {
                            Text(server.name)
                                .foregroundStyle(.secondary)
                        }
                        
                        Button("Disconnect", role: .destructive) {
                            disconnect()
                            isShowingServers = false
                        }
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
        
        // Fetch available models after connecting
        Task {
            await apiService.fetchModels()
        }
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
            guard let apiService = apiService else { return }
            switch event.type {
            case .delta:
                if let index = streamingAssistantIndex, 
                   index < messages.count,
                   let delta = event.delta {
                    messages[index] = ChatMessage(
                        role: .assistant, 
                        content: messages[index].content + delta
                    )
                }
            case .done:
                streamingAssistantIndex = nil
            case .error:
                // Remove incomplete message on error
                if let index = streamingAssistantIndex, index < messages.count {
                    messages.remove(at: index)
                }
                streamingAssistantIndex = nil
                if let message = event.error {
                    apiService.error = message
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var canSendMessage: Bool {
        !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
        !apiService.isChatStreaming &&
        selectedServer != nil
    }
    
    private var connectionLabel: String {
        if selectedServer == nil {
            return discoveryService.isSearching ? "Searching" : "Disconnected"
        }
        return apiService.isWebSocketConnected ? "Live" : "Connected"
    }
    
    private var connectionSymbol: String {
        if selectedServer == nil {
            return "antenna.radiowaves.left.and.right"
        }
        return apiService.isWebSocketConnected ? "circle.fill" : "circle"
    }
    
    private var connectionColor: Color {
        if selectedServer == nil {
            return discoveryService.isSearching ? .orange : .secondary
        }
        return apiService.isWebSocketConnected ? .green : .yellow
    }
    
    private var currentModelLabel: String {
        apiService.modelsResponse?.selectedModel ?? "No model selected"
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if message.role == .assistant {
                // Avatar
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                
                // Message bubble
                Text(message.content.isEmpty ? " " : message.content)
                    .textSelection(.enabled)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 18,
                            bottomLeadingRadius: 4,
                            bottomTrailingRadius: 18,
                            topTrailingRadius: 18,
                            style: .continuous
                        )
                        .fill(.thinMaterial)
                        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
                    }
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
                
                Spacer(minLength: 60)
            } else {
                Spacer(minLength: 60)
                
                // User bubble
                Text(message.content)
                    .textSelection(.enabled)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 18,
                            bottomLeadingRadius: 18,
                            bottomTrailingRadius: 4,
                            topTrailingRadius: 18,
                            style: .continuous
                        )
                        .fill(.blue)
                    }
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
            }
        }
    }
}

// MARK: - Appearance Mode

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

#Preview {
    ContentView()
}
