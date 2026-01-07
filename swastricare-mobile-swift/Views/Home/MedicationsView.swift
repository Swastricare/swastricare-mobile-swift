
import SwiftUI

struct MedicationsView: View {
    @Environment(\.dismiss) var dismiss
    
    // MARK: - Mock Data Models
    struct Medication: Identifiable {
        let id = UUID()
        let name: String
        let dosage: String
        let time: String
        let type: MedType
        var isTaken: Bool
        
        enum MedType {
            case pill, liquid, injection
        }
    }
    
    @State private var medications: [Medication] = [
        Medication(name: "Vitamin D3", dosage: "1 Tablet (2000 IU)", time: "08:00 AM", type: .pill, isTaken: true),
        Medication(name: "Amoxicillin", dosage: "500 mg", time: "02:00 PM", type: .pill, isTaken: false),
        Medication(name: "Ibuprofen", dosage: "400 mg", time: "08:00 PM", type: .pill, isTaken: false)
    ]
    
    @State private var selectedDate = Date()
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Custom Calendar Strip
                    calendarStrip
                    
                    // Progress Header
                    progressSection
                    
                    // Medication List
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach($medications) { $med in
                                MedicationCard(medication: $med)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Medications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        // Add medication action
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
        }
        .preferredColorScheme(.dark)
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
                
                let takenCount = medications.filter { $0.isTaken }.count
                Text("\(takenCount) of \(medications.count) taken")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Simple circular progress
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 6)
                    .frame(width: 50, height: 50)
                
                let progress = Double(medications.filter { $0.isTaken }.count) / Double(medications.count)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(PremiumColor.neonGreen, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(), value: progress)
            }
        }
        .padding()
        .glass(cornerRadius: 16)
        .padding(.horizontal)
    }
}

struct MedicationCard: View {
    @Binding var medication: MedicationsView.Medication
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon Container
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "pills.fill")
                    .font(.title2)
                    .foregroundStyle(Color.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(medication.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(medication.dosage) • \(medication.time)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Checkbox
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    medication.isTaken.toggle()
                }
            }) {
                Image(systemName: medication.isTaken ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundStyle(medication.isTaken ? PremiumColor.neonGreen : LinearGradient(colors: [.secondary], startPoint: .top, endPoint: .bottom))
            }
        }
        .padding()
        .glass(cornerRadius: 20)
        .opacity(medication.isTaken ? 0.6 : 1.0) // Dim if taken
    }
}

#Preview {
    MedicationsView()
}
