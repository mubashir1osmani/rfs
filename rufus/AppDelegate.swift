//
//  AppDelegate.swift
//  beacon
//
//  Created by AI Assistant on 2025-07-25.
//

import Foundation
import UIKit
import UserNotifications
import BackgroundTasks
import SwiftData

class AppDelegate: NSObject, UIApplicationDelegate {
    private var modelContainer: ModelContainer?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Request notification permissions
        Task {
            let granted = await NotificationService.shared.requestPermission()
            if granted {
                print("Notification permissions granted")
            } else {
                print("Notification permissions denied")
            }
        }
        
        // Register background tasks
        BackgroundTaskHandler.shared.registerBackgroundTasks()
        
        // Initialize model container for background checks
        setupModelContainer()
        
        // Setup LLM background service for daily briefings
        LLMBackgroundService.shared.setupBackgroundTasks()
        
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Schedule background task when app enters background
        BackgroundTaskHandler.shared.scheduleNextBackgroundCheck()
    }
    
    private func setupModelContainer() {
        let schema = Schema([
            Item.self,
            Assignment.self,
            NotificationItem.self,
            Course.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("Error creating ModelContainer: \(error)")
        }
    }
    
    func getModelContext() -> ModelContext? {
        guard let container = modelContainer else { return nil }
        return ModelContext(container)
    }
}
