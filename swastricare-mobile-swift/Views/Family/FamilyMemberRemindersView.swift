//
//  FamilyMemberRemindersView.swift
//  swastricare-mobile-swift
//
//  Family Monitoring — Batch 6.
//  Caregiver UI for remotely editing a family member's medication
//  reminder schedule times and toggles. V1 only supports daily schedules.
//

import SwiftUI

struct FamilyMemberRemindersView: View {
    let targetHealthProfileId: String

    @StateObject private var vm = FamilyMemberRemindersViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                if vm.isLoading {
                    ProgressView()
                        .tint(AppColors.accentBlue)
                } else if let err = vm.error {
                    errorView(err)
                } else if vm.schedules.isEmpty {
                    emptyView
                } else {
                    schedulesScroll
                }
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .font(.poppins(.medium, size: 15))
                            .foregroundStyle(AppColors.accentBlue)
                    }
                }
            }
        }
        .task { await vm.load(targetHealthProfileId: targetHealthProfileId) }
        .alert(item: messageBinding) { wrapper in
            Alert(
                title: Text(wrapper.message),
                dismissButton: .default(Text("OK")) { vm.clearMessage() }
            )
        }
    }

    // MARK: - Subviews

    private var schedulesScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Editing reminders for your family member. Changes apply on their device.")
                    .font(.poppins(.regular, size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                ForEach(vm.schedules) { sched in
                    scheduleRow(sched)
                }
            }
            .padding(20)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "alarm")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No active medication reminders")
                .font(.poppins(.medium, size: 15))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(AppColors.accentRed)

            Text(message)
                .font(.poppins(.regular, size: 14))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(.poppins(.semiBold, size: 15))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 12)
                    .background(AppColors.accentBlue)
                    .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    @ViewBuilder
    private func scheduleRow(_ sched: MedicationWithSchedule) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(sched.medicationName)
                    .font(.poppins(.semiBold, size: 16))
                    .lineLimit(1)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { sched.reminderEnabled },
                    set: { newVal in
                        vm.setReminderEnabled(scheduleId: sched.scheduleId, enabled: newVal)
                    }
                ))
                .tint(AppColors.accentBlue)
                .labelsHidden()
            }

            HStack(spacing: 8) {
                Text(sched.scheduleType.capitalized)
                    .font(.poppins(.medium, size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(white: 0.95))
                    .clipShape(Capsule())

                Spacer()

                if sched.scheduleType == "daily" {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { timeFromString(sched.timeOfDay) ?? Date() },
                            set: { newDate in
                                vm.updateTime(
                                    scheduleId: sched.scheduleId,
                                    newTime: stringFromTime(newDate)
                                )
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                } else {
                    Text("Not editable from family view")
                        .font(.poppins(.regular, size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            if vm.savingScheduleId == sched.scheduleId {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(AppColors.accentBlue)
                    Text("Saving…")
                        .font(.poppins(.regular, size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(white: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private struct MessageWrapper: Identifiable {
        let id = UUID()
        let message: String
    }

    private var messageBinding: Binding<MessageWrapper?> {
        Binding<MessageWrapper?>(
            get: { vm.message.map { MessageWrapper(message: $0) } },
            set: { newValue in
                if newValue == nil { vm.clearMessage() }
            }
        )
    }

    private func timeFromString(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        if let d = f.date(from: s) { return d }
        let f2 = DateFormatter()
        f2.dateFormat = "HH:mm"
        f2.locale = Locale(identifier: "en_US_POSIX")
        return f2.date(from: s)
    }

    private func stringFromTime(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:00"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: d)
    }
}

#Preview {
    FamilyMemberRemindersView(targetHealthProfileId: "00000000-0000-0000-0000-000000000000")
}
