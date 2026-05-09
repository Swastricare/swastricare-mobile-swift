//
//  MedicationAnalyticsView.swift
//  swastricare-mobile-swift
//

import SwiftUI
import Charts

struct MedicationAnalyticsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: MedicationViewModel

    @State private var selectedPeriod: AnalyticsPeriod = .month
    @State private var trendData: [DayAdherence] = []

    private let accent = AppColors.accentBlue
    private let bg = Color(hex: "E8F8F5")

    enum AnalyticsPeriod: String, CaseIterable {
        case week = "This Week"
        case month = "This Month"
        case threeMonths = "3 Months"
        var days: Int { self == .week ? 7 : self == .month ? 30 : 90 }
    }

    struct DayAdherence: Identifiable {
        let id = UUID()
        let date: Date
        let percentage: Double
    }

    private var stats: AdherenceStatistics? { viewModel.adherenceStatistics }
    private var adherencePct: Int { Int(stats?.adherencePercentage ?? 0) }
    private var dosesTaken: Int  { stats?.takenDoses ?? 0 }
    private var daysOnTrack: Int { trendData.filter { $0.percentage >= 80 }.count }
    private var snoozed: Int     { stats?.skippedDoses ?? 0 }
    private var missed: Int      { stats?.missedDoses ?? 0 }
    private var total: Int       { stats?.totalDoses ?? 0 }
    private var upcoming: Int    { max(0, total - dosesTaken - missed) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Solid mint background
            bg.ignoresSafeArea()

            // Leaf illustration — top right corner
            VStack {
                HStack {
                    Spacer()
                    Image.androidIcon("background leaf illustration right")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 320)
                        .opacity(0.85)
                }
                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            // Content
            VStack(spacing: 0) {
                navBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        overviewSection
                        trendSection
                        donutSection
                        motivationBanner
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 40)
                }
            }
        }
        .task { await loadTrendData() }
        .onChange(of: selectedPeriod) { _, _ in Task { await loadTrendData() } }
        .trackScreen("MedicationAnalytics")
    }

    // MARK: - Nav Bar (back + title only)

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1A2E"))
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Text("Analytics")
                .font(.poppins(.bold, size: 20))
                .foregroundColor(Color(hex: "1A1A2E"))
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
    }

    // MARK: - Overview (header row has "This Month" button)

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Overview")
                    .font(.poppins(.bold, size: 18))
                    .foregroundColor(Color(hex: "1A1A2E"))
                Spacer()
                Menu {
                    ForEach(AnalyticsPeriod.allCases, id: \.self) { p in
                        Button(p.rawValue) { selectedPeriod = p }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedPeriod.rawValue)
                            .font(.poppins(.medium, size: 13))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(accent)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(accent.opacity(0.25), lineWidth: 1))
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                AStatCard(icon: "calendar.badge.checkmark", iconColor: accent,   value: "\(adherencePct)%", label: "Adherence")
                AStatCard(icon: "pills.fill",               iconColor: Color(hex: "FF9500"), value: "\(dosesTaken)",   label: "Doses Taken")
                AStatCard(icon: "checkmark.seal.fill",      iconColor: accent,   value: "\(daysOnTrack)",   label: "Days on Track")
                AStatCard(icon: "bell.badge.fill",          iconColor: accent,   value: "\(snoozed)",       label: "Reminders Snoozed")
            }
        }
    }

    // MARK: - Adherence Trend

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adherence Trend")
                .font(.poppins(.bold, size: 18))
                .foregroundColor(Color(hex: "1A1A2E"))

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 3)

                Group {
                    if trendData.isEmpty {
                        ProgressView().tint(accent).frame(height: 200)
                    } else {
                        trendChart.padding(.horizontal, 14).padding(.top, 16).padding(.bottom, 10)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var trendChart: some View {
        if #available(iOS 16.0, *) {
            Chart(trendData) { pt in
                AreaMark(x: .value("Date", pt.date), y: .value("%", pt.percentage))
                    .foregroundStyle(LinearGradient(
                        colors: [accent.opacity(0.35), accent.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Date", pt.date), y: .value("%", pt.percentage))
                    .foregroundStyle(accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: xStride)) { v in
                    AxisGridLine().foregroundStyle(Color(hex: "F0F0F0"))
                    AxisValueLabel {
                        if let d = v.as(Date.self) {
                            Text(xLabel(d)).font(.system(size: 10)).foregroundStyle(Color(hex: "AAAAAA"))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { v in
                    AxisGridLine().foregroundStyle(Color(hex: "EEEEEE"))
                    AxisValueLabel {
                        if let n = v.as(Int.self) {
                            Text("\(n)%").font(.system(size: 10)).foregroundStyle(Color(hex: "AAAAAA"))
                        }
                    }
                }
            }
            .frame(height: 180)
        }
    }

    private var xStride: Int { selectedPeriod == .week ? 1 : selectedPeriod == .month ? 7 : 20 }
    private func xLabel(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = selectedPeriod == .threeMonths ? "MMM d" : "d MMM"; return f.string(from: d)
    }

    // MARK: - Donut

    private var donutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Medication Overview")
                .font(.poppins(.bold, size: 18))
                .foregroundColor(Color(hex: "1A1A2E"))

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 3)

                HStack(spacing: 20) {
                    ZStack {
                        ADonutChart(taken: Double(dosesTaken), missed: Double(missed),
                                    upcoming: Double(upcoming), accent: accent)
                            .frame(width: 130, height: 130)
                        VStack(spacing: 1) {
                            Text("\(total)")
                                .font(.poppins(.bold, size: 26))
                                .foregroundColor(Color(hex: "1A1A2E"))
                            Text("Total\nDoses")
                                .font(.poppins(.regular, size: 10))
                                .foregroundColor(Color(hex: "888888"))
                                .multilineTextAlignment(.center)
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        ALegendRow(color: accent,              label: "Taken",    count: dosesTaken, total: total)
                        ALegendRow(color: Color(hex: "FF3B30"), label: "Missed",   count: missed,     total: total)
                        ALegendRow(color: Color(hex: "CCCCCC"), label: "Upcoming", count: upcoming,   total: total)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.vertical, 20)
            }
        }
    }

    // MARK: - Motivation Banner

    private var motivationBanner: some View {
        let (title, msg): (String, String) = adherencePct >= 80
            ? ("Great job!", "You're building a healthy habit.")
            : adherencePct >= 50
            ? ("Keep going!", "Consistency is key to better health.")
            : ("Stay consistent!", "Every dose counts toward your wellbeing.")

        return HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 22))
                .foregroundColor(Color(hex: "F5A623"))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.poppins(.semiBold, size: 14))
                    .foregroundColor(Color(hex: "1A1A2E"))
                Text(msg)
                    .font(.poppins(.regular, size: 13))
                    .foregroundColor(Color(hex: "666666"))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "BBBBBB"))
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    // MARK: - Data

    private func loadTrendData() async {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let svc = MedicationService.shared
        var result: [DayAdherence] = []
        for i in stride(from: selectedPeriod.days - 1, through: 0, by: -1) {
            guard let date = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            let ids = Set(svc.getActiveMedications(for: date).map { $0.id })
            let records = svc.loadAdherenceRecords(for: nil, date: date).filter { ids.contains($0.medicationId) }
            let pct = records.isEmpty ? 0.0 : AdherenceStatistics(adherenceRecords: records).adherencePercentage
            result.append(DayAdherence(date: date, percentage: pct))
        }
        trendData = result
    }
}

