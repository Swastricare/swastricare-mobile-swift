//
//  AuthView.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import SwiftUI

struct AuthView: View {
    @State private var showSignUp = false
    
    var body: some View {
        if showSignUp {
            SignUpView(showSignUp: $showSignUp)
        } else {
            LoginView(showSignUp: $showSignUp)
        }
    }
}

// MARK: - Login View
struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @Binding var showSignUp: Bool
    
    @State private var email = ""
    @State private var password = ""
    @State private var showResetPassword = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Animated Premium Background
                PremiumBackground()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Logo & Welcome
                        VStack(spacing: 15) {
                            Image(systemName: "heart.circle.fill")
                                .resizable()
                                .frame(width: 90, height: 90)
                                .foregroundColor(.white)
                                .shadow(color: .pink.opacity(0.5), radius: 20)
                            
                            Text("SwastriCare")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(Color.white)
                                .shadow(color: .purple.opacity(0.5), radius: 10)
                            
                            Text("Your Premium Health Companion")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.top, 60)
                        
                        // Login Form
                        VStack(spacing: 20) {
                            // Email Field
                            GlassInput(icon: "envelope.fill", placeholder: "Email", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                            
                            // Password Field
                            GlassSecureInput(icon: "lock.fill", placeholder: "Password", text: $password)
                            
                            // Forgot Password
                            HStack {
                                Spacer()
                                Button(action: {
                                    showResetPassword = true
                                }) {
                                    Text("Forgot Password?")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                            
                            // Error Message
                            if let error = authManager.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.vertical, 5)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(8)
                            }
                            
                            // Login Button
                            Button(action: {
                                Task {
                                    await authManager.signIn(email: email, password: password)
                                }
                            }) {
                                if authManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                } else {
                                    Text("Sign In")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(PremiumColor.royalBlue)
                                        .cornerRadius(16)
                                        .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                                }
                            }
                            .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                            .padding(.top, 10)
                            
                            // Divider
                            HStack {
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.white.opacity(0.2))
                                Text("OR")
                                    .foregroundColor(.white.opacity(0.6))
                                    .font(.caption)
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.white.opacity(0.2))
                            }
                            .padding(.vertical, 10)
                            
                            // Google Sign In Button
                            Button(action: {
                                Task {
                                    await authManager.signInWithGoogle()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "g.circle.fill")
                                        .font(.title3)
                                    Text("Continue with Google")
                                        .font(.headline)
                                }
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .glass(cornerRadius: 16)
                            }
                            .disabled(authManager.isLoading)
                            
                            // Sign Up Link
                            HStack {
                                Text("Don't have an account?")
                                    .foregroundColor(.white.opacity(0.8))
                                Button(action: {
                                    showSignUp = true
                                }) {
                                    Text("Sign Up")
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .underline()
                                }
                            }
                            .font(.subheadline)
                            .padding(.top, 5)
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 20)
                        
                        Spacer()
                    }
                }
            }
            .sheet(isPresented: $showResetPassword) {
                ResetPasswordView()
            }
        }
    }
}

// MARK: - Sign Up View
struct SignUpView: View {
    @StateObject private var authManager = AuthManager.shared
    @Binding var showSignUp: Bool
    
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var localErrorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Premium Background
                PremiumBackground()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Logo & Title
                        VStack(spacing: 15) {
                            Image(systemName: "heart.fill")
                                .resizable()
                                .frame(width: 70, height: 70)
                                .foregroundColor(.white)
                                .shadow(color: .pink.opacity(0.5), radius: 15)
                            
                            Text("Join SwastriCare")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding(.top, 40)
                        
                        // Sign Up Form
                        VStack(spacing: 20) {
                            GlassInput(icon: "person.fill", placeholder: "Full Name", text: $fullName)
                            
                            GlassInput(icon: "envelope.fill", placeholder: "Email", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                            
                            GlassSecureInput(icon: "lock.fill", placeholder: "Password", text: $password)
                            
                            GlassSecureInput(icon: "lock.shield.fill", placeholder: "Confirm Password", text: $confirmPassword)
                            
                            // Error Message
                            if let error = localErrorMessage ?? authManager.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.vertical, 5)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(8)
                            }
                            
                            // Sign Up Button
                            Button(action: {
                                validateAndSignUp()
                            }) {
                                if authManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                } else {
                                    Text("Create Account")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(PremiumColor.sunset)
                                        .cornerRadius(16)
                                        .shadow(color: Color.orange.opacity(0.3), radius: 10, x: 0, y: 5)
                                }
                            }
                            .disabled(authManager.isLoading || !isFormValid())
                            .padding(.top, 10)
                            
                            // Back to Login
                            HStack {
                                Text("Already have an account?")
                                    .foregroundColor(.white.opacity(0.8))
                                Button(action: {
                                    showSignUp = false
                                }) {
                                    Text("Sign In")
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .underline()
                                }
                            }
                            .font(.subheadline)
                            .padding(.top, 5)
                        }
                        .padding(.horizontal, 30)
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func isFormValid() -> Bool {
        !fullName.isEmpty && !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty
    }
    
    private func validateAndSignUp() {
        localErrorMessage = nil
        
        guard password == confirmPassword else {
            localErrorMessage = "Passwords do not match"
            return
        }
        
        guard password.count >= 6 else {
            localErrorMessage = "Password must be at least 6 characters"
            return
        }
        
        guard email.contains("@") && email.contains(".") else {
            localErrorMessage = "Please enter a valid email"
            return
        }
        
        Task {
            await authManager.signUp(email: email, password: password, fullName: fullName)
        }
    }
}

// MARK: - Reset Password View
struct ResetPasswordView: View {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var emailSent = false
    
    var body: some View {
        NavigationView {
            ZStack {
                PremiumBackground()
                
                VStack(spacing: 25) {
                    Image(systemName: "lock.rotation")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.white)
                        .padding(.top, 50)
                    
                    Text("Reset Password")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if !emailSent {
                        GlassInput(icon: "envelope.fill", placeholder: "Email", text: $email)
                            .padding(.horizontal)
                        
                        Button(action: {
                            Task {
                                await authManager.resetPassword(email: email)
                                if authManager.errorMessage?.contains("sent") == true {
                                    emailSent = true
                                }
                            }
                        }) {
                            Text("Send Reset Link")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(PremiumColor.royalBlue)
                                .cornerRadius(16)
                        }
                        .disabled(authManager.isLoading || email.isEmpty)
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 15) {
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.green)
                            
                            Text("Email Sent!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Button(action: {
                                dismiss()
                            }) {
                                Text("Done")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(PremiumColor.royalBlue)
                                    .cornerRadius(16)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Glass Input Helpers

struct GlassInput: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct GlassSecureInput: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 20)
            
            SecureField(placeholder, text: $text)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}
