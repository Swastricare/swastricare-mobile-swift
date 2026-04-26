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
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppColors.loginMintLight, AppColors.loginMint],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    heroImage
                    formCard
                    trustStrip
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

    private var heroImage: some View {
        // hero.png includes wordmark + 3D family/illustrations baked in.
        // Bleeds slightly past the phone width (108%) and fades into the form card.
        ZStack(alignment: .bottom) {
            Image("LoginHero")
                .resizable()
                .scaledToFit()
                .scaleEffect(1.08)
                .padding(.top, 16)

            LinearGradient(
                colors: [
                    AppColors.loginMintLight.opacity(0),
                    AppColors.loginMint,
                    Color(UIColor.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 70)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, -28)
        .clipped()
    }

    private var formCard: some View {
        VStack(spacing: 12) {
            VStack(spacing: 3) {
                Text("Welcome back")
                    .font(.system(size: 24, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundColor(AppColors.loginSlate)
                Text("Sign in to manage your family health")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.loginSlateMuted)
            }
            .padding(.top, 4)

            LoginField(
                title: "Email Address",
                icon: "envelope",
                placeholder: "Enter your email",
                text: $viewModel.formState.email,
                keyboardType: .emailAddress
            )
            .focused($focusedField, equals: .email)
            .submitLabel(.next)
            .onSubmit { focusedField = .password }

            LoginSecureField(
                title: "Password",
                placeholder: "Enter your password",
                text: $viewModel.formState.password
            )
            .focused($focusedField, equals: .password)
            .submitLabel(.go)
            .onSubmit {
                if viewModel.formState.isValidForLogin {
                    Task { await viewModel.signIn() }
                }
            }

            HStack {
                Spacer()
                Button { showResetPassword = true } label: {
                    Text("Forgot password?")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.loginTeal)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, -4)

            if let error = viewModel.errorMessage {
                AuthAlertBanner(message: error, isSuccess: false)
            }

            LoginPrimaryButton(
                title: "Sign In",
                isLoading: viewModel.isLoading,
                isEnabled: viewModel.formState.isValidForLogin
            ) {
                Task { await viewModel.signIn() }
            }
            .padding(.top, 2)

            HStack(spacing: 12) {
                Rectangle().fill(AppColors.loginBorder).frame(height: 1)
                Text("or continue with")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.loginSlateMuted)
                    .fixedSize()
                Rectangle().fill(AppColors.loginBorder).frame(height: 1)
            }
            .padding(.vertical, 2)

            HStack(spacing: 10) {
                LoginSocialButton(provider: .google) {
                    Task { await viewModel.signInWithGoogle() }
                }
                LoginSocialButton(provider: .apple) {
                    Task { await viewModel.signInWithApple() }
                }
            }

            Button { showSignUp = true } label: {
                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .foregroundColor(AppColors.loginSlateMuted)
                    Text("Create Account")
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.loginTeal)
                }
                .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(EdgeInsets(top: 22, leading: 24, bottom: 16, trailing: 24))
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 28,
                topTrailingRadius: 28,
                style: .continuous
            )
            .fill(Color(UIColor.systemBackground))
            .shadow(color: AppColors.loginSlate.opacity(0.06), radius: 32, y: -12)
        )
    }

    private var trustStrip: some View {
        HStack(spacing: 0) {
            trustItem(icon: "checkmark.shield.fill", title: "ABDM Ready", color: AppColors.loginTeal)
            Spacer()
            trustDot
            Spacer()
            trustItem(icon: "lock.fill", title: "Secure Records", color: AppColors.loginSlate)
            Spacer()
            trustDot
            Spacer()
            trustItem(icon: "person.2.fill", title: "Family Care", color: AppColors.loginTeal)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
    }

    private func trustItem(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.loginSlate)
                .fixedSize()
        }
    }

    private var trustDot: some View {
        Circle()
            .fill(AppColors.loginSlateLight)
            .frame(width: 3, height: 3)
    }
}

// MARK: - Login Field

private struct LoginField: View {
    let title: String
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(AppColors.loginSlate)

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(isFocused ? AppColors.loginTeal : AppColors.loginSlateLight)
                    .font(.system(size: 16))

