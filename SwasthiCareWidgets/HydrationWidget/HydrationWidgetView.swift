//
//  HydrationWidgetView.swift
//  SwasthiCareWidgets
//
//  Widget views for hydration tracking (Small & Medium)
//

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Small Widget View

struct HydrationWidgetSmallView: View {
    let entry: HydrationWidgetEntry
    
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
                    Image(systemName: "drop.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(progressColor)
                    
                    Text("\(Int(entry.percentage * 100))%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
            .frame(width: 70, height: 70)
            
            // Intake text
            VStack(spacing: 2) {
                Text(entry.formattedIntake)
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
        .widgetURL(URL(string: "swasthicare://hydration"))
    }
    
    private var progressColor: Color {
        switch entry.statusLevel {
        case .critical:
            return .red
        case .warning:
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

struct HydrationWidgetMediumView: View {
    let entry: HydrationWidgetEntry
    
    var body: some View {
        HStack(spacing: 16) {
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
                    Image(systemName: "drop.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(progressColor)
                    
                    Text("\(Int(entry.percentage * 100))%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
            .frame(width: 90, height: 90)
            
            // Right side - Stats & Actions
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text("Hydration")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                // Stats
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 12))
                        Text(entry.formattedIntake)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    
                    HStack {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(.blue)
                            .font(.system(size: 12))
                        Text("Goal: \(entry.formattedGoal)")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    
                    if !entry.isGoalMet {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(.orange)
                                .font(.system(size: 12))
                            Text("\(entry.formattedRemaining) left")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Quick action buttons
                if #available(iOS 17.0, *) {
                    HStack(spacing: 8) {
                        Button(intent: QuickLog250mlIntent()) {
                            Label("+250", systemImage: "plus.circle.fill")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(.cyan)
                        
                        Button(intent: QuickLog500mlIntent()) {
                            Label("+500", systemImage: "plus.circle.fill")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(.cyan)
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(URL(string: "swasthicare://hydration"))
    }
    
    private var progressColor: Color {
        switch entry.statusLevel {
        case .critical:
            return .red
        case .warning:
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

struct HydrationWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: HydrationWidgetEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            HydrationWidgetSmallView(entry: entry)
        case .systemMedium:
            HydrationWidgetMediumView(entry: entry)
        default:
            HydrationWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    HydrationWidget()
} timeline: {
    HydrationWidgetEntry.placeholder
    HydrationWidgetEntry(date: Date(), hydrationData: WidgetHydrationData(
        currentIntake: 500,
        dailyGoal: 2500,
        lastLoggedTime: Date(),
        lastUpdated: Date()
    ))
}

#Preview("Medium", as: .systemMedium) {
    HydrationWidget()
} timeline: {
    HydrationWidgetEntry.placeholder
}
