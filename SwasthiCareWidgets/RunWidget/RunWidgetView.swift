//
//  RunWidgetView.swift
//  SwasthiCareWidgets
//
//  Widget views for run/walk activity tracking (Small & Medium)
//

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Small Widget View

struct RunWidgetSmallView: View {
    let entry: RunWidgetEntry
    
    var body: some View {
        VStack(spacing: 6) {
            if entry.hasActiveWorkout {
                // ACTIVE WORKOUT STATE
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: entry.activeWorkoutIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.green)
                }
                
                // Live indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.green)
                }
                
                // Timer
                Text(entry.activeWorkoutStartTime, style: .timer)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                
                Spacer()
                
                // Stop button
                if #available(iOS 17.0, *) {
                    Button(intent: StopWorkoutIntent()) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 10))
                            Text("Stop")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            } else if entry.hasRecentActivity {
                // Activity icon
                ZStack {
                    Circle()
                        .fill(activityBackgroundColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: entry.activityIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(activityColor)
                }
                
                // Activity details
                VStack(spacing: 2) {
                    Text(entry.formattedDistance)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text(entry.formattedDuration)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    
                    if let timeAgo = entry.formattedLastActivityTime {
                        Text(timeAgo)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Spacer()
                
                // Start button
                if #available(iOS 17.0, *) {
                    Button(intent: StartRunIntent()) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            Text("Start")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // No activity state with start button
                VStack(spacing: 8) {
                    Image(systemName: "figure.walk.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    
                    Text("Start your first activity")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                    
                    // Start buttons
                    if #available(iOS 17.0, *) {
                        HStack(spacing: 6) {
                            Button(intent: StartRunIntent()) {
                                VStack(spacing: 2) {
                                    Image(systemName: "figure.run")
                                        .font(.system(size: 12))
                                    Text("Run")
                                        .font(.system(size: 9))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.green)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            Button(intent: StartWalkIntent()) {
                                VStack(spacing: 2) {
                                    Image(systemName: "figure.walk")
                                        .font(.system(size: 12))
                                    Text("Walk")
                                        .font(.system(size: 9))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
    
    private var activityColor: Color {
        switch entry.activityColor {
        case "green":
            return .green
        case "blue":
            return .blue
        case "cyan":
            return .cyan
        default:
            return .blue
        }
    }
    
    private var activityBackgroundColor: Color {
        activityColor
    }
}

// MARK: - Medium Widget View

struct RunWidgetMediumView: View {
    let entry: RunWidgetEntry
    
    var body: some View {
        if entry.hasActiveWorkout {
            // ACTIVE WORKOUT STATE
            HStack(spacing: 12) {
                // Left side - Activity icon with live indicator
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 70, height: 70)
                    
                    VStack(spacing: 4) {
                        Image(systemName: entry.activeWorkoutIcon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.green)
                        
                        HStack(spacing: 2) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 5, height: 5)
                            Text("LIVE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.green)
                        }
                    }
                }
                
                // Right side - Live stats
                VStack(alignment: .leading, spacing: 6) {
                    // Activity type
                    Text("\(entry.activeWorkoutType.capitalized) in Progress")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    // Live timer (large)
                    Text(entry.activeWorkoutStartTime, style: .timer)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                    
                    // Stats
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "map.fill")
                                .foregroundStyle(.purple)
                                .font(.system(size: 10))
                            Text(String(format: "%.2f km", entry.activeWorkoutDistance))
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    
                    Spacer()
                    
                    // Stop button
                    if #available(iOS 17.0, *) {
                        Button(intent: StopWorkoutIntent()) {
                            HStack(spacing: 4) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 12))
                                Text("Stop Workout")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.red)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(12)
            .containerBackground(for: .widget) {
                Color(.systemBackground)
            }
        } else if entry.hasRecentActivity {
            HStack(spacing: 12) {
                // Left side - Activity icon
                ZStack {
                    Circle()
                        .fill(activityBackgroundColor.opacity(0.2))
                        .frame(width: 70, height: 70)
                    
                    VStack(spacing: 4) {
                        Image(systemName: entry.activityIcon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(activityColor)
                        
                        Text(entry.lastActivityType.capitalized)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Right side - Stats and button
                VStack(alignment: .leading, spacing: 6) {
                    // Activity name
                    Text(entry.lastActivityName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    // Stats grid
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "map.fill")
                                    .foregroundStyle(.purple)
                                    .font(.system(size: 10))
                                Text(entry.formattedDistance)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(.blue)
                                    .font(.system(size: 10))
                                Text(entry.formattedDuration)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(.orange)
                                    .font(.system(size: 10))
                                Text(entry.formattedCalories)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            
                            if let timeAgo = entry.formattedLastActivityTime {
                                Text(timeAgo)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Start new activity button
                    if #available(iOS 17.0, *) {
                        HStack(spacing: 6) {
                            Button(intent: StartRunIntent()) {
                                HStack(spacing: 4) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 10))
                                    Text("Start Run")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(Color.green)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            Button(intent: StartWalkIntent()) {
                                HStack(spacing: 4) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 10))
                                    Text("Start Walk")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(12)
            .containerBackground(for: .widget) {
                Color(.systemBackground)
            }
        } else {
            // No activity state with start buttons
            VStack(spacing: 12) {
                Image(systemName: "figure.walk.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 4) {
                    Text("No recent activity")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Text("Start tracking your activities")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Start buttons
                if #available(iOS 17.0, *) {
                    HStack(spacing: 8) {
                        Button(intent: StartRunIntent()) {
                            VStack(spacing: 4) {
                                Image(systemName: "figure.run")
                                    .font(.system(size: 20))
                                Text("Start Run")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        Button(intent: StartWalkIntent()) {
                            VStack(spacing: 4) {
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 20))
                                Text("Start Walk")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
            .containerBackground(for: .widget) {
                Color(.systemBackground)
            }
        }
    }
    
    private var activityColor: Color {
        switch entry.activityColor {
        case "green":
            return .green
        case "blue":
            return .blue
        case "cyan":
            return .cyan
        default:
            return .blue
        }
    }
    
    private var activityBackgroundColor: Color {
        activityColor
    }
}

// MARK: - Main Widget View

struct RunWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: RunWidgetEntry
    
    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                RunWidgetSmallView(entry: entry)
            case .systemMedium:
                RunWidgetMediumView(entry: entry)
            default:
                RunWidgetSmallView(entry: entry)
            }
        }
        // Widget tap should open the Steps/Run tab.
        .widgetURL(URL(string: "swastricareapp://run"))
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    RunWidget()
} timeline: {
    RunWidgetEntry.placeholder
    RunWidgetEntry.activeRun
    RunWidgetEntry.empty
}

#Preview("Medium", as: .systemMedium) {
    RunWidget()
} timeline: {
    RunWidgetEntry.placeholder
    RunWidgetEntry.activeRun
    RunWidgetEntry.empty
}
