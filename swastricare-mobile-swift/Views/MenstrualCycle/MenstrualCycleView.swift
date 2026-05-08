//
//  MenstrualCycleView.swift
//  swastricare-mobile-swift
//
//  Android-parity Cycle Tracker screen.
//

import SwiftUI

// MARK: - Color constants (matching Android hex values)
private let cyclePink   = Color(hex: "E91E63")
private let cyclePurple = Color(hex: "9C27B0")
private let cycleOrange = Color(hex: "FF9800")
private let cycleGreen  = Color(hex: "4CAF50")
private let cycleBlue   = Color(hex: "2196F3")

private func blobMatchColor(_ phase: CyclePhase) -> Color {
    switch phase {
    case .menstrual:  return Color(hex: "5B8DEF")
    case .follicular: return Color(hex: "FFAA33")
    case .ovulation:  return Color(hex: "FFCC02")
    case .luteal:     return Color(hex: "9B8EC4")
    case .pms:        return Color(hex: "E91E63")
    case .unknown:    return Color(hex: "A0A0A0")
    }
}

private func phaseBackground(_ phase: CyclePhase) -> Color {
    switch phase {
    case .menstrual:  return Color(hex: "FFF0F4")
    case .follicular: return Color(hex: "F0FFF5")
    case .ovulation:  return Color(hex: "EFF8FF")
    case .luteal:     return Color(hex: "F5F0FF")
    case .pms:        return Color(hex: "FFF0F4")
    case .unknown:    return Color(hex: "F8F8F8")
    }
}

struct PhaseTip {
    let icon: String
    let title: String
    let description: String
}

private func tipsForPhase(_ phase: CyclePhase) -> [PhaseTip] {
    switch phase {
    case .menstrual:
        return [
            PhaseTip(icon: "🧘", title: "Gentle Movement", description: "Try light yoga or stretching to ease cramps and boost circulation."),
            PhaseTip(icon: "🍲", title: "Iron-Rich Meals", description: "Eat spinach, lentils, and red meat to replenish iron lost during menstruation."),
            PhaseTip(icon: "☕", title: "Warm Beverages", description: "Herbal teas like ginger or chamomile can soothe cramps and calm the mind."),
            PhaseTip(icon: "🛌", title: "Rest & Recovery", description: "Honor your body's need for rest. Sleep 7–9 hours and avoid overexertion.")
        ]
    case .follicular:
        return [
            PhaseTip(icon: "🏋️", title: "High-Intensity Training", description: "Your rising estrogen boosts strength and endurance. Push your limits!"),
            PhaseTip(icon: "🥦", title: "Eat Fresh & Light", description: "Focus on fermented foods, lean proteins, and fresh vegetables."),
            PhaseTip(icon: "💡", title: "Start New Projects", description: "Creativity peaks in this phase. Great time for brainstorming and planning."),
            PhaseTip(icon: "💧", title: "Hydrate Well", description: "Drink at least 2–3 liters of water daily to support cell renewal.")
        ]
    case .ovulation:
        return [
            PhaseTip(icon: "⚡", title: "Peak Performance", description: "Your body is at peak physical capacity. Try HIIT, running, or group sports."),
            PhaseTip(icon: "🥑", title: "Healthy Fats", description: "Avocados, nuts, and olive oil support hormone production during ovulation."),
            PhaseTip(icon: "🌞", title: "Social Connection", description: "Confidence and communication skills are at their best. Plan social events."),
            PhaseTip(icon: "🌡️", title: "Track Temperature", description: "Monitor basal body temperature for fertility awareness.")
        ]
    case .luteal, .pms:
        return [
            PhaseTip(icon: "🚶", title: "Moderate Exercise", description: "Switch to walking, Pilates, or swimming as energy levels start to dip."),
            PhaseTip(icon: "🍫", title: "Magnesium-Rich Foods", description: "Dark chocolate, bananas, and almonds help combat PMS and cravings."),
            PhaseTip(icon: "😴", title: "Prioritize Sleep", description: "Progesterone may cause drowsiness. Aim for consistent sleep patterns."),
            PhaseTip(icon: "🧘‍♀️", title: "Stress Management", description: "Practice deep breathing or meditation to manage mood swings.")
        ]
    case .unknown:
        return [
            PhaseTip(icon: "📅", title: "Log Your Period", description: "Track your first day to get phase predictions and personalized tips."),
            PhaseTip(icon: "📊", title: "Track Symptoms", description: "Log symptoms daily to identify patterns across your cycle.")
        ]
    }
}

