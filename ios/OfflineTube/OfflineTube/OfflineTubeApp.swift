//
//  OfflineTubeApp.swift
//  OfflineTube
//
//  Created by Stefan Dimitrov on 5/5/25.
//

import SwiftUI

struct OfflineTubeApp: App {
    // Removing the @main annotation to avoid conflict with AppDelegate
    // The AppDelegate will be the main entry point
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
