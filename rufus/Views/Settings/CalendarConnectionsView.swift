//
//  CalendarConnectionsView.swift
//  rufus
//
//  Created by AI Assistant on 2025-08-11.
//

import SwiftUI
import GoogleSignIn
import EventKit

#if canImport(UIKit)
import UIKit
#endif

struct CalendarConnectionsView: View {
    @StateObject private var calendarService = CalendarService()
    @StateObject private var authService = AuthService.shared
    @State private var showingGoogleSignIn = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        Form {
            Section(header: Text("Calendar Connections")) {
                // Apple Calendar Connection
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Calendar")
                            .font(.headline)
                        Text(calendarService.hasCalendarAccess ? "Connected" : "Not Connected")
                            .font(.caption)
                            .foregroundColor(calendarService.hasCalendarAccess ? .green : .orange)
                    }
                    
                    Spacer()
                    
                    if !calendarService.hasCalendarAccess {
                        Button("Connect") {
                            calendarService.requestCalendarPermission()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                // Google Calendar Connection
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundColor(.red)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Google Calendar")
                            .font(.headline)
                        Text(googleConnectionStatus)
                            .font(.caption)
                            .foregroundColor(isGoogleSignedIn ? .green : .orange)
                    }
                    
                    Spacer()
                    
                    if !isGoogleSignedIn {
                        Button("Connect") {
                            signInWithGoogle()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else if !hasCalendarScopes {
                        Button("Enable Calendar") {
                            requestCalendarPermissions()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.orange)
                    } else {
                        Button("Disconnect") {
                            signOutFromGoogle()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.red)
                    }
                }
            }
            
            if calendarService.hasCalendarAccess || (isGoogleSignedIn && hasCalendarScopes) {
                Section(header: Text("Calendar Management")) {
                    Button("Sync Calendars") {
                        calendarService.refreshAllCalendars()
                    }
                    .disabled(calendarService.isLoading)
                    
                    if calendarService.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Syncing calendars...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section(header: Text("Calendar Status")) {
                if let errorMessage = calendarService.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .font(.caption)
                } else {
                    Label("All calendars are working properly", systemImage: "checkmark.circle")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                
                if calendarService.hasCalendarAccess || (isGoogleSignedIn && hasCalendarScopes) {
                    HStack {
                        Text("Events loaded:")
                        Spacer()
                        Text("\(calendarService.calendarEvents.count)")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
            }
        }
        .navigationTitle("Calendar Connections")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Calendar Connection", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isGoogleSignedIn: Bool {
        GIDSignIn.sharedInstance.currentUser != nil
    }
    
    private var hasCalendarScopes: Bool {
        guard let user = GIDSignIn.sharedInstance.currentUser else { return false }
        return user.grantedScopes?.contains("https://www.googleapis.com/auth/calendar.readonly") == true
    }
    
    private var googleConnectionStatus: String {
        if !isGoogleSignedIn {
            return "Not Connected"
        } else if !hasCalendarScopes {
            return "Connected (No Calendar Access)"
        } else {
            return "Connected"
        }
    }
    
    private func signInWithGoogle() {
        Task {
            do {
                // First, sign in with Google (this will request calendar scopes)
                try await authService.signInWithGoogle()
                
                // Then load Google Calendar events
                calendarService.loadGoogleCalendarEvents()
                
                alertMessage = "Successfully connected to Google Calendar!"
                showingAlert = true
            } catch {
                alertMessage = "Failed to connect to Google Calendar: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    private func signOutFromGoogle() {
        GIDSignIn.sharedInstance.signOut()
        
        // Remove Google Calendar events from the service
        calendarService.calendarEvents = calendarService.calendarEvents.filter { $0.source == .apple }
        
        alertMessage = "Disconnected from Google Calendar"
        showingAlert = true
    }
    
    private func requestCalendarPermissions() {
        Task {
            do {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let presentingViewController = windowScene.windows.first?.rootViewController else {
                    alertMessage = "Unable to request calendar permissions"
                    showingAlert = true
                    return
                }
                
                let additionalScopes = ["https://www.googleapis.com/auth/calendar.readonly"]
                
                _ = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController, 
                                                             hint: nil,
                                                             additionalScopes: additionalScopes)
                
                // After granting permissions, load calendar events
                calendarService.loadGoogleCalendarEvents()
                
                alertMessage = "Calendar permissions granted successfully!"
                showingAlert = true
                
            } catch {
                alertMessage = "Failed to request calendar permissions: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        CalendarConnectionsView()
    }
}