// MARK: - Main View

struct MenstrualCycleView: View {
    @StateObject private var viewModel = MenstrualCycleViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var weekOffset = 0
    @State private var ringAppeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                        .tint(cyclePink)
                } else if viewModel.cycles.filter({ !$0.isPredicted }).isEmpty {
                    onboardingContent
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            weekCalendarStrip
                                .padding(.horizontal, 16)

                            ringCard
                                .padding(.horizontal, 16)

                            pregnancyChancesCard
                                .padding(.horizontal, 16)

                            phaseInfoCard
                                .padding(.horizontal, 16)

                            tipsSection
                                .padding(.horizontal, 16)

                            if viewModel.statistics != nil {
                                statsCard
                                    .padding(.horizontal, 16)
                            }

                            Spacer().frame(height: 40)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Cycle Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { viewModel.showSettingsSheet = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17))
                            .foregroundStyle(.primary.opacity(0.8))
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddPeriodSheet) { AddPeriodSheet(viewModel: viewModel) }
            .sheet(isPresented: $viewModel.showDailyLogSheet) { DailyLogSheet(viewModel: viewModel, date: viewModel.selectedDate) }
            .sheet(isPresented: $viewModel.showSettingsSheet) { CycleSettingsSheet(viewModel: viewModel) }
            .sheet(isPresented: $viewModel.showStatsSheet) { CycleStatisticsSheet(viewModel: viewModel) }
            .task { await viewModel.onAppear() }
            .refreshable { await viewModel.refresh() }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear {
                withAnimation(.spring(response: 1.2, dampingFraction: 0.75).delay(0.1)) { ringAppeared = true }
            }
            .onChange(of: weekOffset) { _, _ in
                let cal = Calendar.current
                let today = cal.startOfDay(for: Date())
                let weekday = cal.component(.weekday, from: today) - 1
                let baseSunday = cal.date(byAdding: .day, value: -weekday, to: today)!
                let weekStart = cal.date(byAdding: .weekOfYear, value: weekOffset, to: baseSunday)!
                // Reload calendar data if we've navigated outside the current 3-month window
                let diff = cal.dateComponents([.month], from: viewModel.selectedMonth, to: weekStart).month ?? 0
                if abs(diff) > 1 {
                    viewModel.selectedMonth = weekStart
                }
            }
        }
        .trackScreen("MenstrualCycle")
    }

    // MARK: - Week Calendar Strip

    private var weekCalendarStrip: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekdayIdx = cal.component(.weekday, from: today) - 1
        guard let baseSunday = cal.date(byAdding: .day, value: -weekdayIdx, to: today),
              let weekStart = cal.date(byAdding: .weekOfYear, value: weekOffset, to: baseSunday) else {
            return AnyView(EmptyView())
        }
        let weekDays = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
        let dayLetters = ["S","M","T","W","T","F","S"]
        let monthLabel = weekStart.formatted(.dateTime.month(.abbreviated).year())

        return AnyView(
            VStack(spacing: 10) {
                HStack {
                    Button { withAnimation { weekOffset -= 1 } } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                    }
                    Spacer()
                    Text(monthLabel)
                        .font(.poppins(.semiBold, size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button { withAnimation { weekOffset += 1 } } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                    }
                }
                .padding(.horizontal, 8)

                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { idx in
                        if idx < weekDays.count {
                            CycleDayCell(
                                day: weekDays[idx],
                                letter: dayLetters[idx],
                                calendarData: viewModel.calendarData,
                                onTap: { day in
                                    viewModel.selectDate(day)
                                    viewModel.showDailyLogSheet = true
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
        )
    }

    // MARK: - Ring Card

    private var ringCard: some View {
        let phase = viewModel.currentPhase
        let blobColor = blobMatchColor(phase)
        let progress = CGFloat(viewModel.cycleProgress)

        return VStack(spacing: 12) {
            ZStack {
                // Blob ring canvas
                CycleRingView(progress: ringAppeared ? progress : 0, blobColor: blobColor)
                    .frame(width: 260, height: 260)

                // Center content
                VStack(spacing: 2) {
                    Text("Day")
                        .font(.poppins(.regular, size: 12))
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.dayOfCycle)")
                        .font(.poppins(.bold, size: 48))
                        .foregroundStyle(blobColor)
                        .contentTransition(.numericText())
                    Text(phase.rawValue)
                        .font(.poppins(.regular, size: 14))
                        .foregroundStyle(.secondary)
                    Spacer().frame(height: 4)
                    Image.androidIllustration(phase.blobName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                }
            }
            .frame(height: 300)

            // Legend
            HStack(spacing: 20) {
                LegendRow(color: cyclePink, label: "Period phase")
                LegendRow(color: cycleOrange.opacity(0.6), label: "Fertile window")
            }

            // Buttons
            HStack(spacing: 12) {
                Button { viewModel.showAddPeriodSheet = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 14, weight: .semibold))
                        Text("Log Period").font(.poppins(.semiBold, size: 14))
                    }
                    .foregroundStyle(cyclePink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(cyclePink.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())

                Button { viewModel.showStatsSheet = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar").font(.system(size: 14, weight: .semibold))
                        Text("View Calendar").font(.poppins(.semiBold, size: 14))
                    }
                    .foregroundStyle(cyclePurple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(cyclePurple.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
    }

    // MARK: - Pregnancy Chances Card

    private var pregnancyChancesCard: some View {
        let (label, color, emoji) = pregnancyChance(viewModel.currentPhase)
        return HStack {
            HStack(spacing: 10) {
                Text(emoji).font(.system(size: 22))
                Text("Chances of Pregnancy")
                    .font(.poppins(.medium, size: 14))
                    .foregroundStyle(.primary)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(label)
                    .font(.poppins(.semiBold, size: 13))
                    .foregroundStyle(color)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
    }

    private func pregnancyChance(_ phase: CyclePhase) -> (String, Color, String) {
        switch phase {
        case .ovulation:  return ("High",   cyclePink,   "🥚")
        case .follicular: return ("Medium",  cycleOrange, "🌱")
        default:          return ("Low",     cycleGreen,  "🌙")
        }
    }

    // MARK: - Phase Info Card

    private var phaseInfoCard: some View {
        let phase = viewModel.currentPhase
        let accent = blobMatchColor(phase)

        return VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(accent.opacity(0.12)).frame(width: 44, height: 44)
                    Text(phase.emojiIcon).font(.system(size: 22))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(phase.rawValue + " Phase")
                        .font(.poppins(.semiBold, size: 16))
                        .foregroundStyle(accent)
                    Text("Current Phase")
                        .font(.poppins(.regular, size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            // Gradient divider
            LinearGradient(colors: [accent, accent.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
                .frame(height: 3)
                .clipShape(Capsule())

            // Description
            Text(phase.description)
                .font(.poppins(.regular, size: 14))
                .foregroundStyle(.primary.opacity(0.85))
                .lineSpacing(4)

            if !phase.symptoms.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Typical Symptoms")
                        .font(.poppins(.semiBold, size: 13))
                        .foregroundStyle(.primary)
                    ForEach(phase.symptoms, id: \.self) { symptom in
                        HStack(alignment: .center, spacing: 8) {
                            Circle().fill(accent).frame(width: 6, height: 6)
                            Text(symptom)
                                .font(.poppins(.regular, size: 13))
                                .foregroundStyle(.primary.opacity(0.8))
                        }
                    }
                }
            }

            if !phase.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recommendations")
                        .font(.poppins(.semiBold, size: 13))
                        .foregroundStyle(.primary)
                    ForEach(Array(phase.recommendations.enumerated()), id: \.offset) { idx, rec in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(idx + 1).")
                                .font(.poppins(.semiBold, size: 13))
                                .foregroundStyle(accent)
                            Text(rec)
                                .font(.poppins(.regular, size: 13))
                                .foregroundStyle(.primary.opacity(0.8))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        let tips = tipsForPhase(viewModel.currentPhase)
        let phase = viewModel.currentPhase
        let accent = blobMatchColor(phase)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Phase Tips")
                .font(.poppins(.semiBold, size: 16))
                .foregroundStyle(.primary)

            ForEach(Array(tips.enumerated()), id: \.offset) { idx, tip in
                CycleTipCard(tip: tip, accent: accent, delay: Double(idx) * 0.1)
            }
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        guard let stats = viewModel.statistics else { return AnyView(EmptyView()) }

        let lastText: String = {
            guard let cycle = viewModel.cycles.filter({ !$0.isPredicted }).first else { return "--" }
            let days = abs(Calendar.current.dateComponents([.day], from: cycle.startDate, to: Date()).day ?? 0)
            return "\(days)d ago"
        }()
        let nextText: String = {
            guard let pred = viewModel.prediction else { return "--" }
            let days = pred.daysUntilPeriod
            return days <= 0 ? "Today" : "in \(days)d"
        }()
        let regColor = regularityColor(stats.cycleRegularity)

        return AnyView(
            Button { viewModel.showStatsSheet = true } label: {
                VStack(spacing: 16) {
                    HStack {
                        Text("Cycle Statistics").font(.poppins(.semiBold, size: 16)).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(.secondary)
                    }

                    HStack {
                        CycleStatItem(label: "Avg Cycle", value: "\(Int(stats.averageCycleLength)) days", color: cyclePurple)
                        CycleStatItem(label: "Avg Period", value: "\(Int(stats.averagePeriodLength)) days", color: cyclePink)
                    }
                    HStack {
                        CycleStatItem(label: "Last Period", value: lastText, color: cyclePink)
                        CycleStatItem(label: "Next Period", value: nextText, color: cycleOrange)
                    }

                    Text(stats.cycleRegularity)
                        .font(.poppins(.semiBold, size: 13))
                        .foregroundStyle(regColor)
                        .padding(.horizontal, 16).padding(.vertical, 6)
                        .background(regColor.opacity(0.12))
                        .clipShape(Capsule())
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
            }
            .buttonStyle(ScaleButtonStyle())
        )
    }

    private func regularityColor(_ regularity: String) -> Color {
        switch regularity {
        case "Very Regular", "Regular": return cycleGreen
        case "Somewhat Irregular":      return cycleOrange
        default:                        return cyclePink
        }
    }

    // MARK: - Onboarding

    private var onboardingContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer().frame(height: 24)

                Text("Track Your Cycle")
                    .font(.poppins(.bold, size: 22))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("Log your period to get predictions for your next cycle, fertile window, and ovulation day.")
                    .font(.poppins(.regular, size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)

                VStack(spacing: 16) {
                    OnboardingRow(icon: "📅", title: "Period Tracking", desc: "Log start and end dates of your period")
                    OnboardingRow(icon: "🔮", title: "Cycle Predictions", desc: "Get accurate predictions for your next period")
                    OnboardingRow(icon: "🥚", title: "Fertility Window", desc: "Know your most fertile days and ovulation")
                    OnboardingRow(icon: "📈", title: "Cycle Insights", desc: "Track patterns with statistics and charts")
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
                .padding(.horizontal, 16)

                Button { viewModel.showAddPeriodSheet = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 16, weight: .semibold))
                        Text("Log Your Period").font(.poppins(.semiBold, size: 16))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(cyclePink)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 16)

                Text("You can always edit this later")
                    .font(.poppins(.regular, size: 12))
                    .foregroundStyle(.secondary)

                Spacer().frame(height: 40)
            }
        }
    }
}

// MARK: - Cycle Ring (Canvas-based, matching Android)

private struct CycleRingView: View {
    let progress: CGFloat
    let blobColor: Color

    var body: some View {
        Canvas { ctx, size in
            let strokeW: CGFloat = 12
            let radius = (min(size.width, size.height) - strokeW) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            // Soft fill inside ring
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - radius * 0.88,
                                             y: center.y - radius * 0.88,
                                             width: radius * 1.76, height: radius * 1.76)),
                     with: .color(blobColor.opacity(0.06)))

            // Track ring
            var track = Path()
            track.addArc(center: center, radius: radius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            ctx.stroke(track, with: .color(.gray.opacity(0.12)), style: StrokeStyle(lineWidth: strokeW, lineCap: .round))

            // Progress arc
            let sweep = progress * 360.0
            if sweep > 0 {
                var arc = Path()
                arc.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(-90 + sweep), clockwise: false)
                ctx.stroke(arc, with: .color(blobColor), style: StrokeStyle(lineWidth: strokeW, lineCap: .round))

                // End dot
                let endAngle = (-90.0 + sweep) * .pi / 180.0
                let dotX = center.x + radius * cos(endAngle)
                let dotY = center.y + radius * sin(endAngle)
                ctx.fill(Path(ellipseIn: CGRect(x: dotX - strokeW/2 - 2, y: dotY - strokeW/2 - 2, width: strokeW + 4, height: strokeW + 4)), with: .color(.white))
                ctx.fill(Path(ellipseIn: CGRect(x: dotX - strokeW/2, y: dotY - strokeW/2, width: strokeW, height: strokeW)), with: .color(blobColor))
            }
        }
        .animation(.spring(response: 1.2, dampingFraction: 0.75), value: progress)
    }
}

private extension CyclePhase {
    var blobName: String {
        switch self {
        case .menstrual: return "blob_sad"
        case .follicular: return "blob_energetic"
        case .ovulation:  return "blob_happy"
        case .luteal:     return "blob_tired"
        case .pms:        return "blob_sad"
        case .unknown:    return "blob_neutral"
        }
    }
}

// MARK: - Supporting Views

private struct CycleDayCell: View {
    let day: Date
    let letter: String
    let calendarData: [CalendarDayData]
    let onTap: (Date) -> Void

    private var cal: Calendar { .current }

    private var isToday: Bool { cal.isDateInToday(day) }
    private var dayData: CalendarDayData? {
        calendarData.first { cal.isDate($0.date, inSameDayAs: day) }
    }
    private var isLogged: Bool { dayData?.isPeriodDay == true }
    private var isFertile: Bool { dayData?.isFertileDay == true }
    private var isPredicted: Bool { dayData?.isPredictedPeriod == true }

    private var bgColor: Color {
        if isToday   { return cycleBlue }
        if isLogged  { return cyclePink.opacity(0.8) }
        if isFertile { return cycleOrange.opacity(0.3) }
        if isPredicted { return cyclePink.opacity(0.2) }
        return .clear
    }
    private var textColor: Color { (isToday || isLogged) ? .white : .primary }

    var body: some View {
        VStack(spacing: 4) {
            Text(letter)
                .font(.poppins(.medium, size: 11))
                .foregroundStyle(isToday ? cycleBlue : .secondary)

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(bgColor)
                    .frame(width: 36, height: 36)
                Text("\(cal.component(.day, from: day))")
                    .font(.poppins(isToday || isLogged ? .bold : .regular, size: 14))
                    .foregroundStyle(textColor)
            }
            .onTapGesture { onTap(day) }

            Circle()
                .fill(isToday ? cycleBlue : .clear)
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LegendRow: View {
    let color: Color; let label: String
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.poppins(.regular, size: 12)).foregroundStyle(.secondary)
        }
    }
}

private struct CycleTipCard: View {
    let tip: PhaseTip; let accent: Color; let delay: Double
    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.opacity(0.10)).frame(width: 40, height: 40)
                Text(tip.icon).font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title).font(.poppins(.semiBold, size: 13)).foregroundStyle(.primary)
                Text(tip.description)
                    .font(.poppins(.regular, size: 12))
                    .foregroundStyle(.primary.opacity(0.7))
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay)) { appeared = true }
        }
    }
}

