//
//  CreativeDatePicker.swift
//  swastricare-mobile-swift
//
//  Created by Assistant on 17/01/26.
//

import SwiftUI

struct CreativeDatePicker: View {
    @Binding var date: Date
    
    var body: some View {
        VStack(spacing: 24) {
            // Selected Date & Info Card
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.primary.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                
                HStack {
                    // Date Display
                    VStack(alignment: .leading, spacing: 4) {
                        Text(date.formatted(.dateTime.day().month(.wide)))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(date.formatted(.dateTime.year()))
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Zodiac / Age / Icon
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(calculateAge())
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(PremiumColor.royalBlue)
                        
                        Text("years old")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(24)
            }
            .frame(height: 100)
            
            // Picker Container
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.primary.opacity(0.02))
                
                DatePicker(
                    "",
                    selection: $date,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxHeight: 180)
            }
            .frame(height: 200)
        }
    }
    
    private func calculateAge() -> String {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: date, to: Date())
        return String(ageComponents.year ?? 0)
    }
}
