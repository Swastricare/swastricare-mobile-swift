//
//  HealthProfileQuestionnaireView.swift
//  swastricare-mobile-swift
//
//  Created by SwastriCare Team
//  Redesigned from scratch - High-End Production UI
//

import SwiftUI

// MARK: - Main View
struct HealthProfileQuestionnaireView: View {
    // MARK: - State
    @StateObject private var formState = HealthProfileFormState()
    @State private var currentStep = 0
    @State private var showSetup = false
    @State private var isCompleting = false  // Hide everything immediately when completing
    @Namespace private var animation
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Properties
    let onComplete: () -> Void
    // Steps:
    // 0: Intro
    // 1: Name
    // 2: Welcome (Transition)
    // 3: Gender
    // 4: DOB
    // 5: Height
    // 6: Weight
    private let totalSteps = 7
    
    // MARK: - Init
    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }
    
    // MARK: - Body
    var body: some View {
        Group {
            if isCompleting {
                // Show blank screen immediately when completing to prevent any glitch
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
            } else {
                ZStack {
                    // 1. Clean Background
                    Color(UIColor.systemBackground).ignoresSafeArea()
                    
                    // Ambient Glow
                    GeometryReader { geo in
                        Circle()
                            .fill(Color(hex: "2E3192").opacity(colorScheme == .dark ? 0.15 : 0.05))
                            .blur(radius: 120)
                            .frame(width: 400, height: 400)
                            .position(x: geo.size.width, y: 0)
                        
                        Circle()
                            .fill(Color(hex: "1BFFFF").opacity(colorScheme == .dark ? 0.1 : 0.05))
                            .blur(radius: 100)
                            .frame(width: 300, height: 300)
                            .position(x: 0, y: geo.size.height)
                    }
                    .ignoresSafeArea()
                    
                    // 2. Content - Hide immediately when setup starts to prevent glitch
                    if !showSetup {
                        VStack(spacing: 0) {
                            // Header (Progress) - Hide on Intro (0) and Welcome (2)
                            if currentStep > 0 && currentStep != 2 {
                                ProgressHeader(current: adjustedProgressStep, total: 4) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        // Skip Welcome screen when going back from Gender (3) -> Name (1)
                                        if currentStep == 3 {
                                            currentStep = 1
                                        } else {
                                            currentStep -= 1
                                        }
                                    }
                                }
                                .padding(.top, 60)
                                .padding(.horizontal, 24)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                            
                            // Steps
                            TabView(selection: $currentStep) {
                                IntroStepView(onStart: nextStep)
                                    .tag(0)
                                
                                NameStepView(name: $formState.name)
                                    .tag(1)
                                
                                WelcomeStepView(name: formState.name, onContinue: nextStep)
                                    .tag(2)
                                
                                GenderStepView(gender: $formState.gender)
                                    .tag(3)
                                
                                DOBStepView(date: $formState.dateOfBirth)
                                    .tag(4)
                                
                                HeightStepView(height: $formState.heightCm)
                                    .tag(5)
                                    
                                WeightStepView(weight: $formState.weightKg)
                                    .tag(6)
                            }
                            .tabViewStyle(.page(indexDisplayMode: .never))
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
                            
                            // Bottom Button (Only for input steps)
                            if shouldShowBottomButton {
                                Button(action: {
                                    if currentStep == 6 {
                                        // Dismiss keyboard before showing setup
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        // Small delay to ensure keyboard is dismissed
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                showSetup = true
                                            }
                                        }
                                    } else {
                                        nextStep()
                                    }
                                }) {
                                    Text(currentStep == 6 ? "Finish Setup" : "Continue")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(canProceed ? Color(hex: "2E3192") : Color.gray.opacity(0.3))
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .shadow(color: canProceed ? Color(hex: "2E3192").opacity(0.4) : .clear, radius: 20, y: 10)
                                }
                                .disabled(!canProceed)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 40)
                                .padding(.top, 20)
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .fullScreenCover(isPresented: $showSetup) {
                    SetupLoadingView(formState: formState, onComplete: {
                        // Set completing flag immediately to hide everything
                        isCompleting = true
                        
                        // Dismiss setup screen
                        showSetup = false
                        
                        // Complete onboarding after a brief delay to ensure smooth transition
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onComplete()
                        }
                    })
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func nextStep() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentStep += 1
        }
    }
    
    private var shouldShowBottomButton: Bool {
        // Hide button on Intro (0) and Welcome (2)
        // Intro has its own button, Welcome has its own button/auto-advance
        return currentStep != 0 && currentStep != 2
    }
    
    private var adjustedProgressStep: Int {
        // Map currentStep to 1...4 for the progress bar
        // 0: Intro (Hidden)
        // 1: Name -> 1
        // 2: Welcome (Hidden)
        // 3: Gender -> 2
        // 4: DOB -> 3
        // 5: Height -> 4
        // 6: Weight -> 4 (keep at max) or maybe expand total to 5
        
        switch currentStep {
        case 1: return 1
        case 3: return 2
        case 4: return 3
        case 5: return 4
        case 6: return 5 // Increased total to 5 displayed steps in logic
        default: return 1
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 1: return !formState.name.trimmingCharacters(in: .whitespaces).isEmpty
        case 3: return formState.gender != nil
        default: return true
        }
    }
}

