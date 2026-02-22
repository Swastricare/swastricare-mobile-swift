//
//  HealthLiveActivityWidget.swift
//  SwasthiCareWidgetsExtension
//
//  Live Activity + Dynamic Island UI for daily health tracking
//

import ActivityKit
import SwiftUI
import WidgetKit

struct HealthLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HealthActivityAttributes.self) { context in
            // Lock Screen / Notification banner view
            HealthLiveActivityLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded UI

                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.title3)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.18, green: 0.19, blue: 0.57), Color(red: 0.11, green: 1.0, blue: 1.0)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        VStack(alignment: .leading, spacing: 1) {
                            Text("SwasthiCare")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text("Health Tracker")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.heartRate > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                            Text("\(context.state.heartRate)")
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                        .padding(.trailing, 4)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 0) {
                        // Steps
                        VStack(alignment: .leading, spacing: 4) {
                            Text("STEPS")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(context.state.formattedSteps)
                                    .font(.system(.title3, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                Text("/\(context.state.stepGoal)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Calories
                        VStack(alignment: .center, spacing: 4) {
                            Text("KCAL")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text("\(context.state.calories)")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                        }
                        .frame(maxWidth: .infinity)

                        // Hydration
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("WATER")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(context.state.formattedHydration)
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.cyan)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                }
            } compactLeading: {
                // Compact leading: steps icon + count
                HStack(spacing: 3) {
                    Image(systemName: "figure.walk")
                        .foregroundStyle(.green)
                        .font(.caption2)
                    Text(context.state.formattedSteps)
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            } compactTrailing: {
                // Compact trailing: heart rate
                if context.state.heartRate > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 8))
                        Text("\(context.state.heartRate)")
                            .font(.system(.caption2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                } else {
                    HStack(spacing: 2) {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(.cyan)
                            .font(.system(size: 8))
                        Text(context.state.formattedHydration)
                            .font(.system(.caption2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
            } minimal: {
                // Minimal: just steps icon
                Image(systemName: "figure.walk")
                    .foregroundStyle(.green)
            }
            .widgetURL(URL(string: "swastricareapp://health/live"))
            .keylineTint(.cyan)
        }
    }
}

// MARK: - Lock Screen View

private struct HealthLiveActivityLockScreenView: View {
    let context: ActivityViewContext<HealthActivityAttributes>

    private let primaryText = Color(uiColor: .label)
    private let secondaryText = Color(uiColor: .secondaryLabel)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.18, green: 0.19, blue: 0.57), Color(red: 0.29, green: 0.56, blue: 0.89)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Today's Health")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(primaryText)
                        Text("Live Tracking")
                            .font(.caption2)
                            .foregroundColor(secondaryText)
                    }
                }
                Spacer()
                if context.state.heartRate > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                        Text("\(context.state.heartRate) bpm")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(primaryText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()

            // Metrics row
            HStack(spacing: 0) {
                // Steps (featured)
                VStack(alignment: .leading, spacing: 4) {
                    Text("STEPS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(secondaryText)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(context.state.formattedSteps)
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundColor(primaryText)
                        Text("/ \(context.state.stepGoal)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)

                HStack(spacing: 20) {
                    // Calories
                    VStack(alignment: .leading, spacing: 4) {
                        Text("KCAL")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(secondaryText)
                        Text("\(context.state.calories)")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }

                    // Hydration
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WATER")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(secondaryText)
                        Text(context.state.formattedHydration)
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.cyan)
                    }
                }
                .padding(.trailing, 20)
            }
            .padding(.bottom, 20)
        }
        .background {
            Color(uiColor: .systemBackground)
        }
        .applyHealthContainerBackground()
        .widgetURL(URL(string: "swastricareapp://health/live"))
    }
}

private extension View {
    @ViewBuilder
    func applyHealthContainerBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                Color(uiColor: .systemBackground)
            }
        } else {
            self.background(Color(uiColor: .systemBackground))
        }
    }
}
