//
//  MedicationsView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI

// MARK: - Time Period Grouping

private enum TimePeriod: String, CaseIterable, Identifiable {
    case morning, afternoon, evening, night

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morning:   return "Morning"
        case .afternoon: return "Afternoon"
        case .evening:   return "Evening"
        case .night:     return "Night"
        }
    }

    var icon: String {
        switch self {
        case .morning:   return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening:   return "sunset.fill"
        case .night:     return "moon.fill"
        }
    }

    var color: Color {
        switch self {
        case .morning:   return .orange
        case .afternoon: return Color(hex: "F59E0B")
        case .evening:   return Color(hex: "F97316")
        case .night:     return .indigo
        }
    }

    var timeRange: String {
        switch self {
        case .morning:   return "6 AM – 12 PM"
        case .afternoon: return "12 – 5 PM"
        case .evening:   return "5 – 9 PM"
        case .night:     return "9 PM – 6 AM"
        }
    }

    static func from(hour: Int) -> TimePeriod {
        switch hour {
        case 6..<12:  return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default:      return .night
        }
    }
}

// MARK: - MedicationsView

struct MedicationsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: MedicationViewModel

    @State private var selectedDate = Date()
    @State private var showAddMedication = false
    @State private var selectedMedication: MedicationWithAdherence?

    // Group today's medications by time-of-day period
    private var groupedMedications: [(period: TimePeriod, items: [(medication: MedicationWithAdherence, dose: MedicationAdherence)])] {
        var groups: [TimePeriod: [(medication: MedicationWithAdherence, dose: MedicationAdherence)]] = [:]

        for med in viewModel.todaysMedications {
            for dose in med.todayDoses {
                let hour = Calendar.current.component(.hour, from: dose.scheduledTime)
                let period = TimePeriod.from(hour: hour)
                groups[period, default: []].append((medication: med, dose: dose))
            }
        }

        return TimePeriod.allCases.compactMap { period in
            guard let items = groups[period], !items.isEmpty else { return nil }
            return (period: period, items: items.sorted { $0.dose.scheduledTime < $1.dose.scheduledTime })
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    skeletonView
                } else if viewModel.todaysMedications.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            calendarStrip
                                .padding(.top, 4)

                            progressCard
                                .padding(.horizontal, 16)

                            ForEach(groupedMedications, id: \.period) { group in
                                medicationGroup(group.period, items: group.items)
                                    .padding(.horizontal, 16)
                            }

                            askAIButton
                                .padding(.horizontal, 16)
                                .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationTitle("Medications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddMedication = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.poppins(.regular, size: 24))
                            .foregroundColor(AppColors.medication)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.primary)
                        .font(.poppins(.regular, size: 17))
                }
            }
            .sheet(isPresented: $showAddMedication) {
                AddMedicationView(viewModel: viewModel)
            }
            .sheet(item: $selectedMedication) { med in
                MedicationDetailView(medication: med.medication, viewModel: viewModel)
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            await viewModel.loadMedications()
        }
        .trackScreen("Medications")
    }

    // MARK: - Calendar Strip

    private var calendarStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(-3..<4, id: \.self) { offset in
                        let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
                        let isToday = Calendar.current.isDateInToday(date)
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedDate = date
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                                    .font(.poppins(.semiBold, size: 11))
                                    .foregroundColor(isSelected ? .white : .secondary)

                                Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.poppins(.bold, size: 17))
                                    .foregroundColor(isSelected ? .white : .primary)
                            }
                            .frame(width: 46, height: 64)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(isSelected ? AppColors.medication : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(AppColors.medication.opacity(0.35), lineWidth: isToday && !isSelected ? 1.5 : 0)
                            )
                        }
                        .buttonStyle(.plain)
                        .id(offset)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear { proxy.scrollTo(0, anchor: .center) }
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                AdherenceRingView(
                    progress: viewModel.todayAdherencePercentage / 100,
                    size: 80,
                    lineWidth: 8
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Today's Progress")
                        .font(.poppins(.medium, size: 13))
                        .foregroundColor(.secondary)

                    Text("\(viewModel.takenCount) of \(viewModel.totalCount) taken")
                        .font(.poppins(.bold, size: 20))
                        .foregroundColor(.primary)

                    if viewModel.totalCount - viewModel.takenCount > 0 {
                        Text("\(viewModel.totalCount - viewModel.takenCount) remaining")
                            .font(.poppins(.regular, size: 14))
                            .foregroundColor(.secondary)
                    } else if viewModel.totalCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.poppins(.regular, size: 13))
                            Text("All done!")
                                .font(.poppins(.semiBold, size: 14))
                        }
                        .foregroundColor(AppColors.accentGreen)
                    }
                }

                Spacer()
            }

            HStack(spacing: 10) {
                statPill(icon: "checkmark.circle.fill", color: AppColors.accentGreen, value: "\(viewModel.takenCount)", label: "Taken")
                statPill(icon: "clock.fill", color: .orange, value: "\(viewModel.totalCount - viewModel.takenCount)", label: "Left")
                statPill(icon: "chart.line.uptrend.xyaxis", color: AppColors.medication, value: viewModel.adherenceStatistics?.adherenceRate ?? "0%", label: "Adherence")
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private func statPill(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.poppins(.medium, size: 13))
                .foregroundColor(color)
            Text(value)
                .font(.poppins(.bold, size: 16))
                .foregroundColor(.primary)
            Text(label)
                .font(.poppins(.regular, size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }

    // MARK: - Medication Group

    private func medicationGroup(_ period: TimePeriod, items: [(medication: MedicationWithAdherence, dose: MedicationAdherence)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: period.icon)
                    .font(.poppins(.semiBold, size: 14))
                    .foregroundColor(period.color)

                Text(period.label)
                    .font(.poppins(.semiBold, size: 15))
                    .foregroundColor(.primary)

                Text("·")
                    .foregroundColor(.secondary)

                Text(period.timeRange)
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 4)

            // Grouped cards
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.dose.id) { index, item in
                    MedicationItemCard(
                        medication: item.medication,
                        dose: item.dose,
                        onTake: {
                            Task {
                                try? await viewModel.quickMarkAsTaken(medicationWithAdherence: item.medication)
                            }
                        },
                        onTap: {
                            selectedMedication = item.medication
                        }
                    )

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(14)
        }
    }

    // MARK: - Ask AI Button

    private var askAIButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToAITab"), object: nil)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.poppins(.semiBold, size: 14))
                Text("Ask AI about my medications")
                    .font(.poppins(.semiBold, size: 14))
            }
            .foregroundColor(AppColors.accentBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.medication.opacity(0.08))
                    .frame(width: 120, height: 120)

                Image(systemName: "pills.circle.fill")
                    .font(.poppins(.regular, size: 56))
                    .foregroundColor(AppColors.medication.opacity(0.5))
            }

            VStack(spacing: 8) {
                Text("No Medications Yet")
                    .font(.poppins(.bold, size: 24))
                    .foregroundColor(.primary)

                Text("Track your medications and never\nmiss a dose again")
                    .font(.poppins(.regular, size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showAddMedication = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.poppins(.semiBold, size: 15))
                    Text("Add Medication")
                        .font(.poppins(.semiBold, size: 16))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(AppColors.medication)
                .cornerRadius(14)
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()
        }
    }

    // MARK: - Skeleton Loading

    private var skeletonView: some View {
        VStack(spacing: 16) {
            // Calendar skeleton
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { _ in
                    SkeletonShape(width: 46, height: 64, cornerRadius: 14)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Progress card skeleton
            HStack(spacing: 20) {
                SkeletonCircle(size: 80)
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonShape(width: 100, height: 12, cornerRadius: 4)
                    SkeletonShape(width: 150, height: 20, cornerRadius: 6)
                    SkeletonShape(width: 90, height: 12, cornerRadius: 4)
                }
                Spacer()
            }
            .padding(20)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .padding(.horizontal, 16)

            // Group skeletons
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    SkeletonShape(width: 160, height: 14, cornerRadius: 4)
                        .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        ForEach(0..<2, id: \.self) { i in
                            HStack(spacing: 14) {
                                SkeletonCircle(size: 44)
                                VStack(alignment: .leading, spacing: 6) {
                                    SkeletonShape(width: 120, height: 14, cornerRadius: 4)
                                    SkeletonShape(width: 80, height: 11, cornerRadius: 4)
                                }
                                Spacer()
                                SkeletonShape(width: 56, height: 28, cornerRadius: 14)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)

                            if i == 0 { Divider().padding(.leading, 72) }
                        }
                    }
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(14)
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Medication Item Card

struct MedicationItemCard: View {
    let medication: MedicationWithAdherence
    let dose: MedicationAdherence
    let onTake: () -> Void
    let onTap: () -> Void

    @State private var justTaken = false

    private var isTaken: Bool {
        dose.status == .taken || dose.status == .late || dose.status == .early
    }

    private var typeColor: Color {
        switch medication.medication.type {
        case .pill:      return AppColors.medication
        case .liquid:    return .cyan
        case .injection: return .red
        case .inhaler:   return .teal
        case .drops:     return .blue
        case .cream:     return .pink
        case .other:     return .gray
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Type icon
                Image(systemName: medication.medication.type.icon)
                    .font(.poppins(.medium, size: 18))
                    .foregroundColor(typeColor)
                    .frame(width: 44, height: 44)
                    .background(typeColor.opacity(0.1))
                    .clipShape(Circle())

                // Name + dosage + time
                VStack(alignment: .leading, spacing: 3) {
                    Text(medication.medication.name)
                        .font(.poppins(.semiBold, size: 15))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(medication.medication.dosage)
                            .font(.poppins(.regular, size: 13))
                            .foregroundColor(.secondary)

                        Text("·")
                            .foregroundColor(.secondary)

                        Text(formatTime(dose.scheduledTime))
                            .font(.poppins(.regular, size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Status / action
                statusView
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if dose.status == .pending {
                Button { handleTake() } label: {
                    Label("Mark as Taken", systemImage: "checkmark.circle")
                }
                Button { onTap() } label: {
                    Label("View Details", systemImage: "info.circle")
                }
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        if justTaken {
            Image(systemName: "checkmark.circle.fill")
                .font(.poppins(.regular, size: 28))
                .foregroundColor(AppColors.accentGreen)
                .transition(.scale.combined(with: .opacity))
        } else if isTaken {
            VStack(spacing: 2) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.poppins(.regular, size: 22))
                    .foregroundColor(AppColors.accentGreen)
                if let takenAt = dose.takenAt {
                    Text(formatTime(takenAt))
                        .font(.poppins(.regular, size: 10))
                        .foregroundColor(.secondary)
                }
            }
        } else if dose.status == .skipped {
            HStack(spacing: 3) {
                Image(systemName: "forward.fill")
                    .font(.poppins(.regular, size: 10))
                Text("Skipped")
                    .font(.poppins(.medium, size: 12))
            }
            .foregroundColor(.secondary)
        } else if dose.status == .missed {
            HStack(spacing: 3) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.poppins(.regular, size: 10))
                Text("Missed")
                    .font(.poppins(.medium, size: 12))
            }
            .foregroundColor(.red)
        } else if dose.isOverdue() {
            Button(action: handleTake) {
                Text("Overdue")
                    .font(.poppins(.bold, size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.red)
                    .cornerRadius(20)
            }
            .buttonStyle(.plain)
        } else if dose.scheduledTime <= Date() {
            Button(action: handleTake) {
                Text("Take")
                    .font(.poppins(.bold, size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(AppColors.accentGreen)
                    .cornerRadius(20)
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 3) {
                Image(systemName: "clock")
                    .font(.poppins(.regular, size: 11))
                Text(formatTime(dose.scheduledTime))
                    .font(.poppins(.medium, size: 13))
            }
            .foregroundColor(.secondary)
        }
    }

    private func handleTake() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            justTaken = true
        }
        onTake()
    }

    private func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return fmt.string(from: date)
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
        if animatedProgress >= 0.5 { return AppColors.medication }
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
                        .font(.poppins(.bold, size: size * 0.28))
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