// MARK: - Stat Card

private struct AStatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)
                }
                Text(value)
                    .font(.poppins(.bold, size: 22))
                    .foregroundColor(Color(hex: "1A1A2E"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            Text(label)
                .font(.poppins(.regular, size: 12))
                .foregroundColor(Color(hex: "888888"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}

// MARK: - Donut Chart

private struct ADonutChart: View {
    let taken: Double
    let missed: Double
    let upcoming: Double
    let accent: Color
    private var total: Double { max(taken + missed + upcoming, 1) }

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2, cy = size.height / 2
            let r = min(size.width, size.height) / 2 - 4
            let lw = r * 0.36
            let segments: [(Double, Color)] = [
                (taken,    accent),
                (missed,   Color(hex: "FF3B30")),
                (upcoming, Color(hex: "CCCCCC")),
            ]
            var start = -Double.pi / 2
            for (val, color) in segments {
                guard val > 0 else { continue }
                let sweep = (val / total) * 2 * Double.pi
                var path = Path()
                path.addArc(center: CGPoint(x: cx, y: cy), radius: r - lw / 2,
                            startAngle: .radians(start), endAngle: .radians(start + sweep - 0.04), clockwise: false)
                ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .butt))
                start += sweep
            }
        }
    }
}

// MARK: - Legend Row

private struct ALegendRow: View {
    let color: Color
    let label: String
    let count: Int
    let total: Int
    private var pct: Int { total > 0 ? Int(Double(count) / Double(total) * 100) : 0 }

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label)
                .font(.poppins(.medium, size: 13))
                .foregroundColor(Color(hex: "1A1A2E"))
            Spacer()
            Text("\(count) (\(pct)%)")
                .font(.poppins(.regular, size: 12))
                .foregroundColor(Color(hex: "888888"))
        }
    }
}

#Preview {
    MedicationAnalyticsView(viewModel: MedicationViewModel())
}
