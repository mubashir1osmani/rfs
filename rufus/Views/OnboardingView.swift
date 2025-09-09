// Author: Mubashir Osmani
// beacon
// onboarding view

import SwiftUI

struct OnboardingView: View {
    @StateObject private var authService = AuthService.shared
    @State private var showingEmailSignIn = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
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
        .sheet(isPresented: $showingEmailSignIn) {
            EmailSignInView()
        }
        .alert("Authentication Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
