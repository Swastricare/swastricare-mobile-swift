//
//  NotificationSettingsView.swift
//  swastricare-mobile-swift
//

import SwiftUI
import UserNotifications
import Supabase

struct NotificationSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: HydrationViewModel

    // Permission
    @State private var permissionStatus: NotificationPermissionStatus = .notDetermined
    @State private var showPermissionAlert = false

    // Hydration
    @State private var settings: NotificationSettings
    @State private var quietHoursStart: Date
    @State private var quietHoursEnd: Date

    // Medication
    @AppStorage("notif_medication_enabled") private var medicationEnabled = true
    @AppStorage("notif_medication_remind_before") private var medicationRemindBefore = 15
    @AppStorage("notif_medication_missed_followup") private var medicationMissedFollowUp = true
    @AppStorage("notif_medication_snooze") private var medicationSnooze = 10

    // Diet
    @AppStorage("notif_diet_enabled") private var dietEnabled = false

    // Cycle
    @AppStorage("notif_cycle_enabled") private var cycleEnabled = false
    @AppStorage("notif_cycle_period_prediction") private var cyclePeriodPrediction = true
    @AppStorage("notif_cycle_days_before") private var cycleDaysBefore = 2
    @AppStorage("notif_cycle_symptom_checkin") private var cycleSymptomCheckin = false
    @AppStorage("notif_cycle_ovulation") private var cycleOvulation = false
    @AppStorage("notif_cycle_summary") private var cycleSummary = false

    // Appointments
    @AppStorage("notif_appointment_enabled") private var appointmentEnabled = false

    // Activity
    @AppStorage("notif_activity_enabled") private var activityEnabled = false

    // AI Health Coach
    @AppStorage("notif_ai_coach_enabled") private var aiCoachEnabled = false
    @AppStorage("notif_ai_coach_frequency") private var aiCoachFrequency = 1

    // WhatsApp
    @State private var whatsAppNudgesEnabled = false
    @State private var isSavingWhatsApp = false
    @State private var userPhone: String? = nil
    @State private var showPhoneRequiredAlert = false

    // Meal times (stored as seconds since midnight via AppStorage)
    @AppStorage("notif_diet_breakfast") private var breakfastSecs: Double = 8 * 3600
    @AppStorage("notif_diet_lunch") private var lunchSecs: Double = 13 * 3600
    @AppStorage("notif_diet_dinner") private var dinnerSecs: Double = 19.5 * 3600

    // Test
    @State private var isTestingNotification = false

    private let notificationService = NotificationService.shared
    private let supabase = SupabaseManager.shared
    private let accent = AppColors.accentBlue

    init(viewModel: HydrationViewModel) {
        self.viewModel = viewModel
        let s = NotificationService.shared.getSettings()
        _settings = State(initialValue: s)
        _quietHoursStart = State(initialValue: s.quietHoursStart)
        _quietHoursEnd = State(initialValue: s.quietHoursEnd)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if !permissionStatus.canSchedule {
                            permissionBanner
                        }
                        hydrationCard
                        medicationCard
                        dietCard
                        cycleCard
                        appointmentCard
                        activityCard
                        aiCoachCard
                        whatsAppRow
                        testRow
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .task {
            await checkPermissionStatus()
            await loadWhatsAppSettings()
        }
        .alert("Notifications Disabled", isPresented: $showPermissionAlert) {
            Button("Open Settings") { openAppSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable notifications in Settings to receive health reminders.")
        }
        .alert("Phone Number Required", isPresented: $showPhoneRequiredAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A phone number is required for WhatsApp nudges. Please add one in your profile.")
        }
        .trackScreen("NotificationSettings")
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1A2E"))
                    .frame(width: 40, height: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications & Reminders")
                    .font(.poppins(.bold, size: 20))
                    .foregroundColor(Color(hex: "1A1A2E"))
                Text("Manage your health alerts")
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(Color(hex: "888888"))
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
    }

    // MARK: - Permission Banner

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: "FFF3CD")).frame(width: 40, height: 40)
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "FF9500"))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications Disabled")
                    .font(.poppins(.semiBold, size: 14))
                    .foregroundColor(Color(hex: "1A1A2E"))
                Text(permissionStatus == .notDetermined
                     ? "Tap Enable to allow notifications"
                     : "Open Settings to re-enable")
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(Color(hex: "888888"))
            }
            Spacer()
            Button {
                if permissionStatus == .notDetermined {
                    Task { await requestPermission() }
                } else {
                    openAppSettings()
                }
            } label: {
                Text(permissionStatus == .notDetermined ? "Enable" : "Settings")
                    .font(.poppins(.semiBold, size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color(hex: "FF9500"))
                    .cornerRadius(20)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color(hex: "FFF8EC"))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "FFE5B0"), lineWidth: 1))
        .cornerRadius(16)
    }

    // MARK: - Hydration Card

    private var hydrationCard: some View {
        NotifSectionCard(
            icon: "drop.fill", iconColor: accent,
            title: "Hydration Reminders",
            isEnabled: $settings.enabled
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Reminder Frequency")
                    .font(.poppins(.medium, size: 13))
                    .foregroundColor(Color(hex: "666666"))
                    .padding(.horizontal, 16)
                NotifChipSelector(
                    options: ["30 min", "1 hour", "2 hours", "3 hours"],
                    selected: Binding(
                        get: {
                            let hrs = settings.reminderFrequencyHours
                            if hrs <= 0 { return 0 }
                            if hrs == 1 { return 1 }
                            if hrs == 2 { return 2 }
                            return 3
                        },
                        set: { settings.reminderFrequencyHours = [0, 1, 2, 3][$0] }
                    ),
                    accent: accent
                )
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 4)

            Divider().padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 10) {
                Text("Quiet Hours")
                    .font(.poppins(.medium, size: 13))
                    .foregroundColor(Color(hex: "666666"))
                    .padding(.horizontal, 16)
                HStack {
                    Label("Start", systemImage: "moon.fill")
                        .font(.poppins(.regular, size: 14))
                        .foregroundColor(Color(hex: "1A1A2E"))
                    Spacer()
                    DatePicker("", selection: $quietHoursStart, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
                HStack {
                    Label("End", systemImage: "sun.max.fill")
                        .font(.poppins(.regular, size: 14))
                        .foregroundColor(Color(hex: "1A1A2E"))
                    Spacer()
                    DatePicker("", selection: $quietHoursEnd, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 12)
        }
        .onChange(of: settings.enabled) { _, _ in saveHydration() }
        .onChange(of: settings.reminderFrequencyHours) { _, _ in saveHydration() }
        .onChange(of: quietHoursStart) { _, v in settings.quietHoursStart = v; saveHydration() }
        .onChange(of: quietHoursEnd) { _, v in settings.quietHoursEnd = v; saveHydration() }
    }

    // MARK: - Medication Card

    private var medicationCard: some View {
        NotifSectionCard(
            icon: "pills.fill", iconColor: Color(hex: "5856D6"),
            title: "Medication Reminders",
            isEnabled: $medicationEnabled
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Remind Before Dose")
                    .font(.poppins(.medium, size: 13))
                    .foregroundColor(Color(hex: "666666"))
                    .padding(.horizontal, 16)
                NotifChipSelector(
                    options: ["15 min", "30 min", "1 hour"],
                    selected: Binding(
                        get: { medicationRemindBefore == 15 ? 0 : (medicationRemindBefore == 30 ? 1 : 2) },
                        set: { medicationRemindBefore = [15, 30, 60][$0] }
                    ),
                    accent: Color(hex: "5856D6")
                )
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 4)

            Divider().padding(.horizontal, 16)

            notifToggleRow(
                label: "Missed Dose Follow-up",
                subtitle: "Alert if a dose is not taken",
                isOn: $medicationMissedFollowUp,
                color: Color(hex: "5856D6")
            )

            Divider().padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 8) {
                Text("Snooze Duration")
                    .font(.poppins(.medium, size: 13))
                    .foregroundColor(Color(hex: "666666"))
                    .padding(.horizontal, 16)
                NotifChipSelector(
                    options: ["5 min", "10 min", "15 min", "30 min"],
                    selected: Binding(
                        get: { [5, 10, 15, 30].firstIndex(of: medicationSnooze) ?? 1 },
                        set: { medicationSnooze = [5, 10, 15, 30][$0] }
                    ),
                    accent: Color(hex: "5856D6")
                )
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: - Diet Card

    private var dietCard: some View {
        NotifSectionCard(
            icon: "fork.knife", iconColor: Color(hex: "FF9500"),
            title: "Diet Reminders",
            isEnabled: $dietEnabled
        ) {
            VStack(spacing: 0) {
                mealTimeRow(label: "Breakfast", icon: "sunrise.fill", secs: $breakfastSecs)
                Divider().padding(.horizontal, 16)
                mealTimeRow(label: "Lunch", icon: "sun.max.fill", secs: $lunchSecs)
                Divider().padding(.horizontal, 16)
                mealTimeRow(label: "Dinner", icon: "moon.stars.fill", secs: $dinnerSecs)
            }
            .padding(.bottom, 4)
        }
    }

    private func mealTimeRow(label: String, icon: String, secs: Binding<Double>) -> some View {
        let binding = Binding<Date>(
            get: {
                let s = Int(secs.wrappedValue)
                return Calendar.current.date(bySettingHour: s / 3600,
                                             minute: (s % 3600) / 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                secs.wrappedValue = Double((comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60)
            }
        )
        return HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "FF9500"))
                .frame(width: 20)
            Text(label)
                .font(.poppins(.regular, size: 14))
                .foregroundColor(Color(hex: "1A1A2E"))
            Spacer()
            DatePicker("", selection: binding, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Cycle Card

    private var cycleCard: some View {
        NotifSectionCard(
            icon: "heart.fill", iconColor: Color(hex: "FF2D55"),
            title: "Cycle Reminders",
            isEnabled: $cycleEnabled
        ) {
            VStack(spacing: 0) {
                notifToggleRow(label: "Period Prediction",
                               subtitle: "Get notified before your period",
                               isOn: $cyclePeriodPrediction, color: Color(hex: "FF2D55"))

                if cyclePeriodPrediction {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Days Before")
                            .font(.poppins(.medium, size: 13))
                            .foregroundColor(Color(hex: "666666"))
                            .padding(.horizontal, 16)
                        NotifChipSelector(
                            options: ["1 day", "2 days", "3 days", "5 days"],
                            selected: Binding(
                                get: { [1, 2, 3, 5].firstIndex(of: cycleDaysBefore) ?? 1 },
                                set: { cycleDaysBefore = [1, 2, 3, 5][$0] }
                            ),
                            accent: Color(hex: "FF2D55")
                        )
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 4).padding(.bottom, 8)
                    Divider().padding(.horizontal, 16)
                }

                notifToggleRow(label: "Symptom Check-in",
                               subtitle: "Daily check during your period",
                               isOn: $cycleSymptomCheckin, color: Color(hex: "FF2D55"))
                Divider().padding(.horizontal, 16)
                notifToggleRow(label: "Ovulation Reminder",
                               subtitle: "Fertile window notifications",
                               isOn: $cycleOvulation, color: Color(hex: "FF2D55"))
                Divider().padding(.horizontal, 16)
                notifToggleRow(label: "Cycle Summary",
                               subtitle: "Monthly insights report",
                               isOn: $cycleSummary, color: Color(hex: "FF2D55"))
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - Appointment Card

    private var appointmentCard: some View {
        NotifSectionCard(
            icon: "calendar.badge.clock", iconColor: Color(hex: "34C759"),
            title: "Appointment Reminders",
            isEnabled: $appointmentEnabled
        ) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "888888"))
                Text("Get reminders before your upcoming health appointments.")
                    .font(.poppins(.regular, size: 13))
                    .foregroundColor(Color(hex: "888888"))
            }
            .padding(.horizontal, 16).padding(.bottom, 14)
        }
    }

    // MARK: - Activity Card

    private var activityCard: some View {
        NotifSectionCard(
            icon: "figure.run", iconColor: Color(hex: "FF6B35"),
            title: "Activity Reminders",
            isEnabled: $activityEnabled
        ) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "888888"))
                Text("Timely nudges to hit your daily step and exercise goals.")
                    .font(.poppins(.regular, size: 13))
                    .foregroundColor(Color(hex: "888888"))
            }
            .padding(.horizontal, 16).padding(.bottom, 14)
        }
    }

    // MARK: - AI Coach Card

    private var aiCoachCard: some View {
        NotifSectionCard(
            icon: "sparkles", iconColor: Color(hex: "AF52DE"),
            title: "AI Health Coach",
            isEnabled: $aiCoachEnabled
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Daily check-ins, insights, and personalized health tips from your AI coach.")
                    .font(.poppins(.regular, size: 13))
                    .foregroundColor(Color(hex: "888888"))
                    .padding(.horizontal, 16)

                Divider().padding(.horizontal, 16)

                Text("Daily Frequency")
                    .font(.poppins(.medium, size: 13))
                    .foregroundColor(Color(hex: "666666"))
                    .padding(.horizontal, 16)
                NotifChipSelector(
                    options: ["1× per day", "2× per day", "3× per day"],
                    selected: Binding(
                        get: { min(max(aiCoachFrequency - 1, 0), 2) },
                        set: { aiCoachFrequency = $0 + 1 }
                    ),
                    accent: Color(hex: "AF52DE")
                )
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: - WhatsApp Row

    private var whatsAppRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: "E8F5E9")).frame(width: 44, height: 44)
                Image(systemName: "message.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "25D366"))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("WhatsApp Nudges")
                    .font(.poppins(.semiBold, size: 14))
                    .foregroundColor(Color(hex: "1A1A2E"))
                if whatsAppNudgesEnabled, let phone = userPhone, !phone.isEmpty {
                    Text(phone)
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(Color(hex: "888888"))
                } else {
                    Text("Receive health tips on WhatsApp")
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(Color(hex: "888888"))
                }
            }
            Spacer()
            Toggle("", isOn: $whatsAppNudgesEnabled)
                .tint(Color(hex: "25D366"))
                .disabled(isSavingWhatsApp)
                .onChange(of: whatsAppNudgesEnabled) { _, v in
                    Task { await saveWhatsAppSetting(enabled: v) }
                }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "E5E5EA"), lineWidth: 1))
        .cornerRadius(16)
    }

    // MARK: - Test Row

    private var testRow: some View {
        Button(action: sendTestNotification) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(accent.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 18))
                        .foregroundColor(accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Send Test Notification")
                        .font(.poppins(.semiBold, size: 14))
                        .foregroundColor(Color(hex: "1A1A2E"))
                    Text("Appears in 3 seconds — minimize the app")
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(Color(hex: "888888"))
                }
                Spacer()
                if isTestingNotification {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "AAAAAA"))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "E5E5EA"), lineWidth: 1))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .disabled(isTestingNotification || !permissionStatus.canSchedule)
    }

    // MARK: - Reusable Toggle Row

    private func notifToggleRow(label: String, subtitle: String,
                                isOn: Binding<Bool>, color: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.poppins(.medium, size: 14))
                    .foregroundColor(Color(hex: "1A1A2E"))
                Text(subtitle)
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(Color(hex: "888888"))
            }
            Spacer()
            Toggle("", isOn: isOn)
                .tint(color)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    // MARK: - Actions

    private func checkPermissionStatus() async {
        permissionStatus = await notificationService.checkPermissionStatus()
    }

    private func requestPermission() async {
        let granted = await notificationService.requestPermission()
        await checkPermissionStatus()
        if granted { settings.enabled = true }
    }

    private func saveHydration() {
        notificationService.updateSettings(settings)
        if settings.enabled {
            Task { await viewModel.scheduleNextNotification() }
        } else {
            notificationService.cancelAllReminders()
        }
    }

    private func sendTestNotification() {
        isTestingNotification = true
        Task {
            let status = await notificationService.checkPermissionStatus()
            if !status.canSchedule {
                let granted = await notificationService.requestPermission()
                if !granted {
                    await MainActor.run { isTestingNotification = false; showPermissionAlert = true }
                    return
                }
                await checkPermissionStatus()
            }
            let streak = viewModel.insights?.currentStreak ?? 0
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
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
            let req = UNNotificationRequest(
                identifier: "test_\(Date().timeIntervalSince1970)",
                content: content, trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(req)
            await MainActor.run { isTestingNotification = false }
        }
    }

    private func loadWhatsAppSettings() async {
        guard let userId = try? await supabase.client.auth.session.user.id else { return }
        struct WARow: Decodable { let whatsapp_nudges_enabled: Bool? }
        if let row: WARow = try? await supabase.client
            .from("user_settings").select("whatsapp_nudges_enabled")
            .eq("user_id", value: userId.uuidString).single().execute().value {
            whatsAppNudgesEnabled = row.whatsapp_nudges_enabled ?? false
        }
        struct PhoneRow: Decodable { let phone: String? }
        if let row: PhoneRow = try? await supabase.client
            .from("users").select("phone")
            .eq("id", value: userId.uuidString).single().execute().value {
            userPhone = row.phone
        }
    }

    private func saveWhatsAppSetting(enabled: Bool) async {
        if enabled {
            let digits = userPhone?.replacingOccurrences(of: "\\D", with: "", options: .regularExpression) ?? ""
            if digits.count < 10 {
                whatsAppNudgesEnabled = false
                showPhoneRequiredAlert = true
                return
            }
        }
        isSavingWhatsApp = true
        defer { isSavingWhatsApp = false }
        guard let userId = try? await supabase.client.auth.session.user.id else { return }
        struct WAUpdate: Encodable { let whatsapp_nudges_enabled: Bool }
        do {
            try await supabase.client.from("user_settings")
                .update(WAUpdate(whatsapp_nudges_enabled: enabled))
                .eq("user_id", value: userId.uuidString).execute()
        } catch {
            whatsAppNudgesEnabled = !enabled
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Section Card

private struct NotifSectionCard<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @Binding var isEnabled: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(iconColor.opacity(0.12)).frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(.poppins(.semiBold, size: 15))
                    .foregroundColor(Color(hex: "1A1A2E"))
                Spacer()
                Toggle("", isOn: $isEnabled)
                    .tint(iconColor)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)

            if isEnabled {
                Divider().padding(.horizontal, 16)
                content().padding(.top, 12)
            }
        }
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isEnabled ? iconColor.opacity(0.3) : Color(hex: "E5E5EA"), lineWidth: 1)
        )
        .cornerRadius(16)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

// MARK: - Chip Selector

private struct NotifChipSelector: View {
    let options: [String]
    @Binding var selected: Int
    let accent: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { idx, label in
                    Button { selected = idx } label: {
                        Text(label)
                            .font(.poppins(.medium, size: 13))
                            .foregroundColor(selected == idx ? .white : Color(hex: "666666"))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(selected == idx ? accent : Color(hex: "F0F0F0"))
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    NotificationSettingsView(viewModel: HydrationViewModel())
}
