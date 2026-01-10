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
    
    // Animation States
    @State private var isAnimating = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                PremiumBackground()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header Section
                        VStack(spacing: 20) {
                            // Premium Animated Logo
                            PremiumAnimatedLogo()
                                .padding(.bottom, 20)
                            
                            VStack(spacing: 8) {
                                Text("Welcome Back")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [PremiumColor.hex("2E3192"), PremiumColor.hex("1BFFFF")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                Text("Sign in to your health companion")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .tracking(0.5)
                            }
                        }
                        .padding(.top, 60)
                        .offset(y: isAnimating ? 0 : -20)
                        .opacity(isAnimating ? 1 : 0)
                        
                        // Main Form Card
                        VStack(spacing: 25) {
                            
                            // Input Fields
                            VStack(spacing: 20) {
                                PremiumTextField(
                                    icon: "envelope.fill",
                                    placeholder: "Email",
                                    text: $viewModel.formState.email,
                                    isFocused: focusedField == .email
                                )
                                .focused($focusedField, equals: .email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                                
                                PremiumSecureField(
                                    icon: "lock.fill",
                                    placeholder: "Password",
                                    text: $viewModel.formState.password,
                                    isFocused: focusedField == .password
                                )
                                .focused($focusedField, equals: .password)
                                .textContentType(.password)
                                .submitLabel(.go)
                                .onSubmit {
                                    if viewModel.formState.isValidForLogin {
                                        Task { await viewModel.signIn() }
                                    }
                                }
                            }
                            
                            // Error Message
                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .transition(.opacity.combined(with: .scale))
                            }
                            
                            // Forgot Password
                            HStack {
                                Spacer()
                                Button(action: { showResetPassword = true }) {
                                    Text("Forgot Password?")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(PremiumColor.royalBlue)
                                }
                            }
                            
                            // Sign In Button
                            Button(action: {
                                Task { await viewModel.signIn() }
                            }) {
                                HStack {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Sign In")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(PremiumColor.royalBlue)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: PremiumColor.hex("2E3192").opacity(0.4), radius: 10, x: 0, y: 5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .disabled(viewModel.isLoading || !viewModel.formState.isValidForLogin)
                            .opacity(viewModel.formState.isValidForLogin ? 1 : 0.6)
                        }
                        .padding(30)
                        .background(
                            RoundedRectangle(cornerRadius: 30)
                                .fill(.ultraThinMaterial)
                                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        .offset(y: isAnimating ? 0 : 20)
                        .opacity(isAnimating ? 1 : 0)
                        
                        // Social Login
                        VStack(spacing: 20) {
                            HStack(spacing: 16) {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 1)
                                Text("Or continue with")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 1)
                            }
                            .padding(.horizontal, 40)
                            
                            HStack(spacing: 20) {
                                SocialButton(icon: "g.circle.fill", label: "Google") {
                                    Task { await viewModel.signInWithGoogle() }
                                }
                                
                                SocialButton(icon: "apple.logo", label: "Apple") {
                                    Task { await viewModel.signInWithApple() }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .offset(y: isAnimating ? 0 : 30)
                        .opacity(isAnimating ? 1 : 0)
                        
                        // Sign Up Link
                        Button(action: { showSignUp = true }) {
                            HStack {
                                Text("Don't have an account?")
                                    .foregroundColor(.secondary)
                                Text("Sign Up")
                                    .fontWeight(.bold)
                                    .foregroundStyle(PremiumColor.royalBlue)
                            }
                            .font(.subheadline)
                        }
                        .padding(.bottom, 30)
                        .offset(y: isAnimating ? 0 : 40)
                        .opacity(isAnimating ? 1 : 0)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showResetPassword) {
                ResetPasswordView()
            }
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                    isAnimating = true
                }
            }
        }
    }
}

// MARK: - Sign Up View

struct SignUpView: View {
    
