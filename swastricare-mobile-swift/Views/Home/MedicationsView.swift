//
//  MedicationsView.swift
//  swastricare-mobile-swift
//

import SwiftUI
import UserNotifications

// MARK: - MedicationsView

struct MedicationsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: MedicationViewModel

    @State private var showAddMedication = false
    @State private var showAllMedications = false
    @State private var showNotificationSettings = false
    @State private var selectedMedication: MedicationWithAdherence?
    @State private var skipDialogDose: MedicationAdherence?
    @State private var skipReason = ""

    private let aiTeal = AppColors.accentBlue

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            if viewModel.isLoading && viewModel.todaysMedications.isEmpty {
                skeletonView
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroSection
                        statsRow
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        todayScheduleSection
                        Divider()
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        adherenceAndMedsSection
                            .padding(.horizontal, 20)
                        Spacer(minLength: 16)
                        remindersCard
                            .padding(.horizontal, 16)
                        Spacer(minLength: 32)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddMedication) {
            AddMedicationView(viewModel: viewModel)
        }
        .sheet(isPresented: $showAllMedications) {
            AllMedicationsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showNotificationSettings) {
            NotificationSettingsView(viewModel: DependencyContainer.shared.hydrationViewModel)
        }
        .sheet(item: $selectedMedication) { med in
            MedicationDetailView(medication: med.medication, viewModel: viewModel)
        }
        .alert("Skip Dose", isPresented: Binding(
            get: { skipDialogDose != nil },
            set: { if !$0 { skipDialogDose = nil; skipReason = "" } }
        )) {
            TextField("Reason (optional)", text: $skipReason)
            Button("Skip", role: .destructive) {
                if let dose = skipDialogDose {
                    Task { try? await viewModel.markAsSkipped(medicationId: dose.medicationId, scheduledTime: dose.scheduledTime, notes: skipReason.isEmpty ? nil : skipReason) }
                }
                skipDialogDose = nil; skipReason = ""
            }
            Button("Cancel", role: .cancel) { skipDialogDose = nil; skipReason = "" }
        } message: {
            if let dose = skipDialogDose {
                Text("Skip \(formatTime(dose.scheduledTime)) dose?")
            }
        }
        .task { await viewModel.loadMedications() }
        .trackScreen("Medications")
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .top) {
            Image.androidImage("medication illustration")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .top, endPoint: .center
                    )
                )
                .overlay(
                    LinearGradient(
                        colors: [.clear, .white],
                        startPoint: .center, endPoint: .bottom
                    )
                )

            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "1A1A2E"))
                            .frame(width: 40, height: 40)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Medication")
                            .font(.poppins(.bold, size: 22))
                            .foregroundColor(Color(hex: "1A1A2E"))
                        Text("Stay on track, stay healthy 🌿")
                            .font(.poppins(.regular, size: 13))
                            .foregroundColor(Color(hex: "666666"))
                    }
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        let stats = viewModel.adherenceStatistics
        let pending = (stats?.totalDoses ?? 0) - (stats?.takenDoses ?? 0)
        return HStack(spacing: 8) {
            MedStatCell(value: "\(max(0, pending))", label: "To Take\nToday",  color: Color(hex: "FF9500"))
            MedStatCell(value: "\(stats?.takenDoses ?? 0)",   label: "Taken\nToday",   color: aiTeal)
            MedStatCell(value: "\(stats?.missedDoses ?? 0)",  label: "Missed\nToday",  color: Color(hex: "FF3B30"))
            MedStatCell(value: "\(viewModel.activeMedicationsCount)", label: "Active\nMeds", color: Color(hex: "5856D6"))
        }
    }

    // MARK: - Today's Schedule

    private var todayScheduleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Today's Schedule")
                    .font(.poppins(.bold, size: 16))
                    .foregroundColor(Color(hex: "1A1A2E"))
                Spacer()
                Button { showAllMedications = true } label: {
                    Text("View all")
                        .font(.poppins(.medium, size: 13))
                        .foregroundColor(aiTeal)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)

            if viewModel.todaysMedications.flatMap(\.todayDoses).isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "pills")
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: "CCCCCC"))
                    Text("No doses scheduled today")
                        .font(.poppins(.regular, size: 14))
                        .foregroundColor(Color(hex: "888888"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(sortedDoses, id: \.dose.id) { entry in
                        ScheduleDoseRow(
                            medName: entry.medName,
                            dosage: entry.dosage,
                            dose: entry.dose,
                            onTaken: {
                                Task { try? await viewModel.quickMarkAsTaken(medicationWithAdherence: entry.mwa) }
                            },
                            onSkip: { skipDialogDose = entry.dose },
                            onTap: { selectedMedication = entry.mwa }
                        )
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    private struct DoseEntry {
        let mwa: MedicationWithAdherence
        let medName: String
        let dosage: String
        let dose: MedicationAdherence
    }

    private var sortedDoses: [DoseEntry] {
        viewModel.todaysMedications.flatMap { mwa in
            mwa.todayDoses.map { dose in
                DoseEntry(mwa: mwa, medName: mwa.medication.name, dosage: mwa.medication.dosage, dose: dose)
            }
        }
        .sorted { $0.dose.scheduledTime < $1.dose.scheduledTime }
    }

    // MARK: - Adherence + Meds

    private var adherenceAndMedsSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Adherence")
                        .font(.poppins(.bold, size: 14))
                        .foregroundColor(Color(hex: "1A1A2E"))
                    Spacer()
                    Text("This Week ▾")
                        .font(.poppins(.regular, size: 11))
                        .foregroundColor(Color(hex: "888888"))
                }
                AdherenceRingView(
                    progress: CGFloat(viewModel.todayAdherencePercentage / 100),
                    size: 110,
                    lineWidth: 14
                )
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Medications")
                        .font(.poppins(.bold, size: 14))
                        .foregroundColor(Color(hex: "1A1A2E"))
                    Spacer()
                    Button(action: { showAddMedication = true }) {
                        Text("+ Add")
                            .font(.poppins(.medium, size: 12))
                            .foregroundColor(aiTeal)
                    }
                }
                ForEach(viewModel.medications.prefix(3)) { med in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(med.name)
                            .font(.poppins(.medium, size: 13))
                            .foregroundColor(Color(hex: "1A1A2E"))
                            .lineLimit(1)
                        Text("\(med.scheduleTemplate.displayName) · Every day")
                            .font(.poppins(.regular, size: 11))
                            .foregroundColor(Color(hex: "888888"))
                    }
                }
                if !viewModel.medications.isEmpty {
                    Button(action: { showAllMedications = true }) {
                        Text("View all medications")
                            .font(.poppins(.medium, size: 12))
                            .foregroundColor(aiTeal)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Reminders Card

    private var remindersCard: some View {
        RemindersToggleCardView(onTap: { showNotificationSettings = true })
    }


    // MARK: - Skeleton

    private var skeletonView: some View {
        VStack(spacing: 16) {
            // Hero placeholder
            Rectangle()
                .fill(Color(.systemGray6))
                .frame(height: 120)

            // Stats
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(height: 68)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)

            // Schedule rows
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { _ in
                    HStack(spacing: 12) {
                        SkeletonShape(width: 52, height: 40, cornerRadius: 4)
                        VStack(alignment: .leading, spacing: 6) {
                            SkeletonShape(width: 120, height: 14, cornerRadius: 4)
                            SkeletonShape(width: 80, height: 11, cornerRadius: 4)
                        }
                        Spacer()
                        SkeletonShape(width: 70, height: 30, cornerRadius: 15)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter(); fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}

// MARK: - Stat Cell

private struct MedStatCell: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.poppins(.bold, size: 22))
                .foregroundColor(Color(hex: "1A1A2E"))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "888888"))
                .multilineTextAlignment(.center)
                .lineSpacing(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "E8E8E8"), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// MARK: - Schedule Dose Row

private struct ScheduleDoseRow: View {
    let medName: String
    let dosage: String
    let dose: MedicationAdherence
    let onTaken: () -> Void
    let onSkip: () -> Void
    let onTap: () -> Void

    private let aiTeal = AppColors.accentBlue

    private var isTaken: Bool { dose.status == .taken || dose.status == .late || dose.status == .early }
    private var isFuture: Bool { dose.scheduledTime > Date() }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Time column
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(timeStr)
                            .font(.poppins(.semiBold, size: 14))
                            .foregroundColor(Color(hex: "1A1A2E"))
                        Text(amPm)
                            .font(.poppins(.regular, size: 11))
                            .foregroundColor(Color(hex: "888888"))
                    }
                    .frame(width: 52, alignment: .trailing)

                    Rectangle()
                        .fill(Color(hex: "E0E0E0"))
                        .frame(width: 2, height: 40)
                        .cornerRadius(1)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(medName)
                            .font(.poppins(.semiBold, size: 15))
                            .foregroundColor(Color(hex: "1A1A2E"))
                            .lineLimit(1)
                        if !dosage.isEmpty {
                            Text(dosage)
                                .font(.poppins(.regular, size: 12))
                                .foregroundColor(Color(hex: "888888"))
                        }
                    }
                    Spacer()

                    statusView
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 66)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        if isTaken {
            Text("Taken")
                .font(.poppins(.medium, size: 12))
                .foregroundColor(Color(hex: "888888"))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "CCCCCC"), lineWidth: 1))
        } else if isFuture {
            Text("Upcoming")
                .font(.poppins(.medium, size: 12))
                .foregroundColor(Color(hex: "888888"))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "CCCCCC"), lineWidth: 1))
        } else if dose.status == .missed {
            Text("Missed")
                .font(.poppins(.medium, size: 12))
                .foregroundColor(Color(hex: "FF3B30"))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "FF3B30").opacity(0.4), lineWidth: 1))
        } else if dose.status == .skipped {
            Text("Skipped")
                .font(.poppins(.medium, size: 12))
                .foregroundColor(Color(hex: "888888"))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "CCCCCC"), lineWidth: 1))
        } else {
            // Pending + current/overdue → Take Now + Skip
            HStack(spacing: 4) {
                Button(action: onTaken) {
                    Text("Take Now")
                        .font(.poppins(.bold, size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(aiTeal)
                        .cornerRadius(20)
                }
                .buttonStyle(.plain)
                Button(action: onSkip) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var timeStr: String {
        let cal = Calendar.current
        let h = cal.component(.hour, from: dose.scheduledTime)
        let m = cal.component(.minute, from: dose.scheduledTime)
        let dh = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return String(format: "%d:%02d", dh, m)
    }
    private var amPm: String {
        Calendar.current.component(.hour, from: dose.scheduledTime) < 12 ? "AM" : "PM"
    }
}

// MARK: - Reminders Toggle Card

struct RemindersToggleCardView: View {
    let onTap: () -> Void
    @State private var isEnabled = false
    private let aiTeal = AppColors.accentBlue

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isEnabled ? aiTeal.opacity(0.15) : Color(hex: "EEEEEE"))
                        .frame(width: 40, height: 40)
                    Image(systemName: isEnabled ? "bell.fill" : "bell.slash.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isEnabled ? aiTeal : Color(hex: "AAAAAA"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(isEnabled ? "Reminders enabled" : "Enable reminders")
                        .font(.poppins(.semiBold, size: 14))
                        .foregroundColor(Color(hex: "1A1A2E"))
                    Text(isEnabled ? "You'll be notified at scheduled times" : "Never miss your medication")
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(Color(hex: "888888"))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "AAAAAA"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isEnabled ? Color(hex: "F0FBF8") : Color(hex: "F8F8F8"))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isEnabled ? Color(hex: "CCEEE5") : Color(hex: "E5E5EA"), lineWidth: 1)
            )
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .onAppear { checkPermission() }
    }

    private func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            DispatchQueue.main.async {
                isEnabled = s.authorizationStatus == .authorized || s.authorizationStatus == .provisional
            }
        }
    }
}

// MARK: - Adherence Ring View

struct AdherenceRingView: View {
    let progress: CGFloat
    let size: CGFloat
    let lineWidth: CGFloat

    @State private var animatedProgress: CGFloat = 0

    private var ringColor: Color {
        if animatedProgress >= 1.0 { return AppColors.accentGreen }
        if animatedProgress >= 0.5 { return AppColors.accentBlue }
        return .orange
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                if animatedProgress >= 1.0 {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.28, weight: .bold))
                        .foregroundColor(AppColors.accentGreen)
                } else {
                    Text("\(Int(animatedProgress * 100))")
                        .font(.poppins(.bold, size: size * 0.28))
                        .foregroundColor(.primary)
                    Text("%")
                        .font(.poppins(.medium, size: size * 0.14))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animatedProgress = min(max(progress, 0), 1)
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animatedProgress = min(max(newValue, 0), 1)
            }
        }
    }
}

#Preview {
    MedicationsView(viewModel: MedicationViewModel())
}
