//
//  MacroBreakdownBar.swift
//  swastricare-mobile-swift
//
//  Reusable Component - Horizontal bar showing macro breakdown
//

import SwiftUI

struct MacroBreakdownBar: View {
    let label: String
    let current: Int
    let goal: Int
    let progress: Double
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(current)g / \(goal)g")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 8)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: geometry.size.width * min(progress, 1.0), height: 8)
                        .animation(.spring(response: 0.5), value: progress)
                }
            }
            .frame(height: 8)
        }
    }
}

struct MacroBreakdownCard: View {
    let proteinCurrent: Int
    let proteinGoal: Int
    let proteinProgress: Double
    
    let carbsCurrent: Int
    let carbsGoal: Int
    let carbsProgress: Double
    
    let fatCurrent: Int
    let fatGoal: Int
    let fatProgress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.green)
                Text("Macros")
                    .font(.system(size: 18, weight: .semibold))
            }
            
            VStack(spacing: 16) {
                MacroBreakdownBar(
                    label: "Protein",
                    current: proteinCurrent,
                    goal: proteinGoal,
                    progress: proteinProgress,
                    color: .orange,
                    icon: "flame.fill"
                )
                
                MacroBreakdownBar(
                    label: "Carbs",
                    current: carbsCurrent,
                    goal: carbsGoal,
                    progress: carbsProgress,
                    color: .blue,
                    icon: "bolt.fill"
                )
                
                MacroBreakdownBar(
                    label: "Fat",
                    current: fatCurrent,
                    goal: fatGoal,
                    progress: fatProgress,
                    color: .purple,
                    icon: "drop.fill"
                )
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}

#Preview {
    VStack(spacing: 20) {
        MacroBreakdownCard(
            proteinCurrent: 80,
            proteinGoal: 125,
            proteinProgress: 0.64,
            carbsCurrent: 200,
            carbsGoal: 250,
            carbsProgress: 0.80,
            fatCurrent: 45,
            fatGoal: 55,
            fatProgress: 0.82
        )
    }
    .padding()
}
