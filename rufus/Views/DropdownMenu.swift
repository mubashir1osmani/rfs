//
//  DropdownMenu.swift
//  rufus
//
//  Created by AI Assistant on 2025-08-10.
//

import SwiftUI

struct DropdownMenu: View {
    @Binding var isPresented: Bool
    @StateObject private var authService = AuthService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Menu items
            VStack(spacing: 0) {
                DropdownMenuItem(
                    icon: "person.circle",
                    title: "Profile",
                    action: {
                        isPresented = false
                        // Navigate to profile
                    }
                )

                DropdownMenuItem(
                    icon: "gear",
                    title: "Settings",
                    action: {
                        isPresented = false
                        // Navigate to settings
                    }
                )

                DropdownMenuItem(
                    icon: "bell",
                    title: "Notifications",
                    action: {
                        isPresented = false
                        // Navigate to notifications
                    }
                )

                Divider()

                DropdownMenuItem(
                    icon: "arrow.right.square",
                    title: "Sign Out",
                    isDestructive: true,
                    action: {
                        isPresented = false
                        Task {
                            do {
                                try await authService.signOut()
                            } catch {
                                print("Error signing out: \(error)")
                            }
                        }
                    }
                )
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .frame(width: 200)
    }
}

struct DropdownMenuItem: View {
    let icon: String
    let title: String
    let isDestructive: Bool
    let action: () -> Void

    init(icon: String, title: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.isDestructive = isDestructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isDestructive ? .red : .primary)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(isDestructive ? .red : .primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

#Preview {
    DropdownMenu(isPresented: .constant(true))
        .padding()
}