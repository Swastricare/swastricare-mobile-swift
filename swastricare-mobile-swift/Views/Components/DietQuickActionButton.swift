//
//  DietQuickActionButton.swift
//  swastricare-mobile-swift
//
//  Quick action button for diet tracking on home screen
//

import SwiftUI

struct DietQuickActionButton: View {
    let currentCalories: Int
    let dailyGoal: Int
    let action: () -> Void
    
    @State private var animateGradient = false
    
    private var progress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1.0, Double(currentCalories) / Double(dailyGoal))
    }
    
    private var progressColor: Color {
        if progress >= 1.0 {
            return AppColors.accentGreen
        } else if progress >= 0.7 {
            return AppColors.accentOrange
        } else {
            return AppColors.diet
        }
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background with gradient
                RoundedRectangle(cornerRadius: AppDimensions.quickActionRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.diet.opacity(0.15),
                                AppColors.diet.opacity(0.08)
                            ],
                            startPoint: animateGradient ? .topLeading : .bottomLeading,
                            endPoint: animateGradient ? .bottomTrailing : .topTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.quickActionRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        AppColors.diet.opacity(0.3),
                                        AppColors.diet.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        ZStack {
                            Circle()
                                .fill(AppColors.diet.opacity(0.2))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "fork.knife")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppColors.diet)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.diet.opacity(0.6))
                    }
                    
                    // Title
                    Text("Diet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // Progress Info
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(currentCalories)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(progressColor)
                            
                            Text("/ \(dailyGoal)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text("cal")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        // Progress Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(progressColor)
                                    .frame(width: geometry.size.width * progress, height: 6)
                                    .animation(.spring(response: 0.6), value: progress)
                            }
                        }
                        .frame(height: 6)
                    }
                }
                .padding(AppDimensions.largeCardPadding)
            }
            .frame(height: AppDimensions.quickActionHeight)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        DietQuickActionButton(
            currentCalories: 1450,
            dailyGoal: 2000,
            action: {}
        )
        
        DietQuickActionButton(
            currentCalories: 2100,
            dailyGoal: 2000,
            action: {}
        )
        
        DietQuickActionButton(
            currentCalories: 500,
            dailyGoal: 2000,
            action: {}
        )
    }
    .padding()
}
