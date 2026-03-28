//
//  NotificationSettingsView.swift
//  swastricare-mobile-swift
//
//  Notification preferences and controls
//

import SwiftUI
import Supabase

struct NotificationSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: HydrationViewModel

    @State private var settings: NotificationSettings
    @State private var permissionStatus: NotificationPermissionStatus = .notDetermined
    @State private var showPermissionAlert = false
    @State private var quietHoursStart: Date
    @State private var quietHoursEnd: Date
    @State private var isTestingNotification = false
    @State private var whatsAppNudgesEnabled = false
    @State private var isSavingWhatsApp = false
    @State private var userPhone: String? = nil
    @State private var showPhoneRequiredAlert = false

    private let notificationService = NotificationService.shared
    private let supabase = SupabaseManager.shared
    
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
                
                // WhatsApp Nudges Section
                if settings.enabled && permissionStatus.canSchedule {
                    whatsAppSection
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
                await loadWhatsAppSettings()
            }
            .alert("Notifications Disabled", isPresented: $showPermissionAlert) {
                Button("Open Settings", role: .none) {
                    openAppSettings()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable notifications in Settings to receive hydration reminders.")
            }
            .alert("Phone Number Required", isPresented: $showPhoneRequiredAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("A phone number is required for WhatsApp nudges. Please add your phone number in your profile settings.")
            }
        }
        .trackScreen("NotificationSettings")
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
            
            Toggle(isOn: $settings.useAdaptiveLearning) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.cyan)
                    VStack(alignment: .leading) {
                        Text("Adaptive Learning")
                            .fontWeight(.medium)
                        Text("Learn your drinking patterns over time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.cyan)
            
            if !settings.smartReminders {
                Picker("Reminder Frequency", selection: $settings.reminderFrequencyHours) {
                    Text("Every 2 hours").tag(2)
                    Text("Every 3 hours").tag(3)
                    Text("Every 4 hours").tag(4)
                    Text("Every 5 hours").tag(5)
                }
            }
            
            Picker("Snooze Duration", selection: $settings.snoozeMinutes) {
                ForEach(NotificationSettings.snoozeDurationOptions, id: \.self) { minutes in
                    if minutes >= 60 {
                        Text("\(minutes / 60) hour").tag(minutes)
                    } else {
                        Text("\(minutes) minutes").tag(minutes)
                    }
                }
            }
        } header: {
            Text("Reminder Schedule")
        } footer: {
            if settings.smartReminders {
                Text("Behind schedule: every 2 hours\nOn track: every 3 hours\nAhead: every 4 hours\nGoal met: no reminders")
            }
            if settings.useAdaptiveLearning {
                Text("\nAdaptive learning personalizes reminder timing based on when you typically drink water.")
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
    
    // MARK: - WhatsApp Section

    private var whatsAppSection: some View {
        Section {
            Toggle(isOn: $whatsAppNudgesEnabled) {
                HStack {
                    Image(systemName: "message.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading) {
                        Text("WhatsApp Nudges")
                            .fontWeight(.medium)
                        Text("Receive health nudges via WhatsApp")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.green)
            .disabled(isSavingWhatsApp)
            .onChange(of: whatsAppNudgesEnabled) { newValue in
                Task { await saveWhatsAppSetting(enabled: newValue) }
            }

            if whatsAppNudgesEnabled {
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    if let phone = userPhone, !phone.isEmpty {
                        Text(phone)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No phone number on file")
                            .foregroundColor(.orange)
                    }
                }
                .font(.caption)
            }
        } header: {
            Text("WhatsApp")
        } footer: {
            Text("Health nudges will also be sent to your WhatsApp. Requires a phone number on your account.")
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
                featureRow("🌡️ Weather Aware", "Extra reminders on hot days")
                featureRow("🏃‍♂️ Exercise Aware", "Post-workout hydration reminders")
                featureRow("📊 Pattern Learning", "Learns when you typically drink water")
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
    
    // MARK: - WhatsApp Settings

    private func loadWhatsAppSettings() async {
        guard let userId = try? await supabase.client.auth.session.user.id else { return }

        // Load toggle state from user_settings
        struct WhatsAppRow: Decodable {
            let whatsapp_nudges_enabled: Bool?
        }
        if let row: WhatsAppRow = try? await supabase.client
            .from("user_settings")
            .select("whatsapp_nudges_enabled")
            .eq("user_id", value: userId.uuidString)
            .single()
            .execute()
            .value {
            whatsAppNudgesEnabled = row.whatsapp_nudges_enabled ?? false
        }

        // Load phone number
        struct PhoneRow: Decodable {
            let phone: String?
        }
        if let row: PhoneRow = try? await supabase.client
            .from("users")
            .select("phone")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value {
            userPhone = row.phone
        }
    }

    private func saveWhatsAppSetting(enabled: Bool) async {
        // If enabling, check phone number first
        if enabled {
            let phone = userPhone?.replacingOccurrences(of: "\\D", with: "", options: .regularExpression) ?? ""
            if phone.count < 10 {
                whatsAppNudgesEnabled = false
                showPhoneRequiredAlert = true
                return
            }
        }

        isSavingWhatsApp = true
        defer { isSavingWhatsApp = false }

        guard let userId = try? await supabase.client.auth.session.user.id else { return }

        struct WhatsAppUpdate: Encodable {
            let whatsapp_nudges_enabled: Bool
        }

        do {
            try await supabase.client
                .from("user_settings")
                .update(WhatsAppUpdate(whatsapp_nudges_enabled: enabled))
                .eq("user_id", value: userId.uuidString)
                .execute()
        } catch {
            // Revert on failure
            whatsAppNudgesEnabled = !enabled
            print("Failed to save WhatsApp setting: \(error)")
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
