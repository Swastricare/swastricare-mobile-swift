//
//  RunCalendarView.swift
//  swastricare-mobile-swift
//
//  Calendar view showing running activity dates
//  Updated with Movements+ UI design - lime green accent, dark theme
//

import SwiftUI

struct RunCalendarView: View {
    @Environment(\.colorScheme) var colorScheme
    
    let activities: [RouteActivity]
    @State private var selectedMonth: Date = Date()
    @State private var selectedDate: Date?
    @State private var calendarData: [CalendarRunData] = []
    @State private var isAnimating = false
    
    private let limeGreen = MovementsColors.limeGreen
    private let darkGreen = MovementsColors.darkGreen
    private let analyticsService = RunAnalyticsService.shared
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(spacing: 20) {
            // Month Navigation
            monthNavigationHeader
            
            // Calendar Grid
            calendarGrid
            
            // Selected Date Activities
            if let selectedDate = selectedDate {
                selectedDateActivities(for: selectedDate)
            }
            
            // Month Summary
            monthSummarySection
        }
        .padding(.horizontal, 20)
        .onAppear {
            generateCalendarData()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAnimating = true
            }
        }
        .onChange(of: selectedMonth) { _, _ in
            generateCalendarData()
        }
    }
    
    // MARK: - Month Navigation Header
    
    private var monthNavigationHeader: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(limeGreen)
                    .frame(width: 44, height: 44)
                    .background(limeGreen.opacity(0.15))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(monthYearString)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("\(activeDaysInMonth) active days")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(limeGreen)
            }
            
            Spacer()
            
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(canGoToNextMonth ? limeGreen : .gray)
                    .frame(width: 44, height: 44)
                    .background((canGoToNextMonth ? limeGreen : Color.gray).opacity(0.15))
                    .clipShape(Circle())
            }
            .disabled(!canGoToNextMonth)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 10)
    }
    
    // MARK: - Calendar Grid
    
    private var calendarGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 10)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 10) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        CalendarDayCell(
                            date: date,
                            calendarData: calendarDataForDate(date),
                            isSelected: isDateSelected(date),
                            isToday: calendar.isDateInToday(date),
                            colorScheme: colorScheme,
                            action: {
                                withAnimation(.spring(response: 0.3)) {
                                    if selectedDate == date {
                                        selectedDate = nil
                                    } else {
                                        selectedDate = date
                                    }
                                }
                                let generator = UISelectionFeedbackGenerator()
                                generator.selectionChanged()
                            }
                        )
                    } else {
                        Color.clear
                            .frame(height: 48)
                    }
                }
            }
        }
        .padding(18)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 15)
        .animation(.spring(response: 0.5).delay(0.1), value: isAnimating)
    }
    
    // MARK: - Selected Date Activities
    
    @ViewBuilder
    private func selectedDateActivities(for date: Date) -> some View {
        let dayData = calendarDataForDate(date)
        
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(formattedSelectedDate(date))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if dayData?.hasActivity == true {
                    Text(String(format: "%.1f km", dayData?.totalDistance ?? 0))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(limeGreen)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(limeGreen.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            
            if let dayData = dayData, dayData.hasActivity {
                ForEach(dayData.activities) { activity in
                    NavigationLink(destination: ActivityDetailView(activity: activity)) {
                        SelectedDateActivityRow(activity: activity, colorScheme: colorScheme)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "figure.run")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No activities")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text("Rest day or no tracked runs")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    
                    Spacer()
                }
                .padding(14)
            }
        }
        .padding(18)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - Month Summary Section
    
    private var monthSummarySection: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(limeGreen)
                
                Text("Monthly Summary")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            HStack(spacing: 14) {
                MonthSummaryCard(
                    title: "Total Distance",
                    value: String(format: "%.1f km", totalDistanceInMonth),
                    icon: "map.fill",
                    color: limeGreen,
                    colorScheme: colorScheme
                )
                
                MonthSummaryCard(
                    title: "Activities",
                    value: "\(totalActivitiesInMonth)",
                    icon: "figure.run",
                    color: Color(hex: "5AC8FA"),
                    colorScheme: colorScheme
                )
                
                MonthSummaryCard(
                    title: "Active Days",
                    value: "\(activeDaysInMonth)",
                    icon: "calendar",
                    color: .orange,
                    colorScheme: colorScheme
                )
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.spring(response: 0.5).delay(0.2), value: isAnimating)
    }
    
    // MARK: - Helper Methods
    
    private func generateCalendarData() {
        calendarData = analyticsService.generateCalendarData(activities: activities, for: selectedMonth)
    }
    
    private func calendarDataForDate(_ date: Date) -> CalendarRunData? {
        calendarData.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    private func isDateSelected(_ date: Date) -> Bool {
        guard let selectedDate = selectedDate else { return false }
        return calendar.isDate(date, inSameDayAs: selectedDate)
    }
    
    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedMonth),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday else {
            return []
        }
        
        var days: [Date?] = []
        
        // Add empty cells for days before the first day of month
        for _ in 1..<firstWeekday {
            days.append(nil)
        }
        
        // Add all days in the month
        var currentDate = monthInterval.start
        while currentDate < monthInterval.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }
    
    private func formattedSelectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: date)
    }
    
    private var canGoToNextMonth: Bool {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) else {
            return false
        }
        return nextMonth <= Date()
    }
    
    private func previousMonth() {
        withAnimation(.spring(response: 0.3)) {
            selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
            selectedDate = nil
        }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func nextMonth() {
        guard canGoToNextMonth else { return }
        withAnimation(.spring(response: 0.3)) {
            selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
            selectedDate = nil
        }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private var totalDistanceInMonth: Double {
        calendarData.reduce(0) { $0 + $1.totalDistance }
    }
    
    private var totalActivitiesInMonth: Int {
        calendarData.reduce(0) { $0 + $1.activityCount }
    }
    
    private var activeDaysInMonth: Int {
        calendarData.filter { $0.hasActivity }.count
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let calendarData: CalendarRunData?
    let isSelected: Bool
    let isToday: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(dayNumber)
                    .font(.system(size: 15, weight: isToday || isSelected ? .bold : .medium))
                    .foregroundColor(textColor)
                
                if let data = calendarData, data.hasActivity {
                    Circle()
                        .fill(intensityColor(data.intensityLevel))
                        .frame(width: 7, height: 7)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(width: 42, height: 48)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isToday && !isSelected ? limeGreen.opacity(0.6) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var textColor: Color {
        if isSelected {
            return .black
        } else if isToday {
            return limeGreen
        } else if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month) {
            return .primary
        } else {
            return .secondary
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return limeGreen
        } else {
            return Color.clear
        }
    }
    
    private func intensityColor(_ level: Int) -> Color {
        switch level {
        case 0: return .clear
        case 1: return limeGreen.opacity(0.3)
        case 2: return limeGreen.opacity(0.5)
        case 3: return limeGreen.opacity(0.7)
        case 4: return limeGreen.opacity(0.85)
        default: return limeGreen
        }
    }
}

// MARK: - Selected Date Activity Row

struct SelectedDateActivityRow: View {
    let activity: RouteActivity
    let colorScheme: ColorScheme
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(activity.type.color.opacity(0.15))
                    .frame(width: 46, height: 46)
                
                Image(systemName: activity.type.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(activity.type.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(activity.formattedTimeRange)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(activity.formattedDistance)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(limeGreen)
                
                Text(activity.formattedDuration)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(MovementsColors.card(for: colorScheme).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Month Summary Card

struct MonthSummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 38, height: 38)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Compact Calendar View (for embedding)

struct CompactRunCalendarView: View {
    @Environment(\.colorScheme) var colorScheme
    
    let activities: [RouteActivity]
    let onViewFullCalendar: () -> Void
    
    @State private var calendarData: [CalendarRunData] = []
    @State private var isAnimating = false
    
    private let limeGreen = MovementsColors.limeGreen
    private let analyticsService = RunAnalyticsService.shared
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(limeGreen)
                    
                    Text("Run Calendar")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: onViewFullCalendar) {
                    Text("View All")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(limeGreen)
                }
            }
            
            HStack(spacing: 5) {
                ForEach(last14Days, id: \.self) { date in
                    MiniCalendarDayCell(
                        date: date,
                        hasActivity: hasActivityOnDate(date),
                        isToday: calendar.isDateInToday(date)
                    )
                }
            }
            
            HStack {
                Text("\(activeDaysLast14) active days in the last 2 weeks")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding(18)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            generateCalendarData()
        }
    }
    
    private func generateCalendarData() {
        calendarData = analyticsService.generateCalendarData(activities: activities, for: Date())
    }
    
    private var last14Days: [Date] {
        (0..<14).compactMap { offset in
            calendar.date(byAdding: .day, value: -13 + offset, to: Date())
        }
    }
    
    private func hasActivityOnDate(_ date: Date) -> Bool {
        activities.contains { activity in
            calendar.isDate(activity.startTime, inSameDayAs: date)
        }
    }
    
    private var activeDaysLast14: Int {
        last14Days.filter { hasActivityOnDate($0) }.count
    }
}

// MARK: - Mini Calendar Day Cell

struct MiniCalendarDayCell: View {
    let date: Date
    let hasActivity: Bool
    let isToday: Bool
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        VStack(spacing: 3) {
            Text(dayLetter)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
            
            Circle()
                .fill(circleColor)
                .frame(width: 18, height: 18)
                .overlay(
                    Circle()
                        .stroke(isToday ? limeGreen : Color.clear, lineWidth: 2)
                )
        }
        .frame(maxWidth: .infinity)
    }
    
    private var dayLetter: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }
    
    private var circleColor: Color {
        if hasActivity {
            return limeGreen
        } else {
            return Color.gray.opacity(0.2)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ScrollView {
            RunCalendarView(activities: MockRunActivityData.generateMockActivities())
        }
        .navigationTitle("Calendar")
    }
}
