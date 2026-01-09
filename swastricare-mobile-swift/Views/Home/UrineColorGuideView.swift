//
//  UrineColorGuideView.swift
//  swastricare-mobile-swift
//
//  Visual hydration assessment tool
//

import SwiftUI

struct UrineColorGuideView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: HydrationViewModel
    
    @State private var selectedColor: UrineColor?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Color Chart
                    colorChartSection
                    
                    // Selected Color Info
                    if let color = selectedColor {
                        selectedColorInfo(color)
                    }
                    
                    // Tips Section
                    tipsSection
                }
                .padding()
            }
            .background(PremiumBackground())
            .navigationTitle("Hydration Check")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            Text("Check Your Hydration")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Tap the color that best matches your urine to check your hydration level")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Color Chart Section
    
    private var colorChartSection: some View {
        VStack(spacing: 16) {
            Text("Color Chart")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(UrineColor.allCases) { color in
                    colorButton(color)
                }
            }
        }
        .padding()
        .glass(cornerRadius: 16)
    }
    
    private func colorButton(_ color: UrineColor) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                selectedColor = color
            }
        }) {
            VStack(spacing: 8) {
                Circle()
                    .fill(color.color)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                    )
                    .shadow(color: color.color.opacity(0.5), radius: selectedColor == color ? 8 : 0)
                
                Text(color.displayName)
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Selected Color Info
    
    private func selectedColorInfo(_ color: UrineColor) -> some View {
        let status = color.status
        
        return VStack(spacing: 16) {
            HStack {
                Image(systemName: status.icon)
                    .font(.title2)
                    .foregroundColor(status.color)
                
                Text(status.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            
            Text(status.recommendation)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Action suggestion
            if status == .mildlyDehydrated || status == .dehydrated || status == .severelyDehydrated {
                Button(action: {
                    dismiss()
                    // Will trigger add water in parent view
                    Task {
                        await viewModel.addWaterIntake(amount: 250, drinkType: .water)
                    }
                }) {
                    HStack {
                        Image(systemName: "drop.fill")
                        Text("Log 250ml Now")
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "2E3192"))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(status.color.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(status.color.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Tips Section
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hydration Tips")
                .font(.headline)
            
            tipRow(icon: "clock.fill", color: .blue, text: "Check in the morning for the most accurate reading")
            
            tipRow(icon: "pills.fill", color: .orange, text: "Vitamins and medications can affect color")
            
            tipRow(icon: "carrot.fill", color: .red, text: "Certain foods (beets, berries) may change color")
            
            tipRow(icon: "exclamationmark.triangle.fill", color: .yellow, text: "Consistently dark urine may indicate a health issue - consult a doctor")
        }
        .padding()
        .glass(cornerRadius: 16)
    }
    
    private func tipRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    UrineColorGuideView(viewModel: HydrationViewModel())
}
