//
//  LockScreenView.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import SwiftUI

// #region agent log helper
func logDebugView(_ location: String, _ message: String, _ data: [String: Any] = [:], hypothesisId: String = "") {
    let logPath = "/Users/onwords/i do coding/swastricare-mobile-swift/.cursor/debug.log"
    var logData: [String: Any] = [
        "timestamp": Date().timeIntervalSince1970 * 1000,
        "location": location,
        "message": message,
        "sessionId": "debug-session",
        "data": data
    ]
    if !hypothesisId.isEmpty {
        logData["hypothesisId"] = hypothesisId
    }
    if let jsonData = try? JSONSerialization.data(withJSONObject: logData),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        if let fileHandle = FileHandle(forWritingAtPath: logPath) {
            fileHandle.seekToEndOfFile()
            if let data = (jsonString + "\n").data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } else {
            try? (jsonString + "\n").write(toFile: logPath, atomically: true, encoding: .utf8)
        }
    }
}
// #endregion

struct LockScreenView: View {
    @ObservedObject var biometricAuth = BiometricAuthManager.shared
    @State private var isAuthenticating = false
    
    var body: some View {
        let _ = {
            // #region agent log
            logDebugView("LockScreenView:body", "View rendering", ["isLocked": biometricAuth.isLocked, "isAuthenticating": isAuthenticating, "errorMessage": biometricAuth.errorMessage ?? "none"], hypothesisId: "B")
            // #endregion
        }()
        
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
            // #region agent log
            logDebugView("LockScreenView:task:entry", "Task started", ["isLocked": biometricAuth.isLocked, "isAuthenticating": isAuthenticating], hypothesisId: "E")
            // #endregion
            
            // Auto-trigger authentication when lock screen appears
            print("🔐 LockScreenView: Appearing, will trigger auth immediately")
            isAuthenticating = true
            
            // #region agent log
            logDebugView("LockScreenView:task:beforeSleep", "Before sleep", [:], hypothesisId: "E")
            // #endregion
            
            // Very small delay to show the UI first
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // #region agent log
            logDebugView("LockScreenView:task:beforeAuth", "About to call authenticate", ["isLocked": biometricAuth.isLocked], hypothesisId: "E,B")
            // #endregion
            
            await biometricAuth.authenticate()
            
            // #region agent log
            logDebugView("LockScreenView:task:afterAuth", "After authenticate call", ["isLocked": biometricAuth.isLocked, "errorMessage": biometricAuth.errorMessage ?? "none"], hypothesisId: "E,B")
            // #endregion
            
            isAuthenticating = false
            print("🔐 LockScreenView: Auth completed")
            
            // #region agent log
            logDebugView("LockScreenView:task:exit", "Task completed", ["isLocked": biometricAuth.isLocked], hypothesisId: "E,B")
            // #endregion
        }
    }
}

#Preview {
    LockScreenView()
}
