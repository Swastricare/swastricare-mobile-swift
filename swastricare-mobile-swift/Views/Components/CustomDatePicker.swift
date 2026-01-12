//
//  CustomDatePicker.swift
//  swastricare-mobile-swift
//
//  Custom Date Picker with Premium UI
//

import SwiftUI

struct CustomDatePickerView: View {
    @Binding var selectedDate: Date
    
    @State private var selectedDay: Int
    @State private var selectedMonth: Int
    @State private var selectedYear: Int
    
    private let days = Array(1...31)
    private let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private let monthNumbers = Array(1...12)
    
    private var years: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 100)...(currentYear))
    }
    
    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        let components = Calendar.current.dateComponents([.day, .month, .year], from: selectedDate.wrappedValue)
        _selectedDay = State(initialValue: components.day ?? 1)
        _selectedMonth = State(initialValue: components.month ?? 1)
        _selectedYear = State(initialValue: components.year ?? Calendar.current.component(.year, from: Date()))
    }
    
    private func syncFromBinding() {
        let components = Calendar.current.dateComponents([.day, .month, .year], from: selectedDate)
        selectedDay = components.day ?? selectedDay
        selectedMonth = components.month ?? selectedMonth
        selectedYear = components.year ?? selectedYear
    }
    
    var body: some View {
        GlassCard(cornerRadius: 20, padding: 0) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Date of Birth")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Picker Columns
                HStack(spacing: 0) {
                    // Day Column
                    PickerColumn(
                        items: days.map { String($0) },
                        selectedIndex: Binding(
                            get: { days.firstIndex(of: selectedDay) ?? 0 },
                            set: { index in
                                selectedDay = days[index]
                                updateDate()
                            }
                        ),
                        label: "Day",
                        onSelectionChanged: { index in
                            selectedDay = days[index]
                            updateDate()
                        }
                    )
                    
                    // Month Column
                    PickerColumn(
                        items: months,
                        selectedIndex: Binding(
                            get: { monthNumbers.firstIndex(of: selectedMonth) ?? 0 },
                            set: { index in
                                selectedMonth = monthNumbers[index]
                                updateDate()
                            }
                        ),
                        label: "Month",
                        onSelectionChanged: { index in
                            selectedMonth = monthNumbers[index]
                            updateDate()
                        }
                    )
                    
                    // Year Column
                    PickerColumn(
                        items: years.reversed().map { String($0) },
                        selectedIndex: Binding(
                            get: { years.reversed().firstIndex(of: selectedYear) ?? 0 },
                            set: { index in
                                selectedYear = years.reversed()[index]
                                updateDate()
                            }
                        ),
                        label: "Year",
                        onSelectionChanged: { index in
                            selectedYear = years.reversed()[index]
                            updateDate()
                        }
                    )
                }
                .frame(height: 200)
                .padding(.bottom, 20)
            }
        }
        .onChange(of: selectedDate) { _, _ in
            syncFromBinding()
        }
        .onAppear {
            syncFromBinding()
        }
    }
    
    private func updateDate() {
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        
        // Get the maximum days in the selected month/year
        let calendar = Calendar.current
        if let dateInMonth = calendar.date(from: components),
           let range = calendar.range(of: .day, in: .month, for: dateInMonth) {
            let maxDays = range.count
            // Clamp day to valid range
            let validDay = min(selectedDay, maxDays)
            components.day = validDay
            
            if validDay != selectedDay {
                selectedDay = validDay
            }
        } else {
            components.day = selectedDay
        }
        
        if let newDate = Calendar.current.date(from: components) {
            selectedDate = newDate
        }
    }
}

// MARK: - Picker Column

private struct PickerColumn: View {
    let items: [String]
    @Binding var selectedIndex: Int
    let label: String
    let onSelectionChanged: (Int) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(0..<items.count, id: \.self) { index in
                            PickerItem(
                                text: items[index],
                                isSelected: index == selectedIndex
                            )
                            .id(index)
                            .frame(height: 50)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedIndex = index
                                    onSelectionChanged(index)
                                    proxy.scrollTo(index, anchor: .center)
                                }
                            }
                        }
                    }
                    .padding(.vertical, geometry.size.height / 2 - 25)
                }
                .scrollDisabled(false)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(selectedIndex, anchor: .center)
                        }
                    }
                }
                .onChange(of: selectedIndex) { _, newValue in
                    withAnimation {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.clear, .black],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .frame(height: 50)
                    
                    Rectangle()
                        .fill(.black)
                    
                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .frame(height: 50)
                }
            )
        }
    }
}

// MARK: - Picker Item

private struct PickerItem: View {
    let text: String
    let isSelected: Bool
    
    var body: some View {
        Text(text)
            .font(.system(size: isSelected ? 22 : 18, weight: isSelected ? .bold : .regular))
            .foregroundStyle(isSelected ? AnyShapeStyle(PremiumColor.royalBlue) : AnyShapeStyle(Color.secondary))
            .scaleEffect(isSelected ? 1.1 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
