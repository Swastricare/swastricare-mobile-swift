//
//  LockScreenView.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import SwiftUI

struct LockScreenView: View {
    @ObservedObject var biometricAuth = BiometricAuthManager.shared
    @State private var isAuthenticating = false
    
    var body: some View {
        ZStack {
            // Premium Background
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.6),
                    Color.blue.opacity(0.6),
                    Color.cyan.opacity(0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Blur effect
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // App Icon or Logo Area
                VStack(spacing: 16) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Swastricare")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Biometric Authentication Section
                VStack(spacing: 24) {
                    // Biometric Icon
                    Button(action: {
                        guard !isAuthenticating else { return }
                        isAuthenticating = true
                        Task {
                            await biometricAuth.authenticate()
                            isAuthenticating = false
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 100, height: 100)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            
                            if isAuthenticating {
                                ProgressView()
                                    .tint(.blue)
                                    .scaleEffect(1.5)
                            } else {
                                Image(systemName: biometricAuth.biometricIconName)
                                    .font(.system(size: 44))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isAuthenticating)
                    
                    // Instructions
                    VStack(spacing: 8) {
                        Text(isAuthenticating ? "Authenticating..." : "Unlock with \(biometricAuth.biometricDisplayName)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if !isAuthenticating {
                            Text("Tap to authenticate")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Error Message
                    if let errorMessage = biometricAuth.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .task {
            // Auto-trigger authentication when lock screen appears
            isAuthenticating = true
            // Very small delay to show the UI first
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            await biometricAuth.authenticate()
            isAuthenticating = false
        }
    }
}

#Preview {
    LockScreenView()
}
