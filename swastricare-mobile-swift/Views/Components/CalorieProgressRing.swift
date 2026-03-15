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

    /// Dynamic gradient based on progress level
    private var progressGradient: LinearGradient {
        if progress >= 1.0 {
            // Over goal: amber/red
            return LinearGradient(
                colors: [Color.orange, Color.red.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if progress >= 0.75 {
            // Almost there: green
            return LinearGradient(
                colors: [AppColors.accentGreen, AppColors.accentGreen.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if progress >= 0.5 {
            // Halfway: green-blue
            return LinearGradient(
                colors: [AppColors.accentGreen, AppColors.accentBlue.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Early: blue-green
            return LinearGradient(
                colors: [AppColors.accentBlue, AppColors.accentGreen.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var statusMessage: String {
        if progress >= 1.0 {
            return "Goal reached!"
        } else if progress >= 0.75 {
            return "Almost there"
        } else if progress >= 0.5 {
            return "Halfway"
        } else if progress > 0 {
            return "Keep going"
        } else {
            return "Let's start"
        }
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 16)
                .frame(width: 150, height: 150)

            // Progress circle
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    progressGradient,
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .frame(width: 150, height: 150)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.75), value: progress)

            // Glow effect when close to or exceeding goal
            if progress >= 0.75 {
                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(
                        progressGradient,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 8)
                    .opacity(0.4)
                    .animation(.spring(response: 0.6, dampingFraction: 0.75), value: progress)
            }

            // Center content
            VStack(spacing: 2) {
                Text("\(current)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.3), value: current)

                Rectangle()
                    .fill(Color.primary.opacity(0.2))
                    .frame(width: 36, height: 1)

                Text("\(goal)")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                Text(statusMessage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(progress >= 1.0 ? .orange : AppColors.accentGreen)
                    .padding(.top, 2)
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
