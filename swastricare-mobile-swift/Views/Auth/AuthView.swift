//
//  AuthView.swift
//  swastricare-mobile-swift
//
//  Redesigned for SwastriCare Premium - Theme Adaptive
//

import SwiftUI

// MARK: - Login View

struct LoginView: View {
    @StateObject private var viewModel = DependencyContainer.shared.authViewModel
    @State private var showSignUp = false
    @State private var showResetPassword = false
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive Background
                AuthBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        Spacer().frame(height: 40)
                        
                        // Header
                        VStack(spacing: 16) {
                            // Logo
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(LinearGradient(colors: [Color(hex: "2E3192"), Color(hex: "1BFFFF")], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .shadow(color: Color(hex: "2E3192").opacity(0.3), radius: 10, x: 0, y: 5)
                            
                            VStack(spacing: 8) {
                                Text("Welcome Back")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("Sign in to your health companion")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Form
                        VStack(spacing: 24) {
                            VStack(spacing: 16) {
                                AuthTextField(
                                    title: "Email",
                                    icon: "envelope.fill",
                                    text: $viewModel.formState.email,
                                    keyboardType: .emailAddress
                                )
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                                
                                AuthSecureField(
                                    title: "Password",
                                    icon: "lock.fill",
                                    text: $viewModel.formState.password
                                )
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit {
                                    if viewModel.formState.isValidForLogin {
                                        Task { await viewModel.signIn() }
                                    }
                                }
                                
                                // Forgot Password
                                HStack {
                                    Spacer()
                                    Button(action: { showResetPassword = true }) {
                                        Text("Forgot Password?")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(hex: "2E3192"))
                                    }
                                }
                            }
                            
                            // Error
                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .transition(.opacity.combined(with: .scale))
                            }
                            
                            // Actions
                            VStack(spacing: 16) {
                                Button(action: {
                                    Task { await viewModel.signIn() }
                                }) {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Sign In")
                                            .fontWeight(.bold)
                                    }
                                }
                                .buttonStyle(AuthPrimaryButtonStyle(isEnabled: viewModel.formState.isValidForLogin))
                                .disabled(viewModel.isLoading || !viewModel.formState.isValidForLogin)
                                
                                HStack(spacing: 16) {
                                    Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
                                    Text("OR").font(.caption).foregroundColor(.secondary)
                                    Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
                                }
                                
                                HStack(spacing: 16) {
                                    AuthSocialButton(icon: "g.circle.fill", title: "Google") {
                                        Task { await viewModel.signInWithGoogle() }
                                    }
                                    
                                    AuthSocialButton(icon: "apple.logo", title: "Apple") {
                                        Task { await viewModel.signInWithApple() }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer()
                        
                        // Sign Up Link
                        Button(action: { showSignUp = true }) {
                            HStack {
                                Text("Don't have an account?")
                                    .foregroundColor(.secondary)
                                Text("Sign Up")
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(hex: "2E3192"))
                            }
                            .font(.system(size: 15))
                        }
                        .padding(.bottom, 20)
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
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, email, password, confirm
    }
    
    var body: some View {
        ZStack {
            AuthBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    Spacer().frame(height: 20)
                    
                    // Header
                    VStack(spacing: 8) {
                        Text("Create Account")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Start your health journey today")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Form
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            AuthTextField(
                                title: "Full Name",
                                icon: "person.fill",
                                text: $viewModel.formState.fullName
                            )
                            .focused($focusedField, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .email }
                            
                            AuthTextField(
                                title: "Email",
                                icon: "envelope.fill",
                                text: $viewModel.formState.email,
                                keyboardType: .emailAddress
                            )
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                            
                            AuthSecureField(
                                title: "Password",
                                icon: "lock.fill",
                                text: $viewModel.formState.password
                            )
                            .focused($focusedField, equals: .password)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .confirm }
                            
                            AuthSecureField(
                                title: "Confirm Password",
                                icon: "checkmark.shield.fill",
                                text: $viewModel.formState.confirmPassword
                            )
                            .focused($focusedField, equals: .confirm)
                            .submitLabel(.done)
                            .onSubmit {
                                if viewModel.formState.isValidForSignUp {
                                    Task { await viewModel.signUp() }
                                }
                            }
                        }
                        
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        
                        VStack(spacing: 16) {
                            Button(action: {
                                Task { await viewModel.signUp() }
                            }) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Create Account")
                                        .fontWeight(.bold)
                                }
                            }
                            .buttonStyle(AuthPrimaryButtonStyle(isEnabled: viewModel.formState.isValidForSignUp))
                            .disabled(viewModel.isLoading || !viewModel.formState.isValidForSignUp)
                            
                            Text("By signing up, you agree to our Terms & Privacy Policy")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        HStack {
                            Text("Already have an account?")
                                .foregroundColor(.secondary)
                            Text("Sign In")
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "2E3192"))
                        }
                        .font(.system(size: 15))
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                }
            }
        }
        .onChange(of: viewModel.isAuthenticated) { _, isAuth in
            if isAuth { dismiss() }
        }
    }
}