private struct CycleStatItem: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(label).font(.poppins(.regular, size: 11)).foregroundStyle(.secondary)
            Text(value).font(.poppins(.semiBold, size: 15)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct OnboardingRow: View {
    let icon: String; let title: String; let desc: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cyclePink.opacity(0.10)).frame(width: 44, height: 44)
                Text(icon).font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.poppins(.semiBold, size: 14)).foregroundStyle(.primary)
                Text(desc).font(.poppins(.regular, size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
        }
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
                        ForEach(FlowIntensity.allCases) { i in
                            HStack { Image(systemName: i.icon); Text(i.displayName) }.tag(i)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Notes (Optional)") {
                    TextField("Any notes about this period", text: $notes, axis: .vertical).lineLimit(3...6)
                }
            }
            .navigationTitle("Log Period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await viewModel.startPeriod(date: startDate, flowIntensity: flowIntensity, notes: notes.isEmpty ? nil : notes); dismiss() }
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
                            HStack { Image(systemName: level.icon); Text(level.displayName) }.tag(FlowLevel?.some(level))
                        }
                    }
                }
                Section("Mood") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(CycleMood.allCases) { mood in
                                MoodButton(mood: mood, isSelected: log.mood == mood) { log.mood = (log.mood == mood) ? nil : mood }
                            }
                        }.padding(.vertical, 4)
                    }
                }
                Section("Pain Level") {
                    VStack {
                        Slider(value: Binding(get: { Double(log.painLevel ?? 0) }, set: { log.painLevel = Int($0) }), in: 0...10, step: 1)
                        HStack {
                            Text("None").font(.poppins(.regular, size: 12)).foregroundColor(.secondary)
                            Spacer()
                            Text("\(log.painLevel ?? 0)").font(.poppins(.semiBold, size: 17)).foregroundColor(.pink)
                            Spacer()
                            Text("Severe").font(.poppins(.regular, size: 12)).foregroundColor(.secondary)
                        }
                    }
                }
                Section("Energy Level") {
                    VStack {
                        Slider(value: Binding(get: { Double(log.energyLevel ?? 5) }, set: { log.energyLevel = Int($0) }), in: 0...10, step: 1)
                        HStack {
                            Text("Low").font(.poppins(.regular, size: 12)).foregroundColor(.secondary)
                            Spacer()
                            Text("\(log.energyLevel ?? 5)").font(.poppins(.semiBold, size: 17)).foregroundColor(.orange)
                            Spacer()
                            Text("High").font(.poppins(.regular, size: 12)).foregroundColor(.secondary)
                        }
                    }
                }
                Section("Symptoms") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(SymptomType.allCases) { symptom in
                            SymptomButton(symptom: symptom, isSelected: selectedSymptoms.contains(symptom)) {
                                if selectedSymptoms.contains(symptom) { selectedSymptoms.remove(symptom) } else { selectedSymptoms.insert(symptom) }
                            }
                        }
                    }
                }
                Section("Sleep Quality") {
                    Picker("Sleep", selection: $log.sleepQuality) {
                        Text("Not logged").tag(SleepQuality?.none)
                        ForEach(SleepQuality.allCases) { q in
                            HStack { Image(systemName: q.icon); Text(q.displayName) }.tag(SleepQuality?.some(q))
                        }
                    }.pickerStyle(.segmented)
                }
                Section("Notes") {
                    TextField("Any notes for today", text: Binding(get: { log.notes ?? "" }, set: { log.notes = $0.isEmpty ? nil : $0 }), axis: .vertical).lineLimit(3...6)
                }
            }
            .navigationTitle(date.formatted(.dateTime.month(.abbreviated).day().year()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        log.symptoms = selectedSymptoms.map { MenstrualSymptom(symptomType: $0) }
                        Task { await viewModel.saveDailyLog(log); dismiss() }
                    }
                }
            }
        }
    }
}

