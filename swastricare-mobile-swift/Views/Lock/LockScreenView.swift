//
//  LockScreenView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI

struct LockScreenView: View {
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel = DependencyContainer.shared.lockScreenViewModel
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Theme-aware Background
            PremiumBackground()
             Color.black.opacity(0.30)
                .ignoresSafeArea()
            VStack(spacing: 30) {
                Spacer()
                
                // App Icon
                // Image(systemName: "heart.text.square.fill")
                //     .font(.system(size: 80))
                //     .foregroundStyle(
                //         LinearGradient(
                //             colors: [Color(hex: "2E3192"), Color(hex: "654ea3")],
                //             startPoint: .topLeading,
                //             endPoint: .bottomTrailing
                //         )
                //     )
                
                // Title
                VStack(spacing: 8) {
                    Text("Swastricare")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Tap to unlock")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Biometric Button
                Button(action: {
                    Task { await viewModel.authenticate() }
                }) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Material.ultraThinMaterial)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
                                )
                            
                            if viewModel.isAuthenticating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Image(systemName: viewModel.biometricIcon)
                                    .font(.system(size: 36))
                                    // .foregroundStyle(PremiumColor.royalBlue)
                            }
                        }
                        
                        Text("Unlock with \(viewModel.biometricName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(viewModel.isAuthenticating)
                
                // Error Message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Spacer()
            }
        }
        .onAppear {
            // Auto-authenticate when view appears
            Task { await viewModel.authenticate() }
        }
    }
}

#Preview {
    LockScreenView()
}

