//
//  RemindersSettingsView.swift
//  swastricare-mobile-swift
//

import SwiftUI

struct RemindersSettingsView: View {

    @StateObject private var viewModel = DependencyContainer.shared.remindersSettingsViewModel
    @State private var expandedCategory: String? = nil

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    permissionBanner
                    masterToggle

                    if viewModel.settings.globalEnabled {
                        categoryCard(
                            id: "hydration",
                            icon: "drop.fill",
                            color: AppColors.accentBlue,
                            title: "Hydration",
                            subtitle: hydrationSubtitle,
                            enabled: Binding(
                                get: { viewModel.settings.hydration.enabled },
                                set: { viewModel.setHydrationEnabled($0) }
                            )
                        ) { hydrationContent }

                        categoryCard(
                            id: "medication",
                            icon: "pills.fill",
                            color: AppColors.accentBlue,
                            title: "Medication",
                            subtitle: "Before-dose reminders & follow-ups",
                            enabled: Binding(
                                get: { viewModel.settings.medication.enabled },
                                set: { viewModel.setMedicationEnabled($0) }
                            )
                        ) { medicationContent }

                        categoryCard(
                            id: "diet",
                            icon: "fork.knife",
                            color: AppColors.accentBlue,
                            title: "Diet",
                            subtitle: dietSubtitle,
                            enabled: Binding(
                                get: { viewModel.settings.diet.enabled },
                                set: { viewModel.setDietEnabled($0) }
                            )
                        ) { dietContent }

                        categoryCard(
                            id: "menstrual",
                            icon: "heart.fill",
                            color: AppColors.accentBlue,
                            title: "Menstrual Cycle",
                            subtitle: "Period predictions & symptom tracking",
                            enabled: Binding(
                                get: { viewModel.settings.menstrual.enabled },
                                set: { viewModel.setMenstrualEnabled($0) }
                            )
                        ) { menstrualContent }

                        categoryCard(
                            id: "ai",
                            icon: "sparkles",
                            color: AppColors.accentBlue,
                            title: "AI Nudges",
                            subtitle: "\(viewModel.settings.aiNudges.frequencyPerDay)x per day",
                            enabled: Binding(
                                get: { viewModel.settings.aiNudges.enabled },
                                set: { viewModel.setAINudgesEnabled($0) }
                            )
                        ) { aiContent }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.checkPermission()
            await viewModel.loadWhatsAppSettings()
        }
    }

    // MARK: - Permission Banner

    @ViewBuilder
    private var permissionBanner: some View {
        if viewModel.permissionStatus != .authorized && viewModel.permissionStatus != .provisional {
            HStack(spacing: 12) {
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 20))
                    .foregroundColor(viewModel.permissionStatus == .denied ? .red : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.permissionStatus == .denied ? "Notifications Disabled" : "Enable Notifications")
                        .font(.system(size: 14, weight: .semibold))
                    Text(viewModel.permissionStatus == .denied ? "Open Settings to re-enable" : "Allow notifications to receive reminders")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if viewModel.permissionStatus == .notDetermined {
                    Button("Enable") {
                        Task { await viewModel.requestPermission() }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color(hex: "4F46E5"))
                    .clipShape(Capsule())
                } else {
                    Button("Settings") { openAppSettings() }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "4F46E5"))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(viewModel.permissionStatus == .denied ? Color.red.opacity(0.08) : Color.orange.opacity(0.08))
            )
        }
    }

    // MARK: - Master Toggle

    private var masterToggle: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: "4F46E5").opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "4F46E5"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("All Notifications")
                    .font(.system(size: 15, weight: .semibold))
                Text(viewModel.settings.globalEnabled ? "Reminders are active" : "All reminders paused")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { viewModel.settings.globalEnabled },
                set: { viewModel.setGlobalEnabled($0) }
            ))
            .labelsHidden()
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Category Card Builder

    private func categoryCard<Content: View>(
        id: String,
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        enabled: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedCategory = expandedCategory == id ? nil : id
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Toggle("", isOn: enabled)
                        .labelsHidden()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                        .rotationEffect(.degrees(expandedCategory == id ? 90 : 0))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(16)

            // Expanded content
            if expandedCategory == id && enabled.wrappedValue {
                Divider()
                    .padding(.leading, 70)

                content()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .padding(.top, 8)
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Hydration Content

    private var hydrationSubtitle: String {
        viewModel.settings.hydration.smartReminders ? "Smart scheduling active" : "Every \(viewModel.settings.hydration.reminderFrequencyHours)h reminders"
    }

    @ViewBuilder
    private var hydrationContent: some View {
        VStack(spacing: 0) {
            settingToggle("Smart Scheduling", isOn: $viewModel.settings.hydration.smartReminders)
                .onChange(of: viewModel.settings.hydration.smartReminders) { _ in viewModel.updateHydrationSettings() }

            settingDivider

            settingToggle("Adaptive Learning", isOn: $viewModel.settings.hydration.useAdaptiveLearning)
                .onChange(of: viewModel.settings.hydration.useAdaptiveLearning) { _ in viewModel.updateHydrationSettings() }

            if !viewModel.settings.hydration.smartReminders {
                settingDivider
                settingPicker("Frequency", selection: $viewModel.settings.hydration.reminderFrequencyHours) {
                    Text("Every 2 hours").tag(2)
                    Text("Every 3 hours").tag(3)
                    Text("Every 4 hours").tag(4)
                    Text("Every 5 hours").tag(5)
                }
                .onChange(of: viewModel.settings.hydration.reminderFrequencyHours) { _ in viewModel.updateHydrationSettings() }
            }

            settingDivider

            settingPicker("Snooze", selection: $viewModel.settings.hydration.snoozeMinutes) {
                ForEach(NotificationSettings.snoozeDurationOptions, id: \.self) { m in
                    Text(m >= 60 ? "\(m / 60) hour" : "\(m) min").tag(m)
                }
            }
            .onChange(of: viewModel.settings.hydration.snoozeMinutes) { _ in viewModel.updateHydrationSettings() }

            settingDivider

            settingTime("Quiet Start", selection: $viewModel.settings.hydration.quietHoursStart)
                .onChange(of: viewModel.settings.hydration.quietHoursStart) { _ in viewModel.updateHydrationSettings() }

            settingDivider

            settingTime("Quiet End", selection: $viewModel.settings.hydration.quietHoursEnd)
                .onChange(of: viewModel.settings.hydration.quietHoursEnd) { _ in viewModel.updateHydrationSettings() }

            settingDivider

            settingToggle("Progress Updates", isOn: $viewModel.settings.hydration.showProgress)
                .onChange(of: viewModel.settings.hydration.showProgress) { _ in viewModel.updateHydrationSettings() }

            settingDivider

            settingToggle("Motivational Messages", isOn: $viewModel.settings.hydration.showMotivational)
                .onChange(of: viewModel.settings.hydration.showMotivational) { _ in viewModel.updateHydrationSettings() }
        }
    }

    // MARK: - Medication Content

    @ViewBuilder
    private var medicationContent: some View {
        VStack(spacing: 0) {
            settingPicker("Remind Before", selection: $viewModel.settings.medication.reminderBeforeDoseMinutes) {
                Text("15 min").tag(15)
                Text("30 min").tag(30)
                Text("1 hour").tag(60)
            }

            settingDivider

            settingToggle("Missed Dose Follow-up", isOn: $viewModel.settings.medication.missedDoseFollowUp)

            settingDivider

            settingPicker("Snooze", selection: $viewModel.settings.medication.snoozeMinutes) {
                Text("5 min").tag(5)
                Text("10 min").tag(10)
                Text("15 min").tag(15)
                Text("30 min").tag(30)
            }
        }
    }

    // MARK: - Diet Content

    private var dietSubtitle: String {
        let count = [
            viewModel.settings.diet.breakfastEnabled,
            viewModel.settings.diet.lunchEnabled,
            viewModel.settings.diet.dinnerEnabled,
            viewModel.settings.diet.snacksEnabled
        ].filter { $0 }.count
        return "\(count) meal\(count == 1 ? "" : "s") tracked"
    }

    @ViewBuilder
    private var dietContent: some View {
        VStack(spacing: 0) {
            mealRow("Breakfast", enabled: $viewModel.settings.diet.breakfastEnabled, time: $viewModel.settings.diet.breakfastTime)
            settingDivider
            mealRow("Lunch", enabled: $viewModel.settings.diet.lunchEnabled, time: $viewModel.settings.diet.lunchTime)
            settingDivider
            mealRow("Dinner", enabled: $viewModel.settings.diet.dinnerEnabled, time: $viewModel.settings.diet.dinnerTime)
            settingDivider
            mealRow("Snacks", enabled: $viewModel.settings.diet.snacksEnabled, time: $viewModel.settings.diet.snacksTime)
            settingDivider
            settingToggle("Log Nudge", isOn: $viewModel.settings.diet.logNudgeEnabled)

            Text("Reminds you 30 min after meal time if nothing logged")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
    }

    // MARK: - Menstrual Content

    @ViewBuilder
    private var menstrualContent: some View {
        VStack(spacing: 0) {
            settingToggle("Period Prediction", isOn: $viewModel.settings.menstrual.periodPredictionEnabled)

            if viewModel.settings.menstrual.periodPredictionEnabled {
                settingDivider
                settingPicker("Days Before", selection: $viewModel.settings.menstrual.periodPredictionDaysBefore) {
                    Text("1 day").tag(1)
                    Text("2 days").tag(2)
                    Text("3 days").tag(3)
                }
            }

            settingDivider

            settingToggle("Symptom Check-in", isOn: $viewModel.settings.menstrual.dailySymptomCheckIn)

            if viewModel.settings.menstrual.dailySymptomCheckIn {
                settingDivider
                settingTime("Check-in Time", selection: $viewModel.settings.menstrual.symptomCheckInTime)
            }

            settingDivider
            settingToggle("Ovulation Alerts", isOn: $viewModel.settings.menstrual.ovulationAlertEnabled)
            settingDivider
            settingToggle("Cycle Summary", isOn: $viewModel.settings.menstrual.cycleSummaryEnabled)
        }
    }

    // MARK: - AI Content

    @ViewBuilder
    private var aiContent: some View {
        VStack(spacing: 0) {
            settingPicker("Frequency", selection: $viewModel.settings.aiNudges.frequencyPerDay) {
                Text("1x per day").tag(1)
                Text("2x per day").tag(2)
                Text("3x per day").tag(3)
            }

            settingDivider

            settingToggle("Global Quiet Hours", isOn: $viewModel.settings.aiNudges.useGlobalQuietHours)

            settingDivider

            settingToggle("WhatsApp Nudges", isOn: $viewModel.settings.aiNudges.whatsAppNudgesEnabled)

            if viewModel.settings.aiNudges.whatsAppNudgesEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    if let phone = viewModel.userPhone, !phone.isEmpty {
                        Text(phone)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No phone number on file")
                            .foregroundColor(.orange)
                    }
                }
                .font(.system(size: 12))
                .padding(.top, 6)
            }
        }
    }

    // MARK: - Shared Setting Rows

    private func settingToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.vertical, 6)
    }

    private func settingPicker<S: Hashable, Content: View>(
        _ label: String,
        selection: Binding<S>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
            Spacer()
            Picker("", selection: selection, content: content)
                .pickerStyle(.menu)
                .tint(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func settingTime(_ label: String, selection: Binding<Date>) -> some View {
        DatePicker(label, selection: selection, displayedComponents: .hourAndMinute)
            .font(.system(size: 15))
            .padding(.vertical, 2)
    }

    private func mealRow(_ label: String, enabled: Binding<Bool>, time: Binding<Date>) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 15))
                Spacer()
                if enabled.wrappedValue {
                    Text(time.wrappedValue.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Toggle("", isOn: enabled)
                    .labelsHidden()
            }

            if enabled.wrappedValue {
                DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }

    private var settingDivider: some View {
        Divider().padding(.vertical, 2)
    }

    // MARK: - Helpers

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NavigationStack {
        RemindersSettingsView()
    }
}