struct MoodButton: View {
    let mood: CycleMood; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(mood.emoji).font(.poppins(.bold, size: 22)).scaleEffect(isSelected ? 1.2 : 1.0)
                Text(mood.displayName).font(.poppins(.regular, size: 11))
            }
            .padding(8)
            .background(isSelected ? Color.pink.opacity(0.2) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.pink : Color.clear, lineWidth: 2))
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct SymptomButton: View {
    let symptom: SymptomType; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symptom.icon).font(.poppins(.regular, size: 12))
                Text(symptom.displayName).font(.poppins(.regular, size: 12))
            }
            .padding(.horizontal, 10).padding(.vertical, 8).frame(maxWidth: .infinity)
            .background(isSelected ? Color.pink.opacity(0.2) : Color(.systemGray6))
            .foregroundColor(isSelected ? .pink : .primary)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.pink : Color.clear, lineWidth: 1))
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
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await viewModel.saveSettings(settings); dismiss() } }
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
                        VStack(spacing: 16) {
                            Text("Cycle Overview").font(.poppins(.semiBold, size: 17))
                            HStack(spacing: 20) {
                                StatisticItem(title: "Avg Cycle", value: String(format: "%.1f", stats.averageCycleLength), unit: "days", color: .pink)
                                StatisticItem(title: "Avg Period", value: String(format: "%.1f", stats.averagePeriodLength), unit: "days", color: .red)
                            }
                            HStack(spacing: 20) {
                                StatisticItem(title: "Shortest", value: "\(stats.shortestCycle)", unit: "days", color: .blue)
                                StatisticItem(title: "Longest", value: "\(stats.longestCycle)", unit: "days", color: .orange)
                            }
                            VStack(spacing: 4) {
                                Text("Regularity").font(.poppins(.regular, size: 12)).foregroundColor(.secondary)
                                Text(stats.cycleRegularity).font(.poppins(.bold, size: 20)).foregroundColor(.purple)
                            }
                            .padding().frame(maxWidth: .infinity).background(Color.purple.opacity(0.1)).cornerRadius(12)
                        }
                        .padding().background(Color(.systemBackground)).cornerRadius(16)

                        if !stats.mostCommonSymptoms.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Most Common Symptoms").font(.poppins(.semiBold, size: 17))
                                ForEach(stats.mostCommonSymptoms.prefix(5), id: \.self) { symptom in
                                    HStack { Image(systemName: symptom.icon).foregroundColor(.pink); Text(symptom.displayName); Spacer() }.padding(.vertical, 4)
                                }
                            }
                            .padding().background(Color(.systemBackground)).cornerRadius(16)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Cycle History").font(.poppins(.semiBold, size: 17))
                            ForEach(viewModel.cycles.filter { !$0.isPredicted }.prefix(10)) { cycle in
                                CycleHistoryRow(cycle: cycle)
                            }
                        }
                        .padding().background(Color(.systemBackground)).cornerRadius(16)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "chart.bar.xaxis").font(.poppins(.regular, size: 48)).foregroundColor(.secondary)
                            Text("Not Enough Data").font(.poppins(.semiBold, size: 17))
                            Text("Log at least 2 complete cycles to see statistics")
                                .font(.poppins(.regular, size: 15)).foregroundColor(.secondary).multilineTextAlignment(.center)
                        }.padding(40)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

struct StatisticItem: View {
    let title: String; let value: String; let unit: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.poppins(.regular, size: 12)).foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.poppins(.bold, size: 22)).foregroundColor(color)
                Text(unit).font(.poppins(.regular, size: 12)).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity).padding().background(color.opacity(0.1)).cornerRadius(12)
    }
}

struct CycleHistoryRow: View {
    let cycle: MenstrualCycle
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(cycle.startDate.formatted(.dateTime.month(.abbreviated).day().year())).font(.poppins(.regular, size: 15))
                if let length = cycle.cycleLength { Text("\(length) day cycle").font(.poppins(.regular, size: 12)).foregroundColor(.secondary) }
            }
            Spacer()
            if let period = cycle.periodLength {
                Text("\(period)d period").font(.poppins(.regular, size: 12)).foregroundColor(.red)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(Color.red.opacity(0.1)).cornerRadius(8)
            }
        }.padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview { MenstrualCycleView() }
