//
//  RemindersView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//  Display pending reminders (hydration and medication)
//

import SwiftUI

struct RemindersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var reminders: [PendingReminder] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if reminders.isEmpty {
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
            
            Text("No Pending Reminders")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("You're all caught up! No reminders scheduled at this time.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var remindersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(groupedReminders.keys.sorted(), id: \.self) { date in
                    if let remindersForDate = groupedReminders[date] {
                        reminderSection(for: date, reminders: remindersForDate)
                    }
                }
            }
            .padding()
        }
    }
    
    private func reminderSection(for date: Date, reminders: [PendingReminder]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text(sectionTitle(for: date))
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // Reminder cards
            ForEach(reminders) { reminder in
                ReminderCard(reminder: reminder)
            }
        }
    }
    
    private var groupedReminders: [Date: [PendingReminder]] {
        let calendar = Calendar.current
        return Dictionary(grouping: reminders) { reminder in
            calendar.startOfDay(for: reminder.scheduledTime)
        }
    }
    
    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }
    
    private func loadReminders() async {
        isLoading = true
        reminders = await NotificationService.shared.getAllPendingReminders()
        isLoading = false
    }
}

// MARK: - Reminder Card

private struct ReminderCard: View {
    let reminder: PendingReminder
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(reminder.type.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: reminder.type.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(reminder.type.color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(reminder.body)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(reminder.formattedTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(reminder.relativeTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
