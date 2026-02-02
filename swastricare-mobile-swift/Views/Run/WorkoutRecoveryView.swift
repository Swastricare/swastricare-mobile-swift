//
//  WorkoutRecoveryView.swift
//  swastricare-mobile-swift
//
//  UI for recovering crashed workouts
//

import SwiftUI

struct WorkoutRecoveryView: View {
    let state: WorkoutState
    let onRecover: () -> Void
    let onDiscard: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 36))
                    .foregroundColor(.orange)
            }
            .padding(.top, 40)
            
            // Title
            Text("Recover Workout?")
                .font(.title2)
                .fontWeight(.bold)
            
            // Description
            VStack(spacing: 12) {
                Text("We found an unfinished workout session:")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Workout Details Card
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: activityIcon)
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(state.activityType.capitalized)
                                .font(.headline)
                            Text(formattedStartTime)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Stats Grid
                    HStack(spacing: 20) {
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
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Actions
            VStack(spacing: 12) {
                Button(action: {
                    dismiss()
                    onRecover()
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Recover Workout")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    dismiss()
                    onDiscard()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Discard")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.red)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
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
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption2)
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
