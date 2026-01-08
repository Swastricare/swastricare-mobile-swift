//
//  MedicationsView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI

struct MedicationsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = MedicationViewModel()
    
    @State private var selectedDate = Date()
    @State private var showAddMedication = false
    @State private var selectedMedication: MedicationWithAdherence?
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {   // Black Background
          
                // Theme-aware Background
                // PremiumBackground()
                if viewModel.isLoading {
                    ProgressView()
                        .tint(Color(hex: "2E3192"))
                        .scaleEffect(1.2)
                } else if viewModel.todaysMedications.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        // Custom Calendar Strip
                        calendarStrip
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                        
                        // Progress Header
                        progressSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        
                        // Medication List
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.todaysMedications) { medWithAdherence in
                                    MedicationCard(
                                        medicationWithAdherence: medWithAdherence,
                                        onTaken: {
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
                            .padding(.top, 8)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationTitle("Medications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showAddMedication = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "2E3192"))
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                    .font(.body)
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
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "pills.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(Color(hex: "2E3192").opacity(0.3))
            
            VStack(spacing: 12) {
                Text("No Medications Yet")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Add your first medication to get started with reminders")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: {
                showAddMedication = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add Medication")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color(hex: "2E3192"))
                .cornerRadius(14)
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Subviews
    
    private var calendarStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<7) { index in
                    let date = Calendar.current.date(byAdding: .day, value: index, to: Date()) ?? Date()
                    let isToday = Calendar.current.isDateInToday(date)
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDate = date
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isSelected ? .white : .secondary)
                            
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(isSelected ? .white : .primary)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(isSelected ? Color(hex: "2E3192") : Color.clear)
                                )
                        }
                        .frame(width: 56)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isToday && !isSelected ? Color(hex: "2E3192").opacity(0.1) : Color.clear)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var progressSection: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Today's Progress")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("\(viewModel.takenCount) of \(viewModel.totalCount) taken")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
                if let stats = viewModel.adherenceStatistics {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 12))
                        Text("\(stats.adherenceRate) adherence")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Circular progress
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 8)
                    .frame(width: 72, height: 72)
                
                let progress = viewModel.todayAdherencePercentage / 100
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color(hex: "11998e"), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
                
                VStack(spacing: 2) {
                    Text("\(Int(viewModel.todayAdherencePercentage))%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .glass(cornerRadius: 20)
    }
}

// MARK: - Medication Card

struct MedicationCard: View {
    let medicationWithAdherence: MedicationWithAdherence
    let onTaken: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon Container
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "2E3192").opacity(0.12))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: medicationWithAdherence.medication.type.icon)
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "2E3192"))
                }
                
                // Medication Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(medicationWithAdherence.medication.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(medicationWithAdherence.medication.dosage)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    // Status indicator
                    if let overdue = medicationWithAdherence.overdueDose {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 11))
                            Text("Overdue • \(formatTime(overdue.scheduledTime))")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.red)
                    } else if let next = medicationWithAdherence.nextDose {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 11))
                            Text("Next • \(formatTime(next.scheduledTime))")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Progress indicator
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(Color.primary.opacity(0.1), lineWidth: 3.5)
                            .frame(width: 44, height: 44)
                        
                        Circle()
                            .trim(from: 0, to: medicationWithAdherence.adherencePercentage)
                            .stroke(Color(hex: "11998e"), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(medicationWithAdherence.takenCount)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    
                    Text("\(medicationWithAdherence.takenCount)/\(medicationWithAdherence.totalDoses)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                // Quick action button
                if medicationWithAdherence.overdueDose != nil || medicationWithAdherence.nextDose != nil {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            onTaken()
                        }
                    }) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Color(hex: "11998e"))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .glass(cornerRadius: 18)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    MedicationsView()
}
