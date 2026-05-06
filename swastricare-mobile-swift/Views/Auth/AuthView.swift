//
//  AuthView.swift
//  swastricare-mobile-swift
//
//  Ported from Android auth screens (LoginScreen, SignUpScreen, ResetPasswordScreen,
//  EmailVerificationScreen, NewPasswordScreen) — pixel-matching Android design.
//  All screens live here behind a single `AuthPhase` enum so the app navigation
//  contract (just mount `LoginView()`) stays intact.
//

import SwiftUI
import UIKit
import Combine

// MARK: - Auth Phase

private enum AuthPhase: Equatable {
    case login
    case signUp
    case signUpPassword       // step 2 of signup
    case resetPassword
    case emailVerification
    case newPassword
}

// MARK: - Shared Design Tokens

private let aiTeal       = AppColors.aiTeal           // #22C5A6
private let aiTealDark   = AppColors.aiTealDark        // #0E8C75
private let errorRed     = Color(hex: "EF4444")
private let textDark     = Color(hex: "0F172A")
private let textGray     = Color(hex: "6B7280")
private let fieldBg      = Color.black.opacity(0.035)

// MARK: - Haptics

private func lightHaptic()  { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
private func mediumHaptic() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
private func errorHaptic()  { UINotificationFeedbackGenerator().notificationOccurred(.error) }

// MARK: - LoginView (public — app nav contract)

struct LoginView: View {
    @StateObject private var vm = DependencyContainer.shared.authViewModel
    @State private var phase: AuthPhase = .login

    var body: some View {
        ZStack {
            switch phase {
            case .login:
                LoginPhaseView(vm: vm, phase: $phase)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
            case .signUp, .signUpPassword:
                SignUpPhaseView(vm: vm, phase: $phase)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .trailing).combined(with: .opacity)
                    ))
            case .resetPassword:
                ResetPasswordPhaseView(vm: vm, phase: $phase)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .trailing).combined(with: .opacity)
                    ))
            case .emailVerification:
                EmailVerificationPhaseView(vm: vm, phase: $phase)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .trailing).combined(with: .opacity)
                    ))
            case .newPassword:
                NewPasswordPhaseView(vm: vm, phase: $phase)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: phase)
    }
}

// MARK: - Login Phase

private struct LoginPhaseView: View {
    @ObservedObject var vm: AuthViewModel
    @Binding var phase: AuthPhase

    @FocusState private var focused: LoginField?
    @State private var hasAttempted = false

