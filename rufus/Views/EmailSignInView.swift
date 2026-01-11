//
//  EmailSignInView.swift
//  beacon
//
//  Created by GitHub Copilot on 2025-08-03.
//

import SwiftUI

struct EmailSignInView: View {
    @StateObject private var authService = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUp = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss

    var onSignInSuccess: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // App branding
                    VStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        Text("beacon")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text(isSignUp ? "Create your account" : "Welcome back")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Form fields
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textContentType(.emailAddress)
                            .textFieldStyle(.roundedBorder)
                        
                        SecureField("Password", text: $password)
                            .textContentType(isSignUp ? .newPassword : .password)
                            .textFieldStyle(.roundedBorder)
                        
                        if isSignUp {
                            SecureField("Confirm Password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(.horizontal, 20)

                    .padding(.horizontal, 20)
                    
                    // Main action button
                    Button(action: {
                        Task {
                            await handleAuthentication()
                        }
                    }) {
                        HStack {
                            if authService.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isFormInvalid || authService.isLoading)
                    .padding(.horizontal, 20)
                    
                    // Toggle between sign in and sign up
                    Button(action: {
                        isSignUp.toggle()
                        confirmPassword = "" // Clear confirm password when switching
                    }) {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                    .disabled(authService.isLoading)
                    
                    Spacer()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(authService.isLoading)
                }
            }
            .alert("Authentication Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var isFormInvalid: Bool {
        email.isEmpty || password.isEmpty || (isSignUp && (confirmPassword.isEmpty || password != confirmPassword))
    }
    
    private func handleAuthentication() async {
        // Validate password confirmation for sign-up
        if isSignUp && password != confirmPassword {
            alertMessage = "Passwords do not match"
            showingAlert = true
            return
        }
        
        do {
            if isSignUp {
                try await authService.signUp(email: email, password: password)
            } else {
                try await authService.signIn(email: email, password: password)
            }
            
            // Call success callback and dismiss the view on successful authentication
            DispatchQueue.main.async {
                onSignInSuccess?()
                dismiss()
            }
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }
}

struct EmailSignInView_Previews: PreviewProvider {
    static var previews: some View {
        EmailSignInView()
    }
}
