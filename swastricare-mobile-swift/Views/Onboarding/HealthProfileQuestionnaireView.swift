//
//  HealthProfileQuestionnaireView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI

struct HealthProfileQuestionnaireView: View {
    @StateObject private var formState = HealthProfileFormState()
    @StateObject private var authViewModel = DependencyContainer.shared.authViewModel
    @State private var currentStep = 0
    @State private var showSetup = false
    @State private var isAnimating = false
    
    // Text field states for numeric inputs
    @State private var heightText: String = "170"
    @State private var weightText: String = "70"
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField {
        case height, weight, name
    }
    
    let onComplete: () -> Void
    
    private let totalSteps = 4
    
    // CRITICAL: Only show this view if user is authenticated
    private var isAuthenticated: Bool {
        authViewModel.isAuthenticated && authViewModel.currentUser != nil
    }
    
    var body: some View {
        Group {
            if isAuthenticated {
                questionnaireContent
            } else {
                // User not authenticated - show login screen instead
                LoginView()
            }
        }
    }
    
    private var questionnaireContent: some View {
        ZStack {
            PremiumBackground()
            
            VStack(spacing: 0) {
                // Progress Bar
                progressBar
                
                // Content
                TabView(selection: $currentStep) {
                    // Step 1: Name
                    nameStep
                        .tag(0)
                    
                    // Step 2: Gender & Date of Birth
                    genderAndDOBStep
                        .tag(1)
                    
                    // Step 3: Height
                    heightStep
                        .tag(2)
                    
                    // Step 4: Weight
                    weightStep
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Navigation Buttons
                navigationButtons
            }
        }
        .onTapGesture {
            focusedField = nil
        }
        .fullScreenCover(isPresented: $showSetup) {
            SetupLoadingView(
                formState: formState,
                onComplete: onComplete
            )
        }
        .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
            // If user logs out while on this screen, the view will automatically switch to LoginView
            if !isAuthenticated {
                // User logged out - view will handle it via the Group check above
            }
        }
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Step \(currentStep + 1) of \(totalSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int((Double(currentStep + 1) / Double(totalSteps)) * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "2E3192"), Color(hex: "4A90E2")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(currentStep + 1) / CGFloat(totalSteps), height: 4)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Name Step
    
    private var nameStep: some View {
        QuestionnaireStepView(
            title: "What's your name?",
            subtitle: "We'll use this to personalize your experience",
            icon: "person.fill"
        ) {
            VStack(spacing: 24) {
                TextField("Enter your name", text: $formState.name)
                    .font(.system(size: 20, weight: .medium))
                    .padding()
                    .padding(.horizontal, 8)
                    .glass(cornerRadius: 16)
                    .focused($focusedField, equals: .name)
                    .textContentType(.name)
                    .autocapitalization(.words)
                    .padding(.horizontal, 20)
            }
        }
        .onTapGesture {
            focusedField = nil
        }
    }
    
    // MARK: - Gender & DOB Step
    
    private var genderAndDOBStep: some View {
        QuestionnaireStepView(
            title: "Tell us about yourself",
            subtitle: "This helps us provide better health insights",
            icon: "person.circle.fill"
        ) {
            VStack(spacing: 32) {
                // Gender Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Gender")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        ForEach(Gender.allCases, id: \.self) { gender in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    formState.gender = gender
                                }
                            }) {
                                Text(gender.displayName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(formState.gender == gender ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        formState.gender == gender
                                            ? LinearGradient(
                                                colors: [Color(hex: "2E3192"), Color(hex: "4A90E2")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                            : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(formState.gender == gender ? Color.clear : Color.primary.opacity(0.2), lineWidth: 1)
                                    )
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                
                // Date of Birth
                VStack(alignment: .leading, spacing: 12) {
                    Text("Date of Birth")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    DatePicker(
                        "",
                        selection: $formState.dateOfBirth,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding()
                    .glass(cornerRadius: 16)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Height Step
    
    private var heightStep: some View {
        QuestionnaireStepView(
            title: "What's your height?",
            subtitle: "This helps calculate your health metrics",
            icon: "ruler.fill"
        ) {
            VStack(spacing: 32) {
                // Height Input (CM only)
                VStack(spacing: 24) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField("170", text: $heightText)
                            .keyboardType(.numberPad)
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "2E3192"))
                            .multilineTextAlignment(.center)
                            .frame(width: 140)
                            .focused($focusedField, equals: .height)
                            .onChange(of: heightText) { _, newValue in
                                if let value = Double(newValue), value >= 50, value <= 300 {
                                    formState.heightCm = value
                                }
                            }
                        
                        Text("cm")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    
                    // Quick adjust buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            if formState.heightCm > 100 {
                                formState.heightCm -= 1
                                heightText = String(Int(formState.heightCm))
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "2E3192"))
                        }
                        
                        Slider(
                            value: $formState.heightCm,
                            in: 100...250,
                            step: 1
                        )
                        .tint(Color(hex: "2E3192"))
                        .onChange(of: formState.heightCm) { _, newValue in
                            heightText = String(Int(newValue))
                        }
                        
                        Button(action: {
                            if formState.heightCm < 250 {
                                formState.heightCm += 1
                                heightText = String(Int(formState.heightCm))
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "2E3192"))
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .padding(.vertical, 30)
                .padding(.horizontal, 16)
                .glass(cornerRadius: 24)
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            heightText = String(Int(formState.heightCm))
        }
        .onTapGesture {
            focusedField = nil
        }
    }
    
    // MARK: - Weight Step
    
    private var weightStep: some View {
        QuestionnaireStepView(
            title: "What's your weight?",
            subtitle: "This helps us track your health progress",
            icon: "scalemass.fill"
        ) {
            VStack(spacing: 32) {
                // Weight Input (KG only)
                VStack(spacing: 24) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField("70", text: $weightText)
                            .keyboardType(.numberPad)
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "2E3192"))
                            .multilineTextAlignment(.center)
                            .frame(width: 140)
                            .focused($focusedField, equals: .weight)
                            .onChange(of: weightText) { _, newValue in
                                if let value = Double(newValue), value >= 20, value <= 300 {
                                    formState.weightKg = value
                                }
                            }
                        
                        Text("kg")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    
                    // Quick adjust buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            if formState.weightKg > 30 {
                                formState.weightKg -= 1
                                weightText = String(Int(formState.weightKg))
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "2E3192"))
                        }
                        
                        Slider(
                            value: $formState.weightKg,
                            in: 30...200,
                            step: 1
                        )
                        .tint(Color(hex: "2E3192"))
                        .onChange(of: formState.weightKg) { _, newValue in
                            weightText = String(Int(newValue))
                        }
                        
                        Button(action: {
                            if formState.weightKg < 200 {
                                formState.weightKg += 1
                                weightText = String(Int(formState.weightKg))
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "2E3192"))
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .padding(.vertical, 30)
                .padding(.horizontal, 16)
                .glass(cornerRadius: 24)
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            weightText = String(Int(formState.weightKg))
        }
        .onTapGesture {
            focusedField = nil
        }
    }
    
    // MARK: - Exercise Level Step
    
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentStep -= 1
                    }
                }) {
                    Text("Back")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .glass(cornerRadius: 16)
                }
            }
            
            Button(action: {
                if currentStep < totalSteps - 1 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentStep += 1
                    }
                } else {
                    // Last step - proceed to setup
                    showSetup = true
                }
            }) {
                HStack {
                    Text(currentStep < totalSteps - 1 ? "Next" : "Complete")
                        .font(.system(size: 17, weight: .semibold))
                    
                    if currentStep == totalSteps - 1 {
                        Image(systemName: "checkmark")
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color(hex: "2E3192"), Color(hex: "4A90E2")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .disabled(!canProceed)
            .opacity(canProceed ? 1 : 0.5)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0: return !formState.name.isEmpty
        case 1: return formState.gender != nil
        default: return true
        }
    }
}

// MARK: - Questionnaire Step View

private struct QuestionnaireStepView<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundColor(Color(hex: "2E3192"))
                    .padding(.top, 40)
                
                // Title & Subtitle
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(subtitle)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                
                // Content
                content
                    .padding(.top, 20)
            }
        }
    }
}

// MARK: - Glass Text Field

private struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        TextField(placeholder, text: $text)
            .padding()
            .glass(cornerRadius: 16)
    }
}