// MARK: - Reset Password View

struct ResetPasswordView: View {
    @StateObject private var viewModel = DependencyContainer.shared.authViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            AuthBackground()
            
            VStack(spacing: 32) {
                // Handle for sheet
                Capsule()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                
                VStack(spacing: 16) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "2E3192"))
                    
                    Text("Reset Password")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Enter your email and we'll send you a link to reset your password")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                
                VStack(spacing: 24) {
                    AuthTextField(
                        title: "Email",
                        icon: "envelope.fill",
                        text: $viewModel.formState.email,
                        keyboardType: .emailAddress
                    )
                    
                    if let message = viewModel.errorMessage {
                        Text(message)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(message.contains("sent") ? .green : .red)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: {
                        Task { await viewModel.resetPassword() }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Send Reset Link")
                                .fontWeight(.bold)
                        }
                    }
                    .buttonStyle(AuthPrimaryButtonStyle(isEnabled: viewModel.formState.isValidEmail))
                    .disabled(viewModel.isLoading || !viewModel.formState.isValidEmail)
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
    }
}

// MARK: - Components

struct AuthBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            GeometryReader { geo in
                // Top Right - Blue
                Circle()
                    .fill(Color(hex: "2E3192").opacity(colorScheme == .dark ? 0.15 : 0.05))
                    .blur(radius: 100)
                    .frame(width: 300, height: 300)
                    .position(x: geo.size.width, y: 0)
                
                // Bottom Left - Cyan
                Circle()
                    .fill(Color(hex: "1BFFFF").opacity(colorScheme == .dark ? 0.1 : 0.05))
                    .blur(radius: 90)
                    .frame(width: 250, height: 250)
                    .position(x: 0, y: geo.size.height)
            }
            .ignoresSafeArea()
        }
    }
}

struct AuthTextField: View {
    let title: String
    let icon: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                TextField("", text: $text)
                    .font(.system(size: 17))
                    .foregroundColor(.primary)
                    .tint(Color(hex: "2E3192"))
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
            }
            .padding()
            .background(Color.primary.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct AuthSecureField: View {
    let title: String
    let icon: String
    @Binding var text: String
    @State private var isSecure = true
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                if isSecure {
                    SecureField("", text: $text)
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                        .tint(Color(hex: "2E3192"))
                } else {
                    TextField("", text: $text)
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                        .tint(Color(hex: "2E3192"))
                }
                
                Button(action: { isSecure.toggle() }) {
                    Image(systemName: isSecure ? "eye" : "eye.slash")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.primary.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct AuthPrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                isEnabled ? Color(hex: "2E3192") : Color.gray.opacity(0.3)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: isEnabled ? Color(hex: "2E3192").opacity(0.3) : .clear,
                radius: 12, y: 6
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct AuthSocialButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

#Preview {
    LoginView()
}
