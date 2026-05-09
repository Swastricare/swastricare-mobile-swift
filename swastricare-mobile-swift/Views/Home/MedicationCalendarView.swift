//
//  MedicationCalendarView.swift
//  swastricare-mobile-swift
//

import SwiftUI

struct MedicationCalendarView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: MedicationViewModel

    @State private var calendarMonth: Date = Calendar.current.startOfMonth(for: Date())
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var calendarData: [Date: Double?] = [:]
    @State private var dosesForSelected: [DoseRow] = []
    @State private var showAddMedication = false

    private let teal = Color(hex: "22C5A6")
    private let tealLight = Color(hex: "E8FAF6")

    struct DoseRow: Identifiable {
        let id = UUID()
        let medicationName: String
        let dosage: String
        let scheduledTime: Date
        let status: AdherenceStatus
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    topBar
                    monthCalendar
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    Spacer().frame(height: 8)
                    dayHeader
                    if dosesForSelected.isEmpty {
                        Text("No medications scheduled")
                            .font(.poppins(.regular, size: 15))
                            .foregroundColor(Color(hex: "AAAAAA"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(dosesForSelected) { dose in
                                doseRow(dose)
                            }
                        }
                    }
                    Spacer().frame(height: 100)
                }
            }

            addMedicationFab
                .padding(.bottom, 16)
        }
        .sheet(isPresented: $showAddMedication) {
            AddMedicationView(viewModel: viewModel)
        }
        .task { reloadCalendar() }
        .onChange(of: calendarMonth) { _, _ in reloadCalendar() }
        .onChange(of: selectedDate) { _, _ in reloadDoses() }
        .onChange(of: viewModel.medications.count) { _, _ in reloadCalendar() }
        .trackScreen("MedicationCalendar")
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 0) {
            Button(action: { dismiss() }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1A2E"))
                    .frame(width: 44, height: 44)
            }
            Text("Medication Calendar")
                .font(.poppins(.bold, size: 20))
                .foregroundColor(Color(hex: "1A1A2E"))
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    // MARK: - Month Calendar

    private var monthCalendar: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let canGoNext = calendarMonth < cal.startOfMonth(for: today)

        return VStack(spacing: 0) {
            HStack {
                Button { navigateMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(teal)
                        .frame(width: 36, height: 36)
                }
                Spacer()
                Text(monthTitle)
                    .font(.poppins(.bold, size: 18))
                    .foregroundColor(Color(hex: "1A1A2E"))
                Spacer()
                Button { if canGoNext { navigateMonth(1) } } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(canGoNext ? teal : Color(hex: "CCCCCC"))
                        .frame(width: 36, height: 36)
                }
                .disabled(!canGoNext)
            }
            .padding(.bottom, 4)

            HStack(spacing: 0) {
                ForEach(["Sun","Mon","Tue","Wed","Thu","Fri","Sat"], id: \.self) { d in
                    Text(d)
                        .font(.poppins(.semiBold, size: 12))
                        .foregroundColor(Color(hex: "888888"))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 8)

            calendarGrid
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(tealLight)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var calendarGrid: some View {
        let cal = Calendar.current
        let firstOfMonth = calendarMonth
        let weekday = cal.component(.weekday, from: firstOfMonth) // 1=Sun
        let startOffset = weekday - 1
        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        let totalCells = startOffset + daysInMonth
        let rows = (totalCells + 6) / 7
        let today = cal.startOfDay(for: Date())

        return VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let cellIdx = row * 7 + col
                        let dayNum = cellIdx - startOffset + 1
                        if dayNum < 1 || dayNum > daysInMonth {
                            Color.clear.frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                        } else {
                            let date = cal.date(byAdding: .day, value: dayNum - 1, to: firstOfMonth)!
                            calendarCell(
                                day: dayNum,
                                date: date,
                                isToday: cal.isDate(date, inSameDayAs: today),
                                isSelected: cal.isDate(date, inSameDayAs: selectedDate),
                                isFuture: date > today,
                                adherence: calendarData[cal.startOfDay(for: date)] ?? nil
                            )
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
    }

    private func calendarCell(day: Int, date: Date, isToday: Bool, isSelected: Bool, isFuture: Bool, adherence: Double?) -> some View {
        let textColor: Color = {
            if isSelected { return .white }
            if isToday { return teal }
            if isFuture { return Color(hex: "CCCCCC") }
            return Color(hex: "333333")
        }()
        let bgColor: Color = {
            if isSelected { return teal }
            if isToday { return teal.opacity(0.1) }
            return .clear
        }()
        let dotColor: Color = {
            guard let pct = adherence else { return .clear }
            if pct >= 1.0 { return teal }
            if pct > 0 { return Color(hex: "FFB347") }
            return Color(hex: "FF6B6B")
        }()

        return Button {
            if !isFuture {
                selectedDate = Calendar.current.startOfDay(for: date)
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.poppins(isSelected || isToday ? .bold : .regular, size: 14))
                    .foregroundColor(textColor)
                if dotColor != .clear {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.85) : dotColor)
                        .frame(width: 4, height: 4)
                } else {
                    Color.clear.frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(2)
            .background(bgColor)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    // MARK: - Day Header + Doses

    private var dayHeader: some View {
        HStack {
            Text(selectedDayLabel)
                .font(.poppins(.bold, size: 16))
                .foregroundColor(Color(hex: "1A1A2E"))
            Spacer()
            Text("\(dosesForSelected.count) Medication\(dosesForSelected.count == 1 ? "" : "s")")
                .font(.poppins(.medium, size: 13))
                .foregroundColor(teal)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func doseRow(_ dose: DoseRow) -> some View {
        let isTaken = dose.status == .taken || dose.status == .late || dose.status == .early
        let isSkipped = dose.status == .skipped
        return HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(timeStr(dose.scheduledTime))
                    .font(.poppins(.bold, size: 14))
                    .foregroundColor(Color(hex: "333333"))
                Text(amPm(dose.scheduledTime))
                    .font(.poppins(.regular, size: 11))
                    .foregroundColor(Color(hex: "888888"))
            }
            .frame(width: 70)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dose.medicationName)
                        .font(.poppins(.semiBold, size: 15))
                        .foregroundColor(Color(hex: "1A1A2E"))
                    if !dose.dosage.isEmpty {
                        Text(dose.dosage)
                            .font(.poppins(.regular, size: 12))
                            .foregroundColor(Color(hex: "888888"))
                    }
                }
                Spacer()
                Image(systemName: isTaken ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isTaken ? teal : (isSkipped ? Color(hex: "FF9500") : Color(hex: "CCCCCC")))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isTaken ? tealLight : Color(hex: "F8F8F8"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }

    // MARK: - FAB

    private var addMedicationFab: some View {
        Button { showAddMedication = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("Add Medication")
                    .font(.poppins(.semiBold, size: 14))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(teal)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: teal.opacity(0.3), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: calendarMonth)
    }

    private var selectedDayLabel: String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if cal.isDate(selectedDate, inSameDayAs: today) { return "Today" }
        if let yest = cal.date(byAdding: .day, value: -1, to: today),
           cal.isDate(selectedDate, inSameDayAs: yest) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM"
        return f.string(from: selectedDate)
    }

    private func navigateMonth(_ delta: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: delta, to: calendarMonth) {
            calendarMonth = Calendar.current.startOfMonth(for: newMonth)
        }
    }

    private func reloadCalendar() {
        let cal = Calendar.current
        let svc = MedicationService.shared
        let monthStart = calendarMonth
        let daysInMonth = cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let today = cal.startOfDay(for: Date())

        var data: [Date: Double?] = [:]
        for i in 0..<daysInMonth {
            guard let date = cal.date(byAdding: .day, value: i, to: monthStart) else { continue }
            let dayStart = cal.startOfDay(for: date)
            if dayStart > today {
                data[dayStart] = .some(nil)
                continue
            }
            let activeIds = Set(svc.getActiveMedications(for: date).map { $0.id })
            let records = svc.loadAdherenceRecords(for: nil, date: date).filter { activeIds.contains($0.medicationId) }
            if records.isEmpty {
                data[dayStart] = .some(nil)
            } else {
                let pct = AdherenceStatistics(adherenceRecords: records).adherencePercentage / 100.0
                data[dayStart] = pct
            }
        }
        calendarData = data
        reloadDoses()
    }

    private func reloadDoses() {
        let svc = MedicationService.shared
        let activeMeds = svc.getActiveMedications(for: selectedDate)
        let nameById = Dictionary(uniqueKeysWithValues: activeMeds.map { ($0.id, ($0.name, $0.dosage)) })
        let activeIds = Set(activeMeds.map { $0.id })
        let records = svc.loadAdherenceRecords(for: nil, date: selectedDate).filter { activeIds.contains($0.medicationId) }
        let rows = records
            .compactMap { rec -> DoseRow? in
                guard let info = nameById[rec.medicationId] else { return nil }
                return DoseRow(
                    medicationName: info.0,
                    dosage: info.1,
                    scheduledTime: rec.scheduledTime,
                    status: rec.status
                )
            }
            .sorted { $0.scheduledTime < $1.scheduledTime }
        dosesForSelected = rows
    }

    private func timeStr(_ d: Date) -> String {
        let cal = Calendar.current
        let h = cal.component(.hour, from: d)
        let m = cal.component(.minute, from: d)
        let dh = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return String(format: "%d:%02d", dh, m)
    }

    private func amPm(_ d: Date) -> String {
        Calendar.current.component(.hour, from: d) < 12 ? "AM" : "PM"
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}

#Preview {
    MedicationCalendarView(viewModel: MedicationViewModel())
}
