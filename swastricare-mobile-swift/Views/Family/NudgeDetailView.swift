//
//  NudgeDetailView.swift
//  swastricare-mobile-swift
//
//  Family Monitoring — detail screen reached when a recipient taps an FCM push
//  notification (swastricareapp://nudge/{id}). Mirrors the Android
//  NudgeDetailScreen: hero icon + title + relative timestamp, optional critical
//  banner, soft-grey message card, meta rows, and context-aware action buttons.
//

import SwiftUI

struct NudgeDetailView: View {
    let nudgeId: String

    @StateObject private var vm = NudgeDetailViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                content
            }
            .navigationTitle("Nudge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.backward")
                            .foregroundColor(.black)
                    }
                }
            }
        }
        .task { await vm.load(id: nudgeId) }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            ProgressView()
                .tint(AppColors.accentBlue)
        } else if let err = vm.error {
            errorView(err)
        } else if let nudge = vm.nudge {
            detailScroll(for: nudge)
        }
    }

    private func errorView(_ err: String) -> some View {
        VStack(spacing: 12) {
            Text("Couldn't open nudge")
                .font(.poppins(.semiBold, size: 18))
                .foregroundColor(.black)
            Text(err)
                .font(.poppins(.regular, size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button(action: { dismiss() }) {
                Text("Go back")
                    .font(.poppins(.semiBold, size: 15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppColors.accentBlue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .padding(24)
    }

    private func detailScroll(for nudge: NudgeDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroSection(for: nudge)

                if nudge.isCritical {
                    criticalBanner
                }

                if !nudge.message.isEmpty {
                    messageCard(nudge.message)
                }

                metaSection(for: nudge)

                Spacer().frame(height: 8)

                if !nudge.isActedOn && !nudge.isDismissed {
                    primaryActionButton(for: nudge)
                    dismissButton
                } else {
                    closeButton
                }
            }
            .padding(20)
        }
    }

    // MARK: - Sections

    private func heroSection(for nudge: NudgeDetail) -> some View {
        HStack(spacing: 14) {
            let (icon, tint) = iconAndTint(for: nudge.nudgeType)
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .foregroundColor(tint)
                    .font(.system(size: 28))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(nudge.title.isEmpty ? friendlyType(nudge.nudgeType) : nudge.title)
                    .font(.poppins(.bold, size: 20))
                    .foregroundColor(.black)
                Text("From your family • \(formatRelative(nudge.createdAt))")
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(.gray)
            }
            Spacer()
        }
    }

    private var criticalBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(hex: "B71C1C"))
            Text("Important — needs your attention")
                .font(.poppins(.medium, size: 13))
                .foregroundColor(Color(hex: "B71C1C"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "FFE3E3"))
        .cornerRadius(12)
    }

    private func messageCard(_ message: String) -> some View {
        Text(message)
            .font(.poppins(.regular, size: 15))
            .foregroundColor(.black)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "F7F7F7"))
            .cornerRadius(16)
    }

    private func metaSection(for nudge: NudgeDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            metaRow(label: "Type", value: friendlyType(nudge.nudgeType))
            if let p = nudge.priority, !p.isEmpty {
                metaRow(label: "Priority", value: p.capitalized)
            }
            metaRow(label: "Received", value: formatAbsolute(nudge.createdAt))
            if nudge.isActedOn {
                metaRow(label: "Status", value: "Acknowledged")
            } else if nudge.isDismissed {
                metaRow(label: "Status", value: "Dismissed")
            }
        }
    }

    private func primaryActionButton(for nudge: NudgeDetail) -> some View {
        Button(action: { vm.markActedOn { dismiss() } }) {
            Text(actionLabel(for: nudge.nudgeType))
                .font(.poppins(.semiBold, size: 16))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(vm.isActing ? AppColors.accentBlue.opacity(0.4) : AppColors.accentBlue)
                .cornerRadius(14)
        }
        .disabled(vm.isActing)
    }

    private var dismissButton: some View {
        Button(action: { vm.dismissNudge { dismiss() } }) {
            Text("Dismiss")
                .font(.poppins(.medium, size: 14))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, minHeight: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
        .disabled(vm.isActing)
    }

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Text("Close")
                .font(.poppins(.medium, size: 14))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, minHeight: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.poppins(.regular, size: 12))
                .foregroundColor(.gray)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.poppins(.medium, size: 13))
                .foregroundColor(.black)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Mappers

    private func iconAndTint(for type: String) -> (String, Color) {
        switch type.uppercased() {
        case "MEDICATION", "MEDICATION_MISSED":
            return ("pills", Color(hex: "4F46E5"))
        case "HYDRATION":
            return ("drop.fill", Color(hex: "0EA5E9"))
        case "VITALS":
            return ("heart.text.square", Color(hex: "EF4444"))
        case "APPOINTMENT":
            return ("calendar", Color(hex: "F59E0B"))
        case "CHECKIN":
            return ("heart.fill", Color(hex: "EC4899"))
        default:
            return ("bell", AppColors.accentBlue)
        }
    }

    private func friendlyType(_ type: String) -> String {
        switch type.uppercased() {
        case "MEDICATION": return "Medication reminder"
        case "MEDICATION_MISSED": return "Missed medication"
        case "HYDRATION": return "Hydration nudge"
        case "VITALS": return "Vitals reminder"
        case "APPOINTMENT": return "Appointment"
        case "CHECKIN": return "Family check-in"
        default:
            return type.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func actionLabel(for type: String) -> String {
        switch type.uppercased() {
        case "MEDICATION", "MEDICATION_MISSED": return "I took my medication"
        case "HYDRATION": return "I'm drinking water"
        case "VITALS": return "I'll log it now"
        case "APPOINTMENT": return "Got it"
        case "CHECKIN": return "Thanks for checking in"
        default: return "Got it"
        }
    }

    // MARK: - Date formatting

    private func formatAbsolute(_ iso: String) -> String {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        guard let date = fractional.date(from: iso) ?? plain.date(from: iso) else {
            return String(iso.prefix(16))
        }
        let out = DateFormatter()
        out.dateFormat = "MMM d, h:mm a"
        return out.string(from: date)
    }

    private func formatRelative(_ iso: String) -> String {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        guard let then = fractional.date(from: iso) ?? plain.date(from: iso) else {
            return "recently"
        }
        let secs = Int(Date().timeIntervalSince(then))
        switch secs {
        case ..<60: return "just now"
        case ..<3600: return "\(secs / 60)m ago"
        case ..<86400: return "\(secs / 3600)h ago"
        case ..<172800: return "yesterday"
        default: return "\(secs / 86400)d ago"
        }
    }
}
