//
//  AuthView.swift
//  swastricare-mobile-swift
//
//  Redesigned to match app theme
//

import SwiftUI

// MARK: - Login View

struct LoginView: View {
    @StateObject private var viewModel = DependencyContainer.shared.authViewModel
    @State private var showSignUp = false
    @State private var showResetPassword = false
    @State private var appeared = false
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                GeometryReader { geo in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Header
                            VStack(spacing: 20) {
                                // App logo
                                Image("AppLogo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .shadow(color: AppColors.accentBlue.opacity(0.3), radius: 16, y: 8)

                                VStack(spacing: 6) {
                                    Text("Welcome back")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.primary)

                                    Text("Sign in to continue your health journey")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.top, 50)
                            .padding(.bottom, 36)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 15)

                            // Form
                            VStack(spacing: 20) {
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

                                // Forgot Password
                                HStack {
                                    Spacer()
                                    Button(action: { showResetPassword = true }) {
                                        Text("Forgot Password?")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(AppColors.accentBlue)
                                    }
                                }

                                // Error
                                if let error = viewModel.errorMessage {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .font(.system(size: 12))
                                        Text(error)
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundColor(AppColors.accentRed)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(AppColors.accentRed.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                }

                                // Sign In Button
                                Button(action: {
                                    Task { await viewModel.signIn() }
                                }) {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Sign In")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundColor(.white)
                                .background(
                                    viewModel.formState.isValidForLogin
                                        ? AnyShapeStyle(LinearGradient(colors: [AppColors.accentBlue, AppColors.onboardingPurple], startPoint: .leading, endPoint: .trailing))
                                        : AnyShapeStyle(Color.gray.opacity(0.3))
                                )
                                .clipShape(Capsule())
                                .shadow(color: viewModel.formState.isValidForLogin ? AppColors.accentBlue.opacity(0.3) : .clear, radius: 12, y: 6)
                                .buttonStyle(ScaleButtonStyle())
                                .disabled(viewModel.isLoading || !viewModel.formState.isValidForLogin)

                                // Divider
                                HStack(spacing: 16) {
                                    Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5)
                                    Text("or continue with")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5)
                                }
                                .padding(.vertical, 4)

                                // Social Buttons
                                HStack(spacing: 14) {
                                    AuthSocialButton(icon: "g.circle.fill", title: "Google") {
                                        Task { await viewModel.signInWithGoogle() }
                                    }

                                    AuthSocialButton(icon: "apple.logo", title: "Apple") {
                                        Task { await viewModel.signInWithApple() }
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)

                            Spacer(minLength: 30)

                            // Sign Up Link
                            Button(action: { showSignUp = true }) {
                                HStack(spacing: 4) {
                                    Text("Don't have an account?")
                                        .foregroundColor(.secondary)
                                    Text("Sign Up")
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.accentBlue)
                                }
                                .font(.system(size: 14))
                            }
                            .padding(.bottom, 24)
                        }
                        .frame(minHeight: geo.size.height)
                    }
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                    appeared = true
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
        case name, phone, email, password, confirm
    }

    var body: some View {
        ZStack {
            PremiumBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Spacer().frame(height: 16)

                    // Header
                    VStack(spacing: 6) {
                        Text("Create Account")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)

                        Text("Start your health journey today")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }

                    // Form
                    VStack(spacing: 20) {
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
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 12))
                                Text(error)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(AppColors.accentRed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(AppColors.accentRed.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button(action: {
                            Task { await viewModel.signUp() }
                        }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Create Account")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundColor(.white)
                        .background(
                            viewModel.formState.isValidForSignUp
                                ? AnyShapeStyle(LinearGradient(colors: [AppColors.accentBlue, AppColors.onboardingPurple], startPoint: .leading, endPoint: .trailing))
                                : AnyShapeStyle(Color.gray.opacity(0.3))
                        )
                        .clipShape(Capsule())
                        .shadow(color: viewModel.formState.isValidForSignUp ? AppColors.accentBlue.opacity(0.3) : .clear, radius: 12, y: 6)
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(viewModel.isLoading || !viewModel.formState.isValidForSignUp)

                        Text("By signing up, you agree to our Terms & Privacy Policy")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .foregroundColor(.secondary)
                            Text("Sign In")
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.accentBlue)
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
            PremiumBackground()

            VStack(spacing: 28) {
                // Handle
                Capsule()
                    .fill(Color.primary.opacity(0.15))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppColors.accentBlue.opacity(0.1))
                            .frame(width: 64, height: 64)

                        Image(systemName: "lock.rotation")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.accentBlue)
                    }

                    Text("Reset Password")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Enter your email and we'll send you a link to reset your password")
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
                        HStack(spacing: 6) {
                            Image(systemName: message.contains("sent") ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .font(.system(size: 12))
                            Text(message)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(message.contains("sent") ? AppColors.accentGreen : AppColors.accentRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background((message.contains("sent") ? AppColors.accentGreen : AppColors.accentRed).opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button(action: {
                        Task { await viewModel.resetPassword() }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Send Reset Link")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundColor(.white)
                    .background(
                        viewModel.formState.isValidEmail
                            ? AnyShapeStyle(LinearGradient(colors: [AppColors.accentBlue, AppColors.onboardingPurple], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.gray.opacity(0.3))
                    )
                    .clipShape(Capsule())
                    .shadow(color: viewModel.formState.isValidEmail ? AppColors.accentBlue.opacity(0.3) : .clear, radius: 12, y: 6)
                    .buttonStyle(ScaleButtonStyle())
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
    var body: some View {
        PremiumBackground()
    }
}

struct AuthTextField: View {
    let title: String
    let icon: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isFocused ? AppColors.accentBlue : .secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(isFocused ? AppColors.accentBlue : .secondary)
                    .frame(width: 18)
                    .font(.system(size: 14))

                TextField("", text: $text)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .tint(AppColors.accentBlue)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .focused($isFocused)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                colorScheme == .dark
                    ? AnyShapeStyle(Color.white.opacity(0.05))
                    : AnyShapeStyle(Color.primary.opacity(0.04))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isFocused ? AppColors.accentBlue.opacity(0.5) : Color.primary.opacity(0.08),
                        lineWidth: isFocused ? 1.5 : 0.5
                    )
            )
            .animation(.easeOut(duration: 0.2), value: isFocused)
        }
    }
}

struct AuthSecureField: View {
    let title: String
    let icon: String
    @Binding var text: String
    @State private var isSecure = true
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isFocused ? AppColors.accentBlue : .secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(isFocused ? AppColors.accentBlue : .secondary)
                    .frame(width: 18)
                    .font(.system(size: 14))

                if isSecure {
                    SecureField("", text: $text)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .tint(AppColors.accentBlue)
                        .focused($isFocused)
                } else {
                    TextField("", text: $text)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .tint(AppColors.accentBlue)
                        .focused($isFocused)
                }

                Button(action: { isSecure.toggle() }) {
                    Image(systemName: isSecure ? "eye" : "eye.slash")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                colorScheme == .dark
                    ? AnyShapeStyle(Color.white.opacity(0.05))
                    : AnyShapeStyle(Color.primary.opacity(0.04))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isFocused ? AppColors.accentBlue.opacity(0.5) : Color.primary.opacity(0.08),
                        lineWidth: isFocused ? 1.5 : 0.5
                    )
            )
            .animation(.easeOut(duration: 0.2), value: isFocused)
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
                    ? AnyShapeStyle(LinearGradient(colors: [AppColors.accentBlue, AppColors.onboardingPurple], startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(Color.gray.opacity(0.3))
            )
            .clipShape(Capsule())
            .shadow(
                color: isEnabled ? AppColors.accentBlue.opacity(0.3) : .clear,
                radius: 12, y: 6
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
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                colorScheme == .dark
                    ? AnyShapeStyle(Color.white.opacity(0.06))
                    : AnyShapeStyle(Color.primary.opacity(0.04))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    LoginView()
}