// MARK: - Subviews

struct ProgressHeader: View {
    let current: Int
    let total: Int // Should ideally be 5 now
    let onBack: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Segmented Progress
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { step in
                    Capsule()
                        .fill(step <= current ? Color(hex: "2E3192") : Color.primary.opacity(0.1))
                        .frame(width: 30, height: 6)
                        .animation(.spring, value: current)
                }
            }
            
            Spacer()
            
            // Invisible balancer
            Color.clear.frame(width: 44, height: 44)
        }
    }
}

// MARK: - Step 0: Intro
struct IntroStepView: View {
    let onStart: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(colors: [Color(hex: "2E3192"), Color(hex: "1BFFFF")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Color(hex: "2E3192").opacity(0.5), radius: 30)
            
            VStack(spacing: 16) {
                Text("Your Health Profile")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Let's personalize Swastricare for you.\nThis takes less than a minute.")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button(action: onStart) {
                Text("Get Started")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "2E3192"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Step 1: Name
struct NameStepView: View {
    @Binding var name: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 40)
            
            Text("What's your name?")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
            
            TextField("Your Name", text: $name)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.primary)
                .tint(Color(hex: "2E3192"))
                .focused($isFocused)
                .submitLabel(.done)
                .padding(.vertical, 20)
                .overlay(
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 2)
                        .padding(.top, 50),
                    alignment: .bottom
                )
                .onSubmit {
                    // Dismiss keyboard when user presses done
                    isFocused = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            
            Text("This is how we'll address you.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .onAppear { 
            isFocused = true 
        }
        .onDisappear {
            // Always dismiss keyboard when leaving this view
            isFocused = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

// MARK: - Step 2: Welcome
struct WelcomeStepView: View {
    let name: String
    let onContinue: () -> Void
    @State private var displayedWelcomeText = ""
    @State private var displayedNameText = ""
    @State private var welcomeCursorOpacity: Double = 1.0
    @State private var nameCursorOpacity: Double = 1.0
    @State private var showQuote = false
    @State private var showButton = false
    @State private var welcomeTimer: Timer?
    @State private var nameTimer: Timer?
    @State private var welcomeCursorTimer: Timer?
    @State private var nameCursorTimer: Timer?
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                // Welcome text and name on separate lines to prevent overflow
                VStack(spacing: 8) {
                    HStack(spacing: 0) {
                        Text(displayedWelcomeText)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        if displayedWelcomeText != "Welcome" {
                            Text("|")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.primary.opacity(0.6))
                                .opacity(welcomeCursorOpacity)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .onChange(of: displayedWelcomeText) { _, newValue in
                        if newValue == "Welcome" {
                            // Stop cursor and start typing name after welcome is complete
                            welcomeCursorTimer?.invalidate()
                            welcomeCursorOpacity = 0
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                startTypingName()
                            }
                        }
                    }
                    
                    HStack(spacing: 0) {
                        Text(displayedNameText)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        if !displayedNameText.isEmpty && displayedNameText != name {
                            Text("|")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.primary.opacity(0.6))
                                .opacity(nameCursorOpacity)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .opacity(displayedNameText.isEmpty ? 0 : 1)
                    .onChange(of: displayedNameText) { _, newValue in
                        if newValue == name {
                            // Hide cursor and show quote after name is complete
                            nameCursorTimer?.invalidate()
                            nameCursorOpacity = 0
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    showQuote = true
                                }
                            }
                        }
                    }
                }
                
                Text("\"The journey of a thousand miles\nbegins with a single step.\"")
                    .font(.system(size: 18, weight: .medium, design: .serif))
                    .italic()
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .opacity(showQuote ? 1 : 0)
                    .offset(y: showQuote ? 0 : 20)
                    .onChange(of: showQuote) { _, newValue in
                        if newValue {
                            // Show button after quote appears
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    showButton = true
                                }
                            }
                        }
                    }
            }
            
            Spacer()
            
            Button(action: onContinue) {
                Text("Let's Go")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "2E3192"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color(hex: "2E3192").opacity(0.4), radius: 20, y: 10)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .opacity(showButton ? 1 : 0)
            .scaleEffect(showButton ? 1 : 0.9)
        }
        .onAppear {
            // Dismiss keyboard immediately when welcome screen appears
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            // Start typing welcome text
            startTypingWelcome()
            startWelcomeCursorBlink()
        }
        .onDisappear {
            // Clean up timers
            welcomeTimer?.invalidate()
            nameTimer?.invalidate()
            welcomeCursorTimer?.invalidate()
            nameCursorTimer?.invalidate()
        }
    }
    
    private func startTypingWelcome() {
        let welcomeText = "Welcome"
        var index = 0
        displayedWelcomeText = ""
        
        welcomeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if index < welcomeText.count {
                let charIndex = welcomeText.index(welcomeText.startIndex, offsetBy: index)
                displayedWelcomeText += String(welcomeText[charIndex])
                index += 1
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func startWelcomeCursorBlink() {
        welcomeCursorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                welcomeCursorOpacity = welcomeCursorOpacity == 1.0 ? 0.0 : 1.0
            }
        }
    }
    
    private func startTypingName() {
        var index = 0
        displayedNameText = ""
        nameCursorOpacity = 1.0
        startNameCursorBlink()
        
        nameTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { timer in
            if index < name.count {
                let charIndex = name.index(name.startIndex, offsetBy: index)
                displayedNameText += String(name[charIndex])
                index += 1
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func startNameCursorBlink() {
        nameCursorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                nameCursorOpacity = nameCursorOpacity == 1.0 ? 0.0 : 1.0
            }
        }
    }
}


