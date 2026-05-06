//
//  UrineColorGuideView.swift
//  swastricare-mobile-swift
//
//  Visual hydration assessment tool — Android-matched card layout
//

import SwiftUI

struct UrineColorGuideView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var viewModel: HydrationViewModel

    @State private var expandedLevel: Int?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    headerSection

                    // Level cards
                    ForEach(UrineColor.allCases) { color in
                        urineColorCard(color)
                    }

                    // Tips section
                    tipsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F8F9FA"))
            .navigationTitle("Hydration Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.cyan)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.cyan.opacity(0.3), .blue.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 72, height: 72)

                Image(systemName: "drop.fill")
                    .font(.poppins(.regular, size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            Text("Check Your Hydration")
                .font(.poppins(.bold, size: 22))

            Text("Tap a level to see details and recommendations")
                .font(.poppins(.regular, size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Urine Color Card

    private func urineColorCard(_ color: UrineColor) -> some View {
        let status = color.status
        let isExpanded = expandedLevel == color.rawValue
        let isDehydrated = status == .mildlyDehydrated || status == .dehydrated || status == .severelyDehydrated

        return VStack(spacing: 0) {
            // Main row
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    expandedLevel = isExpanded ? nil : color.rawValue
                }
                Haptics.select()
            }) {
                HStack(spacing: 14) {
                    // Color swatch
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(color.color)
                            .frame(width: 52, height: 52)
                            .shadow(color: color.color.opacity(0.4), radius: isExpanded ? 6 : 0)

                        Text("\(color.rawValue + 1)")
                            .font(.poppins(.bold, size: 16))
                            .foregroundColor(color.rawValue < 4 ? .black.opacity(0.6) : .white)
                    }

                    // Name + status
                    VStack(alignment: .leading, spacing: 4) {
                        Text(color.displayName)
                            .font(.poppins(.semiBold, size: 16))
                            .foregroundColor(.primary)

                        // Status chip
                        Text(status.displayName)
                            .font(.poppins(.semiBold, size: 11))
                            .foregroundColor(status.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(status.color.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.poppins(.medium, size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()

                    // Status icon + recommendation
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: status.icon)
                            .font(.poppins(.regular, size: 18))
                            .foregroundColor(status.color)
                            .frame(width: 24)

                        Text(status.recommendation)
                            .font(.poppins(.regular, size: 14))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 14)

                    // Log water button for dehydrated levels
                    if isDehydrated {
                        Button(action: {
                            Haptics.medium()
                            dismiss()
                            Task {
                                await viewModel.addWaterIntake(amount: 250, drinkType: .water)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "drop.fill")
                                    .font(.poppins(.regular, size: 14))
                                Text("Log 250ml Water")
                                    .font(.poppins(.semiBold, size: 14))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.cyan)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isExpanded ? status.color.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Hydration Tips")
                .font(.poppins(.semiBold, size: 16))

            tipRow(icon: "clock.fill", color: .blue, text: "Check in the morning for the most accurate reading")
            tipRow(icon: "pills.fill", color: .orange, text: "Vitamins and medications can affect color")
            tipRow(icon: "carrot.fill", color: .red, text: "Certain foods (beets, berries) may change color")
            tipRow(icon: "exclamationmark.triangle.fill", color: .yellow, text: "Consistently dark urine may indicate a health issue — consult a doctor")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white)
        )
    }

    private func tipRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(text)
                .font(.poppins(.regular, size: 14))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    UrineColorGuideView(viewModel: HydrationViewModel())
}
