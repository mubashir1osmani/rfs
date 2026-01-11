//
//  beaconApp.swift
//  beacon
//
//  Created by Mubashir Osmani on 2025-07-23.

import SwiftUI
import SwiftData
import UserNotifications
import GoogleSignIn

@main
struct beaconApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authService = AuthService.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Assignment.self,
            NotificationItem.self,
            Course.self,
            KnowledgeEntry.self,
            KnowledgeAnnotation.self,
            Goal.self,
            GoalTask.self,
            AssistantSettings.self,
            UserLocation.self,
            DailyPrayerTimes.self,
            Note.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        // Configure Google Sign In
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("Warning: Could not find GoogleService-Info.plist or CLIENT_ID")
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    ContentView()
                        .modelContainer(sharedModelContainer)
                } else {
                    OnboardingView()
                }
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
