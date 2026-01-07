
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
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else if viewModel.todaysMedications.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 20) {
                        // Custom Calendar Strip
                        calendarStrip
                        
                        // Progress Header
                        progressSection
                        
                        // Medication List
                        ScrollView {
                            VStack(spacing: 16) {
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
                            .padding()
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
                            .font(.title2)
                            .foregroundStyle(PremiumColor.royalBlue)
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
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
        .preferredColorScheme(.dark)
        .task {
            await viewModel.loadMedications()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "pills.circle")
                .font(.system(size: 80))
                .foregroundStyle(PremiumColor.royalBlue)
            
            Text("No Medications Yet")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Add your first medication to get started with reminders")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                showAddMedication = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Medication")
                }
                .padding()
                .background(PremiumColor.royalBlue)
                .cornerRadius(12)
                .foregroundColor(.white)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
    
    // MARK: - Subviews
    
    private var calendarStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<7) { index in
                    let date = Calendar.current.date(byAdding: .day, value: index, to: Date()) ?? Date()
                    let isToday = Calendar.current.isDateInToday(date)
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    
                    VStack(spacing: 8) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(isSelected ? .white : .secondary)
                        
                        Text(date.formatted(.dateTime.day()))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(isSelected ? .white : .secondary)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(isSelected ? PremiumColor.royalBlue : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom))
                            )
                    }
                    .frame(width: 50)
                    .padding(.vertical, 8)
                    .background(isToday && !isSelected ? Color.white.opacity(0.1) : Color.clear)
                    .cornerRadius(25)
                    .onTapGesture {
                        withAnimation {
                            selectedDate = date
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var progressSection: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Today's Progress")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("\(viewModel.takenCount) of \(viewModel.totalCount) taken")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if let stats = viewModel.adherenceStatistics {
                    Text("\(stats.adherenceRate) adherence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Simple circular progress
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                let progress = viewModel.todayAdherencePercentage / 100
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(PremiumColor.neonGreen, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(), value: progress)
                
                Text("\(Int(viewModel.todayAdherencePercentage))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .glass(cornerRadius: 16)
        .padding(.horizontal)
    }
}

struct MedicationCard: View {
    let medicationWithAdherence: MedicationWithAdherence
    let onTaken: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon Container
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: medicationWithAdherence.medication.type.icon)
                        .font(.title2)
                        .foregroundStyle(Color.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(medicationWithAdherence.medication.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(medicationWithAdherence.medication.dosage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Show next dose or overdue indicator
                    if let overdue = medicationWithAdherence.overdueDose {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Overdue • \(formatTime(overdue.scheduledTime))")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } else if let next = medicationWithAdherence.nextDose {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                            Text("Next • \(formatTime(next.scheduledTime))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Progress indicator
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 3)
                            .frame(width: 40, height: 40)
                        
                        Circle()
                            .trim(from: 0, to: medicationWithAdherence.adherencePercentage)
                            .stroke(PremiumColor.neonGreen, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(medicationWithAdherence.takenCount)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Text("\(medicationWithAdherence.takenCount)/\(medicationWithAdherence.totalDoses)")
                        .font(.caption2)
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
                            .font(.system(size: 28))
                            .foregroundStyle(PremiumColor.neonGreen)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding()
            .glass(cornerRadius: 20)
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