    enum LoginField { case email, password }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero illustration — onboarding-style 4-edge blend, same size as onboarding p1
                    ZStack {
                        Image.androidImage("onboarding illustration")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 270)
                            .mask(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .black, location: 0.28),
                                        .init(color: .black, location: 0.72),
                                        .init(color: .clear, location: 1)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 56)
                            Spacer(minLength: 0)
                        }

                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            LinearGradient(
                                colors: [Color.white.opacity(0), Color.white],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 56)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 270)
                    .allowsHitTesting(false)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    // Title block
                    VStack(spacing: 6) {
                        Text("Welcome back!")
                            .font(.poppins(.bold, size: 24))
                            .foregroundColor(textDark)
                        Text("Login to continue")
                            .font(.poppins(.regular, size: 14))
                            .foregroundColor(textGray)
                    }
                    .padding(.bottom, 20)

                    // Form
                    VStack(spacing: 12) {
                        FloatingLabelField(
                            placeholder: "Email or Phone Number",
                            systemIcon: "envelope",
                            text: $vm.formState.email,
                            keyboardType: .emailAddress,
                            isSecure: false,
                            isFocused: focused == .email,
                            isError: hasAttempted && !vm.formState.isValidEmail
                        )
                        .focused($focused, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focused = .password }
                        .onTapGesture { lightHaptic() }

                        FloatingLabelField(
                            placeholder: "Password",
                            systemIcon: "lock",
                            text: $vm.formState.password,
                            isSecure: true,
                            isFocused: focused == .password,
                            isError: hasAttempted && !vm.formState.isValidPassword
                        )
                        .focused($focused, equals: .password)
                        .submitLabel(.go)
                        .onSubmit {
                            submitLogin()
                        }
                        .onTapGesture { lightHaptic() }

                        // Forgot password
                        HStack {
                            Spacer()
                            Button {
                                vm.clearError()
                                phase = .resetPassword
                            } label: {
                                Text("Forgot Password?")
                                    .font(.poppins(.semiBold, size: 13))
                                    .foregroundColor(aiTeal)
                            }
                        }

                        // Error banner
                        if let err = vm.errorMessage {
                            AuthBanner(message: err, isSuccess: false)
                                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        }

                        // Primary CTA
                        PrimaryAuthButton(title: "Login", isLoading: vm.isLoading, isEnabled: !vm.isLoading) {
                            submitLogin()
                        }

                        OrDivider(text: "or continue with")

                        GoogleAuthButton(isEnabled: !vm.isLoading) {
                            mediumHaptic()
                            Task { await vm.signInWithGoogle() }
                        }

                        AppleAuthButton(isEnabled: !vm.isLoading) {
                            mediumHaptic()
                            Task { await vm.signInWithApple() }
                        }

                        // Sign up link
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .font(.poppins(.regular, size: 14))
                                .foregroundColor(textGray)
                            Button {
                                vm.clearError()
                                vm.formState = AuthFormState()
                                phase = .signUp
                            } label: {
                                Text("Sign Up")
                                    .font(.poppins(.bold, size: 14))
                                    .foregroundColor(aiTeal)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { focused = nil }
        }
        .onAppear { vm.clearError() }
    }

    private func submitLogin() {
        hasAttempted = true
        mediumHaptic()
        if vm.formState.isValidForLogin {
            Task {
                await vm.signIn()
            }
        } else {
            errorHaptic()
        }
    }
}

// MARK: - Sign Up Phase

private struct SignUpPhaseView: View {
    @ObservedObject var vm: AuthViewModel
    @Binding var phase: AuthPhase

    // Step is tracked here; phase .signUp = step1, .signUpPassword = step2
    @FocusState private var focused: SignUpField?
    @State private var hasAttemptedStep1 = false
    @State private var hasAttemptedStep2 = false

    // Local first/last name mirrors to vm.formState.fullName on commit
    @State private var firstName = ""
    @State private var lastName  = ""
    @State private var agreedToTerms = false

    enum SignUpField { case firstName, lastName, email, password, confirm }

    private var isStep1: Bool { phase == .signUp }

