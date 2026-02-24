//
//  MedicationsView.swift
//  swastricare-mobile-swift
//
//  Medications Tracking with Movements+ Design
//

import SwiftUI

struct MedicationsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: MedicationViewModel
    
    @State private var selectedDate = Date()
    @State private var showAddMedication = false
    @State private var selectedMedication: MedicationWithAdherence?
    @State private var hasAppeared = false
    
    // MARK: - Theme Colors
    
    private var medicationPurple: Color { Color(hex: "5856D6") }
    private var medicationTeal: Color { Color(hex: "11998e") }
    private var overdueRed: Color { Color(hex: "FF6B6B") }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.todaysMedications.isEmpty {
                    emptyStateView
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            calendarStrip
                                .padding(.top, 8)
                                .padding(.bottom, 20)
                                .opacity(hasAppeared ? 1 : 0)
                                .offset(y: hasAppeared ? 0 : 20)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: hasAppeared)
                            
                            progressSection
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                                .opacity(hasAppeared ? 1 : 0)
                                .offset(y: hasAppeared ? 0 : 20)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: hasAppeared)
                            
                            statsCardsSection
                                .padding(.bottom, 20)
                                .opacity(hasAppeared ? 1 : 0)
                                .offset(y: hasAppeared ? 0 : 20)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: hasAppeared)
                            
                            medicationListSection
                                .opacity(hasAppeared ? 1 : 0)
                                .offset(y: hasAppeared ? 0 : 20)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: hasAppeared)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .onAppear {
                AppAnalyticsService.shared.logScreen("medications")
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    hasAppeared = true
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Medications")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAddMedication = true }) {
                        ZStack {
                            Circle()
                                .fill(medicationPurple.opacity(0.15))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(medicationPurple)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.08))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddMedication) {
                AddMedicationView(viewModel: viewModel)
            }
            .sheet(item: $selectedMedication) { medWithAdherence in
                MedicationDetailView(
                    medication: medWithAdherence.medication,
                    viewModel: viewModel
                )
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            await viewModel.loadMedications()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(medicationPurple.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                ProgressView()
                    .tint(medicationPurple)
                    .scaleEffect(1.2)
            }
            
            Text("Loading medications...")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(medicationPurple.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "pills.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(medicationPurple.opacity(0.6))
            }
            
            VStack(spacing: 10) {
                Text("No Medications Yet")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Add your first medication to get started\nwith reminders and tracking")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showAddMedication = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    
                    Text("Add Medication")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [medicationPurple, Color(hex: "7B68EE")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Calendar Strip
    
    private var calendarStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<7) { index in
                    let date = Calendar.current.date(byAdding: .day, value: index, to: Date()) ?? Date()
                    let isToday = Calendar.current.isDateInToday(date)
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDate = date
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(isSelected ? .white : .secondary)
                            
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(isSelected ? .white : .primary)
                        }
                        .frame(width: 48, height: 64)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isSelected ? medicationPurple : (isToday ? medicationPurple.opacity(0.1) : Color.clear))
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [medicationPurple, Color(hex: "7B68EE")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            MedicationPatternView()
                .clipShape(RoundedRectangle(cornerRadius: 28))
            
            HStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 10)
                        .frame(width: 110, height: 110)
                    
                    let progress = viewModel.todayAdherencePercentage / 100
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color.white,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 110, height: 110)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                    
                    VStack(spacing: 2) {
                        Text("\(Int(viewModel.todayAdherencePercentage))%")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("done")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Progress")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("\(viewModel.takenCount) of \(viewModel.totalCount) taken")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    if let stats = viewModel.adherenceStatistics {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 12))
                            
                            Text("\(stats.adherenceRate) adherence")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                    
                    if viewModel.hasOverdueDoses {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            
                            Text("Overdue doses")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(Color(hex: "FFD93D"))
                    }
                }
                
                Spacer()
            }
            .padding(24)
        }
        .frame(height: 180)
    }
    
    // MARK: - Stats Cards Section
    
    private var statsCardsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                MedicationMiniStatCard(
                    title: "Taken",
                    value: "\(viewModel.takenCount)",
                    icon: "checkmark.circle.fill",
                    color: medicationTeal,
                    colorScheme: colorScheme
                )
                
                MedicationMiniStatCard(
                    title: "Remaining",
                    value: "\(viewModel.totalCount - viewModel.takenCount)",
                    icon: "clock.fill",
                    color: medicationPurple,
                    colorScheme: colorScheme
                )
                
                MedicationMiniStatCard(
                    title: "Total",
                    value: "\(viewModel.totalCount)",
                    icon: "pills.fill",
                    color: Color(hex: "7B68EE"),
                    colorScheme: colorScheme
                )
                
                if viewModel.hasOverdueDoses {
                    MedicationMiniStatCard(
                        title: "Overdue",
                        value: "\(viewModel.todaysMedications.filter { $0.overdueDose != nil }.count)",
                        icon: "exclamationmark.triangle.fill",
                        color: overdueRed,
                        colorScheme: colorScheme
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Medication List Section
    
    private var medicationListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Medications")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(viewModel.todaysMedications.count) items")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                ForEach(viewModel.todaysMedications) { medWithAdherence in
                    MedicationCardNew(
                        medicationWithAdherence: medWithAdherence,
                        colorScheme: colorScheme,
                        onTaken: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            Task {
                                try? await viewModel.quickMarkAsTaken(medicationWithAdherence: medWithAdherence)
                            }
                        },
                        onTap: {
                            selectedMedication = medWithAdherence
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Medication Pattern View

struct MedicationPatternView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<6) { i in
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        .frame(width: 40 + CGFloat(i) * 30, height: 40 + CGFloat(i) * 30)
                        .offset(x: geometry.size.width * 0.7, y: -20)
                }
                
                ForEach(0..<4) { i in
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 20 + CGFloat(i) * 15, height: 20 + CGFloat(i) * 15)
                        .offset(x: -geometry.size.width * 0.3, y: geometry.size.height * 0.6)
                }
            }
        }
    }
}

