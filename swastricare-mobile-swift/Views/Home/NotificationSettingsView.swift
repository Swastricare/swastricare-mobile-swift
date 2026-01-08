//
//  NotificationSettingsView.swift
//  swastricare-mobile-swift
//
//  Notification preferences and controls
//

import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: HydrationViewModel
    
    @State private var settings: NotificationSettings
    @State private var permissionStatus: NotificationPermissionStatus = .notDetermined
    @State private var showPermissionAlert = false
    @State private var quietHoursStart: Date
    @State private var quietHoursEnd: Date
    @State private var isTestingNotification = false
    
    private let notificationService = NotificationService.shared
    
    init(viewModel: HydrationViewModel) {
        self.viewModel = viewModel
        let initialSettings = NotificationService.shared.getSettings()
        _settings = State(initialValue: initialSettings)
        _quietHoursStart = State(initialValue: initialSettings.quietHoursStart)
        _quietHoursEnd = State(initialValue: initialSettings.quietHoursEnd)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Permission Status Section
                permissionSection
                
                // Main Toggle Section
                if permissionStatus.canSchedule {
                    mainToggleSection
                }
                
                // Smart Reminders Section
                if settings.enabled && permissionStatus.canSchedule {
                    smartRemindersSection
                }
                
                // Quiet Hours Section
                if settings.enabled && permissionStatus.canSchedule {
                    quietHoursSection
                }
                
                // Notification Content Section
                if settings.enabled && permissionStatus.canSchedule {
                    contentSection
                }
                
                // Test Section
                if settings.enabled && permissionStatus.canSchedule {
                    testSection
                }
                
                // About Section
                aboutSection
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                await checkPermissionStatus()
            }
            .alert("Notifications Disabled", isPresented: $showPermissionAlert) {
                Button("Open Settings", role: .none) {
                    openAppSettings()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable notifications in Settings to receive hydration reminders.")
            }
        }
    }
    
    // MARK: - Permission Section
    
    private var permissionSection: some View {
        Section {
            HStack {
                Image(systemName: permissionStatusIcon)
                    .foregroundColor(permissionStatusColor)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Permission Status")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(permissionStatus.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if permissionStatus == .notDetermined {
                    Button("Enable") {
                        Task {
                            await requestPermission()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                } else if permissionStatus == .denied {
                    Button("Settings") {
                        openAppSettings()
                    }
                    .buttonStyle(.bordered)
                }
            }
        } footer: {
            if permissionStatus == .denied {
                Text("Notifications are disabled. Open Settings to enable them.")
            } else if permissionStatus == .notDetermined {
                Text("Tap 'Enable' to allow Swastricare to send you hydration reminders.")
            }
        }
    }
    
    private var permissionStatusIcon: String {
        switch permissionStatus {
        case .notDetermined: return "bell.slash.fill"
        case .authorized: return "bell.badge.fill"
        case .denied: return "bell.slash.fill"
        case .provisional: return "bell.fill"
        }
    }
    
    private var permissionStatusColor: Color {
        switch permissionStatus {
        case .notDetermined: return .orange
        case .authorized: return .green
        case .denied: return .red
        case .provisional: return .yellow
        }
    }
    
    // MARK: - Main Toggle Section
    
    private var mainToggleSection: some View {
        Section {
            Toggle(isOn: $settings.enabled) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.cyan)
                    VStack(alignment: .leading) {
                        Text("Hydration Reminders")
                            .fontWeight(.medium)
                        Text("Get reminded to drink water throughout the day")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.cyan)
        }
    }
    
    // MARK: - Smart Reminders Section
    
    private var smartRemindersSection: some View {
        Section {
            Toggle(isOn: $settings.smartReminders) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                    VStack(alignment: .leading) {
                        Text("Smart Scheduling")
                            .fontWeight(.medium)
                        Text("Adjust frequency based on your progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.purple)
            
            if !settings.smartReminders {
                Picker("Reminder Frequency", selection: $settings.reminderFrequencyHours) {
                    Text("Every 2 hours").tag(2)
                    Text("Every 3 hours").tag(3)
                    Text("Every 4 hours").tag(4)
                    Text("Every 5 hours").tag(5)
                }
            }
        } header: {
            Text("Reminder Schedule")
        } footer: {
            if settings.smartReminders {
                Text("Behind schedule: every 2 hours\nOn track: every 3 hours\nAhead: every 4 hours\nGoal met: no reminders")
            }
        }
    }
    
    // MARK: - Quiet Hours Section
    
    private var quietHoursSection: some View {
        Section {
            DatePicker(
                "Start Time",
                selection: $quietHoursStart,
                displayedComponents: .hourAndMinute
            )
            
            DatePicker(
                "End Time",
                selection: $quietHoursEnd,
                displayedComponents: .hourAndMinute
            )
            
            HStack {
                Image(systemName: "moon.fill")
                    .foregroundColor(.indigo)
                Text(settings.quietHoursDescription)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Quiet Hours")
        } footer: {
            Text("No notifications will be sent during quiet hours. Perfect for your sleep schedule.")
        }
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        Section {
            Toggle(isOn: $settings.showProgress) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading) {
                        Text("Progress Updates")
                        Text("Show percentage and remaining amount")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.green)
            
            Toggle(isOn: $settings.showMotivational) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)
                    VStack(alignment: .leading) {
                        Text("Motivational Messages")
                        Text("Encouraging messages and streak tracking")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.yellow)
        } header: {
            Text("Notification Content")
        }
    }
    
    // MARK: - Test Section
    
    private var testSection: some View {
        Section {
            Button(action: sendTestNotification) {
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .foregroundColor(.cyan)
                    
                    if isTestingNotification {
                        Text("Sending in 3 seconds...")
                            .foregroundColor(.secondary)
                        Spacer()
                        ProgressView()
                    } else {
                        Text("Send Test Notification")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .disabled(isTestingNotification)
        } header: {
            Text("Test")
        } footer: {
            if permissionStatus.canSchedule {
                Text("Tap to send a test notification. It will appear in 3 seconds. Minimize the app to see the banner.")
            } else {
                Text("Enable notifications first by tapping 'Enable' above.")
                    .foregroundColor(.orange)
            }
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                featureRow("📱 Quick Actions", "Log water directly from notifications")
                featureRow("🧠 Smart Timing", "Notifications adapt to your progress")
                featureRow("🌙 Quiet Hours", "No disturbance during sleep")
                featureRow("⭐ Motivation", "Encouraging messages and streak tracking")
            }
            .padding(.vertical, 8)
        } header: {
            Text("Features")
        }
    }
    
    private func featureRow(_ title: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Actions
    
    private func checkPermissionStatus() async {
        permissionStatus = await notificationService.checkPermissionStatus()
    }
    
    private func requestPermission() async {
        let granted = await notificationService.requestPermission()
        await checkPermissionStatus()
        
        if granted {
            settings.enabled = true
        }
    }
    
    private func saveSettings() {
        // Update quiet hours
        settings.quietHoursStart = quietHoursStart
        settings.quietHoursEnd = quietHoursEnd
        
        // Save to service
        notificationService.updateSettings(settings)
        
        // Schedule notifications if enabled
        if settings.enabled {
            Task {
                await viewModel.scheduleNextNotification()
            }
        } else {
            notificationService.cancelAllReminders()
        }
        
        dismiss()
    }
    
    private func sendTestNotification() {
        isTestingNotification = true
        
        Task {
            // First check/request permission
            let status = await notificationService.checkPermissionStatus()
            
            if !status.canSchedule {
                // Request permission first
                let granted = await notificationService.requestPermission()
                if !granted {
                    print("🔔 Permission denied - cannot send test notification")
                    await MainActor.run {
                        isTestingNotification = false
                        showPermissionAlert = true
                    }
                    return
                }
                await checkPermissionStatus()
            }
            
            let streak = viewModel.insights?.currentStreak ?? 0
            
            // Schedule a test notification for 3 seconds from now
            let content = UNMutableNotificationContent()
            let message = NotificationMessageGenerator.generateMessage(
                progress: viewModel.progress,
                remainingMl: viewModel.remainingMl,
                effectiveIntake: viewModel.effectiveIntake,
                dailyGoal: viewModel.dailyGoal,
                timeOfDay: TimeOfDay.current(),
                streak: streak
            )
            
            content.title = message.title
            content.body = message.body
            content.sound = .default
            content.categoryIdentifier = NotificationCategory.hydrationReminder.identifier
            
            // Use 3 second delay for faster testing
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
            let request = UNNotificationRequest(identifier: "test_notification_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
            
            do {
                try await UNUserNotificationCenter.current().add(request)
                print("🔔 Test notification scheduled - will appear in 3 seconds")
                print("🔔 Title: \(message.title)")
                print("🔔 Body: \(message.body)")
            } catch {
                print("🔔 Failed to schedule test notification: \(error)")
            }
            
            await MainActor.run {
                isTestingNotification = false
            }
        }
    }
    
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NotificationSettingsView(viewModel: HydrationViewModel())
}
