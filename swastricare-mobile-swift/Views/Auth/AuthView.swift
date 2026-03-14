//
//  AuthView.swift
//  swastricare-mobile-swift
//

import SwiftUI

// MARK: - Login View

struct LoginView: View {
    @StateObject private var viewModel = DependencyContainer.shared.authViewModel
    @State private var showSignUp = false
    @State private var showResetPassword = false
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var headerOpacity: Double = 0
    @State private var headerOffset: CGFloat = 20
    @State private var formOpacity: Double = 0
    @State private var formOffset: CGFloat = 25
    @State private var footerOpacity: Double = 0
    @State private var glowBreathing: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Rich layered background
                AuthGradientBackground()

                GeometryReader { geo in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {

                            // MARK: — Logo hero
                            ZStack {
                                // Breathing glow behind logo
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color(hex: "11998e").opacity(0.35),
                                                Color(hex: "11998e").opacity(0.0)
                                            ],
                                            center: .center,
                                            startRadius: 20,
                                            endRadius: 80
                                        )
                                    )
                                    .frame(width: 160, height: 160)
                                    .scaleEffect(glowBreathing ? 1.15 : 0.85)

                                Image("AppLogo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 88, height: 88)
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                    .shadow(color: Color(hex: "11998e").opacity(0.4), radius: 20, y: 8)
                            }
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                            .padding(.top, 44)

                            // MARK: — Header text
                            VStack(spacing: 6) {
                                Text("SwasthiCare")
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(hex: "11998e"), Color(hex: "38ef7d")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )

                                Text("Your family's health companion")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .opacity(headerOpacity)
                            .offset(y: headerOffset)
                            .padding(.top, 16)
                            .padding(.bottom, 40)

                            // MARK: — Form card
                            VStack(spacing: 18) {
                                // Input fields
                                VStack(spacing: 14) {
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
                                }

                                // Forgot password
                                HStack {
                                    Spacer()
                                    Button(action: { showResetPassword = true }) {
                                        Text("Forgot Password?")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(Color(hex: "11998e"))
                                    }
                                }

                                // Error
                                if let error = viewModel.errorMessage {
                                    AuthAlertBanner(message: error, isSuccess: false)
                                }

                                // Sign In button
                                Button(action: {
                                    Task { await viewModel.signIn() }
                                }) {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Sign In")
                                    }
                                }
                                .buttonStyle(AuthPrimaryButtonStyle(isEnabled: viewModel.formState.isValidForLogin))
                                .disabled(viewModel.isLoading || !viewModel.formState.isValidForLogin)

                                // Divider
                                HStack(spacing: 16) {
                                    VStack { Divider() }
                                    Text("or")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                    VStack { Divider() }
                                }
                                .padding(.vertical, 2)

                                // Social row
                                HStack(spacing: 12) {
                                    AuthSocialButton(icon: "g.circle.fill", title: "Google") {
                                        Task { await viewModel.signInWithGoogle() }
                                    }
                                    AuthSocialButton(icon: "apple.logo", title: "Apple") {
                                        Task { await viewModel.signInWithApple() }
                                    }
                                }
                            }
                            .padding(20)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.25), lineWidth: 0.5)
                            )
                            .padding(.horizontal, 20)
                            .opacity(formOpacity)
                            .offset(y: formOffset)

                            Spacer(minLength: 40)

                            // MARK: — Footer
                            Button(action: { showSignUp = true }) {
                                HStack(spacing: 4) {
                                    Text("New here?")
                                        .foregroundColor(.secondary)
                                    Text("Create Account")
                                        .fontWeight(.bold)
                                        .foregroundColor(Color(hex: "11998e"))
                                }
                                .font(.system(size: 14))
                            }
                            .opacity(footerOpacity)
                            .padding(.bottom, 28)
                        }
                        .frame(minHeight: geo.size.height)
                    }
                }
            }
            .onAppear { runEntranceAnimation() }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showResetPassword) {
                ResetPasswordView()
            }
        }
    }

    private func runEntranceAnimation() {
        // 1. Logo pops in
        withAnimation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.1)) {
            logoScale = 1.0
            logoOpacity = 1
        }
        // 2. Glow breathes
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(0.5)) {
            glowBreathing = true
        }
        // 3. Header slides up
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
            headerOpacity = 1
            headerOffset = 0
        }
        // 4. Form card slides up
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.5)) {
            formOpacity = 1
            formOffset = 0
        }
        // 5. Footer fades
        withAnimation(.easeOut(duration: 0.4).delay(0.8)) {
            footerOpacity = 1
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
        case name, phone, email, password, confirm
    }

    var body: some View {
        ZStack {
            AuthGradientBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 16)

                    // Header
                    VStack(spacing: 6) {
                        Text("Create Account")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Text("Start your health journey today")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    // Form card
                    VStack(spacing: 18) {
                        VStack(spacing: 14) {
                            AuthTextField(
                                title: "Full Name",
                                icon: "person.fill",
                                text: $viewModel.formState.fullName
                            )
                            .focused($focusedField, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .phone }

                            AuthTextField(
                                title: "Phone Number",
                                icon: "phone.fill",
                                text: $viewModel.formState.phoneNumber,
                                keyboardType: .phonePad
                            )
                            .focused($focusedField, equals: .phone)
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
                            AuthAlertBanner(message: error, isSuccess: false)
                        }

                        Button(action: {
                            Task { await viewModel.signUp() }
                        }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Create Account")
                            }
                        }
                        .buttonStyle(AuthPrimaryButtonStyle(isEnabled: viewModel.formState.isValidForSignUp))
                        .disabled(viewModel.isLoading || !viewModel.formState.isValidForSignUp)

                        Text("By signing up, you agree to our Terms & Privacy Policy")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.25), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 20)

                    Spacer()

                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .foregroundColor(.secondary)
                            Text("Sign In")
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "11998e"))
                        }
                        .font(.system(size: 14))
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
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
            AuthGradientBackground()

            VStack(spacing: 28) {
                Capsule()
                    .fill(Color.primary.opacity(0.15))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "11998e").opacity(0.12))
                            .frame(width: 64, height: 64)

                        Image(systemName: "lock.rotation")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: "11998e"))
                    }

                    Text("Reset Password")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Enter your email and we'll send you a reset link")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 8)

                VStack(spacing: 20) {
                    AuthTextField(
                        title: "Email",
                        icon: "envelope.fill",
                        text: $viewModel.formState.email,
                        keyboardType: .emailAddress
                    )

                    if let message = viewModel.errorMessage {
                        AuthAlertBanner(message: message, isSuccess: message.contains("sent"))
                    }

                    Button(action: {
                        Task { await viewModel.resetPassword() }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Send Reset Link")
                        }
                    }
                    .buttonStyle(AuthPrimaryButtonStyle(isEnabled: viewModel.formState.isValidEmail))
                    .disabled(viewModel.isLoading || !viewModel.formState.isValidEmail)
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.25), lineWidth: 0.5)
                )
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }
}