// MARK: - Step 3: Gender
struct GenderStepView: View {
    @Binding var gender: Gender?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            Spacer().frame(height: 40)
            
            Text("Which gender do you identify with?")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                GenderOption(title: "Male", icon: "figure.stand", isSelected: gender == .male) {
                    gender = .male
                }
                
                GenderOption(title: "Female", icon: "figure.dress.line.vertical.figure", isSelected: gender == .female) {
                    gender = .female
                }
                
                GenderOption(title: "Other", icon: "person.2", isSelected: gender == .other) {
                    gender = .other
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

struct GenderOption: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .frame(width: 40)
                
                Text(title)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .white : .secondary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "2E3192"))
                        .font(.system(size: 24))
                        .background(Circle().fill(.white).padding(2))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color(hex: "2E3192") : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color(hex: "2E3192") : Color.clear, lineWidth: 1.5)
            )
        }
    }
}

// MARK: - Step 4: DOB (Redesigned)
struct DOBStepView: View {
    @Binding var date: Date
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            Spacer().frame(height: 40)
            
            Text("Date of Birth")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
            
            Text("This helps us provide age-appropriate insights.")
                .font(.system(size: 17))
                .foregroundColor(.secondary)
            
            // Clean Wheel Picker style
            DatePicker("", selection: $date, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Step 5: Height
struct HeightStepView: View {
    @Binding var height: Double
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("How tall are you?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(height))")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("cm")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            // Slider with custom thumb
            VStack(spacing: 20) {
                Slider(value: $height, in: 100...250, step: 1)
                    .tint(Color(hex: "2E3192"))
                
                HStack {
                    Text("100 cm")
                    Spacer()
                    Text("250 cm")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
}

// MARK: - Step 6: Weight
struct WeightStepView: View {
    @Binding var weight: Double
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("What is your weight?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(weight))")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("kg")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            // Slider with custom thumb
            VStack(spacing: 20) {
                Slider(value: $weight, in: 30...200, step: 0.5)
                    .tint(Color(hex: "2E3192"))
                
                HStack {
                    Text("30 kg")
                    Spacer()
                    Text("200 kg")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
}

#Preview {
    HealthProfileQuestionnaireView {}
}
