//
//  WorkoutLiveActivityWidget.swift
//  SwasthiCareWidgetsExtension
//
//  Live Activity + Dynamic Island UI for workout tracking
//

import ActivityKit
import SwiftUI
import WidgetKit

struct WorkoutLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutLiveActivityLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: context.attributes.activityIcon)
                            .font(.title3)
                            .foregroundStyle(context.state.isPaused ? .orange : .green)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.activityType.capitalized)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text(context.state.isPaused ? "Paused" : "Active")
                                .font(.caption2)
                                .foregroundStyle(context.state.isPaused ? .orange : .green)
                        }
                    }
                    .padding(.leading, 8)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.formattedElapsedTime)
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .numericTextTransitionIfAvailable()
                        .padding(.trailing, 8)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .firstTextBaseline) {
                        // Distance
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Distance")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(context.state.formattedDistance)
                                    .font(.system(.title2, design: .rounded))
                                    .fontWeight(.bold)
                                    .numericTextTransitionIfAvailable()
                                Text(context.state.distanceUnit)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Pace
                        VStack(alignment: .center, spacing: 4) {
                            Text("Pace")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(context.state.formattedAveragePace)
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.bold)
                                .numericTextTransitionIfAvailable()
                        }
                        
                        Spacer()
                        
                        // Calories
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Energy")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(context.state.caloriesBurned)")
                                    .font(.system(.title2, design: .rounded))
                                    .fontWeight(.bold)
                                    .numericTextTransitionIfAvailable()
                                Text("kcal")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: context.attributes.activityIcon)
                        .foregroundStyle(context.state.isPaused ? .orange : .green)
                    if context.state.isPaused {
                        Image(systemName: "pause.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            } compactTrailing: {
                Text(context.state.formattedElapsedTime)
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(context.state.isPaused ? Color.secondary : Color.white)
                    .numericTextTransitionIfAvailable()
            } minimal: {
                Image(systemName: context.attributes.activityIcon)
                    .foregroundStyle(context.state.isPaused ? .orange : .green)
            }
            .widgetURL(URL(string: "swastricareapp://workout/live"))
            .keylineTint(context.state.isPaused ? .orange : .green)
        }
    }
}

private struct WorkoutLiveActivityLockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>
    
    var body: some View {
        WorkoutLiveActivityLockScreenContent(context: context)
            .background {
                // Direct background on content - system adaptive color
                Color(uiColor: .systemBackground)
            }
            .applyContainerBackground()
            .widgetURL(URL(string: "swastricareapp://workout/live"))
    }
}

private struct WorkoutLiveActivityLockScreenContent: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    // Use system colors that automatically adapt to light/dark mode
    private let primaryText = Color(uiColor: .label)
    private let secondaryText = Color(uiColor: .secondaryLabel)
    private let badgeBackground = Color(uiColor: .secondarySystemBackground)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(context.state.isPaused ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                            .frame(width: 32, height: 32)

                        Image(systemName: context.attributes.activityIcon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(context.state.isPaused ? .orange : .green)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.activityType.capitalized)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(primaryText)

                        HStack(spacing: 4) {
                            if !context.state.isPaused {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                            }
                            Text(context.state.isPaused ? "Paused" : "Live Tracking")
                                .font(.caption2)
                                .foregroundColor(secondaryText)
                        }
                    }
                }

                Spacer()

                // Timer Badge
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption2)
                        .foregroundColor(secondaryText)
                    Text(context.state.formattedElapsedTime)
                        .font(.system(.callout, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(primaryText)
                        .numericTextTransitionIfAvailable()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(badgeBackground)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            // Main Metrics Grid
            HStack(spacing: 0) {
                // Distance (Featured)
                VStack(alignment: .leading, spacing: 0) {
                    Text("DISTANCE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(secondaryText)
                        .padding(.bottom, 4)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(context.state.formattedDistance)
                            .font(.system(size: 42, weight: .heavy, design: .rounded))
                            .foregroundColor(primaryText)
                            .numericTextTransitionIfAvailable()

                        Text(context.state.distanceUnit)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)

                // Secondary Stats Column
                HStack(spacing: 24) {
                    // Pace
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AVG PACE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(secondaryText)

                        Text(context.state.formattedAveragePace)
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(primaryText)
                            .numericTextTransitionIfAvailable()
                    }

                    // Calories
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CALORIES")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(secondaryText)

                        Text("\(context.state.caloriesBurned)")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(primaryText)
                            .numericTextTransitionIfAvailable()
                    }
                }
                .padding(.trailing, 20)
            }
            .padding(.bottom, 24)
        }
    }
}

private extension View {
    /// Uses the iOS 17 numeric transition when available; no-op otherwise (keeps iOS 16 builds working).
    @ViewBuilder
    func numericTextTransitionIfAvailable() -> some View {
        if #available(iOS 17.0, *) {
            self.contentTransition(.numericText())
        } else {
            self
        }
    }

    /// Applies container background with system adaptive color for iOS 17+
    @ViewBuilder
    func applyContainerBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                Color(uiColor: .systemBackground)
            }
        } else {
            self.background(Color(uiColor: .systemBackground))
        }
    }
}
