// user authentication

import Foundation
import Supabase
import Combine
import GoogleSignIn

#if canImport(UIKit)
import UIKit
#endif

let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://vmzmwybvcybsiplmmelv.supabase.co")!,
  supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZtem13eWJ2Y3lic2lwbG1tZWx2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU1NDQ3MTEsImV4cCI6MjA2MTEyMDcxMX0.SVWjQUjA5km-db31SwNV0CLZAG0hM213OXIN11nlshQ"
)

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
        
        // Use existing configuration
        guard let config = GIDSignIn.sharedInstance.configuration else {
            throw AuthError.noConfiguration
        }
        GIDSignIn.sharedInstance.configuration = config
        
        // Begin sign-in
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
        
        // Ensure calendar scope is granted before extracting tokens
        let calendarScope = "https://www.googleapis.com/auth/calendar.readonly"
        if result.user.grantedScopes?.contains(calendarScope) != true {
            // Request additional scope
            try await requestCalendarScopes()
            
            // Refresh tokens so new access token includes the newly granted scope
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                result.user.refreshTokensIfNeeded { _, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        }
        
        // Use the current user after potential scope expansion
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            throw AuthError.noConfiguration
        }
        
        guard let idToken = currentUser.idToken?.tokenString else {
            throw AuthError.noIdToken
        }
        
        let accessToken = currentUser.accessToken.tokenString
        
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
