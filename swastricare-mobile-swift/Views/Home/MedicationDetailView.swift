//
//  MedicationDetailView.swift
//  swastricare-mobile-swift
//

import SwiftUI

struct MedicationDetailView: View {
    @Environment(\.dismiss) var dismiss
    let medication: Medication
    @ObservedObject var viewModel: MedicationViewModel

    @State private var showEditSheet    = false
    @State private var showDeleteAlert  = false
    @State private var showCalendarSheet = false
    @State private var showStatusSheet  = false
    @State private var skipDialogDose: MedicationAdherence?
    @State private var skipReason = ""

    // Edit fields
    @State private var editName = ""
    @State private var editDosage = ""
    @State private var editNotes = ""
    @State private var editIsOngoing = true

    private let aiTeal = AppColors.accentBlue
    private let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; return f
    }()

    private var currentMed: Medication {
        viewModel.medications.first { $0.id == medication.id } ?? medication
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    navBar
                    heroCard
                        .padding(.horizontal, 16)
                    overviewRow
                        .padding(.top, 20)
                        .padding(.horizontal, 16)
                    todayDoseSection
                        .padding(.top, 20)
                    scheduleSection
                        .padding(.top, 20)
                    if let notes = currentMed.notes, !notes.isEmpty {
                        aboutSection(notes: notes)
                            .padding(.top, 20)
                    }
                    Spacer(minLength: 32)
                }
            }
        }
        .onAppear {
            editName     = currentMed.name
            editDosage   = currentMed.dosage
            editNotes    = currentMed.notes ?? ""
            editIsOngoing = currentMed.isOngoing
        }
        // ── Skip dialog ──
        .alert("Skip Dose", isPresented: Binding(
            get: { skipDialogDose != nil },
            set: { if !$0 { skipDialogDose = nil; skipReason = "" } }
        )) {
            TextField("Reason (optional)", text: $skipReason)
            Button("Skip", role: .destructive) {
                if let dose = skipDialogDose {
                    Task { try? await viewModel.markAsSkipped(
                        medicationId: dose.medicationId,
                        scheduledTime: dose.scheduledTime,
                        notes: skipReason.isEmpty ? nil : skipReason) }
                }
                skipDialogDose = nil; skipReason = ""
            }
            Button("Cancel", role: .cancel) { skipDialogDose = nil; skipReason = "" }
        }
        // ── Delete confirmation ──
        .alert("Delete Medication", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    try? await viewModel.deleteMedication(id: currentMed.id)
                    await MainActor.run { dismiss() }
                }
            }
        } message: {
            Text("Delete \(currentMed.name)? This will also cancel all scheduled reminders.")
        }
        // ── Edit sheet ──
        .sheet(isPresented: $showEditSheet) { editSheet }
        // ── Calendar sheet ──
        .sheet(isPresented: $showCalendarSheet) { calendarSheet }
        // ── Status sheet ──
        .confirmationDialog("Change Status", isPresented: $showStatusSheet, titleVisibility: .visible) {
            ForEach(MedicationStatus.allCases, id: \.self) { s in
                Button(s.displayName) {
                    var updated = currentMed; updated.status = s
                    Task { try? await viewModel.updateMedication(updated) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .trackScreen("MedicationDetail")
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "1C1C1E"))
                    .frame(width: 40, height: 40)
            }
            Spacer()
            Text("Medication Details")
                .font(.poppins(.semiBold, size: 17))
                .foregroundColor(Color(hex: "1C1C1E"))
            Spacer()
            Menu {
                Button { showEditSheet = true } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button { showStatusSheet = true } label: {
                    Label("Change Status", systemImage: "slider.horizontal.3")
                }
                Divider()
                Button(role: .destructive) { showDeleteAlert = true } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "1C1C1E"))
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        let med = currentMed
        return ZStack(alignment: .leading) {
            Image.androidImage("medication details screen banner")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .clipped()

            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 64, height: 64)
                    Image.androidIcon("medicine icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(med.name)
                        .font(.poppins(.bold, size: 16))
                        .foregroundColor(Color(hex: "1C1C1E"))

                    HStack(spacing: 5) {
                        Circle()
                            .fill(med.status.color)
                            .frame(width: 7, height: 7)
                        Text(med.status.displayName)
                            .font(.poppins(.medium, size: 13))
                            .foregroundColor(med.status.color)
                    }

                    Text("\(med.dosage) · \(med.type.displayName)")
                        .font(.poppins(.regular, size: 13))
                        .foregroundColor(Color(hex: "3C3C43").opacity(0.6))

                    if let notes = med.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.poppins(.regular, size: 12))
                            .foregroundColor(Color(hex: "3C3C43").opacity(0.5))
                            .lineLimit(2)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }

    // MARK: - Overview Row

    private var overviewRow: some View {
        let med = currentMed
        let firstTime = med.scheduledTimes.first.map { timeFmt.string(from: $0) } ?? ""
        let schedLabel = med.scheduledTimes.count <= 1 ? "Every day" : "\(med.scheduledTimes.count)× daily"
        let durationLabel = med.isOngoing ? "Ongoing" : (med.endDate.map { formatDate($0) } ?? "—")
        let durationSub = med.isOngoing ? "(No end date)" : ""

        return HStack(spacing: 0) {
            OverviewCell(icon: "calendar", tint: aiTeal, label: "Schedule", value: schedLabel, sub: firstTime)
            overviewDivider
            OverviewCell(icon: "pills.fill", tint: Color(hex: "FF9500"), label: "Dosage", value: med.dosage.isEmpty ? "—" : med.dosage, sub: med.type.displayName)
            overviewDivider
            OverviewCell(icon: "clock.fill", tint: aiTeal, label: "Duration", value: durationLabel, sub: durationSub)
            overviewDivider
            OverviewCell(icon: "bell.fill", tint: Color(hex: "5856D6"), label: "Reminder", value: "On", sub: "")
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "E5E5EA"), lineWidth: 1))
    }

    private var overviewDivider: some View {
        Rectangle()
            .fill(Color(hex: "E5E5EA"))
            .frame(width: 1, height: 72)
    }

    // MARK: - Today's Dose

    private var todayDoseSection: some View {
        let doses = viewModel.getAdherence(for: currentMed.id, date: Date())
        return VStack(alignment: .leading, spacing: 12) {
            Text("Today's Dose")
                .font(.poppins(.semiBold, size: 17))
                .foregroundColor(Color(hex: "1C1C1E"))
                .padding(.horizontal, 16)

            if doses.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "pills")
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: "CCCCCC"))
                    Text("No doses scheduled today")
                        .font(.poppins(.regular, size: 14))
                        .foregroundColor(Color(hex: "888888"))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "F2F2F7"))
                .cornerRadius(14)
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(doses) { dose in
                        DetailDoseCard(
                            med: currentMed,
                            dose: dose,
                            onTaken: {
                                Task { try? await viewModel.markAsTaken(
                                    medicationId: currentMed.id,
                                    scheduledTime: dose.scheduledTime) }
                            },
                            onSkip: { skipDialogDose = dose }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        let med = currentMed
        let today = Date()
        let cal = Calendar.current
        let todayIdx = cal.component(.weekday, from: today) - 1 // 0=Sun
        let dayLetters = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        let doses = viewModel.getAdherence(for: med.id, date: today)
        let anyTakenToday = doses.contains { $0.status == .taken || $0.status == .late }

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Schedule")
                    .font(.poppins(.semiBold, size: 17))
                    .foregroundColor(Color(hex: "1C1C1E"))
                Spacer()
                Button("View calendar") { showCalendarSheet = true }
                    .font(.poppins(.regular, size: 14))
                    .foregroundColor(aiTeal)
            }
            .padding(.horizontal, 16)

            // 7-day strip
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { idx in
                    let isToday = idx == todayIdx
                    let isTakenDay = isToday && anyTakenToday
                    VStack(spacing: 5) {
                        Text(dayLetters[idx])
                            .font(.system(size: 11, weight: isToday ? .semibold : .regular))
                            .foregroundColor(isToday ? aiTeal : Color(hex: "8E8E93"))
                        ZStack {
                            Circle()
                                .fill(isTakenDay ? aiTeal : (isToday ? aiTeal.opacity(0.12) : Color(hex: "F2F2F7")))
                                .frame(width: 32, height: 32)
                            if isToday && !isTakenDay {
                                Circle()
                                    .stroke(aiTeal, lineWidth: 1.5)
                                    .frame(width: 32, height: 32)
                            }
                            if isTakenDay {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)

            Divider().padding(.horizontal, 16)

            // Per-time rows
            VStack(spacing: 0) {
                ForEach(Array(med.scheduledTimes.enumerated()), id: \.offset) { _, time in
                    scheduleTimeRow(time: time, med: med, doses: doses, cal: cal)
                }
            }
        }
    }

    @ViewBuilder
    private func scheduleTimeRow(time: Date, med: Medication, doses: [MedicationAdherence], cal: Calendar) -> some View {
        let doseForTime = doses.first {
            cal.component(.hour, from: $0.scheduledTime) == cal.component(.hour, from: time)
        }
        let status = doseForTime?.status ?? .pending
        let badge = scheduleBadge(for: status)

        HStack(spacing: 12) {
            ZStack {
                Circle().fill(aiTeal.opacity(0.1)).frame(width: 36, height: 36)
                Image(systemName: "clock.fill").font(.system(size: 14)).foregroundColor(aiTeal)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(timeFmt.string(from: time))
                    .font(.poppins(.semiBold, size: 15)).foregroundColor(Color(hex: "1C1C1E"))
                Text("\(med.type.displayName) · \(med.dosage)")
                    .font(.poppins(.regular, size: 12)).foregroundColor(Color(hex: "8E8E93"))
            }
            Spacer()
            Text(badge.0)
                .font(.poppins(.semiBold, size: 12))
                .foregroundColor(badge.1)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(badge.1.opacity(0.12))
                .cornerRadius(20)
        }
        .padding(.vertical, 5).padding(.horizontal, 16)
    }

    private func scheduleBadge(for status: AdherenceStatus) -> (String, Color) {
        switch status {
        case .taken, .early: return ("✓ Taken", Color(hex: "34C759"))
        case .late:          return ("Late",    Color(hex: "FF9500"))
        case .missed:        return ("Missed",  Color(hex: "FF3B30"))
        case .skipped:       return ("Skipped", Color(hex: "FF9500"))
        case .pending:       return ("Pending", Color(hex: "8E8E93"))
        }
    }

    // MARK: - About Section

    private func aboutSection(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About this medication")
                .font(.poppins(.semiBold, size: 17))
                .foregroundColor(Color(hex: "1C1C1E"))
                .padding(.horizontal, 16)

            HStack {
                Text("\(currentMed.name) \(notes)")
                    .font(.poppins(.regular, size: 14))
                    .foregroundColor(Color(hex: "3C3C43"))
                    .lineSpacing(4)
                    .lineLimit(4)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "CCCCCC"))
            }
            .padding(16)
            .background(Color(hex: "F2F2F7"))
            .cornerRadius(14)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Edit Sheet

    private var editSheet: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name").font(.poppins(.medium, size: 13)).foregroundColor(.secondary)
                    TextField("Medication name", text: $editName)
                        .textFieldStyle(PremiumTextFieldStyle())
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dosage").font(.poppins(.medium, size: 13)).foregroundColor(.secondary)
                    TextField("Dosage", text: $editDosage)
                        .textFieldStyle(PremiumTextFieldStyle())
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes").font(.poppins(.medium, size: 13)).foregroundColor(.secondary)
                    TextEditor(text: $editNotes)
                        .frame(height: 90)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .background(Color(.tertiarySystemFill))
                        .cornerRadius(12)
                }
                Toggle("Ongoing medication", isOn: $editIsOngoing).tint(aiTeal)
                Spacer()
            }
            .padding(16)
            .navigationTitle("Edit Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showEditSheet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        var updated = currentMed
                        updated.name = editName
                        updated.dosage = editDosage
                        updated.notes = editNotes.isEmpty ? nil : editNotes
                        updated.isOngoing = editIsOngoing
                        Task { try? await viewModel.updateMedication(updated) }
                        showEditSheet = false
                    }
                    .foregroundColor(aiTeal).font(.poppins(.semiBold, size: 17))
                }
            }
        }
    }

    // MARK: - Calendar Sheet

    private var calendarSheet: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(currentMed.scheduledTimes.enumerated()), id: \.offset) { _, time in
                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 16))
                                .foregroundColor(aiTeal)
                            Text(timeFmt.string(from: time))
                                .font(.poppins(.semiBold, size: 15))
                                .foregroundColor(Color(hex: "1C1C1E"))
                            Spacer()
                            Text("Every day")
                                .font(.poppins(.regular, size: 13))
                                .foregroundColor(Color(hex: "8E8E93"))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(aiTeal.opacity(0.08))
                        .cornerRadius(10)
                    }
                    if let start = Optional(currentMed.startDate) {
                        Text("Started: \(formatDate(start))")
                            .font(.poppins(.regular, size: 13))
                            .foregroundColor(Color(hex: "8E8E93"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                    if !currentMed.isOngoing, let end = currentMed.endDate {
                        Text("Ends: \(formatDate(end))")
                            .font(.poppins(.regular, size: 13))
                            .foregroundColor(Color(hex: "8E8E93"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Medication Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showCalendarSheet = false }
                        .foregroundColor(aiTeal).font(.poppins(.semiBold, size: 17))
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: date)
    }
}

// MARK: - Overview Cell

private struct OverviewCell: View {
    let icon: String
    let tint: Color
    let label: String
    let value: String
    let sub: String

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(tint)
            Spacer(minLength: 2)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "8E8E93"))
            Text(value)
                .font(.poppins(.semiBold, size: 13))
                .foregroundColor(Color(hex: "1C1C1E"))
                .multilineTextAlignment(.center)
            if !sub.isEmpty {
                Text(sub)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "8E8E93"))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Detail Dose Card

