//
//  FamilyMemberDashboardView.swift
//  swastricare-mobile-swift
//
//  Family Monitoring — per-member dashboard. Shown when a caregiver taps
//  a member row in FamilyView. Mirrors the Android FamilyMemberDashboardScreen
//  visual style: pure-white background, flat bordered cards, AITeal accents.
//

import SwiftUI
import UIKit

// MARK: - Local Android-matched palette

private enum DashPalette {
    static let pageBg       = Color.white
    static let cardBg       = Color.white
    static let cardBorder   = Color(hex: "E5E7EB")
    static let onSurface    = Color(hex: "111827")
    static let subtitle     = Color(hex: "6B7280")
    static let tileBg       = Color(hex: "FAFAFB")
    static let teal         = Color(hex: "22C5A6") // AITeal
    static let success      = Color(hex: "22C55E")
    static let danger       = Color(hex: "EF4444")
    static let warning      = Color(hex: "F59E0B")
    static let sleepIndigo  = Color(hex: "6366F1")
    static let waterBlue    = Color(hex: "0EA5E9")
    static let dietAmber    = Color(hex: "F59E0B")
    static let pendingGray  = Color(hex: "9CA3AF")
    static let pendingBg    = Color(hex: "E5E7EB")
}

// Flat card modifier matching the Android Card composable
// (white surface + 1pt hairline border + 16pt corner radius + 16pt inner padding).
private struct FlatCardModifier: ViewModifier {
    var innerPadding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(innerPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DashPalette.cardBg)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(DashPalette.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private extension View {
    func flatCard(innerPadding: CGFloat = 16) -> some View {
        modifier(FlatCardModifier(innerPadding: innerPadding))
    }
}

struct FamilyMemberDashboardView: View {

    let targetHealthProfileId: String

    @StateObject private var vm = FamilyMemberDashboardViewModel()
    @State private var showNudgeSheet = false
    @State private var showAISheet = false
    @State private var showAlertPrefsSheet = false
    @State private var showRemindersSheet = false

    var body: some View {
        ZStack {
            DashPalette.pageBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    if vm.state.isLoading {
                        loadingView.padding(.top, 80)
                    } else if let err = vm.state.error {
                        errorCard(err)
                    } else {
                        memberHeaderCard
                        vitalsCard
                        medicationCard
                        hydrationCard
                        dietCard
                        vaultCard
                        actionRow
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .background(DashPalette.pageBg)
        .navigationTitle(vm.state.member?.fullName?.components(separatedBy: " ").first ?? "Member")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.load(targetHealthProfileId: targetHealthProfileId)
        }
        .sheet(isPresented: $showNudgeSheet) {
            FamilyNudgeView(targetHealthProfileId: targetHealthProfileId)
        }
        .sheet(isPresented: $showAISheet) {
            FamilyMemberAIView(targetHealthProfileId: targetHealthProfileId)
        }
        .sheet(isPresented: $showAlertPrefsSheet) {
            FamilyAlertPreferencesView(targetHealthProfileId: targetHealthProfileId)
        }
        .sheet(isPresented: $showRemindersSheet) {
            FamilyMemberRemindersView(targetHealthProfileId: targetHealthProfileId)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(DashPalette.teal)
                .scaleEffect(1.2)
            Text("Loading dashboard...")
                .font(.poppins(.regular, size: 14))
                .foregroundStyle(DashPalette.subtitle)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error card

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(DashPalette.danger)

            Text("Couldn't load dashboard")
                .font(.poppins(.semiBold, size: 15))
                .foregroundStyle(DashPalette.onSurface)

            Text(message)
                .font(.poppins(.regular, size: 13))
                .foregroundStyle(DashPalette.subtitle)
                .multilineTextAlignment(.center)

            Button {
                Task { await vm.load(targetHealthProfileId: targetHealthProfileId) }
            } label: {
                Text("Retry")
                    .font(.poppins(.semiBold, size: 15))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DashPalette.teal)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .flatCard(innerPadding: 20)
    }

    // MARK: - Member header

    private var memberHeaderCard: some View {
        HStack(spacing: 14) {
            // Avatar (56pt, teal-tinted)
            ZStack {
                Circle()
                    .fill(DashPalette.teal.opacity(0.15))
                    .frame(width: 56, height: 56)

                if let urlStr = vm.state.member?.avatarUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            initialsView
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                } else {
                    initialsView
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(vm.state.member?.fullName ?? "Unknown")
                    .font(.poppins(.bold, size: 18))
                    .foregroundStyle(DashPalette.onSurface)
                    .lineLimit(1)

                roleBadge
            }

            Spacer(minLength: 0)
        }
        .flatCard()
    }

    private var roleBadge: some View {
        let role = vm.state.member?.role
        let label: String = role?.displayName ?? "Member"
        let isPrimary: Bool = (role == .owner)
        let bg: Color = isPrimary ? DashPalette.teal : Color(hex: "F3F4F6")
        let fg: Color = isPrimary ? .white : DashPalette.subtitle
        return Text(label)
            .font(.poppins(.semiBold, size: 11))
            .foregroundStyle(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var initialsView: some View {
        Text(initialFor(vm.state.member))
            .font(.poppins(.bold, size: 18))
            .foregroundStyle(DashPalette.teal)
    }

    private func initialFor(_ member: FamilyMember?) -> String {
        if let name = member?.fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return String(name.prefix(2)).uppercased()
        }
        return "?"
    }

    // MARK: - Vitals

    private var vitalsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vitals")
                .font(.poppins(.semiBold, size: 15))
                .foregroundStyle(DashPalette.onSurface)

            HStack(spacing: 12) {
                vitalTile(
                    icon: "heart.fill",
                    iconColor: DashPalette.danger,
                    label: "Heart rate",
                    value: vm.state.latestHeartRateBpm.map { "\($0) bpm" } ?? "—",
                    sub: vm.state.heartRateMeasuredAt.flatMap { friendlyTime($0) } ?? "No data"
                )

                vitalTile(
                    icon: "bed.double.fill",
                    iconColor: DashPalette.sleepIndigo,
                    label: "Sleep",
                    value: vm.state.sleepHours.map { String(format: "%.1f h", $0) } ?? "—",
                    sub: vm.state.sleepHours == nil ? "No data" : "Last night"
                )
            }
        }
        .flatCard()
    }

    private func vitalTile(icon: String, iconColor: Color, label: String, value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
                Text(label)
                    .font(.poppins(.medium, size: 11))
                    .foregroundStyle(DashPalette.subtitle)
            }
            Text(value)
                .font(.poppins(.bold, size: 20))
                .foregroundStyle(DashPalette.onSurface)
            Text(sub)
                .font(.poppins(.regular, size: 10))
                .foregroundStyle(DashPalette.subtitle)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(DashPalette.tileBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Medication

    private var medicationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "pills.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(DashPalette.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's medications")
                        .font(.poppins(.semiBold, size: 15))
                        .foregroundStyle(DashPalette.onSurface)
                    Text("Adherence: \(vm.state.adherencePercent)%")
                        .font(.poppins(.regular, size: 12))
                        .foregroundStyle(DashPalette.subtitle)
                }
                Spacer()
                // Thin teal arc progress ring (matches Android CircularProgressIndicator)
                adherenceRing
            }

            if vm.state.doses.isEmpty {
                Text("No doses scheduled for today.")
                    .font(.poppins(.regular, size: 13))
                    .foregroundStyle(DashPalette.subtitle)
            } else {
                VStack(spacing: 8) {
                    ForEach(vm.state.doses) { dose in
                        doseRow(dose)
                    }
                }
            }
        }
        .flatCard()
    }

    private var adherenceRing: some View {
        let progress = CGFloat(min(max(vm.state.adherencePercent, 0), 100)) / 100
        return ZStack {
            Circle()
                .stroke(Color(hex: "E5E7EB"), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(DashPalette.teal, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(vm.state.adherencePercent)%")
                .font(.poppins(.semiBold, size: 10))
                .foregroundStyle(DashPalette.onSurface)
        }
        .frame(width: 38, height: 38)
    }

    private func doseRow(_ dose: FamilyMemberDashboardViewModel.MedicationDoseSummary) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundStyle(DashPalette.subtitle)
            Text(friendlyTime(dose.scheduledAt) ?? dose.scheduledAt)
                .font(.poppins(.medium, size: 12))
                .foregroundStyle(DashPalette.subtitle)
                .frame(width: 64, alignment: .leading)
            Text(dose.medicationName)
                .font(.poppins(.medium, size: 13))
                .foregroundStyle(DashPalette.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
            statusPill(dose.status)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(DashPalette.tileBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func statusPill(_ status: String) -> some View {
        let s = status.lowercased()
        let label: String
        let bg: Color
        let fg: Color
        switch s {
        case "taken":
            label = "Taken"; fg = DashPalette.success; bg = DashPalette.success.opacity(0.15)
        case "missed":
            label = "Missed"; fg = DashPalette.danger; bg = DashPalette.danger.opacity(0.15)
        case "skipped":
            label = "Skipped"; fg = DashPalette.warning; bg = DashPalette.warning.opacity(0.15)
        case "late":
            label = "Late"; fg = DashPalette.warning; bg = DashPalette.warning.opacity(0.15)
        case "early":
            label = "Early"; fg = DashPalette.teal; bg = DashPalette.teal.opacity(0.15)
        default:
            label = "Pending"; fg = DashPalette.subtitle; bg = DashPalette.pendingBg
        }
        return Text(label)
            .font(.poppins(.semiBold, size: 10))
            .foregroundStyle(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Hydration

    private var hydrationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(DashPalette.waterBlue)
                Text("Hydration")
                    .font(.poppins(.semiBold, size: 15))
                    .foregroundStyle(DashPalette.onSurface)
                Spacer()
                Text("\(vm.state.hydrationMl) / \(vm.state.hydrationGoalMl) ml")
                    .font(.poppins(.medium, size: 12))
                    .foregroundStyle(DashPalette.subtitle)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "E5E7EB"))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DashPalette.teal)
                        .frame(width: geo.size.width * hydrationProgress)
                }
            }
            .frame(height: 8)
        }
        .flatCard()
    }

    private var hydrationProgress: CGFloat {
        let goal = vm.state.hydrationGoalMl
        guard goal > 0 else { return 0 }
        return min(1, CGFloat(vm.state.hydrationMl) / CGFloat(goal))
    }

    // MARK: - Diet

    private var dietCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "fork.knife")
                .font(.system(size: 16))
                .foregroundStyle(DashPalette.dietAmber)
            VStack(alignment: .leading, spacing: 2) {
                Text("Calories today")
                    .font(.poppins(.regular, size: 12))
                    .foregroundStyle(DashPalette.subtitle)
                Text("\(vm.state.caloriesToday) kcal")
                    .font(.poppins(.bold, size: 18))
                    .foregroundStyle(DashPalette.onSurface)
            }
            Spacer()
        }
        .flatCard()
    }

    // MARK: - Vault

    private var vaultCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .font(.system(size: 16))
                    .foregroundStyle(DashPalette.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vault")
                        .font(.poppins(.regular, size: 12))
                        .foregroundStyle(DashPalette.subtitle)
                    Text(vaultSummaryText)
                        .font(.poppins(.semiBold, size: 15))
                        .foregroundStyle(DashPalette.onSurface)
                }
                Spacer()
            }

            if !vm.state.vaultDocs.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(vm.state.vaultDocs.prefix(10).enumerated()), id: \.element.id) { _, doc in
                        vaultRow(doc)
                    }
                    if vm.state.vaultDocs.count > 10 {
                        Text("+ \(vm.state.vaultDocs.count - 10) more")
                            .font(.poppins(.regular, size: 12))
                            .foregroundStyle(DashPalette.subtitle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .flatCard()
    }

    private var vaultSummaryText: String {
        let n = vm.state.vaultDocs.count
        if n == 0 { return "No documents shared yet" }
        return "\(n) document\(n == 1 ? "" : "s")"
    }

    private func vaultRow(_ doc: VaultDocSummary) -> some View {
        Button {
            openVaultDoc(doc)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Teal-tinted doc icon tile (56pt rounded rect). No thumbnail field on VaultDocSummary.
                vaultIconTile

                VStack(alignment: .leading, spacing: 2) {
                    Text(doc.name.isEmpty ? "Untitled document" : doc.name)
                        .font(.poppins(.semiBold, size: 14))
                        .foregroundStyle(DashPalette.onSurface)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    let metaLine = buildMetaLine(doc)
                    if !metaLine.isEmpty {
                        Text(metaLine)
                            .font(.poppins(.regular, size: 11))
                            .foregroundStyle(DashPalette.subtitle)
                    }

                    let fileMeta = buildFileMeta(doc)
                    if !fileMeta.isEmpty {
                        Text(fileMeta)
                            .font(.poppins(.regular, size: 11))
                            .foregroundStyle(DashPalette.subtitle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 18))
                    .foregroundStyle(DashPalette.teal)
                    .padding(.top, 2)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var vaultIconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(DashPalette.teal.opacity(0.10))
            Image(systemName: "doc.text")
                .font(.system(size: 22))
                .foregroundStyle(DashPalette.teal)
        }
        .frame(width: 56, height: 56)
    }

    private func buildMetaLine(_ doc: VaultDocSummary) -> String {
        var parts: [String] = []
        if let t = doc.docType, !t.isEmpty {
            let pretty = t.replacingOccurrences(of: "_", with: " ").capitalized
            parts.append(pretty)
        }
        let dateOnly = String(doc.uploadedAt.prefix(10))
        if !dateOnly.isEmpty {
            parts.append(dateOnly)
        }
        return parts.joined(separator: " • ")
    }

    private func buildFileMeta(_ doc: VaultDocSummary) -> String {
        var parts: [String] = []
        if let name = doc.fileName, !name.isEmpty { parts.append(name) }
        if let size = doc.fileSizeBytes { parts.append(formatBytes(size)) }
        return parts.joined(separator: " • ")
    }

    private func openVaultDoc(_ doc: VaultDocSummary) {
        guard let path = doc.fileUrl, !path.isEmpty else { return }
        Task {
            if let url = await vm.resolveVaultDocURL(path: path) {
                await UIApplication.shared.open(url)
            }
        }
    }

    // MARK: - Action Row (2x2 solid AITeal grid)

    private var actionRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                actionButton(title: "Nudge", icon: "bell.badge.fill") { showNudgeSheet = true }
                actionButton(title: "Ask AI", icon: "brain.head.profile") { showAISheet = true }
            }
            HStack(spacing: 10) {
                if vm.state.canEdit {
                    actionButton(title: "Reminders", icon: "clock.fill") { showRemindersSheet = true }
                }
                actionButton(title: "Alert prefs", icon: "bell.fill") { showAlertPrefsSheet = true }
            }
        }
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.poppins(.semiBold, size: 13))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(DashPalette.teal)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Helpers

    private func friendlyTime(_ iso: String) -> String? {
        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withInternetDateTime]
        guard let date = isoFmt.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else {
            return nil
        }
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        df.timeZone = .current
        return df.string(from: date)
    }

    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1 { return "\(bytes) B" }
        if kb < 1024 {
            return String(format: "%.0f KB", kb)
        }
        return String(format: "%.1f MB", kb / 1024)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FamilyMemberDashboardView(targetHealthProfileId: "00000000-0000-0000-0000-000000000000")
    }
}