    private var isStep1Valid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        vm.formState.isValidEmail
    }

    private var step1Error: String? {
        guard hasAttemptedStep1 else { return nil }
        if firstName.trimmingCharacters(in: .whitespaces).isEmpty { return "Please enter your first name" }
        if lastName.trimmingCharacters(in: .whitespaces).isEmpty  { return "Please enter your last name" }
        if !vm.formState.isValidEmail { return "Enter a valid email address" }
        return nil
    }

    private var step2Error: String? {
        guard hasAttemptedStep2 else { return nil }
        if vm.formState.password.isEmpty     { return "Password is required" }
        if !vm.formState.isValidPassword     { return "Password must be at least 6 characters" }
        if vm.formState.confirmPassword.isEmpty { return "Please confirm your password" }
        if !vm.formState.passwordsMatch      { return "Passwords do not match" }
        if !agreedToTerms                    { return "Please accept the Terms and Privacy Policy" }
        return nil
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero illustration
                    Image.androidImage("sign in screen icon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .padding(.top, 24)
                        .padding(.bottom, 8)

                    // Animated step content
                    Group {
                        if isStep1 {
                            step1Content
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal:   .move(edge: .trailing).combined(with: .opacity)
                                ))
                        } else {
                            step2Content
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal:   .move(edge: .leading).combined(with: .opacity)
                                ))
                        }
                    }
                    .animation(.spring(response: 0.32, dampingFraction: 0.82), value: phase)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { focused = nil }

            // Back button
            BackCircleButton {
                lightHaptic()
                if phase == .signUpPassword {
                    phase = .signUp
                } else {
                    vm.clearError()
                    vm.formState = AuthFormState()
                    phase = .login
                }
            }
        }
        .onAppear { vm.clearError() }
    }

    @ViewBuilder
    private var step1Content: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                Text("Create your account")
                    .font(.poppins(.bold, size: 24))
                    .foregroundColor(textDark)
                Text("Tell us a bit about you")
                    .font(.poppins(.regular, size: 14))
                    .foregroundColor(textGray)
            }
            .padding(.bottom, 8)

            FloatingLabelField(
                placeholder: "First Name",
                systemIcon: "person",
                text: $firstName,
                isSecure: false,
                isFocused: focused == .firstName,
                isError: hasAttemptedStep1 && firstName.trimmingCharacters(in: .whitespaces).isEmpty
            )
            .focused($focused, equals: .firstName)
            .submitLabel(.next)
            .onSubmit { focused = .lastName }
            .onTapGesture { lightHaptic() }

            FloatingLabelField(
                placeholder: "Last Name",
                systemIcon: "person",
                text: $lastName,
                isSecure: false,
                isFocused: focused == .lastName,
                isError: hasAttemptedStep1 && lastName.trimmingCharacters(in: .whitespaces).isEmpty
            )
            .focused($focused, equals: .lastName)
            .submitLabel(.next)
            .onSubmit { focused = .email }
            .onTapGesture { lightHaptic() }

            FloatingLabelField(
                placeholder: "Email Address",
                systemIcon: "envelope",
                text: $vm.formState.email,
                keyboardType: .emailAddress,
                isSecure: false,
                isFocused: focused == .email,
                isError: hasAttemptedStep1 && !vm.formState.isValidEmail
            )
            .focused($focused, equals: .email)
            .submitLabel(.done)
            .onSubmit { goToStep2() }
            .onTapGesture { lightHaptic() }

            let displayedError = vm.errorMessage ?? step1Error
            if let err = displayedError {
                AuthBanner(message: err, isSuccess: false)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }

            PrimaryAuthButton(title: "Next", isLoading: false, isEnabled: true) {
                goToStep2()
            }

            OrDivider(text: "or continue with")

            GoogleAuthButton(isEnabled: !vm.isLoading) {
                mediumHaptic()
                Task { await vm.signInWithGoogle() }
            }

            AppleAuthButton(isEnabled: !vm.isLoading) {
                mediumHaptic()
                Task { await vm.signInWithApple() }
            }

            HStack(spacing: 4) {
                Text("Already have an account?")
                    .font(.poppins(.regular, size: 14))
                    .foregroundColor(textGray)
                Button {
                    vm.clearError()
                    vm.formState = AuthFormState()
                    phase = .login
                } label: {
                    Text("Sign In")
                        .font(.poppins(.bold, size: 14))
                        .foregroundColor(aiTeal)
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var step2Content: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                Text("Create a password")
                    .font(.poppins(.bold, size: 24))
                    .foregroundColor(textDark)
                Text("Almost done — set a strong password")
                    .font(.poppins(.regular, size: 14))
                    .foregroundColor(textGray)
            }
            .padding(.bottom, 8)

            FloatingLabelField(
                placeholder: "Password",
                systemIcon: "lock",
                text: $vm.formState.password,
                isSecure: true,
                isFocused: focused == .password,
                isError: hasAttemptedStep2 && !vm.formState.isValidPassword
            )
            .focused($focused, equals: .password)
            .submitLabel(.next)
            .onSubmit { focused = .confirm }
            .onTapGesture { lightHaptic() }

            FloatingLabelField(
                placeholder: "Confirm Password",
                systemIcon: "lock",
                text: $vm.formState.confirmPassword,
                isSecure: true,
                isFocused: focused == .confirm,
                isError: hasAttemptedStep2 && !vm.formState.passwordsMatch
            )
            .focused($focused, equals: .confirm)
            .submitLabel(.done)
            .onSubmit { submitSignUp() }
            .onTapGesture { lightHaptic() }

            // Terms checkbox
            TermsRow(agreed: $agreedToTerms)

            let displayedError = vm.errorMessage ?? step2Error
            if let err = displayedError {
                AuthBanner(message: err, isSuccess: false)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }

            PrimaryAuthButton(title: "Sign Up", isLoading: vm.isLoading, isEnabled: !vm.isLoading) {
                submitSignUp()
            }
        }
    }

    private func goToStep2() {
        hasAttemptedStep1 = true
        if isStep1Valid {
            mediumHaptic()
            vm.clearError()
            // Merge first + last name into fullName
            vm.formState.fullName = "\(firstName.trimmingCharacters(in: .whitespaces)) \(lastName.trimmingCharacters(in: .whitespaces))"
            phase = .signUpPassword
        } else {
            errorHaptic()
        }
    }

    private func submitSignUp() {
        hasAttemptedStep2 = true
        mediumHaptic()
        guard vm.formState.isValidPassword && vm.formState.passwordsMatch && agreedToTerms else {
            errorHaptic()
            return
        }
        Task {
            await vm.signUp()
            // If signUp succeeds, vm.isAuthenticated flips → app nav picks it up.
            // If email verification required, errorMessage is set by VM.
            if let msg = vm.errorMessage, msg.lowercased().contains("email") {
                phase = .emailVerification
            }
        }
    }
}

