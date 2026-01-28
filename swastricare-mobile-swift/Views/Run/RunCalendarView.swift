//
//  RunCalendarView.swift
//  swastricare-mobile-swift
//
//  Calendar view showing running activity dates
//

import SwiftUI

struct RunCalendarView: View {
    
    let activities: [RouteActivity]
    @State private var selectedMonth: Date = Date()
    @State private var selectedDate: Date?
    @State private var calendarData: [CalendarRunData] = []
    @State private var isAnimating = false
    
    private let accentBlue = Color(hex: "4F46E5")
    private let accentGreen = Color(hex: "22C55E")
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accentBlue)
                    .frame(width: 40, height: 40)
                    .background(accentBlue.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(monthYearString)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("\(activeDaysInMonth) active days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(canGoToNextMonth ? accentBlue : .gray)
                    .frame(width: 40, height: 40)
                    .background((canGoToNextMonth ? accentBlue : Color.gray).opacity(0.1))
                    .clipShape(Circle())
            }
            .disabled(!canGoToNextMonth)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 10)
    }
    
    // MARK: - Calendar Grid
    
    private var calendarGrid: some View {
        VStack(spacing: 8) {
            // Day of week headers
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 8)
            
            // Calendar days
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        CalendarDayCell(
                            date: date,
                            calendarData: calendarDataForDate(date),
                            isSelected: isDateSelected(date),
                            isToday: calendar.isDateInToday(date),
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
                        // Empty cell for padding
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 15)
        .animation(.spring(response: 0.5).delay(0.1), value: isAnimating)
    }
    
    // MARK: - Selected Date Activities
    
    @ViewBuilder
    private func selectedDateActivities(for date: Date) -> some View {
        let dayData = calendarDataForDate(date)
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(formattedSelectedDate(date))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if dayData?.hasActivity == true {
                    Text(String(format: "%.1f km", dayData?.totalDistance ?? 0))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(accentBlue)
                }
            }
            
            if let dayData = dayData, dayData.hasActivity {
                ForEach(dayData.activities) { activity in
                    NavigationLink(destination: ActivityDetailView(activity: activity)) {
                        SelectedDateActivityRow(activity: activity)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack {
                    Image(systemName: "figure.run")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No activities")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("Rest day or no tracked runs")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    
                    Spacer()
                }
                .padding(12)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - Month Summary Section
    
    private var monthSummarySection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Monthly Summary")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                MonthSummaryCard(
                    title: "Total Distance",
                    value: String(format: "%.1f km", totalDistanceInMonth),
                    icon: "map",
                    color: accentBlue
                )
                
                MonthSummaryCard(
                    title: "Activities",
                    value: "\(totalActivitiesInMonth)",
                    icon: "figure.run",
                    color: accentGreen
                )
                
                MonthSummaryCard(
                    title: "Active Days",
                    value: "\(activeDaysInMonth)",
                    icon: "calendar",
                    color: .orange
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
    let action: () -> Void
    
    private let accentBlue = Color(hex: "4F46E5")
    private let accentGreen = Color(hex: "22C55E")
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(dayNumber)
                    .font(.system(size: 14, weight: isToday ? .bold : .medium))
                    .foregroundColor(textColor)
                
                // Activity indicator
                if let data = calendarData, data.hasActivity {
                    Circle()
                        .fill(intensityColor(data.intensityLevel))
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 40, height: 44)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isToday && !isSelected ? accentBlue.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return accentBlue
        } else if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month) {
            return .primary
        } else {
            return .secondary
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return accentBlue
        } else {
            return Color.clear
        }
    }
    
    private func intensityColor(_ level: Int) -> Color {
        switch level {
        case 0: return .clear
        case 1: return accentGreen.opacity(0.3)
        case 2: return accentGreen.opacity(0.5)
        case 3: return accentGreen.opacity(0.7)
        case 4: return accentGreen.opacity(0.85)
        default: return accentGreen
        }
    }
}

// MARK: - Selected Date Activity Row

struct SelectedDateActivityRow: View {
    let activity: RouteActivity
    
    private let accentBlue = Color(hex: "4F46E5")
    
    var body: some View {
        HStack(spacing: 12) {
            // Activity icon
            ZStack {
                Circle()
                    .fill(activity.type.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: activity.type.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(activity.type.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(activity.formattedTimeRange)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(activity.formattedDistance)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(accentBlue)
                
                Text(activity.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Month Summary Card

struct MonthSummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Compact Calendar View (for embedding)

struct CompactRunCalendarView: View {
    let activities: [RouteActivity]
    let onViewFullCalendar: () -> Void
    
    @State private var calendarData: [CalendarRunData] = []
    @State private var isAnimating = false
    
    private let accentBlue = Color(hex: "4F46E5")
    private let accentGreen = Color(hex: "22C55E")
    private let analyticsService = RunAnalyticsService.shared
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Run Calendar")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onViewFullCalendar) {
                    Text("View All")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(accentBlue)
                }
            }
            
            // Last 14 days mini view
            HStack(spacing: 4) {
                ForEach(last14Days, id: \.self) { date in
                    MiniCalendarDayCell(
                        date: date,
                        hasActivity: hasActivityOnDate(date),
                        isToday: calendar.isDateInToday(date)
                    )
                }
            }
            
            // Summary
            HStack {
                Text("\(activeDaysLast14) active days in the last 2 weeks")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
    
    private let accentBlue = Color(hex: "4F46E5")
    private let accentGreen = Color(hex: "22C55E")
    
    var body: some View {
        VStack(spacing: 2) {
            Text(dayLetter)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)
            
            Circle()
                .fill(circleColor)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(isToday ? accentBlue : Color.clear, lineWidth: 1.5)
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
            return accentGreen
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
