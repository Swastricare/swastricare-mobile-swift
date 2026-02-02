//
//  RemindersView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//  Display past notifications (hydration and medication) - already delivered or time passed
//

import SwiftUI

struct RemindersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var historyEntries: [NotificationHistoryEntry] = []
    @State private var isLoading = true

    private let pastDays = 7

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if historyEntries.isEmpty {
                    emptyStateView
                } else {
                    remindersList
                }
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadReminders()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Past Notifications")
                .font(.title2)
                .fontWeight(.semibold)

            Text("No notifications in the last \(pastDays) days. Past reminders will appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var remindersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(groupedEntries.keys.sorted(by: >), id: \.self) { date in
                    if let entriesForDate = groupedEntries[date] {
                        reminderSection(for: date, entries: entriesForDate)
                    }
                }
            }
            .padding()
        }
    }

    private func reminderSection(for date: Date, entries: [NotificationHistoryEntry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(sectionTitle(for: date))
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)

            ForEach(entries) { entry in
                PastNotificationCard(entry: entry)
            }
        }
    }

    private var groupedEntries: [Date: [NotificationHistoryEntry]] {
        let calendar = Calendar.current
        return Dictionary(grouping: historyEntries) { entry in
            calendar.startOfDay(for: entry.scheduledTime)
        }
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }

    private func loadReminders() async {
        isLoading = true
        historyEntries = NotificationService.shared.getRecentPastNotificationHistory(days: pastDays)
        isLoading = false
    }
}

// MARK: - Past Notification Card

private struct PastNotificationCard: View {
    let entry: NotificationHistoryEntry

    private var displayTitle: String {
        switch entry.notificationType {
        case .hydrationReminder, .hydrationSnooze: return "Hydration Reminder"
        case .hydrationContextual: return "Post-Workout Reminder"
        case .medicationReminder, .medicationSnooze: return "Medication Reminder"
        case .goalAchieved: return "Goal Achieved"
        }
    }

    private var displayBody: String {
        switch entry.notificationType {
        case .hydrationReminder, .hydrationSnooze:
            if let remaining = entry.context.remainingMl, remaining > 0 {
                return "\(remaining) ml left to reach your goal"
            }
            return "Time to drink water"
        case .hydrationContextual: return "Stay hydrated after your workout"
        case .medicationReminder, .medicationSnooze: return "Time to take your medication"
        case .goalAchieved: return "You reached your hydration goal"
        }
    }

    private var icon: String {
        switch entry.notificationType {
        case .hydrationReminder, .hydrationSnooze, .hydrationContextual, .goalAchieved: return "drop.fill"
        case .medicationReminder, .medicationSnooze: return "pills.fill"
        }
    }

    private var color: Color {
        switch entry.notificationType {
        case .hydrationReminder, .hydrationSnooze, .hydrationContextual, .goalAchieved: return .cyan
        case .medicationReminder, .medicationSnooze: return .purple
        }
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: entry.scheduledTime)
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: entry.scheduledTime, relativeTo: Date())
    }

    private var actionLabel: String? {
        guard let action = entry.actionTaken, !action.isEmpty else { return nil }
        switch action {
        case "log_250ml": return "Logged 250 ml"
        case "log_500ml": return "Logged 500 ml"
        case "medication_taken": return "Marked taken"
        case "opened_app": return "Opened app"
        case "dismiss": return "Dismissed"
        default:
            if action.hasPrefix("snooze_") { return "Snoozed" }
            return action
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(displayBody)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(formattedTime)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(relativeTime)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let action = actionLabel {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(action)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding(.top, 2)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

#Preview {
    RemindersView()
}