// MARK: - Reset Password Phase

private struct ResetPasswordPhaseView: View {
    @ObservedObject var vm: AuthViewModel
    @Binding var phase: AuthPhase

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 72)

                    // Hero illustration
                    Image.androidImage("forgot password")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .padding(8)

                    Spacer().frame(height: 20)

                    Text("Forgot Password?")
                        .font(.poppins(.bold, size: 26))
                        .foregroundColor(textDark)

                    Spacer().frame(height: 10)

                    Text("No worries! Enter your registered email address and we'll send you a link to reset your password.")
                        .font(.poppins(.regular, size: 14))
                        .foregroundColor(textGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Spacer().frame(height: 28)

                    VStack(spacing: 16) {
                        FloatingLabelField(
                            placeholder: "Email Address",
                            systemIcon: "envelope",
                            text: $vm.formState.email,
                            keyboardType: .emailAddress,
                            isSecure: false,
                            isFocused: isFocused
                        )
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if vm.formState.isValidEmail { Task { await vm.resetPassword() } }
                        }
                        .onTapGesture { lightHaptic() }

                        if let msg = vm.errorMessage {
                            let isSuccess = msg.lowercased().contains("sent")
                            AuthBanner(message: msg, isSuccess: isSuccess)
                                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        }

                        PrimaryAuthButton(
                            title: "Send Reset Link",
                            isLoading: vm.isLoading,
                            isEnabled: vm.formState.isValidEmail && !vm.isLoading
                        ) {
                            mediumHaptic()
                            Task { await vm.resetPassword() }
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 24)

                    HStack(spacing: 4) {
                        Text("Remember your password?")
                            .font(.poppins(.regular, size: 14))
                            .foregroundColor(textGray)
                        Button {
                            vm.clearError()
                            phase = .login
                        } label: {
                            Text("Login")
                                .font(.poppins(.bold, size: 14))
                                .foregroundColor(aiTeal)
                        }
                    }

                    Spacer().frame(height: 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { isFocused = false }

            BackCircleButton {
                lightHaptic()
                vm.clearError()
                phase = .login
            }
        }
        .onAppear { vm.clearError() }
    }
}

// MARK: - Email Verification Phase

private struct EmailVerificationPhaseView: View {
    @ObservedObject var vm: AuthViewModel
    @Binding var phase: AuthPhase

