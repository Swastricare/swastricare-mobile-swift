//
//  MenstruationView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//  Premium menstrual cycle tracking interface
//

import SwiftUI

// MARK: - Menstruation View

struct MenstruationView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = DependencyContainer.shared.menstruationViewModel

    @State private var animatePhase = false
    @State private var showConfirmEndPeriod = false

    private let primaryColor = Color(hex: "E91E63") // Rose pink
    private let secondaryColor = Color(hex: "AD1457")

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Cycle Phase Card
                cyclePhaseCard

                // Period Action Button
                periodActionSection

                // Daily Log (when period active)
                if viewModel.isPeriodActive {
                    currentPeriodInfo
                }

                // Prediction Card
                if let prediction = viewModel.prediction {
                    predictionCard(prediction)
                }

                // Cycle Insights
                if let insights = viewModel.insights {
                    insightsCard(insights)
                }

                // Recent Cycles
                if !viewModel.cycles.isEmpty {
                    recentCyclesSection
                }

                // Empty State
                if viewModel.cycles.isEmpty && viewModel.dataState == .empty {
                    emptyState
                }

                Spacer(minHeight: 40)
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Cycle Tracker")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if viewModel.isPeriodActive {
                        Button(action: { viewModel.prepareLogSheet() }) {
                            Label("Log Today", systemImage: "pencil.line")
                        }
                    }
                    if let _ = viewModel.insights {
                        Button(action: { viewModel.showInsightsSheet = true }) {
                            Label("Insights", systemImage: "chart.bar.fill")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title2)
                        .foregroundStyle(primaryColor)
                }
            }
        }
        .sheet(isPresented: $viewModel.showLogSheet) {
            DailyLogSheet(viewModel: viewModel, accentColor: primaryColor)
        }
        .sheet(isPresented: $viewModel.showInsightsSheet) {
            InsightsDetailSheet(viewModel: viewModel, accentColor: primaryColor)
        }
        .alert("Cycle Tracker", isPresented: $viewModel.showAlert) {
            Button("OK") {}
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .confirmationDialog("End Period?", isPresented: $showConfirmEndPeriod, titleVisibility: .visible) {
            Button("End Period") {
                Task { await viewModel.endPeriod() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Mark your period as ended today?")
        }
        .task {
            await viewModel.loadData()
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                animatePhase = true
            }
        }
    }

    // MARK: - Cycle Phase Card

    private var cyclePhaseCard: some View {
        VStack(spacing: 16) {
            // Phase Ring
            ZStack {
                // Background track
                Circle()
                    .stroke(Color.gray.opacity(0.12), lineWidth: 10)
                    .frame(width: 180, height: 180)

                // Phase segments
                ForEach(CyclePhase.allCases) { phase in
                    let (start, end) = phaseArcRange(phase)
                    Circle()
                        .trim(from: start, to: animatePhase ? end : start)
                        .stroke(
                            phase.color,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                }

                // Center content
                VStack(spacing: 4) {
                    Image(systemName: viewModel.currentPhase.icon)
                        .font(.system(size: 28))
                        .foregroundColor(viewModel.currentPhase.color)
                        .symbolEffect(.pulse, value: animatePhase)

                    Text(viewModel.currentPhase.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)

                    if viewModel.dayOfCycle > 0 {
                        Text("Day \(viewModel.dayOfCycle)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Status Text
            Text(viewModel.statusText)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)

            // Phase Legend
            HStack(spacing: 12) {
                ForEach(CyclePhase.allCases) { phase in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(phase.color)
                            .frame(width: 8, height: 8)
                        Text(phase.displayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
    }

    // MARK: - Period Action

    private var periodActionSection: some View {
        VStack(spacing: 12) {
            if viewModel.isPeriodActive {
                // Period is active - show end button and log button
                HStack(spacing: 12) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        viewModel.prepareLogSheet()
                    }) {
                        HStack {
                            Image(systemName: "pencil.line")
                            Text("Log Today")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [primaryColor, secondaryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showConfirmEndPeriod = true
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("End")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(primaryColor)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 24)
                        .background(primaryColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            } else {
                // No active period - show start button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task { await viewModel.startPeriod() }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "drop.fill")
                            .symbolEffect(.bounce, value: animatePhase)
                        Text("Period Started Today")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [primaryColor, secondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: primaryColor.opacity(0.3), radius: 8, y: 4)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Current Period Info

    private var currentPeriodInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(primaryColor)
                Text("Current Period")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("Day \(viewModel.periodDayCount)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(primaryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(primaryColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            if let cycle = viewModel.currentCycle {
                HStack(spacing: 20) {
                    if let flow = cycle.flowIntensity {
                        VStack(spacing: 4) {
                            HStack(spacing: 2) {
                                ForEach(0..<flow.dropCount, id: \.self) { _ in
                                    Image(systemName: "drop.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(flow.color)
                                }
                            }
                            Text(flow.displayName)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    if let pain = cycle.painLevel, pain > 0 {
                        VStack(spacing: 4) {
                            Text("\(pain)/10")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.orange)
                            Text("Pain")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    if let mood = cycle.mood, let moodType = MoodType(rawValue: mood) {
                        VStack(spacing: 4) {
                            Text(moodType.emoji)
                                .font(.system(size: 20))
                            Text(moodType.displayName)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if !cycle.symptoms.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(cycle.symptoms, id: \.self) { symptom in
                                if let s = PeriodSymptom(rawValue: symptom) {
                                    HStack(spacing: 4) {
                                        Image(systemName: s.icon)
                                            .font(.system(size: 10))
                                        Text(s.displayName)
                                            .font(.system(size: 11))
                                    }
                                    .foregroundColor(primaryColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(primaryColor.opacity(0.08))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    // MARK: - Prediction Card

    private func predictionCard(_ prediction: CyclePrediction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("Predictions")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(Int(prediction.confidence * 100))% confidence")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 0) {
                predictionStat(
                    icon: "calendar",
                    label: "Next Period",
                    value: prediction.daysUntilNextPeriod <= 0 ? "Any day" : "\(prediction.daysUntilNextPeriod)d",
                    color: primaryColor
                )

                Divider().frame(height: 40)

                if let ovDays = prediction.daysUntilOvulation {
                    predictionStat(
                        icon: "sparkles",
                        label: "Ovulation",
                        value: ovDays <= 0 ? "Now" : "\(ovDays)d",
                        color: .green
                    )
                    Divider().frame(height: 40)
                }

                predictionStat(
                    icon: "arrow.clockwise",
                    label: "Avg Cycle",
                    value: "\(prediction.averageCycleLength)d",
                    color: .blue
                )
            }

            // Fertile window info
            if let start = prediction.fertileWindowStart, let end = prediction.fertileWindowEnd {
                let df = DateFormatter()
                let _ = df.dateFormat = "MMM d"
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                    Text("Fertile window: \(df.string(from: start)) – \(df.string(from: end))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.08))
                .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    // MARK: - Insights Card

    private func insightsCard(_ insights: CycleInsights) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.orange)
                Text("Cycle Insights")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(action: { viewModel.showInsightsSheet = true }) {
                    Text("Details")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(primaryColor)
                }
            }

            HStack(spacing: 0) {
                insightStat(label: "Cycles", value: "\(insights.totalCyclesLogged)", color: .blue)
                Divider().frame(height: 36)
                insightStat(label: "Avg Period", value: "\(insights.averagePeriodLength)d", color: primaryColor)
                Divider().frame(height: 36)
                insightStat(label: "Regularity", value: insights.cycleRegularity, color: .green)
            }

            if !insights.mostCommonSymptoms.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Common Symptoms")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(insights.mostCommonSymptoms) { symptom in
                                HStack(spacing: 4) {
                                    Image(systemName: symptom.icon)
                                        .font(.system(size: 10))
                                    Text(symptom.displayName)
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.08))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    // MARK: - Recent Cycles

    private var recentCyclesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Cycles")
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 16)

            ForEach(viewModel.cycles.prefix(5)) { cycle in
                CycleHistoryRow(cycle: cycle, accentColor: primaryColor, viewModel: viewModel)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(primaryColor.opacity(0.3))
                .symbolEffect(.pulse, options: .repeating, value: animatePhase)

            Text("Start Tracking Your Cycle")
                .font(.system(size: 18, weight: .semibold))

            Text("Log your periods to get predictions, insights, and personalized health information.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 30)
    }

    // MARK: - Components

    private func predictionStat(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func insightStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func phaseArcRange(_ phase: CyclePhase) -> (CGFloat, CGFloat) {
        let cycleLength = Double(viewModel.prediction?.averageCycleLength ?? 28)
        let periodLength = Double(viewModel.prediction?.averagePeriodLength ?? 5)

        switch phase {
        case .menstrual:
            return (0, CGFloat(periodLength / cycleLength))
        case .follicular:
            let start = periodLength / cycleLength
            let end = (cycleLength / 2 - 2) / cycleLength
            return (CGFloat(start), CGFloat(end))
        case .ovulation:
            let start = (cycleLength / 2 - 2) / cycleLength
            let end = (cycleLength / 2 + 2) / cycleLength
            return (CGFloat(start), CGFloat(end))
        case .luteal:
            let start = (cycleLength / 2 + 2) / cycleLength
            return (CGFloat(start), 1.0)
        }
    }
}

// MARK: - Cycle History Row

private struct CycleHistoryRow: View {
    let cycle: MenstrualCycle
    let accentColor: Color
    @ObservedObject var viewModel: MenstruationViewModel

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(cycle.isActive ? accentColor : accentColor.opacity(0.3))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(viewModel.formattedDate(cycle.periodStart))
                        .font(.system(size: 14, weight: .medium))
                    if cycle.isActive {
                        Text("Active")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accentColor)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 12) {
                    if let length = cycle.computedPeriodLength ?? cycle.periodLength {
                        Text("\(length) days")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    if let flow = cycle.flowIntensity {
                        Text(flow.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(flow.color)
                    }
                }
            }

            Spacer()

            if !cycle.isActive {
                Button(role: .destructive, action: {
                    Task { await viewModel.deleteCycle(cycle) }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.5))
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}

// MARK: - Daily Log Sheet

private struct DailyLogSheet: View {
    @ObservedObject var viewModel: MenstruationViewModel
    @Environment(\.dismiss) var dismiss
    let accentColor: Color

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Flow Intensity
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Flow")
                            .font(.system(size: 15, weight: .semibold))

                        HStack(spacing: 8) {
                            ForEach(FlowIntensity.allCases) { flow in
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    viewModel.logFlow = viewModel.logFlow == flow ? nil : flow
                                }) {
                                    VStack(spacing: 4) {
                                        HStack(spacing: 1) {
                                            ForEach(0..<flow.dropCount, id: \.self) { _ in
                                                Image(systemName: "drop.fill")
                                                    .font(.system(size: 8))
                                            }
                                        }
                                        .foregroundColor(viewModel.logFlow == flow ? .white : flow.color)

                                        Text(flow.displayName)
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundColor(viewModel.logFlow == flow ? .white : .secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        viewModel.logFlow == flow
                                            ? AnyShapeStyle(flow.color)
                                            : AnyShapeStyle(Color(UIColor.tertiarySystemBackground))
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }

                    // Symptoms
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Symptoms")
                            .font(.system(size: 15, weight: .semibold))

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                            ForEach(PeriodSymptom.allCases) { symptom in
                                let isSelected = viewModel.logSymptoms.contains(symptom)
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if isSelected {
                                        viewModel.logSymptoms.remove(symptom)
                                    } else {
                                        viewModel.logSymptoms.insert(symptom)
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: symptom.icon)
                                            .font(.system(size: 11))
                                        Text(symptom.displayName)
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(isSelected ? accentColor : Color(UIColor.tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }

                    // Mood
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mood")
                            .font(.system(size: 15, weight: .semibold))

                        HStack(spacing: 8) {
                            ForEach(MoodType.allCases) { mood in
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    viewModel.logMood = viewModel.logMood == mood ? nil : mood
                                }) {
                                    VStack(spacing: 4) {
                                        Text(mood.emoji)
                                            .font(.system(size: 22))
                                        Text(mood.displayName)
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundColor(viewModel.logMood == mood ? accentColor : .secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        viewModel.logMood == mood
                                            ? accentColor.opacity(0.12)
                                            : Color(UIColor.tertiarySystemBackground)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(viewModel.logMood == mood ? accentColor : Color.clear, lineWidth: 1.5)
                                    )
                                }
                            }
                        }
                    }

                    // Pain Level
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Pain Level")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                            Text("\(viewModel.logPainLevel)/10")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(painColor(viewModel.logPainLevel))
                        }

                        Slider(value: Binding(
                            get: { Double(viewModel.logPainLevel) },
                            set: { viewModel.logPainLevel = Int($0) }
                        ), in: 0...10, step: 1)
                        .tint(painColor(viewModel.logPainLevel))
                    }

                    // Energy Level
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Energy")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                            Text("\(viewModel.logEnergyLevel)/5")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.orange)
                        }

                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { level in
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    viewModel.logEnergyLevel = level
                                }) {
                                    Image(systemName: level <= viewModel.logEnergyLevel ? "bolt.fill" : "bolt")
                                        .font(.system(size: 18))
                                        .foregroundColor(level <= viewModel.logEnergyLevel ? .orange : .gray.opacity(0.4))
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.system(size: 15, weight: .semibold))
                        TextField("How are you feeling today?", text: $viewModel.logNotes, axis: .vertical)
                            .lineLimit(3)
                            .padding(12)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
            }
            .navigationTitle("Daily Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await viewModel.saveDailyLog() }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func painColor(_ level: Int) -> Color {
        switch level {
        case 0...2: return .green
        case 3...5: return .yellow
        case 6...8: return .orange
        default: return .red
        }
    }
}

// MARK: - Insights Detail Sheet

private struct InsightsDetailSheet: View {
    @ObservedObject var viewModel: MenstruationViewModel
    @Environment(\.dismiss) var dismiss
    let accentColor: Color

    var body: some View {
        NavigationView {
            ScrollView {
                if let insights = viewModel.insights {
                    VStack(spacing: 20) {
                        // Stats Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            insightTile(title: "Avg Cycle", value: "\(insights.averageCycleLength) days", icon: "arrow.clockwise", color: .blue)
                            insightTile(title: "Avg Period", value: "\(insights.averagePeriodLength) days", icon: "drop.fill", color: accentColor)
                            insightTile(title: "Regularity", value: insights.cycleRegularity, icon: "chart.line.uptrend.xyaxis", color: .green)
                            insightTile(title: "Avg Pain", value: String(format: "%.1f/10", insights.averagePainLevel), icon: "bolt.fill", color: .orange)
                            insightTile(title: "Cycles Logged", value: "\(insights.totalCyclesLogged)", icon: "calendar", color: .purple)
                        }
                        .padding(.horizontal, 16)

                        // Top Symptoms
                        if !insights.mostCommonSymptoms.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Most Common Symptoms")
                                    .font(.system(size: 15, weight: .semibold))

                                ForEach(Array(insights.mostCommonSymptoms.enumerated()), id: \.offset) { idx, symptom in
                                    HStack {
                                        Text("\(idx + 1).")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.secondary)
                                            .frame(width: 24)
                                        Image(systemName: symptom.icon)
                                            .font(.system(size: 14))
                                            .foregroundColor(accentColor)
                                        Text(symptom.displayName)
                                            .font(.system(size: 14))
                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                            .padding(16)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Cycle Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func insightTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    NavigationStack {
        MenstruationView()
    }
}
