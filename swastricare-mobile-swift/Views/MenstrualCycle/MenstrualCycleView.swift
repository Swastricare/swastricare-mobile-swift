//
//  MenstrualCycleView.swift
//  swastricare-mobile-swift
//
//  Main view for menstrual cycle tracking feature.
//

import SwiftUI

struct MenstrualCycleView: View {
    @StateObject private var viewModel = MenstrualCycleViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Status Card
                    CycleStatusCard(viewModel: viewModel)
                    
                    // Calendar
                    CycleCalendarView(viewModel: viewModel)
                    
                    // Phase Info
                    PhaseInfoCard(viewModel: viewModel)
                    
                    // Quick Actions
                    QuickActionsSection(viewModel: viewModel)
                    
                    // Tips Section
                    TipsSection(tips: viewModel.tips, phase: viewModel.currentPhase)
                    
                    // Statistics Preview
                    if viewModel.statistics != nil {
                        StatisticsPreviewCard(viewModel: viewModel)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Cycle Tracker")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            viewModel.showSettingsSheet = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        
                        Button {
                            viewModel.showStatsSheet = true
                        } label: {
                            Label("Statistics", systemImage: "chart.bar")
                        }
                        
                        Button {
                            Task { await viewModel.refresh() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddPeriodSheet) {
                AddPeriodSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showDailyLogSheet) {
                DailyLogSheet(viewModel: viewModel, date: viewModel.selectedDate)
            }
            .sheet(isPresented: $viewModel.showSettingsSheet) {
                CycleSettingsSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showStatsSheet) {
                CycleStatisticsSheet(viewModel: viewModel)
            }
            .task {
                await viewModel.onAppear()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Cycle Status Card

struct CycleStatusCard: View {
    @ObservedObject var viewModel: MenstrualCycleViewModel
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Main status
            HStack(spacing: 16) {
                // Cycle progress ring
                ZStack {
                    Circle()
                        .stroke(Color.pink.opacity(0.1), lineWidth: 8)
                    
                    Circle()
                        .trim(from: 0, to: viewModel.cycleProgress)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [viewModel.currentPhase.color.opacity(0.5), viewModel.currentPhase.color]),
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 1.0, dampingFraction: 0.8), value: viewModel.cycleProgress)
                    
                    VStack(spacing: 2) {
                        Text("Day")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(viewModel.dayOfCycle)")
                            .font(.title2.bold())
                            .contentTransition(.numericText())
                            .foregroundColor(viewModel.currentPhase.color)
                    }
                }
                .frame(width: 80, height: 80)
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .opacity(isAnimating ? 1.0 : 0.0)
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        isAnimating = true
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.currentPhase.rawValue)
                        .font(.headline)
                        .foregroundColor(viewModel.currentPhase.color)
                    
                    Text(viewModel.periodStatusText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if viewModel.isFertileToday {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("Fertile Window")
                        }
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            // Predictions row
            if let prediction = viewModel.prediction {
                HStack(spacing: 20) {
                    PredictionBadge(
                        title: "Period",
                        value: "\(prediction.daysUntilPeriod)d",
                        icon: "drop.fill",
                        color: .red
                    )
                    
                    PredictionBadge(
                        title: "Ovulation",
                        value: "\(prediction.daysUntilOvulation)d",
                        icon: "sparkles",
                        color: .green
                    )
                    
                    PredictionBadge(
                        title: "Confidence",
                        value: "\(Int(prediction.confidence * 100))%",
                        icon: "chart.bar.fill",
                        color: .purple
                    )
                }
            } else {
                Text("Log at least one period to see predictions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

struct PredictionBadge: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Calendar View

struct CycleCalendarView: View {
    @ObservedObject var viewModel: MenstrualCycleViewModel
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
    
    @State private var slideDirection: Edge = .trailing
    
    var body: some View {
        VStack(spacing: 12) {
            // Month navigation
            HStack {
                Button {
                    slideDirection = .leading
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.goToPreviousMonth()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.pink)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                
                Spacer()
                
                Text(viewModel.formatMonthYear(viewModel.selectedMonth))
                    .font(.headline)
                    .animation(.none, value: viewModel.selectedMonth)
                
                Spacer()
                
                Button {
                    slideDirection = .trailing
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.goToNextMonth()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.pink)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal)
            
            // Weekday headers
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
            }
            
            // Calendar days with slide animation
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(leadingEmptyDays(), id: \.self) { _ in
                    Text("")
                }
                
                ForEach(viewModel.calendarData) { dayData in
                    MenstrualCalendarDayCell(
                        dayData: dayData,
                        isSelected: viewModel.isSelected(dayData.date),
                        isToday: viewModel.isToday(dayData.date)
                    )
                    .onTapGesture {
                        viewModel.selectDate(dayData.date)
                        viewModel.showDailyLogSheet = true
                    }
                }
            }
            .id(viewModel.selectedMonth)
            .transition(.asymmetric(
                insertion: .move(edge: slideDirection).combined(with: .opacity),
                removal: .move(edge: slideDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
            ))
            .padding(.bottom, 4)
            
            // Legend
            HStack(spacing: 16) {
                MenstrualLegendItem(color: .red, text: "Period")
                MenstrualLegendItem(color: .red.opacity(0.4), text: "Predicted")
                MenstrualLegendItem(color: .green, text: "Fertile")
                MenstrualLegendItem(color: .purple, text: "PMS")
            }
            .padding(.top, 6)
            .font(.caption2)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
    
    private func leadingEmptyDays() -> [Int] {
        let calendar = Calendar.current
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: viewModel.selectedMonth)) else {
            return []
        }
        let weekday = calendar.component(.weekday, from: monthStart)
        return Array(0..<(weekday - 1))
    }
}

struct MenstrualCalendarDayCell: View {
    let dayData: CalendarDayData
    let isSelected: Bool
    let isToday: Bool
    
    private let cellSize: CGFloat = 40
    private let circleSize: CGFloat = 34
    private let selectedRingSize: CGFloat = 36
    
    var body: some View {
        let dayNumber = Calendar.current.component(.day, from: dayData.date)
        
        ZStack {
            // Background
            Circle()
                .fill(backgroundColor)
                .frame(width: circleSize, height: circleSize)
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            
            // Selected ring
            if isSelected {
                Circle()
                    .stroke(Color.pink, lineWidth: 2)
                    .frame(width: selectedRingSize, height: selectedRingSize)
                    .scaleEffect(1.0)
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Day number
            Text("\(dayNumber)")
                .font(.system(size: 14, weight: isToday ? .bold : .regular))
                .foregroundColor(textColor)
                .minimumScaleFactor(0.8)
            
            // Indicators
            if dayData.hasLog && !dayData.isPeriodDay {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 4, height: 4)
                    .offset(y: (cellSize / 2) - 6)
            }
        }
        .frame(width: cellSize, height: cellSize)
        // Prevent day backgrounds/indicators from painting outside the cell
        .clipped()
        .contentShape(Rectangle())
    }
    
    private var backgroundColor: Color {
        if dayData.isPeriodDay {
            return .red
        } else if dayData.isPredictedPeriod {
            return .red.opacity(0.3)
        } else if dayData.isOvulationDay {
            return .green
        } else if dayData.isFertileDay {
            return .green.opacity(0.3)
        } else if dayData.isPmsDay {
            return .purple.opacity(0.3)
        } else if isToday {
            return .pink.opacity(0.2)
        }
        return .clear
    }
    
    private var textColor: Color {
        if dayData.isPeriodDay || dayData.isOvulationDay {
            return .white
        }
        return .primary
    }
}

struct MenstrualLegendItem: View {
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Phase Info Card

struct PhaseInfoCard: View {
    @ObservedObject var viewModel: MenstrualCycleViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: viewModel.currentPhase.icon)
                    .foregroundColor(viewModel.currentPhase.color)
                Text("Current Phase")
                    .font(.headline)
            }
            
            Text(viewModel.phaseDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

// MARK: - Quick Actions

struct QuickActionsSection: View {
    @ObservedObject var viewModel: MenstrualCycleViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            HStack(spacing: 12) {
                if viewModel.activeCycle == nil {
                    QuickActionButton(
                        title: "Start Period",
                        icon: "drop.fill",
                        color: .red
                    ) {
                        viewModel.showAddPeriodSheet = true
                    }
                } else {
                    QuickActionButton(
                        title: "End Period",
                        icon: "checkmark.circle.fill",
                        color: .green
                    ) {
                        Task { await viewModel.endPeriod() }
                    }
                }
                
                QuickActionButton(
                    title: "Log Today",
                    icon: "plus.circle.fill",
                    color: .pink
                ) {
                    viewModel.selectDate(Date())
                    viewModel.showDailyLogSheet = true
                }
                
                QuickActionButton(
                    title: "History",
                    icon: "calendar",
                    color: .purple
                ) {
                    viewModel.showStatsSheet = true
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Tips Section

struct TipsSection: View {
    let tips: [String]
    let phase: CyclePhase
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Tips for \(phase.rawValue) Phase")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tips.prefix(3), id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

// MARK: - Statistics Preview

struct StatisticsPreviewCard: View {
    @ObservedObject var viewModel: MenstrualCycleViewModel
    
    var body: some View {
        if let stats = viewModel.statistics {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.purple)
                    Text("Your Cycle")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("See All") {
                        viewModel.showStatsSheet = true
                    }
                    .font(.caption)
                    .foregroundColor(.pink)
                }
                
                HStack(spacing: 20) {
                    StatItem(
                        value: String(format: "%.0f", stats.averageCycleLength),
                        unit: "days",
                        label: "Avg Cycle"
                    )
                    
                    StatItem(
                        value: String(format: "%.0f", stats.averagePeriodLength),
                        unit: "days",
                        label: "Avg Period"
                    )
                    
                    StatItem(
                        value: "\(stats.totalCyclesTracked)",
                        unit: "",
                        label: "Tracked"
                    )
                    
                    StatItem(
                        value: stats.cycleRegularity,
                        unit: "",
                        label: "Pattern"
                    )
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        }
    }
}

struct StatItem: View {
    let value: String
    let unit: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Add Period Sheet

struct AddPeriodSheet: View {
    @ObservedObject var viewModel: MenstrualCycleViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var startDate = Date()
    @State private var flowIntensity: FlowIntensity = .medium
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Period Start") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                }
                
                Section("Flow Intensity") {
                    Picker("Intensity", selection: $flowIntensity) {
                        ForEach(FlowIntensity.allCases) { intensity in
                            HStack {
                                Image(systemName: intensity.icon)
                                Text(intensity.displayName)
                            }
                            .tag(intensity)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Notes (Optional)") {
                    TextField("Any notes about this period", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Log Period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.startPeriod(
                                date: startDate,
                                flowIntensity: flowIntensity,
                                notes: notes.isEmpty ? nil : notes
                            )
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Daily Log Sheet

struct DailyLogSheet: View {
    @ObservedObject var viewModel: MenstrualCycleViewModel
    let date: Date
    @Environment(\.dismiss) private var dismiss
    
    @State private var log: MenstrualDailyLog
    @State private var selectedSymptoms: Set<SymptomType> = []
    
    init(viewModel: MenstrualCycleViewModel, date: Date) {
        self.viewModel = viewModel
        self.date = date
        _log = State(initialValue: viewModel.getOrCreateLog(for: date))
        _selectedSymptoms = State(initialValue: Set(viewModel.getOrCreateLog(for: date).symptoms.map { $0.symptomType }))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Flow") {
                    Picker("Flow Level", selection: $log.flowLevel) {
                        Text("None").tag(FlowLevel?.none)
                        ForEach(FlowLevel.allCases) { level in
                            HStack {
                                Image(systemName: level.icon)
                                Text(level.displayName)
                            }
                            .tag(FlowLevel?.some(level))
                        }
                    }
                }
                
                Section("Mood") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(CycleMood.allCases) { mood in
                                MoodButton(
                                    mood: mood,
                                    isSelected: log.mood == mood
                                ) {
                                    log.mood = (log.mood == mood) ? nil : mood
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("Pain Level") {
                    VStack {
                        Slider(value: Binding(
                            get: { Double(log.painLevel ?? 0) },
                            set: { log.painLevel = Int($0) }
                        ), in: 0...10, step: 1)
                        
                        HStack {
                            Text("None")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(log.painLevel ?? 0)")
                                .font(.headline)
                                .foregroundColor(.pink)
                            Spacer()
                            Text("Severe")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Energy Level") {
                    VStack {
                        Slider(value: Binding(
                            get: { Double(log.energyLevel ?? 5) },
                            set: { log.energyLevel = Int($0) }
                        ), in: 0...10, step: 1)
                        
                        HStack {
                            Text("Low")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(log.energyLevel ?? 5)")
                                .font(.headline)
                                .foregroundColor(.orange)
                            Spacer()
                            Text("High")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Symptoms") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(SymptomType.allCases) { symptom in
                            SymptomButton(
                                symptom: symptom,
                                isSelected: selectedSymptoms.contains(symptom)
                            ) {
                                if selectedSymptoms.contains(symptom) {
                                    selectedSymptoms.remove(symptom)
                                } else {
                                    selectedSymptoms.insert(symptom)
                                }
                            }
                        }
                    }
                }
                
                Section("Sleep Quality") {
                    Picker("Sleep", selection: $log.sleepQuality) {
                        Text("Not logged").tag(SleepQuality?.none)
                        ForEach(SleepQuality.allCases) { quality in
                            HStack {
                                Image(systemName: quality.icon)
                                Text(quality.displayName)
                            }
                            .tag(SleepQuality?.some(quality))
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Notes") {
                    TextField("Any notes for today", text: Binding(
                        get: { log.notes ?? "" },
                        set: { log.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                }
            }
            .navigationTitle(formatDate(date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Convert selected symptoms to MenstrualSymptom objects
                        log.symptoms = selectedSymptoms.map { MenstrualSymptom(symptomType: $0) }
                        
                        Task {
                            await viewModel.saveDailyLog(log)
                            dismiss()
                        }
                    }
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

struct MoodButton: View {
    let mood: CycleMood
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(mood.emoji)
                    .font(.title2)
                    .scaleEffect(isSelected ? 1.2 : 1.0)
                Text(mood.displayName)
                    .font(.caption2)
            }
            .padding(8)
            .background(isSelected ? Color.pink.opacity(0.2) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.pink : Color.clear, lineWidth: 2)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct SymptomButton: View {
    let symptom: SymptomType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symptom.icon)
                    .font(.caption)
                Text(symptom.displayName)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.pink.opacity(0.2) : Color(.systemGray6))
            .foregroundColor(isSelected ? .pink : .primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.pink : Color.clear, lineWidth: 1)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Settings Sheet

struct CycleSettingsSheet: View {
    @ObservedObject var viewModel: MenstrualCycleViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var settings: MenstrualSettings
    
    init(viewModel: MenstrualCycleViewModel) {
        self.viewModel = viewModel
        _settings = State(initialValue: viewModel.settings)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Cycle Defaults") {
                    Stepper("Average Cycle Length: \(settings.averageCycleLength) days", value: $settings.averageCycleLength, in: 21...45)
                    Stepper("Average Period Length: \(settings.averagePeriodLength) days", value: $settings.averagePeriodLength, in: 2...10)
                    Stepper("Luteal Phase Length: \(settings.lutealPhaseLength) days", value: $settings.lutealPhaseLength, in: 10...18)
                }
                
                Section("Reminders") {
                    Toggle("Period Reminders", isOn: $settings.reminderEnabled)
                    if settings.reminderEnabled {
                        Stepper("Remind \(settings.reminderDaysBefore) days before", value: $settings.reminderDaysBefore, in: 1...7)
                    }
                }
                
                Section("Tracking Features") {
                    Toggle("Fertile Window", isOn: $settings.fertileWindowTracking)
                    Toggle("Ovulation Tracking", isOn: $settings.ovulationTracking)
                    Toggle("PMS Tracking", isOn: $settings.pmsTracking)
                }
                
                Section("About") {
                    HStack {
                        Text("Cycle Length")
                        Spacer()
                        Text("Days between period starts")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("Luteal Phase")
                        Spacer()
                        Text("Days from ovulation to period")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveSettings(settings)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Statistics Sheet

struct CycleStatisticsSheet: View {
    @ObservedObject var viewModel: MenstrualCycleViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let stats = viewModel.statistics {
                        // Summary Card
                        VStack(spacing: 16) {
                            Text("Cycle Overview")
                                .font(.headline)
                            
                            HStack(spacing: 20) {
                                StatisticItem(
                                    title: "Avg Cycle",
                                    value: String(format: "%.1f", stats.averageCycleLength),
                                    unit: "days",
                                    color: .pink
                                )
                                
                                StatisticItem(
                                    title: "Avg Period",
                                    value: String(format: "%.1f", stats.averagePeriodLength),
                                    unit: "days",
                                    color: .red
                                )
                            }
                            
                            HStack(spacing: 20) {
                                StatisticItem(
                                    title: "Shortest",
                                    value: "\(stats.shortestCycle)",
                                    unit: "days",
                                    color: .blue
                                )
                                
                                StatisticItem(
                                    title: "Longest",
                                    value: "\(stats.longestCycle)",
                                    unit: "days",
                                    color: .orange
                                )
                            }
                            
                            VStack(spacing: 4) {
                                Text("Regularity")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(stats.cycleRegularity)
                                    .font(.title3.bold())
                                    .foregroundColor(.purple)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        
                        // Common Symptoms
                        if !stats.mostCommonSymptoms.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Most Common Symptoms")
                                    .font(.headline)
                                
                                ForEach(stats.mostCommonSymptoms.prefix(5), id: \.self) { symptom in
                                    HStack {
                                        Image(systemName: symptom.icon)
                                            .foregroundColor(.pink)
                                        Text(symptom.displayName)
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                        }
                        
                        // Cycle History
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Cycle History")
                                .font(.headline)
                            
                            ForEach(viewModel.cycles.filter { !$0.isPredicted }.prefix(10)) { cycle in
                                CycleHistoryRow(cycle: cycle)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("Not Enough Data")
                                .font(.headline)
                            Text("Log at least 2 complete cycles to see statistics")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(40)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct StatisticItem: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2.bold())
                    .foregroundColor(color)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct CycleHistoryRow: View {
    let cycle: MenstrualCycle
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDate(cycle.startDate))
                    .font(.subheadline)
                if let length = cycle.cycleLength {
                    Text("\(length) day cycle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let period = cycle.periodLength {
                Text("\(period)d period")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    MenstrualCycleView()
}