    @State private var resendCooldown = 0
    @State private var showSuccess = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 56)

                    // Brand header
                    HStack(spacing: 8) {
                        Image.androidIcon("swastricare icon")
                            .resizable()
                            .frame(width: 36, height: 36)
                        brandWordmark
                    }
                    Spacer().frame(height: 2)
                    Text("Your Family, Our Care")
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(textGray)

                    Spacer().frame(height: 24)

                    // Hero
                    Image.androidImage("verify email")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .padding(8)

                    Spacer().frame(height: 20)

                    Text(showSuccess ? "Email Verified!" : "Check Your Email")
                        .font(.poppins(.bold, size: 26))
                        .foregroundColor(textDark)

                    Spacer().frame(height: 10)

                    if showSuccess {
                        Text("Redirecting you to the app...")
                            .font(.poppins(.regular, size: 14))
                            .foregroundColor(textGray)
                        Spacer().frame(height: 24)
                    } else {
                        verificationBody
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)

            if !showSuccess {
                BackCircleButton {
                    lightHaptic()
                    phase = .signUp
                }
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if resendCooldown > 0 { resendCooldown -= 1 }
        }
        .onChange(of: vm.isAuthenticated) { _, isAuth in
            if isAuth {
                showSuccess = true
            }
        }
    }

    @ViewBuilder
    private var verificationBody: some View {
        VStack(spacing: 0) {
            Text("We've sent a verification link to")
                .font(.poppins(.regular, size: 14))
                .foregroundColor(textGray)
            Spacer().frame(height: 4)
            Text(vm.formState.email)
                .font(.poppins(.semiBold, size: 14))
                .foregroundColor(aiTeal)
            Spacer().frame(height: 8)
            Text("Tap the link in the email to verify your account and continue.")
                .font(.poppins(.regular, size: 12))
                .foregroundColor(textGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer().frame(height: 28)

            VStack(spacing: 12) {
                PrimaryAuthButton(title: "Open Email App", isLoading: false, isEnabled: true) {
                    mediumHaptic()
                    openMailApp()
                }

                SecondaryAuthButton(
                    title: resendCooldown > 0 ? "Resend in \(resendCooldown)s" : "Resend Verification Email",
                    isLoading: vm.isLoading,
                    isEnabled: resendCooldown == 0 && !vm.isLoading
                ) {
                    mediumHaptic()
                    resendCooldown = 60
                    Task { await vm.resetPassword() } // reuse reset to resend; VM sends email
                }
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 20)

            Text("Check your spam folder if you don't see the email")
                .font(.poppins(.regular, size: 12))
                .foregroundColor(textGray.opacity(0.7))
                .multilineTextAlignment(.center)

            Spacer().frame(height: 20)

            HStack(spacing: 4) {
                Text("Wrong email?")
                    .font(.poppins(.regular, size: 14))
                    .foregroundColor(textGray)
                Button {
                    phase = .signUp
                } label: {
                    Text("Use a different email")
                        .font(.poppins(.bold, size: 14))
                        .foregroundColor(aiTeal)
                }
            }
            Spacer().frame(height: 40)
        }
    }

    private var brandWordmark: some View {
        HStack(spacing: 0) {
            Text("Swastri")
                .font(.poppins(.bold, size: 22))
                .foregroundColor(aiTeal)
            Text("care")
                .font(.poppins(.bold, size: 22))
                .foregroundColor(aiTealDark)
        }
    }

    private func openMailApp() {
        let urls = [
            "googlegmail://",
            "ms-outlook://",
            "mailto:"
        ]
        for urlStr in urls {
            if let url = URL(string: urlStr), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }
    }
}

// MARK: - New Password Phase

private struct NewPasswordPhaseView: View {
    @ObservedObject var vm: AuthViewModel
    @Binding var phase: AuthPhase

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @FocusState private var focused: NPField?

