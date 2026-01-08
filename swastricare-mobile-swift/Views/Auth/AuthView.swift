//
//  AuthView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI

// MARK: - Login View

struct LoginView: View {
    
    @StateObject private var viewModel = DependencyContainer.shared.authViewModel
    @State private var showSignUp = false
    @State private var showResetPassword = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                PremiumBackground()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Logo
                        VStack(spacing: 16) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.accentColor)
                            
                            Text("Swastricare")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("Your Health Companion")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 60)
                        
                        // Form
                        VStack(spacing: 16) {
                            GlassTextField(
                                icon: "envelope.fill",
                                placeholder: "Email",
                                text: $viewModel.formState.email
                            )
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            
                            GlassSecureField(
                                icon: "lock.fill",
                                placeholder: "Password",
                                text: $viewModel.formState.password
                            )
                            .textContentType(.password)
                            
                            // Error Message
                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }
                            
                            // Login Button
                            Button(action: {
                                Task { await viewModel.signIn() }
                            }) {
                                HStack {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Sign In")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .cornerRadius(12)
                            }
                            .disabled(viewModel.isLoading || !viewModel.formState.isValidForLogin)
                            
                            // Forgot Password
                            Button(action: { showResetPassword = true }) {
                                Text("Forgot Password?")
                                    .font(.subheadline)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding()
                        .glass(cornerRadius: 20)
                        .padding(.horizontal)
                        
                        // Divider
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                            Text("or")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 40)
                        
                        // Social Login
                        Button(action: {
                            Task { await viewModel.signInWithGoogle() }
                        }) {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                Text("Continue with Google")
                            }
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .glass(cornerRadius: 12)
                        }
                        .padding(.horizontal)
                        
                        // Sign Up Link
                        Button(action: { showSignUp = true }) {
                            HStack {
                                Text("Don't have an account?")
                                    .foregroundColor(.secondary)
                                Text("Sign Up")
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color(hex: "2E3192"))
                            }
                            .font(.subheadline)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showResetPassword) {
                ResetPasswordView()
            }
        }
    }
}

// MARK: - Sign Up View

struct SignUpView: View {
    
    @StateObject private var viewModel = DependencyContainer.shared.authViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            PremiumBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Create Account")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Join Swastricare today")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Form
                    VStack(spacing: 16) {
                        GlassTextField(
                            icon: "person.fill",
                            placeholder: "Full Name",
                            text: $viewModel.formState.fullName
                        )
                        .textContentType(.name)
                        
                        GlassTextField(
                            icon: "envelope.fill",
                            placeholder: "Email",
                            text: $viewModel.formState.email
                        )
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        
                        GlassSecureField(
                            icon: "lock.fill",
                            placeholder: "Password",
                            text: $viewModel.formState.password
                        )
                        .textContentType(.newPassword)
                        
                        GlassSecureField(
                            icon: "lock.fill",
                            placeholder: "Confirm Password",
                            text: $viewModel.formState.confirmPassword
                        )
                        .textContentType(.newPassword)
                        
                        // Error Message
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Sign Up Button
                        Button(action: {
                            Task { await viewModel.signUp() }
                        }) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Create Account")
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(12)
                        }
                        .disabled(viewModel.isLoading || !viewModel.formState.isValidForSignUp)
                    }
                    .padding()
                    .glass(cornerRadius: 20)
                    .padding(.horizontal)
                    
                    // Terms
                    Text("By signing up, you agree to our Terms of Service and Privacy Policy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.isAuthenticated) { _, isAuth in
            if isAuth { dismiss() }
        }
    }
}

// MARK: - Reset Password View

struct ResetPasswordView: View {
    
    @StateObject private var viewModel = DependencyContainer.shared.authViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "lock.rotation")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text("Reset Password")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Enter your email and we'll send you a link to reset your password")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                GlassTextField(
                    icon: "envelope.fill",
                    placeholder: "Email",
                    text: $viewModel.formState.email
                )
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding(.horizontal)
                
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(message.contains("sent") ? .green : .red)
                        .multilineTextAlignment(.center)
                }
                
                Button(action: {
                    Task { await viewModel.resetPassword() }
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Send Reset Link")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isLoading || !viewModel.formState.isValidEmail)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Glass Components

private struct GlassTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Material.ultraThinMaterial)
        )
    }
}

private struct GlassSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var isSecure = true
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
            
            Button(action: { isSecure.toggle() }) {
                Image(systemName: isSecure ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Material.ultraThinMaterial)
        )
    }
}

#Preview("Login") {
    LoginView()
}

#Preview("SignUp") {
    SignUpView()
}

