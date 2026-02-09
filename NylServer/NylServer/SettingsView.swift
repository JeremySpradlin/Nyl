//
//  SettingsView.swift
//  NylServer
//
//  Created by Jeremy Spradlin on 2/8/26.
//

import SwiftUI
import NylKit

/// Settings window for NylServer configuration
struct SettingsView: View {
    @ObservedObject var settingsService: SettingsService
    
    var body: some View {
        TabView {
            GeneralSettingsView(settingsService: settingsService)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            AISettingsView(settingsService: settingsService)
                .tabItem {
                    Label("AI Configuration", systemImage: "brain")
                }
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - General Settings Tab

struct GeneralSettingsView: View {
    @ObservedObject var settingsService: SettingsService
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Heartbeat Interval:")
                        .frame(width: 150, alignment: .trailing)
                    
                    TextField("Seconds", value: $settingsService.settings.heartbeatInterval, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    
                    Text("seconds (\(formattedInterval))")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Weather Location:")
                        .frame(width: 150, alignment: .trailing)
                    
                    TextField("Auto-detect", text: Binding(
                        get: { settingsService.settings.weatherLocation ?? "" },
                        set: { settingsService.settings.weatherLocation = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    
                    Text("(leave empty for auto-detect)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            } header: {
                Text("Server Configuration")
                    .font(.headline)
            }
        }
        .padding()
    }
    
    private var formattedInterval: String {
        let minutes = Int(settingsService.settings.heartbeatInterval / 60)
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

// MARK: - AI Settings Tab

struct AISettingsView: View {
    @ObservedObject var settingsService: SettingsService
    @State private var claudeAPIKey: String = ""
    @State private var isTestingConnection = false
    @State private var testResult: String?
    @State private var isFetchingModels = false
    @State private var availableModels: [OllamaModel] = []
    @State private var modelFetchError: String?
    
    var body: some View {
        Form {
            // AI Enable Toggle
            Section {
                Toggle("Enable AI Features", isOn: $settingsService.settings.aiEnabled)
            }
            
            // Provider Selection
            if settingsService.settings.aiEnabled {
                Section {
                    Picker("AI Provider:", selection: $settingsService.settings.aiProvider) {
                        Text("Ollama").tag(AIProviderType.ollama)
                        Text("Claude (Anthropic)").tag(AIProviderType.claude)
                        Text("Disabled").tag(AIProviderType.disabled)
                    }
                    .pickerStyle(.radioGroup)
                } header: {
                    Text("Provider Selection")
                        .font(.headline)
                }
                
                // Ollama Configuration
                if settingsService.settings.aiProvider == .ollama {
                    Section {
                        HStack {
                            Text("Base URL:")
                                .frame(width: 100, alignment: .trailing)
                            
                            TextField("http://ollama.local/v1", text: $settingsService.settings.ollamaBaseURL)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack {
                            Text("Model:")
                                .frame(width: 100, alignment: .trailing)
                            
                            if availableModels.isEmpty {
                                TextField("No models loaded", text: .constant(""))
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(true)
                            } else {
                                Picker("", selection: $settingsService.settings.ollamaModel) {
                                    Text("Select a model").tag(nil as String?)
                                    ForEach(availableModels) { model in
                                        Text("\(model.name) (\(model.sizeString))").tag(model.name as String?)
                                    }
                                }
                                .labelsHidden()
                            }
                            
                            Button(action: fetchOllamaModels) {
                                if isFetchingModels {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                            .buttonStyle(.borderless)
                            .disabled(isFetchingModels)
                            .help("Fetch available models from Ollama")
                        }
                        
                        if let error = modelFetchError {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        HStack {
                            Spacer()
                            Button("Test Connection") {
                                testOllamaConnection()
                            }
                            .disabled(isTestingConnection)
                        }
                        
                        if let result = testResult {
                            Text(result)
                                .foregroundColor(result.contains("✅") ? .green : .red)
                                .font(.caption)
                        }
                    } header: {
                        Text("Ollama Configuration")
                            .font(.headline)
                    }
                }
                
                // Claude Configuration
                if settingsService.settings.aiProvider == .claude {
                    Section {
                        HStack {
                            Text("API Key:")
                                .frame(width: 100, alignment: .trailing)
                            
                            SecureField("sk-ant-...", text: $claudeAPIKey)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("Save") {
                                settingsService.saveClaudeAPIKey(claudeAPIKey)
                            }
                            .disabled(claudeAPIKey.isEmpty)
                        }
                        
                        HStack {
                            Text("Model:")
                                .frame(width: 100, alignment: .trailing)
                            
                            Picker("", selection: $settingsService.settings.claudeModel) {
                                Text("Claude Opus 4.5").tag("claude-opus-4-5-20251101")
                                Text("Claude Sonnet 4.5").tag("claude-sonnet-4-5-20250929")
                                Text("Claude Haiku 4").tag("claude-haiku-4-20250228")
                            }
                            .labelsHidden()
                        }
                        
                        HStack {
                            Spacer()
                            Button("Test Connection") {
                                testClaudeConnection()
                            }
                            .disabled(isTestingConnection || claudeAPIKey.isEmpty)
                        }
                        
                        if let result = testResult {
                            Text(result)
                                .foregroundColor(result.contains("✅") ? .green : .red)
                                .font(.caption)
                        }
                    } header: {
                        Text("Claude Configuration")
                            .font(.headline)
                    }
                }
                
                // System Prompt
                if settingsService.settings.aiProvider != .disabled {
                    Section {
                        TextEditor(text: $settingsService.settings.systemPrompt)
                            .frame(height: 100)
                            .font(.system(.body, design: .monospaced))
                            .border(Color.gray.opacity(0.2))
                    } header: {
                        Text("System Prompt")
                            .font(.headline)
                    } footer: {
                        Text("Instructions for the AI assistant")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            // Load Claude API key from Keychain
            if let key = settingsService.loadClaudeAPIKey() {
                claudeAPIKey = key
            }
        }
    }
    
    // MARK: - Ollama Methods
    
    private func fetchOllamaModels() {
        isFetchingModels = true
        modelFetchError = nil
        testResult = nil
        
        Task {
            do {
                let client = OllamaClient(baseURL: settingsService.settings.ollamaBaseURL)
                let models = try await client.listModels()
                
                await MainActor.run {
                    availableModels = models
                    isFetchingModels = false
                    
                    if models.isEmpty {
                        modelFetchError = "No models found on Ollama instance"
                    } else {
                        print("📦 Fetched \(models.count) Ollama models")
                    }
                }
            } catch {
                await MainActor.run {
                    modelFetchError = "Failed to fetch models: \(error.localizedDescription)"
                    isFetchingModels = false
                }
            }
        }
    }
    
    private func testOllamaConnection() {
        isTestingConnection = true
        testResult = nil
        
        Task {
            do {
                let client = OllamaClient(baseURL: settingsService.settings.ollamaBaseURL)
                let success = try await client.testConnection()
                
                await MainActor.run {
                    testResult = success ? "✅ Connection successful" : "❌ Connection failed"
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    testResult = "❌ Connection failed: \(error.localizedDescription)"
                    isTestingConnection = false
                }
            }
        }
    }
    
    // MARK: - Claude Methods
    
    private func testClaudeConnection() {
        isTestingConnection = true
        testResult = nil
        
        Task {
            // TODO: Implement Claude API test once ClaudeClient is created
            // For now, just simulate a test
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            await MainActor.run {
                testResult = "⚠️ Claude API client not yet implemented"
                isTestingConnection = false
            }
        }
    }
}
