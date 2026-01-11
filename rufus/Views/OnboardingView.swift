// Author: Mubashir Osmani
// beacon
// onboarding view

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = AuthService.shared
    @State private var showingEmailSignIn = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingLocationPermission = false
    @State private var onboardingComplete = false

    var body: some View {
        NavigationStack {
            if onboardingComplete {
                // After onboarding is complete, show the main app
                ContentView()
            } else if showingLocationPermission {
                LocationPermissionView {
                    // Location permission completed
                    onboardingComplete = true
                }
            } else {
                VStack(spacing: 40) {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)

                        Text("beacon")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Your academic assignment tracker")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()

                    // Sign In Options
                    VStack(spacing: 16) {
                        // Google Sign In Button
                        Button {
                            Task {
                                do {
                                    try await authService.signInWithGoogle()
                                } catch {
                                    alertMessage = error.localizedDescription
                                    showingAlert = true
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "globe")
                                Text("Sign in with Google")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(authService.isLoading)

                        // Email Sign In Button
                        Button {
                            showingEmailSignIn = true
                        } label: {
                            HStack {
                                Image(systemName: "envelope")
                                Text("Sign in with Email")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(authService.isLoading)
                    }
                    .padding(.horizontal, 40)

                    if authService.isLoading {
                        ProgressView("Signing in...")
                            .padding()
                    }

                    Spacer()
                }
                .navigationBarHidden(true)
            }
        }
        .sheet(isPresented: $showingEmailSignIn) {
            EmailSignInView(onSignInSuccess: {
                checkIfLocationNeeded()
            })
        }
        .alert("Authentication Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                checkIfLocationNeeded()
            }
        }
    }

    private func checkIfLocationNeeded() {
        // Check if user already has location saved
        let descriptor = FetchDescriptor<UserLocation>()
        if let _ = try? modelContext.fetch(descriptor).first {
            // Location already exists, skip to main app
            onboardingComplete = true
        } else {
            // No location saved, show location permission
            showingLocationPermission = true
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
