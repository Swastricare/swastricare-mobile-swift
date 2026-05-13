//
//  FamilyAlertPreferencesView.swift
//  swastricare-mobile-swift
//
//  Family Monitoring — caregiver's per-member alert preferences sheet.
//  Mirrors the Android FamilyAlertPreferencesScreen.
//

import SwiftUI

struct FamilyAlertPreferencesView: View {

    let targetHealthProfileId: String

    @StateObject private var vm = FamilyAlertPreferencesViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                if vm.isLoading {
                    ProgressView()
                        .tint(AppColors.accentBlue)
                } else if let prefs = vm.prefs {
                    contentScroll(prefs: prefs)
                    saveBar
                } else if let err = vm.error {
                    Text(err)
                        .font(.poppins(.regular, size: 14))
                        .foregroundColor(.red)
                        .padding()
                        .multilineTextAlignment(.center)
                }
            }
            .navigationTitle("Alert preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .tint(AppColors.accentBlue)
                }
            }
        }
        .task { await vm.load(targetHealthProfileId: targetHealthProfileId) }
        .alert(
            vm.saveMessage ?? "",
            isPresented: Binding(
                get: { vm.saveMessage != nil },
                set: { if !$0 { vm.clearSaveMessage() } }
            )
        ) {
            Button("OK") { vm.clearSaveMessage() }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func contentScroll(prefs: FamilyAlertPreferences) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Section: Alerts I want to receive
                section(title: "Alerts I want to receive") {
                    VStack(spacing: 0) {
                        toggleRow(
                            title: "Missed medication",
                            subtitle: "Get notified when a dose is missed",
                            isOn: Binding(
                                get: { prefs.missedMedicationAlerts },
                                set: { newVal in vm.update { $0.missedMedicationAlerts = newVal } }
                            )
                        )
                        Divider()
                        toggleRow(
                            title: "Low hydration",
                            subtitle: "Get notified if hydration is low today",
                            isOn: Binding(
                                get: { prefs.lowHydrationAlerts },
                                set: { newVal in vm.update { $0.lowHydrationAlerts = newVal } }
                            )
                        )
                        Divider()
                        toggleRow(
                            title: "Missed vitals",
                            subtitle: "Get notified if vitals haven't been logged today",
                            isOn: Binding(
                                get: { prefs.missedVitalsAlerts },
                                set: { newVal in vm.update { $0.missedVitalsAlerts = newVal } }
                            )
                        )
                        Divider()
                        toggleRow(
                            title: "Custom nudges",
                            subtitle: "Get notified for direct nudges from family",
                            isOn: Binding(
                                get: { prefs.customNudgeAlerts },
                                set: { newVal in vm.update { $0.customNudgeAlerts = newVal } }
                            )
                        )
                    }
                }

                // Section: Quiet hours
                section(title: "Quiet hours") {
                    Text("Don't send non-critical alerts during this window. Critical alerts (missed medication) still come through.")
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(.gray)
                    quietHoursRows(prefs: prefs)
                }

                // Section: Grace period
                section(title: "Missed medication grace period") {
                    Text("How long after a scheduled dose before it counts as missed")
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(.gray)
                    graceChips(prefs: prefs)
                }

                // Room for sticky save button
                Spacer().frame(height: 96)
            }
            .padding(20)
        }
    }

    // MARK: - Sticky save bar

    private var saveBar: some View {
        VStack {
            Spacer()
            Button(action: { vm.save() }) {
                Text(vm.isSaving ? "Saving…" : "Save changes")
                    .font(.poppins(.semiBold, size: 16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(vm.isSaving ? AppColors.accentBlue.opacity(0.5) : AppColors.accentBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(vm.isSaving)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Section helper

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.poppins(.semiBold, size: 16))
            content()
        }
    }

    // MARK: - Toggle row

    @ViewBuilder
    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.poppins(.medium, size: 14))
                Text(subtitle)
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(.gray)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .tint(AppColors.accentBlue)
                .labelsHidden()
        }
        .padding(.vertical, 10)
    }

    // MARK: - Quiet hours

    @ViewBuilder
    private func quietHoursRows(prefs: FamilyAlertPreferences) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            timeRow(
                label: "From",
                value: prefs.quietHoursStart,
                setter: { newVal in vm.update { $0.quietHoursStart = newVal } }
            )
            timeRow(
                label: "To",
                value: prefs.quietHoursEnd,
                setter: { newVal in vm.update { $0.quietHoursEnd = newVal } }
            )
            Button("Clear quiet hours") {
                vm.update {
                    $0.quietHoursStart = nil
                    $0.quietHoursEnd = nil
                }
            }
            .font(.poppins(.medium, size: 13))
            .foregroundColor(AppColors.accentBlue)
        }
    }

    @ViewBuilder
    private func timeRow(label: String, value: String?, setter: @escaping (String?) -> Void) -> some View {
        HStack {
            Text(label)
                .font(.poppins(.regular, size: 14))
            Spacer()
            DatePicker(
                "",
                selection: Binding(
                    get: { timeFromString(value) ?? Date() },
                    set: { newDate in setter(stringFromTime(newDate)) }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .tint(AppColors.accentBlue)
        }
    }

    private func timeFromString(_ s: String?) -> Date? {
        guard let s = s else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: s)
    }

    private func stringFromTime(_ d: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:00"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: d)
    }

    // MARK: - Grace chips

    @ViewBuilder
    private func graceChips(prefs: FamilyAlertPreferences) -> some View {
        let options = [15, 30, 45, 60]
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { mins in
                let selected = prefs.missedMedGraceMinutes == mins
                Button(action: { vm.update { $0.missedMedGraceMinutes = mins } }) {
                    Text("\(mins) min")
                        .font(.poppins(selected ? .semiBold : .regular, size: 13))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selected ? AppColors.accentBlue : Color.white)
                        .foregroundColor(selected ? .white : .black)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppColors.accentBlue, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
}

#Preview {
    FamilyAlertPreferencesView(targetHealthProfileId: "00000000-0000-0000-0000-000000000000")
}
