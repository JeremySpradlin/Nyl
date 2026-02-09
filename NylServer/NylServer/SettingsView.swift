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
                    Label("AI", systemImage: "brain")
                }
        }
        .frame(width: 650, height: 550)
    }
}

// MARK: - General Settings Tab

struct GeneralSettingsView: View {
    @ObservedObject var settingsService: SettingsService
    
    var body: some View {
        Form {
            Section {
                LabeledContent("Heartbeat Interval:") {
                    HStack(spacing: 8) {
                        TextField("", value: $settingsService.settings.heartbeatInterval, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                            .multilineTextAlignment(.trailing)
                        
                        Text("seconds")
                            .foregroundStyle(.secondary)
                        
                        Text("(\(formattedInterval))")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                }
                
                LabeledContent("Weather Location:") {
                    TextField("Auto-detect", text: Binding(
                        get: { settingsService.settings.weatherLocation ?? "" },
                        set: { settingsService.settings.weatherLocation = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                }
                .help("Leave empty to automatically detect location")
            }
        }
        .formStyle(.grouped)
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
                Toggle("Enable AI Features", isOn: Binding(
                    get: { settingsService.settings.aiEnabled },
                    set: { settingsService.settings.aiEnabled = $0 }
                ))
            }
            
            // Provider Selection
            if settingsService.settings.aiEnabled {
                Section {
                    Picker("Provider:", selection: Binding(
                        get: { settingsService.settings.aiProvider },
                        set: { 
                            settingsService.settings.aiProvider = $0
                            // Clear test results when provider changes
                            testResult = nil
                            modelFetchError = nil
                        }
                    )) {
                        Text("Ollama").tag(AIProviderType.ollama)
                        Text("Claude").tag(AIProviderType.claude)
                        Text("Disabled").tag(AIProviderType.disabled)
                    }
                    .pickerStyle(.segmented)
                }
                
                // Ollama Configuration
                if settingsService.settings.aiProvider == .ollama {
                    Section {
                        LabeledContent("Base URL:") {
                            TextField("http://ollama.local", text: $settingsService.settings.ollamaBaseURL)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 300)
                        }
                        
                        LabeledContent("Model:") {
                            HStack(spacing: 8) {
                                if availableModels.isEmpty {
                                    Text("No models loaded")
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                        .cornerRadius(6)
                                } else {
                                    Picker("", selection: $settingsService.settings.ollamaModel) {
                                        Text("Select a model").tag(nil as String?)
                                        Divider()
                                        ForEach(availableModels) { model in
                                            Text("\(model.name) • \(model.sizeString)").tag(model.name as String?)
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(width: 250)
                                }
                                
                                Button(action: fetchOllamaModels) {
                                    if isFetchingModels {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                }
                                .buttonStyle(.borderless)
                                .disabled(isFetchingModels)
                                .help("Fetch available models")
                            }
                        }
                        
                        if let error = modelFetchError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text(error)
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                        
                        HStack {
                            Spacer()
                            
                            if let result = testResult {
                                HStack(spacing: 4) {
                                    Image(systemName: result.contains("✅") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(result.contains("✅") ? .green : .red)
                                    Text(result.replacingOccurrences(of: "✅ ", with: "").replacingOccurrences(of: "❌ ", with: ""))
                                        .foregroundStyle(.secondary)
                                }
                                .font(.caption)
                            }
                            
                            Button(isTestingConnection ? "Testing..." : "Test Connection") {
                                testOllamaConnection()
                            }
                            .disabled(isTestingConnection)
                        }
                    } header: {
                        Text("Ollama Configuration")
                    }
                }
                
                // Claude Configuration
                if settingsService.settings.aiProvider == .claude {
                    Section {
                        LabeledContent("API Key:") {
                            HStack(spacing: 8) {
                                SecureField("sk-ant-...", text: $claudeAPIKey)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 250)
                                
                                Button("Save") {
                                    settingsService.saveClaudeAPIKey(claudeAPIKey)
                                }
                                .disabled(claudeAPIKey.isEmpty)
                            }
                        }
                        
                        LabeledContent("Model:") {
                            Picker("", selection: $settingsService.settings.claudeModel) {
                                Text("Claude Opus 4.5 (Most capable)").tag("claude-opus-4-5-20251101")
                                Text("Claude Sonnet 4.5 (Balanced)").tag("claude-sonnet-4-5-20250929")
                                Text("Claude Sonnet 3.5").tag("claude-3-5-sonnet-20241022")
                                Text("Claude Haiku 3.5 (Fast)").tag("claude-3-5-haiku-20241022")
                            }
                            .labelsHidden()
                            .frame(width: 300)
                        }
                        
                        HStack {
                            Spacer()
                            
                            if let result = testResult {
                                HStack(spacing: 4) {
                                    Image(systemName: result.contains("✅") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(result.contains("✅") ? .green : .red)
                                    Text(result.replacingOccurrences(of: "✅ ", with: "").replacingOccurrences(of: "❌ ", with: ""))
                                        .foregroundStyle(.secondary)
                                }
                                .font(.caption)
                            }
                            
                            Button(isTestingConnection ? "Testing..." : "Test Connection") {
                                testClaudeConnection()
                            }
                            .disabled(isTestingConnection || claudeAPIKey.isEmpty)
                        }
                    } header: {
                        Text("Claude Configuration")
                    }
                }
                
                // System Prompt
                if settingsService.settings.aiProvider != .disabled {
                    Section {
                        TextEditor(text: $settingsService.settings.systemPrompt)
                            .frame(height: 100)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                            )
                    } header: {
                        Text("System Prompt")
                    } footer: {
                        Text("Instructions for the AI assistant")
                            .font(.caption)
                    }
                }
            }
        }
        .formStyle(.grouped)
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
            do {
                let client = ClaudeClient(apiKey: claudeAPIKey)
                let success = try await client.testConnection(model: settingsService.settings.claudeModel)
                
                await MainActor.run {
                    testResult = success ? "✅ Connection successful" : "❌ Connection failed"
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    testResult = "❌ \(error.localizedDescription)"
                    isTestingConnection = false
                }
            }
        }
    }
}