    enum NPField { case password, confirm }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 80)

                    // Shield icon circle
                    ZStack {
                        Circle()
                            .fill(aiTeal.opacity(0.12))
                            .frame(width: 64, height: 64)
                        Image(systemName: "shield.fill")
                            .font(.poppins(.regular, size: 28))
                            .foregroundColor(aiTeal)
                    }

                    Spacer().frame(height: 14)

                    Text("Set New Password")
                        .font(.poppins(.bold, size: 24))
                        .foregroundColor(textDark)

                    Spacer().frame(height: 8)

                    Text("Enter your new password below")
                        .font(.poppins(.regular, size: 13))
                        .foregroundColor(textGray)
                        .multilineTextAlignment(.center)

                    Spacer().frame(height: 28)

                    VStack(spacing: 20) {
                        FloatingLabelField(
                            placeholder: "New Password",
                            systemIcon: "lock",
                            text: $newPassword,
                            isSecure: true,
                            isFocused: focused == .password
                        )
                        .focused($focused, equals: .password)
                        .submitLabel(.next)
                        .onSubmit { focused = .confirm }
                        .onTapGesture { lightHaptic() }

                        FloatingLabelField(
                            placeholder: "Confirm Password",
                            systemIcon: "lock",
                            text: $confirmPassword,
                            isSecure: true,
                            isFocused: focused == .confirm
                        )
                        .focused($focused, equals: .confirm)
                        .submitLabel(.done)
                        .onSubmit { submitNewPassword() }
                        .onTapGesture { lightHaptic() }

                        if let err = vm.errorMessage {
                            AuthBanner(message: err, isSuccess: false)
                        }

                        PrimaryAuthButton(
                            title: "Update Password",
                            isLoading: vm.isLoading,
                            isEnabled: !newPassword.isEmpty && !confirmPassword.isEmpty && !vm.isLoading
                        ) {
                            submitNewPassword()
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { focused = nil }
        }
        .onChange(of: vm.isAuthenticated) { _, isAuth in
            if isAuth { phase = .login }
        }
    }

    private func submitNewPassword() {
        mediumHaptic()
        guard !newPassword.isEmpty, newPassword == confirmPassword else {
            errorHaptic()
            return
        }
        // Map to formState so VM's resetPassword / signIn can consume
        vm.formState.password = newPassword
        vm.formState.confirmPassword = confirmPassword
        Task { await vm.resetPassword() }
    }
}

// MARK: - Shared Sub-Components

// Floating-label text field (iOS port of Android PremiumTextField / PremiumSecureField)
struct FloatingLabelField: View {
    let placeholder: String
    let systemIcon: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool
    var isFocused: Bool
    var isError: Bool = false

    @State private var isPasswordVisible = false

    private var borderColor: Color {
        if isError   { return errorRed }
        if isFocused { return aiTeal.opacity(0.6) }
        return Color.black.opacity(0.12)
    }

    private var borderWidth: CGFloat { (isFocused || isError) ? 1 : 0.5 }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemIcon)
                .foregroundColor(isFocused ? aiTeal : Color(hex: "9CA3AF"))
                .font(.system(size: 16, weight: .regular))
                .frame(width: 18)

            if isSecure && !isPasswordVisible {
                SecureField(placeholder, text: $text)
                    .font(.poppins(.regular, size: 16))
                    .foregroundColor(textDark)
                    .tint(aiTeal)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                TextField(placeholder, text: $text)
                    .font(.poppins(.regular, size: 16))
                    .foregroundColor(textDark)
                    .tint(aiTeal)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if isSecure {
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                        .foregroundColor(Color(hex: "9CA3AF"))
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(fieldBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .animation(.easeOut(duration: 0.2), value: isFocused)
        .animation(.easeOut(duration: 0.2), value: isError)
    }
}

// Solid AITeal primary button — NO gradient. Hard rule.
private struct PrimaryAuthButton: View {
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
                        .font(.poppins(.bold, size: 16))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
        }
        .disabled(!isEnabled || isLoading)
        .background(isEnabled ? aiTeal : Color.gray.opacity(0.3))
        .clipShape(Capsule())
        .shadow(color: isEnabled ? aiTeal.opacity(0.35) : .clear, radius: 14, y: 6)
        .animation(.easeOut(duration: 0.2), value: isEnabled)
    }
}

// Secondary outlined AITeal button
private struct SecondaryAuthButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(aiTeal)
                } else {
                    Text(title)
                        .font(.poppins(.bold, size: 16))
                        .foregroundColor(isEnabled ? aiTeal : .gray)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
        }
        .disabled(!isEnabled || isLoading)
        .background(
            Capsule()
                .stroke(isEnabled ? aiTeal : Color.gray.opacity(0.3), lineWidth: 1.5)
        )
        .background(isEnabled ? aiTeal.opacity(0.08) : Color.clear)
        .clipShape(Capsule())
    }
}

