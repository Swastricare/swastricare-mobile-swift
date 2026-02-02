//
//  CalorieProgressRing.swift
//  swastricare-mobile-swift
//
//  Reusable Component - Circular progress ring for calorie tracking
//

import SwiftUI

struct CalorieProgressRing: View {
    let current: Int
    let goal: Int
    let progress: Double
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 16)
                .frame(width: 140, height: 140)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6), value: progress)
            
            // Center content
            VStack(spacing: 4) {
                Text("\(current)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Rectangle()
                    .fill(Color.primary.opacity(0.3))
                    .frame(width: 40, height: 1)
                
                Text("\(goal)")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("kcal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        CalorieProgressRing(current: 1450, goal: 2000, progress: 0.725)
        
        CalorieProgressRing(current: 2100, goal: 2000, progress: 1.0)
        
        CalorieProgressRing(current: 500, goal: 2000, progress: 0.25)
    }
    .padding()
}
