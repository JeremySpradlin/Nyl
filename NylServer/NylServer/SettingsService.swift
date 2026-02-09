//
//  SettingsService.swift
//  NylServer
//
//  Created by Jeremy Spradlin on 2/8/26.
//

import Foundation
import SwiftUI
import Combine
import NylKit
import Security

/// Service for managing application settings persistence
@MainActor
class SettingsService: ObservableObject {
    // MARK: - Properties
    
    @Published var settings: NylSettings {
        didSet {
            save()
        }
    }
    
    private let userDefaultsKey = "nylSettings"
    private let claudeAPIKeyKeychainKey = "com.nyl.claudeAPIKey"
    private let keychainService = "com.nyl.NylServer"
    
    // MARK: - Initialization
    
    init() {
        self.settings = SettingsService.loadFromUserDefaults() ?? NylSettings()
        print("⚙️ Settings loaded")
    }
    
    // MARK: - Persistence
    
    /// Save settings to UserDefaults
    func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let encoded = try? encoder.encode(settings) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            print("💾 Settings saved")
        } else {
            print("❌ Failed to encode settings")
        }
    }
    
    /// Load settings from UserDefaults
    private static func loadFromUserDefaults() -> NylSettings? {
        guard let data = UserDefaults.standard.data(forKey: "nylSettings") else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try? decoder.decode(NylSettings.self, from: data)
    }
    
    // MARK: - Keychain (Claude API Key)
    
    /// Save Claude API key to Keychain
    func saveClaudeAPIKey(_ key: String) {
        guard let data = key.data(using: .utf8) else {
            print("❌ Failed to encode API key")
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: claudeAPIKeyKeychainKey,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("🔐 Claude API key saved to Keychain")
        } else {
            print("❌ Failed to save Claude API key: \(status)")
        }
    }
    
    /// Load Claude API key from Keychain
    func loadClaudeAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: claudeAPIKeyKeychainKey,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess,
           let data = dataTypeRef as? Data,
           let key = String(data: data, encoding: .utf8) {
            return key
        }

        // Fallback to legacy keychain entry without service attribute (migrate forward).
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: claudeAPIKeyKeychainKey,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var legacyDataTypeRef: AnyObject?
        let legacyStatus = SecItemCopyMatching(legacyQuery as CFDictionary, &legacyDataTypeRef)
        if legacyStatus == errSecSuccess,
           let data = legacyDataTypeRef as? Data,
           let key = String(data: data, encoding: .utf8) {
            saveClaudeAPIKey(key)
            SecItemDelete(legacyQuery as CFDictionary)
            return key
        }

        return nil
    }
    
    /// Delete Claude API key from Keychain
    func deleteClaudeAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: claudeAPIKeyKeychainKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess {
            print("🗑️ Claude API key deleted from Keychain")
        }
    }
}