                TextField(placeholder, text: $text)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.loginSlate)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .tint(AppColors.loginTeal)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(
                        isFocused ? AppColors.loginTeal : AppColors.loginBorder,
                        lineWidth: 1.5
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(AppColors.loginTeal.opacity(isFocused ? 0.12 : 0))
                    .blur(radius: isFocused ? 4 : 0)
            )
            .animation(.easeOut(duration: 0.18), value: isFocused)
        }
    }
}

private struct LoginSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @State private var isSecure = true
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(AppColors.loginSlate)

            HStack(spacing: 10) {
                Image(systemName: "lock")
                    .foregroundColor(isFocused ? AppColors.loginTeal : AppColors.loginSlateLight)
                    .font(.system(size: 16))

                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                .font(.system(size: 14))
                .foregroundColor(AppColors.loginSlate)
                .focused($isFocused)
                .tint(AppColors.loginTeal)

                Button { isSecure.toggle() } label: {
                    Image(systemName: isSecure ? "eye" : "eye.slash")
                        .foregroundColor(AppColors.loginSlateLight)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(
                        isFocused ? AppColors.loginTeal : AppColors.loginBorder,
                        lineWidth: 1.5
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(AppColors.loginTeal.opacity(isFocused ? 0.12 : 0))
                    .blur(radius: isFocused ? 4 : 0)
            )
            .animation(.easeOut(duration: 0.18), value: isFocused)
        }
    }
}

// MARK: - Login Primary Button (vertical 3-stop gradient + arrow medallion)

private struct LoginPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 28, height: 28)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, 18)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    stops: [
                        .init(color: AppColors.loginTealBright, location: 0.0),
                        .init(color: AppColors.loginTeal, location: 0.5),
                        .init(color: AppColors.loginTealDark, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .blendMode(.plusLighter)
                    .mask(
                        VStack(spacing: 0) {
                            Rectangle().frame(height: 1)
                            Spacer()
                        }
                    )
            )
            .shadow(color: AppColors.loginTeal.opacity(0.33), radius: 12, x: 0, y: 10)
            .opacity(isEnabled ? 1 : 0.55)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled || isLoading)
    }
}

// MARK: - Login Social Button (with multi-color Google G)

private struct LoginSocialButton: View {
    enum Provider {
        case google, apple
        var label: String {
            switch self {
            case .google: return "Google"
            case .apple: return "Apple"
            }
        }
    }

    let provider: Provider
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                providerIcon
                Text(provider.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.loginSlate)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.loginBorder, lineWidth: 1.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private var providerIcon: some View {
        switch provider {
        case .google:
            GoogleGMark()
                .frame(width: 18, height: 18)
        case .apple:
            Image(systemName: "applelogo")
                .font(.system(size: 18))
                .foregroundColor(AppColors.loginSlate)
        }
    }
}

/// Multi-color Google "G" mark — 4 colored arcs around a transparent center.
/// Approximation of the official Google logo using SwiftUI shapes (no asset required).
private struct GoogleGMark: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let cx = w / 2, cy = h / 2
            let outer = min(w, h) / 2
            let inner = outer * 0.55

            func arc(start: Double, end: Double, color: Color) {
                var path = Path()
                path.addArc(center: CGPoint(x: cx, y: cy),
                           radius: outer,
                           startAngle: .degrees(start),
                           endAngle: .degrees(end),
                           clockwise: false)
                path.addArc(center: CGPoint(x: cx, y: cy),
                           radius: inner,
                           startAngle: .degrees(end),
                           endAngle: .degrees(start),
                           clockwise: true)
                path.closeSubpath()
                ctx.fill(path, with: .color(color))
            }

            // Blue (top right), Green (bottom right), Yellow (bottom left), Red (top left)
            arc(start: -50, end: 40, color: Color(hex: "4285F4"))
            arc(start: 40, end: 130, color: Color(hex: "34A853"))
            arc(start: 130, end: 220, color: Color(hex: "FBBC05"))
            arc(start: 220, end: 310, color: Color(hex: "EA4335"))

            // Horizontal bar of the G (blue extension)
            let barRect = CGRect(x: cx, y: cy - 1.5, width: outer + 1, height: 3)
            ctx.fill(Path(barRect), with: .color(Color(hex: "4285F4")))
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
