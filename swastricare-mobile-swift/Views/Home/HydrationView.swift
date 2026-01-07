import SwiftUI

struct HydrationView: View {
    @Environment(\.dismiss) var dismiss
    
    // MARK: - Mock Data Models
    struct HydrationEntry: Identifiable {
        let id = UUID()
        let time: String
        let amount: Int // in ml
        let type: DrinkType
        
        enum DrinkType {
            case water, tea, coffee, juice
            
            var icon: String {
                switch self {
                case .water: return "drop.fill"
                case .tea: return "cup.and.saucer.fill"
                case .coffee: return "cup.and.saucer.fill"
                case .juice: return "wineglass.fill"
                }
            }
            
            var color: Color {
                switch self {
                case .water: return .cyan
                case .tea: return .brown
                case .coffee: return .brown
                case .juice: return .orange
                }
            }
        }
    }
    
    @State private var hydrationEntries: [HydrationEntry] = [
        HydrationEntry(time: "08:00 AM", amount: 250, type: .water),
        HydrationEntry(time: "10:30 AM", amount: 200, type: .coffee),
        HydrationEntry(time: "12:00 PM", amount: 350, type: .water),
        HydrationEntry(time: "03:00 PM", amount: 150, type: .tea)
    ]
    
    @State private var selectedDate = Date()
    @State private var dailyGoal = 2500 // in ml
    
    private var totalIntake: Int {
        hydrationEntries.reduce(0) { $0 + $1.amount }
    }
    
    private var progress: Double {
        min(Double(totalIntake) / Double(dailyGoal), 1.0)
    }
    
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
                    
                    // Hydration List
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(hydrationEntries) { entry in
                                HydrationCard(entry: entry)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Hydration")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        // Add hydration entry action
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.cyan)
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
                                    .fill(isSelected ? Color.cyan : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom))
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
                Text("Today's Goal")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("\(totalIntake) of \(dailyGoal) ml")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("\(Int(progress * 100))% Complete")
                    .font(.caption)
                    .foregroundColor(Color.cyan)
            }
            
            Spacer()
            
            // Water drop progress indicator
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 6)
                    .frame(width: 70, height: 70)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.cyan, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(), value: progress)
                
                Image(systemName: "drop.fill")
                    .font(.title)
                    .foregroundColor(.cyan)
            }
        }
        .padding()
        .glass(cornerRadius: 16)
        .padding(.horizontal)
    }
}

struct HydrationCard: View {
    let entry: HydrationView.HydrationEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon Container
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [entry.type.color.opacity(0.3), entry.type.color.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                
                Image(systemName: entry.type.icon)
                    .font(.title2)
                    .foregroundStyle(entry.type.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.amount) ml")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(entry.time)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Glass icon indicator
            Image(systemName: "glassware")
                .font(.title3)
                .foregroundStyle(Color.white.opacity(0.3))
        }
        .padding()
        .glass(cornerRadius: 20)
    }
}

#Preview {
    HydrationView()
}
