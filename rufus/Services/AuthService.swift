//
//  AuthService.swift
//  rufus
//
//  Created by Mubashir Osmani on 2025-08-03.

import Foundation
import Supabase
import Combine
import GoogleSignIn

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var isAuthenticated = false
    @Published var user: User?
    @Published var isLoading = false

    private let client = supabase

    private init() {
        Task {
            await loadSession()
        }
    }

    func loadSession() async {
        do {
            let session = try await client.auth.session
            self.user = session.user
            self.isAuthenticated = true
        } catch {
            print("Error loading session: \(error)")
            self.isAuthenticated = false
        }
    }

    // Email & Password Sign Up
    func signUp(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let response = try await client.auth.signUp(email: email, password: password)
        self.user = response.user
        self.isAuthenticated = true
    }

    // Email & Password Sign In
    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let session = try await client.auth.signIn(email: email, password: password)
        self.user = session.user
        self.isAuthenticated = true
    }

    // Google OAuth Sign In
    func signInWithGoogle() async throws {
        isLoading = true
        defer { isLoading = false }
        
        #if canImport(UIKit)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let presentingViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.noViewController
        }
        
        // Configure Google Sign-In with calendar scopes
        guard let config = GIDSignIn.sharedInstance.configuration else {
            throw AuthError.noConfiguration
        }
        
        let configWithScopes = GIDConfiguration(
            clientID: config.clientID,
            serverClientID: config.serverClientID,
            hostedDomain: config.hostedDomain,
            openIDRealm: config.openIDRealm
        )
        
        GIDSignIn.sharedInstance.configuration = configWithScopes
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
        
        // Request calendar scopes if not already granted
        let calendarScope = "https://www.googleapis.com/auth/calendar.readonly"
        if result.user.grantedScopes?.contains(calendarScope) != true {
            try await requestCalendarScopes()
        }
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.noIdToken
        }
        
        let accessToken = result.user.accessToken.tokenString
        
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken
            )
        )
        
        self.user = session.user
        self.isAuthenticated = true
        #else
        throw AuthError.platformNotSupported
        #endif
    }
    
    // Request Calendar Scopes
    func requestCalendarScopes() async throws {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw NSError(domain: "AuthService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
        }
        
        // Check if we already have calendar scope
        let calendarScope = "https://www.googleapis.com/auth/calendar.readonly"
        if user.grantedScopes?.contains(calendarScope) == true {
            return
        }
        
        let additionalScopes = [calendarScope]
        
        guard let viewController = await MainActor.run(body: {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController
        }) else {
            throw NSError(domain: "AuthService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No presenting view controller"])
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard let user = GIDSignIn.sharedInstance.currentUser else {
                continuation.resume(throwing: NSError(domain: "AuthService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not signed in"]))
                return
            }
            
            user.addScopes(additionalScopes, presenting: viewController) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func signOut() async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await client.auth.signOut()
        self.user = nil
        self.isAuthenticated = false
    }
}

enum AuthError: Error, LocalizedError {
    case noViewController
    case noIdToken
    case platformNotSupported
    case noConfiguration
    
    var errorDescription: String? {
        switch self {
        case .noViewController:
            return "No view controller available for sign-in"
        case .noIdToken:
            return "Failed to get ID token from Google"
        case .platformNotSupported:
            return "Google Sign-In not supported on this platform"
        case .noConfiguration:
            return "Google Sign-In configuration not found"
        }
    }
}
