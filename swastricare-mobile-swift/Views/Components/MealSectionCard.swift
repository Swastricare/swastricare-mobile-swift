//
//  MealSectionCard.swift
//  swastricare-mobile-swift
//
//  Reusable Component - Meal section with food entries
//

import SwiftUI

struct MealSectionCard: View {
    let mealType: MealType
    let entries: [DietLogEntry]
    let onDelete: (DietLogEntry) -> Void
    let onAddFood: () -> Void
    
    @State private var isExpanded = true
    
    private var totalCalories: Int {
        Int(entries.reduce(0.0) { $0 + $1.calories })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(mealType.color.opacity(0.15))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: mealType.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(mealType.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mealType.displayName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(mealType.typicalTime)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !entries.isEmpty {
                        Text("\(totalCalories) cal")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(mealType.color)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                if entries.isEmpty {
                    // Empty state
                    Button(action: onAddFood) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(mealType.color)
                            
                            Text("Add food")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(mealType.color)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(mealType.color.opacity(0.08))
                        .cornerRadius(10)
                    }
                } else {
                    // Food entries
                    VStack(spacing: 8) {
                        ForEach(entries) { entry in
                            FoodEntryRow(entry: entry, mealColor: mealType.color) {
                                onDelete(entry)
                            }
                        }
                    }
                    
                    // Add more button
                    Button(action: onAddFood) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 14))
                            Text("Add more")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(mealType.color)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct FoodEntryRow: View {
    let entry: DietLogEntry
    let mealColor: Color
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Food icon
            ZStack {
                Circle()
                    .fill(mealColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                
                Text("🍽️")
                    .font(.system(size: 18))
            }
            
            // Food details
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.foodName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Text(entry.displayQuantity)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(entry.calories)) cal")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(mealColor)
                }
            }
            
            Spacer()
            
            // Macros summary
            VStack(alignment: .trailing, spacing: 2) {
                Text("P: \(Int(entry.proteinG))g")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Text("C: \(Int(entry.carbsG))g")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Text("F: \(Int(entry.fatG))g")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red.opacity(0.7))
            }
            .padding(.leading, 8)
        }
        .padding(12)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            MealSectionCard(
                mealType: .breakfast,
                entries: [
                    DietLogEntry(
                        mealType: .breakfast,
                        foodName: "Oatmeal with Banana",
                        quantity: 1,
                        servingUnit: .bowl,
                        calories: 350,
                        proteinG: 12,
                        carbsG: 65,
                        fatG: 8
                    ),
                    DietLogEntry(
                        mealType: .breakfast,
                        foodName: "Green Tea",
                        quantity: 1,
                        servingUnit: .cup,
                        calories: 2,
                        proteinG: 0,
                        carbsG: 0,
                        fatG: 0
                    )
                ],
                onDelete: { _ in },
                onAddFood: {}
            )
            
            MealSectionCard(
                mealType: .lunch,
                entries: [],
                onDelete: { _ in },
                onAddFood: {}
            )
        }
        .padding()
    }
}
