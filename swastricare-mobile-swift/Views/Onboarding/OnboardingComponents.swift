//
//  OnboardingComponents.swift
//  swastricare-mobile-swift
//
//  Shared UI components for onboarding screens
//

import SwiftUI

// MARK: - Screen Title

struct ScreenTitleView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)

            Text(subtitle)
                .font(.system(size: 17))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Option Button Style

struct OptionButton<Content: View>: View {
    let isSelected: Bool
    let content: Content
    let action: () -> Void

    init(isSelected: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: {
            action()
        }) {
            HStack {
                content
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "2E3192"))
                        .font(.system(size: 22))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color(hex: "2E3192").opacity(0.1) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color(hex: "2E3192") : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
}

// MARK: - Multi-Select Option

struct MultiSelectOption: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        OptionButton(isSelected: isSelected, action: action) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Single Select Option

struct SingleSelectOption: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        OptionButton(isSelected: isSelected, action: action) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}
