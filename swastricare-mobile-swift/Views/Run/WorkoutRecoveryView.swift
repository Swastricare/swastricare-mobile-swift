//
//  WorkoutRecoveryView.swift
//  swastricare-mobile-swift
//
//  UI for recovering crashed workouts
//  Updated with Movements+ UI design - lime green accent, dark theme
//

import SwiftUI

struct WorkoutRecoveryView: View {
    @Environment(\.colorScheme) var colorScheme
    
    let state: WorkoutState
    let onRecover: () -> Void
    let onDiscard: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(limeGreen.opacity(0.15))
                    .frame(width: 88, height: 88)
                
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(limeGreen)
            }
            .padding(.top, 44)
            
            Text("Recover Workout?")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(spacing: 14) {
                Text("We found an unfinished workout session:")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 18) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(limeGreen.opacity(0.15))
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: activityIcon)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(limeGreen)
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text(state.activityType.capitalized)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.primary)
                            Text(formattedStartTime)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    HStack(spacing: 24) {
                        WorkoutStatItem(
                            icon: "timer",
                            label: "Duration",
                            value: formattedDuration
                        )
                        
                        WorkoutStatItem(
                            icon: "location.fill",
                            label: "Distance",
                            value: formattedDistance
                        )
                        
                        WorkoutStatItem(
                            icon: "flame.fill",
                            label: "Calories",
                            value: "\(Int(state.lastMetrics.calories))"
                        )
                    }
                }
                .padding(18)
                .background(MovementsColors.card(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)
            }
            .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 14) {
                Button(action: {
                    dismiss()
                    onRecover()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .bold))
                        Text("Recover Workout")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(limeGreen)
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                
                Button(action: {
                    dismiss()
                    onDiscard()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .bold))
                        Text("Discard")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 36)
        }
    }
    
    // MARK: - Computed Properties
    
    private var activityIcon: String {
        switch state.activityType.lowercased() {
        case "walking": return "figure.walk"
        case "running": return "figure.run"
        case "cycling": return "figure.outdoor.cycle"
        case "hiking": return "figure.hiking"
        default: return "figure.walk"
        }
    }
    
    private var formattedStartTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: state.startTime, relativeTo: Date())
    }
    
    private var formattedDuration: String {
        let minutes = Int(state.lastMetrics.elapsedTime / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }
        return "\(minutes)m"
    }
    
    private var formattedDistance: String {
        let km = state.lastMetrics.totalDistance / 1000
        return String(format: "%.2f km", km)
    }
}

// MARK: - Stat Item

private struct WorkoutStatItem: View {
    let icon: String
    let label: String
    let value: String
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(limeGreen)
            
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    WorkoutRecoveryView(
        state: WorkoutState(
            id: UUID(),
            activityType: "Running",
            startTime: Date().addingTimeInterval(-1800),
            isActive: true,
            isPaused: false,
            pausedDuration: 0,
            locationPoints: [],
            heartRateSamples: [],
            lastMetrics: WorkoutMetricsSnapshot(
                elapsedTime: 1800,
                totalDistance: 3250,
                averagePace: 320,
                calories: 245,
                elevationGain: 25
            ),
            liveActivityId: nil,
            savedAt: Date()
        ),
        onRecover: {},
        onDiscard: {}
    )
}
