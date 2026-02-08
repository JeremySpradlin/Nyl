//
//  AppDelegate.swift
//  NylServer
//
//  Created by Jeremy Spradlin on 2/6/26.
//

import Foundation
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var hasLaunched = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !hasLaunched else {
            print("⚠️ applicationDidFinishLaunching called multiple times - ignoring")
            return
        }
        hasLaunched = true
        
        print("📱 App finished launching - starting services...")
        
        // Initialize services using the singleton
        Task {
            await AppCoordinator.shared.initialize()
        }
    }
}
