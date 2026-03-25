//
//  MedicationDetailView.swift
//  swastricare-mobile-swift
//
//  View for viewing and editing medication details
//

import SwiftUI

struct MedicationDetailView: View {
    @Environment(\.dismiss) var dismiss
    let medication: Medication
    @StateObject private var viewModel: MedicationViewModel

    @State private var name: String
    @State private var dosage: String
    @State private var selectedType: MedicationType
    @State private var selectedSchedule: MedicationSchedule
    @State private var scheduledTimes: [Date]
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isOngoing: Bool
    @State private var notes: String

    @State private var isEditing = false
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var typeColor: Color {
        switch medication.type {
        case .pill:      return AppColors.medication
        case .liquid:    return .cyan
        case .injection: return .red
        case .inhaler:   return .teal
        case .drops:     return .blue
        case .cream:     return .pink
        case .other:     return .gray
        }
    }

    init(medication: Medication, viewModel: MedicationViewModel) {
        self.medication = medication
        _viewModel = StateObject(wrappedValue: viewModel)
        _name = State(initialValue: medication.name)
        _dosage = State(initialValue: medication.dosage)
        _selectedType = State(initialValue: medication.type)
        _selectedSchedule = State(initialValue: medication.scheduleTemplate)
        _scheduledTimes = State(initialValue: medication.scheduledTimes)
        _startDate = State(initialValue: medication.startDate)
        _endDate = State(initialValue: medication.endDate ?? Date())
        _isOngoing = State(initialValue: medication.isOngoing)
        _notes = State(initialValue: medication.notes ?? "")
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        heroHeader
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        todaysDosesSection
                            .padding(.horizontal, 16)

                        weeklyAdherenceSection
                            .padding(.horizontal, 16)

                        if isEditing {
                            editFormSection
                                .padding(.horizontal, 16)
                        } else {
                            detailsSection
                                .padding(.horizontal, 16)
                        }

                        if isEditing {
                            deleteButton
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(isEditing ? "Edit Medication" : "Medication Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isEditing ? "Cancel" : "Close") {
                        if isEditing {
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                cancelEditing()
                            }
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(.primary)
                    .font(.body)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if isEditing {
                        Button("Save") {
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                saveChanges()
                            }
                        }
                        .disabled(isLoading || !hasChanges)
                        .foregroundColor(hasChanges ? AppColors.medication : .secondary)
                        .font(.body)
                    } else {
                        Button("Edit") {
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                isEditing = true
                            }
                        }
                        .foregroundColor(AppColors.medication)
                        .font(.body)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Delete Medication", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteMedication()
                }
            } message: {
                Text("Are you sure you want to delete \(medication.name)? This will also cancel all scheduled reminders.")
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        HStack(spacing: 16) {
            // Large type icon with colored background
            ZStack {
                Circle()
                    .fill(typeColor.opacity(0.12))
                    .frame(width: 72, height: 72)

                Image(systemName: medication.type.icon)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(typeColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(medication.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(medication.dosage)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Label(medication.scheduleTemplate.displayName, systemImage: "clock.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    if medication.isOngoing {
                        Label("Ongoing", systemImage: "infinity")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Today's Doses

    private var todaysDosesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Doses")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 4)

            let adherence = viewModel.getAdherence(for: medication.id, date: Date())

            if adherence.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("No doses scheduled for today")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 28)
                    Spacer()
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(14)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(adherence.enumerated()), id: \.element.id) { index, dose in
                        DoseActionRow(
                            dose: dose,
                            onMarkTaken: {
                                Task {
                                    try? await viewModel.markAsTaken(medicationId: medication.id, scheduledTime: dose.scheduledTime)
                                }
                            },
                            onMarkSkipped: {
                                Task {
                                    try? await viewModel.markAsSkipped(medicationId: medication.id, scheduledTime: dose.scheduledTime, notes: "Skipped manually")
                                }
                            }
                        )

                        if index < adherence.count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(14)
            }
        }
    }

    // MARK: - Weekly Adherence

    private var weeklyAdherenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 4)

            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { dayOffset in
                    let date = weekDate(offset: dayOffset)
                    let isToday = Calendar.current.isDateInToday(date)
                    let isFuture = Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
                    let dayAdherence = viewModel.getAdherence(for: medication.id, date: date)
                    let taken = dayAdherence.filter { $0.status == .taken || $0.status == .late || $0.status == .early }.count
                    let total = dayAdherence.count

                    VStack(spacing: 6) {
                        Text(date.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isToday ? AppColors.medication : .secondary)

                        ZStack {
                            Circle()
                                .fill(adherenceDotColor(taken: taken, total: total, isFuture: isFuture))
                                .frame(width: 28, height: 28)

                            if !isFuture && total > 0 {
                                if taken == total {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Text("\(taken)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }

                        if !isFuture && total > 0 {
                            Text("\(taken)/\(total)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                        } else {
                            Text(" ")
                                .font(.system(size: 9))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(14)
        }
    }

    private func weekDate(offset: Int) -> Date {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        return cal.date(byAdding: .day, value: offset - daysFromMonday, to: today) ?? today
    }

    private func adherenceDotColor(taken: Int, total: Int, isFuture: Bool) -> Color {
        if isFuture || total == 0 { return Color(.systemGray5) }
        if taken == total { return AppColors.accentGreen }
        if taken > 0 { return .orange }
        return Color(.systemGray4)
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                MedicationInfoRow(icon: medication.type.icon, label: "Type", value: medication.type.displayName, color: typeColor)
                Divider().padding(.leading, 48)
                MedicationInfoRow(icon: "calendar", label: "Schedule", value: medication.scheduleTemplate.displayName, color: AppColors.medication)
                Divider().padding(.leading, 48)

                if medication.isOngoing {
                    MedicationInfoRow(icon: "infinity", label: "Duration", value: "Ongoing", color: .secondary)
                } else if let endDate = medication.endDate {
                    MedicationInfoRow(icon: "calendar.badge.clock", label: "End Date", value: formatDate(endDate), color: .secondary)
                }

                if let notes = medication.notes, !notes.isEmpty {
                    Divider().padding(.leading, 48)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "note.text")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            Text("Notes")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Text(notes)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(14)
        }
    }

    // MARK: - Edit Form

    private var editFormSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Details")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 4)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("Medication name", text: $name)
                        .textFieldStyle(PremiumTextFieldStyle())
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Dosage")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("Dosage", text: $dosage)
                        .textFieldStyle(PremiumTextFieldStyle())
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    TextEditor(text: $notes)
                        .frame(height: 100)
                        .scrollContentBackground(.hidden)
                        .padding(14)
                        .background(Color(UIColor.tertiarySystemFill))
                        .cornerRadius(12)
                }

                Toggle(isOn: $isOngoing) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Ongoing medication")
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                        Text("No end date")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(AppColors.medication)
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(14)
        }
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 15))
                Text("Delete Medication")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red.opacity(0.08))
            .cornerRadius(14)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Actions

    private var hasChanges: Bool {
        name != medication.name ||
        dosage != medication.dosage ||
        notes != (medication.notes ?? "") ||
        isOngoing != medication.isOngoing
    }

    private func cancelEditing() {
        name = medication.name
        dosage = medication.dosage
        notes = medication.notes ?? ""
        isOngoing = medication.isOngoing
        isEditing = false
    }

    private func saveChanges() {
        isLoading = true
        var updatedMedication = medication
        updatedMedication.name = name
        updatedMedication.dosage = dosage
        updatedMedication.notes = notes.isEmpty ? nil : notes
        updatedMedication.isOngoing = isOngoing
        updatedMedication.endDate = isOngoing ? nil : endDate

        Task {
            do {
                try await viewModel.updateMedication(updatedMedication)
                await MainActor.run {
                    isLoading = false
                    isEditing = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func deleteMedication() {
        isLoading = true
        Task {
            do {
                try await viewModel.deleteMedication(id: medication.id)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Dose Action Row

struct DoseActionRow: View {
    let dose: MedicationAdherence
    let onMarkTaken: () -> Void
    let onMarkSkipped: () -> Void

    @State private var justTaken = false

    private var statusColor: Color {
        switch dose.status {
        case .taken, .early: return AppColors.accentGreen
        case .late:          return .orange
        case .missed:        return .red
        case .skipped:       return .secondary
        case .pending:       return dose.isOverdue() ? .red : .secondary
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Time circle
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 44, height: 44)

                if justTaken || dose.status == .taken || dose.status == .late || dose.status == .early {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.accentGreen)
                } else {
                    Text(formatTime(dose.scheduledTime))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(statusColor)
                }
            }

            // Status info
            VStack(alignment: .leading, spacing: 3) {
                Text(formatTime(dose.scheduledTime))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Image(systemName: dose.status.icon)
                        .font(.system(size: 11))
                    Text(statusText)
                        .font(.system(size: 13))
                }
                .foregroundColor(statusColor)
            }

            Spacer()

            // Action buttons
            if dose.status == .pending && !justTaken {
                HStack(spacing: 10) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            justTaken = true
                        }
                        onMarkTaken()
                    } label: {
                        Text("Take")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(dose.isOverdue() ? Color.red : AppColors.accentGreen)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onMarkSkipped()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color(UIColor.tertiarySystemFill))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            } else if let takenAt = dose.takenAt {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text("at \(formatTime(takenAt))")
                        .font(.system(size: 13))
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var statusText: String {
        if dose.status == .pending && dose.isOverdue() {
            return "Overdue"
        }
        return dose.status.displayName
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Info Row

struct MedicationInfoRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Medication Stat Card (kept for compatibility)

struct MedicationStatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let medication = Medication(
        name: "Aspirin",
        dosage: "500mg",
        type: .pill,
        scheduleTemplate: .twiceDaily,
        scheduledTimes: [Date(), Date()],
        startDate: Date(),
        isOngoing: true
    )

    MedicationDetailView(medication: medication, viewModel: MedicationViewModel())
}