private struct DetailDoseCard: View {
    let med: Medication
    let dose: MedicationAdherence
    let onTaken: () -> Void
    let onSkip: () -> Void

    private let aiTeal = AppColors.accentBlue
    private let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; return f
    }()

    private var isTaken: Bool { dose.status == .taken || dose.status == .late || dose.status == .early }
    private var isMissed: Bool { dose.status == .missed }
    private var isSkipped: Bool { dose.status == .skipped }
    private var isPending: Bool { dose.status == .pending }

    private var bgColor: Color {
        if isTaken  { return Color(hex: "EAFBF4") }
        if isMissed { return Color(hex: "FFF0EF") }
        if isSkipped { return Color(hex: "FFF8EE") }
        return Color(hex: "F2F2F7")
    }
    private var iconColor: Color {
        if isTaken   { return Color(hex: "34C759") }
        if isMissed  { return Color(hex: "FF3B30") }
        if isSkipped { return Color(hex: "FF9500") }
        return Color(hex: "AAAAAA")
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isTaken ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 28))
                .foregroundColor(iconColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(titleText)
                    .font(.poppins(.semiBold, size: 15))
                    .foregroundColor(Color(hex: "1C1C1E"))
                Text(subtitleText)
                    .font(.poppins(.regular, size: 13))
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            Spacer()

            if isPending {
                HStack(spacing: 4) {
                    Button(action: onTaken) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(aiTeal)
                    }
                    .buttonStyle(.plain)
                    Button(action: onSkip) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "FF9500"))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "CCCCCC"))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .background(bgColor)
        .cornerRadius(14)
    }

    private var titleText: String {
        let t = timeFmt.string(from: dose.scheduledTime)
        if isTaken  { return "Taken at \(dose.takenAt.map { timeFmt.string(from: $0) } ?? t)" }
        if isMissed { return "Missed · \(t)" }
        if isSkipped { return "Skipped · \(t)" }
        return "Scheduled at \(t)"
    }
    private var subtitleText: String {
        if isTaken  { return "Good job! You've taken your medication." }
        if isMissed { return "You missed this dose." }
        if isSkipped { return dose.notes.map { "Skipped: \($0)" } ?? "You skipped this dose." }
        return "\(med.dosage) · \(med.type.displayName)"
    }
}

#Preview {
    let med = Medication(name: "Aspirin", dosage: "500mg", type: .pill, scheduleTemplate: .twiceDaily,
                         scheduledTimes: [], startDate: Date(), isOngoing: true)
    MedicationDetailView(medication: med, viewModel: MedicationViewModel())
}
