//
//  PremiumGenderSelection.swift
//  swastricare-mobile-swift
//
//  Premium Gender Selection Component
//

import SwiftUI

struct PremiumGenderSelectionView: View {
    @Binding var selectedGender: Gender?
    
    private let genders: [Gender] = [.male, .female, .other, .preferNotToSay]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Gender")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                ForEach(genders, id: \.self) { gender in
                    GenderCard(
                        gender: gender,
                        isSelected: selectedGender == gender
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedGender = gender
                            
                            // Haptic feedback
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Gender Card

private struct GenderCard: View {
    let gender: Gender
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    private var scaleValue: CGFloat {
        if isPressed {
            return 0.95
        } else if isSelected {
            return 1.02
        } else {
            return 1.0
        }
    }
    
    private var shadowColor: Color {
        isSelected ? Color(hex: "2E3192").opacity(0.3) : .clear
    }
    
    private var shadowRadius: CGFloat {
        isSelected ? 12 : 0
    }
    
    private var shadowY: CGFloat {
        isSelected ? 6 : 0
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon with Glass Background
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color(hex: "2E3192").opacity(0.3))
                            .frame(width: 60, height: 60)
                    } else {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 60, height: 60)
                    }
                    
                    Image(systemName: iconForGender)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(
                            isSelected
                                ? AnyShapeStyle(PremiumColor.royalBlue)
                                : AnyShapeStyle(LinearGradient(
                                    colors: [Color.secondary, Color.secondary.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        )
                        .symbolEffect(.bounce, value: isSelected)
                }
                
                Text(gender.displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color(hex: "2E3192").opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected
                            ? LinearGradient(
                                colors: [Color(hex: "2E3192"), Color(hex: "1BFFFF")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [.primary.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .glass(cornerRadius: 16)
            .scaleEffect(scaleValue)
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
    }
    
    private var iconForGender: String {
        switch gender {
        case .male:
            return "figure.stand"
        case .female:
            return "figure.dress.line.vertical.figure"
        case .other:
            return "person.2.fill"
        case .preferNotToSay:
            return "person.fill.questionmark"
        }
    }
}
