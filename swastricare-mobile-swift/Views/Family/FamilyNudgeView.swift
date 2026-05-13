//
//  FamilyNudgeView.swift
//  swastricare-mobile-swift
//
//  Family Monitoring — bottom sheet for sending an FCM push nudge to a
//  family member. Shows 5 preset chips (instant-send) plus a custom message
//  text editor. Mirrors the Android FamilyNudgeScreen.
//

import SwiftUI

struct FamilyNudgeView: View {

    let targetHealthProfileId: String

    @StateObject private var vm = FamilyNudgeViewModel()
    @Environment(\.dismiss) private var dismiss

    // MARK: - Preset chip model

    private struct PresetChip: Identifiable {
        let id = UUID()
        let emoji: String
        let label: String
        let preset: NudgePreset
    }

    private let presets: [PresetChip] = [
        .init(emoji: "💊", label: "Take medication", preset: .medication),
        .init(emoji: "💧", label: "Drink water",     preset: .hydration),
        .init(emoji: "🩺", label: "Log vitals",      preset: .vitals),
        .init(emoji: "📅", label: "Appointment",     preset: .appointment),
        .init(emoji: "❤️", label: "Just checking in", preset: .checkin),
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Tap a preset to send instantly, or write a custom message.")
                            .font(.poppins(.regular, size: 14))
                            .foregroundStyle(.secondary)

                        presetChipsRow

                        customMessageSection

                        sendCustomButton

                        if vm.state.recipientUserId == nil && !vm.state.isSending {
                            Text("Resolving member…")
                                .font(.poppins(.regular, size: 12))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 4)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppColors.accentBlue)
                }
            }
        }
        .task { await vm.initialize(targetHealthProfileId: targetHealthProfileId) }
        .alert(item: alertBinding) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK")) {
                    let wasSuccess = alert.isSuccess
                    vm.clearEvent()
                    if wasSuccess { dismiss() }
                }
            )
        }
    }

    // MARK: - Title

    private var navTitle: String {
        let name = vm.state.memberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "Send a nudge" }
        let first = name.components(separatedBy: " ").first ?? name
        return "Nudge \(first)"
    }

    // MARK: - Preset chips

    private var presetChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(presets) { chip in
                    Button {
                        vm.sendPreset(chip.preset)
                    } label: {
                        Text("\(chip.emoji)  \(chip.label)")
                            .font(.poppins(.medium, size: 13))
                            .foregroundStyle(AppColors.accentBlue)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.white)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(AppColors.accentBlue, lineWidth: 1)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(vm.state.isSending || vm.state.recipientUserId == nil)
                    .opacity(vm.state.isSending || vm.state.recipientUserId == nil ? 0.5 : 1)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Custom message editor

    private var customMessageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom message")
                .font(.poppins(.semiBold, size: 13))
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)

                TextEditor(text: Binding(
                    get: { vm.state.customMessage },
                    set: { vm.setCustomMessage($0) }
                ))
                .font(.poppins(.regular, size: 14))
                .scrollContentBackground(.hidden)
                .background(Color.white)
                .padding(8)

                if vm.state.customMessage.isEmpty {
                    Text("Write a message…")
                        .font(.poppins(.regular, size: 14))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 100)

            HStack {
                Spacer()
                Text("\(vm.state.customMessage.count)/200")
                    .font(.poppins(.regular, size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Send custom button

    private var sendCustomButton: some View {
        let trimmed = vm.state.customMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let disabled = vm.state.isSending || trimmed.isEmpty || vm.state.recipientUserId == nil

        return Button {
            vm.sendCustom()
        } label: {
            HStack(spacing: 8) {
                if vm.state.isSending {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                }
                Text(vm.state.isSending ? "Sending…" : "Send custom")
                    .font(.poppins(.semiBold, size: 16))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(disabled ? AppColors.accentBlue.opacity(0.4) : AppColors.accentBlue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(disabled)
    }

    // MARK: - Alert plumbing

    private struct EventAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let isSuccess: Bool
    }

    private var alertBinding: Binding<EventAlert?> {
        Binding<EventAlert?>(
            get: { eventAlert(from: vm.state.event) },
            set: { newValue in
                if newValue == nil { vm.clearEvent() }
            }
        )
    }

    private func eventAlert(from event: FamilyNudgeViewModel.Event?) -> EventAlert? {
        guard let event = event else { return nil }
        switch event {
        case .success(let delivered, _):
            return EventAlert(
                title: "Nudge sent",
                message: delivered ? "Push delivered." : "Saved — recipient offline.",
                isSuccess: true
            )
        case .failure(let message):
            return EventAlert(
                title: "Couldn't send",
                message: message,
                isSuccess: false
            )
        }
    }
}

// MARK: - Preview

#Preview {
    FamilyNudgeView(targetHealthProfileId: "00000000-0000-0000-0000-000000000000")
}