// Google auth button — white bg, 1pt border
private struct GoogleAuthButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image.androidIcon("google_icon")
                    .resizable()
                    .frame(width: 20, height: 20)
                Text("Continue with Google")
                    .font(.poppins(.semiBold, size: 15))
                    .foregroundColor(Color(hex: "111827"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .disabled(!isEnabled)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
    }
}

// Apple auth button — solid black, white logo + label
private struct AppleAuthButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                Text("Continue with Apple")
                    .font(.poppins(.semiBold, size: 15))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .disabled(!isEnabled)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// "— or continue with —" divider
private struct OrDivider: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color.black.opacity(0.08)).frame(height: 0.5)
            Text(text)
                .font(.poppins(.regular, size: 12))
                .foregroundColor(Color.black.opacity(0.45))
                .fixedSize()
            Rectangle().fill(Color.black.opacity(0.08)).frame(height: 0.5)
        }
        .padding(.vertical, 4)
    }
}

// Error / success alert banner
private struct AuthBanner: View {
    let message: String
    let isSuccess: Bool

    private var color: Color { isSuccess ? AppColors.accentGreen : errorRed }
    private var icon:  String { isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill" }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
            Text(message)
                .font(.poppins(.medium, size: 13))
        }
        .foregroundColor(color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// Back chevron circle button
private struct BackCircleButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textDark)
                .frame(width: 36, height: 36)
                .background(Color.black.opacity(0.04))
                .clipShape(Circle())
        }
        .padding(16)
        .buttonStyle(ScaleButtonStyle())
    }
}

// Terms checkbox row
private struct TermsRow: View {
    @Binding var agreed: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                agreed.toggle()
                lightHaptic()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(agreed ? aiTeal : Color.black.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if agreed {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(aiTeal)
                            .frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            (Text("I agree to the ")
                .font(.poppins(.regular, size: 12))
                .foregroundColor(Color.black.opacity(0.7))
             + Text("Terms of Service")
                .font(.poppins(.semiBold, size: 12))
                .foregroundColor(aiTeal)
             + Text(" and ")
                .font(.poppins(.regular, size: 12))
                .foregroundColor(Color.black.opacity(0.7))
             + Text("Privacy Policy")
                .font(.poppins(.semiBold, size: 12))
                .foregroundColor(aiTeal))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Legacy aliases — keep app compiling if anything references old names
struct AuthGradientBackground: View {
    var body: some View {
        Color.white.ignoresSafeArea()
    }
}

struct AuthBackground: View {
    var body: some View { AuthGradientBackground() }
}

/// Alert banner for error/success (public — used by other screens if needed)
struct AuthAlertBanner: View {
    let message: String
    var isSuccess: Bool = false

    private var color: Color { isSuccess ? AppColors.accentGreen : AppColors.accentRed }
    private var icon: String { isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill" }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.poppins(.regular, size: 14))
            Text(message).font(.poppins(.medium, size: 13))
        }
        .foregroundColor(color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

/// Primary button style (public — legacy SignUpView referenced it)
struct AuthPrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.poppins(.bold, size: 16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(isEnabled ? aiTeal : Color.gray.opacity(0.3))
            .clipShape(Capsule())
            .shadow(color: isEnabled ? aiTeal.opacity(0.35) : .clear, radius: 14, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct AuthTextField: View {
    let title: String
    let icon: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    @FocusState private var isFocused: Bool

    var body: some View {
        FloatingLabelField(
            placeholder: title,
            systemIcon: icon,
            text: $text,
            keyboardType: keyboardType,
            isSecure: false,
            isFocused: isFocused
        )
        .focused($isFocused)
    }
}

struct AuthSecureField: View {
    let title: String
    let icon: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        FloatingLabelField(
            placeholder: title,
            systemIcon: icon,
            text: $text,
            isSecure: true,
            isFocused: isFocused
        )
        .focused($isFocused)
    }
}

struct AuthSocialButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.poppins(.semiBold, size: 14))
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