    @StateObject private var viewModel = DependencyContainer.shared.authViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isAnimating = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, email, password, confirmPassword
    }
    
    var body: some View {
        ZStack {
            PremiumBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Create Account")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.primary, .primary.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Start your health journey today")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    .offset(y: isAnimating ? 0 : -20)
                    .opacity(isAnimating ? 1 : 0)
                    
                    // Form
                    VStack(spacing: 20) {
                        PremiumTextField(
                            icon: "person.fill",
                            placeholder: "Full Name",
                            text: $viewModel.formState.fullName,
                            isFocused: focusedField == .name
                        )
                        .focused($focusedField, equals: .name)
                        .textContentType(.name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .email }
                        
                        PremiumTextField(
                            icon: "envelope.fill",
                            placeholder: "Email",
                            text: $viewModel.formState.email,
                            isFocused: focusedField == .email
                        )
                        .focused($focusedField, equals: .email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        
                        PremiumSecureField(
                            icon: "lock.fill",
                            placeholder: "Password",
                            text: $viewModel.formState.password,
                            isFocused: focusedField == .password
                        )
                        .focused($focusedField, equals: .password)
                        .textContentType(.newPassword)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .confirmPassword }
                        
                        PremiumSecureField(
                            icon: "checkmark.shield.fill",
                            placeholder: "Confirm Password",
                            text: $viewModel.formState.confirmPassword,
                            isFocused: focusedField == .confirmPassword
                        )
                        .focused($focusedField, equals: .confirmPassword)
                        .textContentType(.newPassword)
                        .submitLabel(.done)
                        .onSubmit {
                            if viewModel.formState.isValidForSignUp {
                                Task { await viewModel.signUp() }
                            }
                        }
                        
                        // Error Message
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .transition(.opacity)
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
                                            .font(.headline)
                                            .fontWeight(.bold)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(PremiumColor.royalBlue)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: PremiumColor.hex("2E3192").opacity(0.4), radius: 10, x: 0, y: 5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .disabled(viewModel.isLoading || !viewModel.formState.isValidForSignUp)
                            .opacity(viewModel.formState.isValidForSignUp ? 1 : 0.6)
                            .padding(.top, 10)
                        
                        // Terms
                        Text("By signing up, you agree to our Terms of Service and Privacy Policy")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .offset(y: isAnimating ? 0 : 20)
                    .opacity(isAnimating ? 1 : 0)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    isAnimating = true
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
    @State private var isAnimating = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()
                
                VStack(spacing: 30) {
                    
                    VStack(spacing: 20) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 60))
                            .foregroundStyle(PremiumColor.royalBlue)
                            .symbolEffect(.pulse.byLayer, options: .repeating, value: isAnimating)
                        
                        VStack(spacing: 8) {
                            Text("Reset Password")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Enter your email and we'll send you a link to reset your password")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    
                    VStack(spacing: 20) {
                        PremiumTextField(
                            icon: "envelope.fill",
                            placeholder: "Email",
                            text: $viewModel.formState.email,
                            isFocused: false
                        )
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        
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
                                        .fontWeight(.bold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(PremiumColor.royalBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(viewModel.isLoading || !viewModel.formState.isValidEmail)
                        .opacity(viewModel.formState.isValidEmail ? 1 : 0.6)
                    }
                    .padding(25)
                    .glass(cornerRadius: 25)
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { isAnimating = true }
        }
    }
}

// MARK: - Premium Components

private struct PremiumTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(isFocused ? PremiumColor.hex("2E3192") : .secondary)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .tint(PremiumColor.hex("2E3192"))
        }
        .padding()
        .background(Material.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isFocused ? PremiumColor.royalBlue : LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .shadow(color: isFocused ? PremiumColor.hex("2E3192").opacity(0.15) : .clear, radius: 8, x: 0, y: 4)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

private struct PremiumSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isFocused: Bool
    @State private var isSecure = true
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(isFocused ? PremiumColor.hex("2E3192") : .secondary)
                .frame(width: 20)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .tint(PremiumColor.hex("2E3192"))
            } else {
                TextField(placeholder, text: $text)
                    .tint(PremiumColor.hex("2E3192"))
            }
            
            Button(action: { isSecure.toggle() }) {
                Image(systemName: isSecure ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .padding()
        .background(Material.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isFocused ? PremiumColor.royalBlue : LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .shadow(color: isFocused ? PremiumColor.hex("2E3192").opacity(0.15) : .clear, radius: 8, x: 0, y: 4)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

private struct SocialButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Material.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Premium Animated Logo
struct PremiumAnimatedLogo: View {
    @State private var isHovering = false
    @State private var heartScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // 1. Ambient Glow (Breathing)
            Circle()
                .fill(PremiumColor.royalBlue)
                .frame(width: 90, height: 90)
                .blur(radius: 50)
                .opacity(isHovering ? 0.7 : 0.5)
                .scaleEffect(isHovering ? 1.2 : 1.0)
            
            // 2. Glass Container (Floating)
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Material.thinMaterial)
                    .frame(width: 110, height: 110)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.8), .white.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                
                // 3. Main Icon (Heartbeat)
                Image(systemName: "heart.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PremiumColor.hex("2E3192"), PremiumColor.hex("1BFFFF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: PremiumColor.hex("2E3192").opacity(0.4), radius: 8, x: 0, y: 4)
                    .scaleEffect(heartScale)
            }
            .offset(y: isHovering ? -10 : 0)
            .rotation3DEffect(
                .degrees(isHovering ? 5 : -5),
                axis: (x: 1, y: 0, z: 0)
            )
        }
        .onAppear {
            // Floating Animation
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                isHovering = true
            }
            
            // Heartbeat Animation
            startHeartbeat()
        }
    }
    
    func startHeartbeat() {
        // Realistic Lub-Dub
        let beatDuration = 0.15
        
        // Beat 1
        withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) {
            heartScale = 1.2
        }
        
        // Return
        DispatchQueue.main.asyncAfter(deadline: .now() + beatDuration) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) {
                heartScale = 1.0
            }
        }
        
        // Beat 2
        DispatchQueue.main.asyncAfter(deadline: .now() + beatDuration * 2) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) {
                heartScale = 1.2
            }
        }
        
        // Return & Wait
        DispatchQueue.main.asyncAfter(deadline: .now() + beatDuration * 3) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) {
                heartScale = 1.0
            }
            
            // Loop
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                startHeartbeat()
            }
        }
    }
}

#Preview("Login") {
    LoginView()
}

#Preview("SignUp") {
    SignUpView()
}
