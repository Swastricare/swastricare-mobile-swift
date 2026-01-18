//
//  CreativeGenderPicker.swift
//  swastricare-mobile-swift
//
//  Created by Assistant on 17/01/26.
//

import SwiftUI

struct CreativeGenderPicker: View {
    @Binding var selectedGender: Gender?
    
    @State private var hoveredGender: Gender?
    @Namespace private var animation
    
    var body: some View {
        VStack(spacing: 24) {
            // Gender Cards
            HStack(spacing: 16) {
                OnboardingGenderCard(
                    gender: .male,
                    isSelected: selectedGender == .male,
                    namespace: animation,
                    onTap: { selectGender(.male) }
                )
                
                OnboardingGenderCard(
                    gender: .female,
                    isSelected: selectedGender == .female,
                    namespace: animation,
                    onTap: { selectGender(.female) }
                )
            }
            
            // Other options
            HStack(spacing: 12) {
                SmallGenderOption(
                    title: "Other",
                    isSelected: selectedGender == .other,
                    onTap: { selectGender(.other) }
                )
                
                SmallGenderOption(
                    title: "Prefer not to say",
                    isSelected: selectedGender == .preferNotToSay,
                    onTap: { selectGender(.preferNotToSay) }
                )
            }
        }
        .padding(.horizontal, 24)
    }
    
    private func selectGender(_ gender: Gender) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            selectedGender = gender
        }
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
}

// MARK: - Gender Card

struct OnboardingGenderCard: View {
    let gender: Gender
    let isSelected: Bool
    let namespace: Namespace.ID
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    private var icon: String {
        switch gender {
        case .male: return "figure.stand"
        case .female: return "figure.stand.dress"
        default: return "person.fill"
        }
    }
    
    private var gradientColors: [Color] {
        switch gender {
        case .male:
            return [Color(hex: "4A90D9"), Color(hex: "2E3192")]
        case .female:
            return [Color(hex: "FF6B9D"), Color(hex: "C44569")]
        default:
            return [Color(hex: "8E8E93"), Color(hex: "636366")]
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Icon with animated background
                ZStack {
                    // Glow effect when selected
                    if isSelected {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [gradientColors[0].opacity(0.4), .clear],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 120, height: 120)
                            .blur(radius: 10)
                    }
                    
                    // Icon circle
                    Circle()
                        .fill(
                            isSelected
                                ? LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.primary.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(
                                    isSelected
                                        ? LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        : LinearGradient(colors: [Color.primary.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: isSelected ? gradientColors[0].opacity(0.4) : .clear, radius: 12, x: 0, y: 6)
                    
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(isSelected ? .white : .primary.opacity(0.5))
                }
                
                // Label
                Text(gender.displayName)
                    .font(.system(size: 18, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                // Selection indicator
                if isSelected {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                        Text("Selected")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(gradientColors[0])
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.primary.opacity(isSelected ? 0.05 : 0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                isSelected
                                    ? LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Color.primary.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Small Gender Option

struct SmallGenderOption: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(PremiumColor.royalBlue)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(isSelected ? 0.08 : 0.03))
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected ? Color(hex: "2E3192").opacity(0.5) : Color.primary.opacity(0.1),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    CreativeGenderPicker(selectedGender: .constant(.male))
}
