//
//  AITonePicker.swift
//  swastricare-mobile-swift
//
//  Created by Assistant on 17/01/26.
//

import SwiftUI

enum AITone: String, CaseIterable, Identifiable {
    case professional
    case friendly
    case roasting
    case empathetic
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .professional: return "Professional"
        case .friendly: return "Friendly"
        case .roasting: return "Roasting"
        case .empathetic: return "Empathetic"
        }
    }
    
    var description: String {
        switch self {
        case .professional: return "Concise, clinical, and data-driven"
        case .friendly: return "Casual, encouraging, and easy to talk to"
        case .roasting: return "Tough love with a side of sarcasm"
        case .empathetic: return "Gentle, supportive, and understanding"
        }
    }
    
    var icon: String {
        switch self {
        case .professional: return "briefcase.fill"
        case .friendly: return "face.smiling.fill"
        case .roasting: return "flame.fill"
        case .empathetic: return "heart.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .professional: return Color.blue
        case .friendly: return Color.yellow
        case .roasting: return Color.orange
        case .empathetic: return Color.purple
        }
    }
}

struct AITonePicker: View {
    @Binding var selectedTone: AITone?
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(AITone.allCases) { tone in
                ToneCard(
                    tone: tone,
                    isSelected: selectedTone == tone,
                    onTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTone = tone
                        }
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                    }
                )
            }
        }
        .padding(.horizontal, 24)
    }
}

struct ToneCard: View {
    let tone: AITone
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(tone.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: tone.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(tone.color)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(tone.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(tone.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Selection Indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? tone.color : Color.primary.opacity(0.1), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(tone.color)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.primary.opacity(isSelected ? 0.05 : 0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isSelected ? tone.color.opacity(0.5) : Color.primary.opacity(0.05),
                                lineWidth: 1.5
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