// MARK: - Medication Card New

struct MedicationCardNew: View {
    let medicationWithAdherence: MedicationWithAdherence
    let colorScheme: ColorScheme
    let onTaken: () -> Void
    let onTap: () -> Void
    
    private var medicationPurple: Color { Color(hex: "5856D6") }
    private var medicationTeal: Color { Color(hex: "11998e") }
    private var overdueRed: Color { Color(hex: "FF6B6B") }
    
    private var statusColor: Color {
        if medicationWithAdherence.overdueDose != nil {
            return overdueRed
        } else if medicationWithAdherence.takenCount == medicationWithAdherence.totalDoses {
            return medicationTeal
        } else {
            return medicationPurple
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(statusColor.opacity(0.12))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: medicationWithAdherence.medication.type.icon)
                        .font(.system(size: 24))
                        .foregroundColor(statusColor)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(medicationWithAdherence.medication.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(medicationWithAdherence.medication.dosage)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    if let overdue = medicationWithAdherence.overdueDose {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 11))
                            Text("Overdue • \(formatTime(overdue.scheduledTime))")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(overdueRed)
                    } else if let next = medicationWithAdherence.nextDose {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 11))
                            Text("Next • \(formatTime(next.scheduledTime))")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                            Text("All done for today")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(medicationTeal)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.primary.opacity(0.1), lineWidth: 4)
                            .frame(width: 44, height: 44)
                        
                        Circle()
                            .trim(from: 0, to: medicationWithAdherence.adherencePercentage)
                            .stroke(statusColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(medicationWithAdherence.takenCount)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    Text("\(medicationWithAdherence.takenCount)/\(medicationWithAdherence.totalDoses)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                if medicationWithAdherence.overdueDose != nil || medicationWithAdherence.nextDose != nil {
                    Button(action: onTaken) {
                        ZStack {
                            Circle()
                                .fill(statusColor.opacity(0.15))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(statusColor)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(MovementsColors.card(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        medicationWithAdherence.overdueDose != nil ? overdueRed.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Medication Mini Stat Card

struct MedicationMiniStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .padding(14)
        .frame(width: 100)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(MovementsColors.card(for: colorScheme))
        )
    }
}

#Preview {
    MedicationsView(viewModel: MedicationViewModel())
}
