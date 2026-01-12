//
//  PremiumComponents.swift
//  swastricare-mobile-swift
//
//  Premium UI Components for Questionnaire
//

import SwiftUI

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    @ViewBuilder let content: Content
    
    init(cornerRadius: CGFloat = 20, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .glass(cornerRadius: cornerRadius)
    }
}

// MARK: - Premium Text Field

struct QuestionnaireTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var onFocusChange: ((Bool) -> Void)? = nil
    
    @FocusState private var isFocused: Bool
    @State private var showClearButton = false
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isFocused ? AnyShapeStyle(PremiumColor.royalBlue) : AnyShapeStyle(Color.secondary))
                    .frame(width: 24)
            }
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .focused($isFocused)
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .textInputAutocapitalization(autocapitalization)
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(.primary)
            
            if showClearButton && !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .glass(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isFocused ? PremiumColor.royalBlue : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing),
                    lineWidth: isFocused ? 2 : 0
                )
        )
        .onChange(of: isFocused) { _, newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                onFocusChange?(newValue)
            }
        }
        .onChange(of: text) { _, newValue in
            withAnimation(.spring(response: 0.2)) {
                showClearButton = !newValue.isEmpty
            }
        }
        .onAppear {
            showClearButton = !text.isEmpty
        }
    }
}

// MARK: - Premium Button

struct PremiumButton: View {
    let title: String
    let icon: String?
    var style: ButtonStyle = .primary
    var isEnabled: Bool = true
    let action: () -> Void
    
    @State private var isPressed = false
    
    enum ButtonStyle {
        case primary
        case secondary
        case ghost
    }
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(style == .primary ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(backgroundGradient)
            .cornerRadius(16)
            .shadow(
                color: style == .primary ? Color(hex: "2E3192").opacity(0.4) : .clear,
                radius: style == .primary ? 12 : 0,
                x: 0,
                y: style == .primary ? 6 : 0
            )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .scaleEffect(isPressed ? 0.96 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if isEnabled {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
    
    @ViewBuilder
    private var backgroundGradient: some View {
        switch style {
        case .primary:
            PremiumColor.royalBlue
        case .secondary:
            LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.primary.opacity(0.2), lineWidth: 1)
                )
        case .ghost:
            Color.clear
        }
    }
}

// MARK: - Step Indicator

struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    
    private var stepText: String {
        "Step \(currentStep + 1) of \(totalSteps)"
    }
    
    private var percentageText: String {
        let percentage = Int((Double(currentStep + 1) / Double(totalSteps)) * 100)
        return "\(percentage)%"
    }
    
    var body: some View {
        VStack(spacing: 12) {
            headerRow
            progressBar
            stepDots
        }
    }
    
    private var headerRow: some View {
        HStack {
            Text(stepText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PremiumColor.deepPurple)
            
            Spacer()
            
            Text(percentageText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            let progressWidth = geometry.size.width * CGFloat(currentStep + 1) / CGFloat(totalSteps)
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 6)
                
                // Progress
                RoundedRectangle(cornerRadius: 4)
                    .fill(PremiumColor.royalBlue)
                    .frame(width: progressWidth, height: 6)
                    .shadow(color: Color(hex: "2E3192").opacity(0.5), radius: 8, x: 0, y: 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
            }
        }
        .frame(height: 6)
        .padding(.horizontal, 20)
    }
    
    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index <= currentStep ? AnyShapeStyle(PremiumColor.royalBlue) : AnyShapeStyle(Color.primary.opacity(0.2)))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentStep ? 1.2 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Hero Title View

struct HeroTitleView: View {
    let title: String
    let subtitle: String
    let icon: String
    
    @State private var appear = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon with Glass Background
            ZStack {
                Circle()
                    .fill(PremiumColor.royalBlue.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                
                Image(systemName: icon)
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(PremiumColor.royalBlue)
                    .symbolEffect(.pulse, options: .repeating.speed(0.5))
            }
            .padding(.top, 20)
            .scaleEffect(appear ? 1 : 0.8)
            .opacity(appear ? 1 : 0)
            
            // Title with Gradient
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(PremiumColor.deepPurple)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 20)
            .offset(y: appear ? 0 : 20)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appear = true
            }
        }
    }
}
