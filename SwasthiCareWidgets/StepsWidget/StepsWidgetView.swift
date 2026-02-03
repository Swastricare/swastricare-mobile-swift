//
//  StepsWidgetView.swift
//  SwasthiCareWidgets
//
//  Widget views for steps tracking (Small & Medium)
//

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Small Widget View

struct StepsWidgetSmallView: View {
    let entry: StepsWidgetEntry
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: entry.percentage)
                    .stroke(
                        progressGradient,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: entry.percentage)
                
                VStack(spacing: 2) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(progressColor)
                    
                    Text("\(Int(entry.percentage * 100))%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
            .frame(width: 70, height: 70)
            
            // Steps count
            VStack(spacing: 2) {
                Text(entry.formattedSteps)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("of \(entry.formattedGoal)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
    
    private var progressColor: Color {
        switch entry.statusLevel {
        case .low:
            return .red
        case .moderate:
            return .orange
        case .good:
            return .yellow
        case .great:
            return .green
        case .excellent:
            return .cyan
        }
    }
    
    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [progressColor, progressColor.opacity(0.7)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Medium Widget View

struct StepsWidgetMediumView: View {
    let entry: StepsWidgetEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Left side - Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                
                Circle()
                    .trim(from: 0, to: entry.percentage)
                    .stroke(
                        progressGradient,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: entry.percentage)
                
                VStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(progressColor)
                    
                    Text("\(Int(entry.percentage * 100))%")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
            .frame(width: 80, height: 80)
            
            // Right side - Stats and button
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text("Steps")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                // Stats
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.walk.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 10))
                            Text(entry.formattedSteps)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill")
                                .foregroundStyle(.blue)
                                .font(.system(size: 10))
                            Text("Goal: \(entry.formattedGoal)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "map.fill")
                                .foregroundStyle(.purple)
                                .font(.system(size: 10))
                            Text(entry.formattedDistance)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                                .font(.system(size: 10))
                            Text(entry.formattedCalories)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Start activity button
                if #available(iOS 17.0, *) {
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
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
    
    private var progressColor: Color {
        switch entry.statusLevel {
        case .low:
            return .red
        case .moderate:
            return .orange
        case .good:
            return .yellow
        case .great:
            return .green
        case .excellent:
            return .cyan
        }
    }
    
    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [progressColor, progressColor.opacity(0.7)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Main Widget View

struct StepsWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: StepsWidgetEntry
    
    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                StepsWidgetSmallView(entry: entry)
            case .systemMedium:
                StepsWidgetMediumView(entry: entry)
            default:
                StepsWidgetSmallView(entry: entry)
            }
        }
        // Important: use the same scheme the main app supports.
        .widgetURL(URL(string: "swastricareapp://steps"))
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    StepsWidget()
} timeline: {
    StepsWidgetEntry.placeholder
    StepsWidgetEntry(date: Date(), stepsData: WidgetStepsData(
        currentSteps: 7500,
        dailyGoal: 10000,
        distance: 5.2,
        calories: 320,
        lastUpdated: Date()
    ))
}

#Preview("Medium", as: .systemMedium) {
    StepsWidget()
} timeline: {
    StepsWidgetEntry.placeholder
}