// MARK: - Rich Gradient Background

struct AuthGradientBackground: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Base
            Color(UIColor.systemBackground).ignoresSafeArea()

            if colorScheme == .dark {
                // Deep teal-tinted dark
                LinearGradient(
                    colors: [
                        Color(hex: "0A1A1A"),
                        Color(hex: "0D1117"),
                        Color(hex: "0A0E14")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Teal orb — top right
                Circle()
                    .fill(Color(hex: "11998e").opacity(0.12))
                    .blur(radius: 80)
                    .frame(width: 280, height: 280)
                    .offset(x: 120, y: -100)

                // Purple orb — bottom left
                Circle()
                    .fill(Color(hex: "7C3AED").opacity(0.08))
                    .blur(radius: 90)
                    .frame(width: 250, height: 250)
                    .offset(x: -120, y: 300)

                // Pink accent — center bottom
                Circle()
                    .fill(Color(hex: "EC4899").opacity(0.05))
                    .blur(radius: 70)
                    .frame(width: 200, height: 200)
                    .offset(x: 40, y: 200)
            } else {
                // Light mode — soft teal wash
                LinearGradient(
                    colors: [
                        Color(hex: "F0FDFA"),
                        Color.white,
                        Color(hex: "F5F3FF")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Teal orb
                Circle()
                    .fill(Color(hex: "11998e").opacity(0.06))
                    .blur(radius: 80)
                    .frame(width: 280, height: 280)
                    .offset(x: 120, y: -80)

                // Purple orb
                Circle()
                    .fill(Color(hex: "7C3AED").opacity(0.04))
                    .blur(radius: 80)
                    .frame(width: 250, height: 250)
                    .offset(x: -120, y: 280)
            }
        }
    }
}

// Legacy wrapper
struct AuthBackground: View {
    var body: some View {
        AuthGradientBackground()
    }
}

// MARK: - Components

/// Alert banner for error/success
struct AuthAlertBanner: View {
    let message: String
    var isSuccess: Bool = false

    private var color: Color { isSuccess ? AppColors.accentGreen : AppColors.accentRed }
    private var icon: String { isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill" }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 14))
            Text(message).font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

/// Input field chrome
private struct AuthInputModifier: ViewModifier {
    let isFocused: Bool
    @Environment(\.colorScheme) var colorScheme

    private var accentTeal: Color { Color(hex: "11998e") }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(colorScheme == .dark ? Color.white.opacity(0.04) : Color.primary.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isFocused ? accentTeal.opacity(0.6) : Color.primary.opacity(0.06),
                        lineWidth: isFocused ? 1.5 : 0.5
                    )
            )
            .animation(.easeOut(duration: 0.2), value: isFocused)
    }
}

private struct AuthInputLabel: View {
    let title: String
    let isFocused: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(isFocused ? Color(hex: "11998e") : .secondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}

struct AuthTextField: View {
    let title: String
    let icon: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AuthInputLabel(title: title, isFocused: isFocused)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(isFocused ? Color(hex: "11998e") : .secondary)
                    .frame(width: 18)
                    .font(.system(size: 14))

                TextField("", text: $text)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .tint(Color(hex: "11998e"))
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .focused($isFocused)
            }
            .modifier(AuthInputModifier(isFocused: isFocused))
        }
    }
}

struct AuthSecureField: View {
    let title: String
    let icon: String
    @Binding var text: String
    @State private var isSecure = true
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AuthInputLabel(title: title, isFocused: isFocused)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(isFocused ? Color(hex: "11998e") : .secondary)
                    .frame(width: 18)
                    .font(.system(size: 14))

                if isSecure {
                    SecureField("", text: $text)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .tint(Color(hex: "11998e"))
                        .focused($isFocused)
                } else {
                    TextField("", text: $text)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .tint(Color(hex: "11998e"))
                        .focused($isFocused)
                }

                Button(action: { isSecure.toggle() }) {
                    Image(systemName: isSecure ? "eye" : "eye.slash")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
            }
            .modifier(AuthInputModifier(isFocused: isFocused))
        }
    }
}

struct AuthPrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                isEnabled
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [Color(hex: "11998e"), Color(hex: "38ef7d")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    : AnyShapeStyle(Color.gray.opacity(0.25))
            )
            .clipShape(Capsule())
            .shadow(
                color: isEnabled ? Color(hex: "11998e").opacity(0.35) : .clear,
                radius: 14, y: 6
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
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
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    LoginView()
}
