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
    
    private var progress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1.0, Double(currentCalories) / Double(dailyGoal))
    }
    
    private let accent: Color = AppColors.accentOrange
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Solid premium background + subtle highlight
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: AppDimensions.quickActionRadius)
                            .fill(accent)
                            .overlay(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.22), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .clipShape(RoundedRectangle(cornerRadius: AppDimensions.quickActionRadius))
                            )
                        
                        if progress > 0.01 {
                            RoundedRectangle(cornerRadius: AppDimensions.quickActionRadius)
                                .fill(Color.white.opacity(0.14))
                                .frame(height: max(geo.size.height * progress, geo.size.height * 0.05))
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                .clipShape(RoundedRectangle(cornerRadius: AppDimensions.quickActionRadius))
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "fork.knife")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    // Title
                    Text("Diet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    
                    // Progress Info
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(currentCalories)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("/ \(dailyGoal)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("cal")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                        }
                    }
                }
                .padding(AppDimensions.largeCardPadding)
            }
            .frame(height: AppDimensions.quickActionHeight)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.quickActionRadius)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
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
