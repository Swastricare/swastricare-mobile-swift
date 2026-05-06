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
    @State private var entryToConfirmDelete: DietLogEntry?

    private var totalCalories: Int {
        Int(entries.reduce(0.0) { $0 + $1.calories })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    // Larger meal icon (44pt circle)
                    ZStack {
                        Circle()
                            .fill(mealType.color.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: mealType.icon)
                            .font(.poppins(.semiBold, size: 20))
                            .foregroundColor(mealType.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(mealType.displayName)
                            .font(.poppins(.semiBold, size: 17))
                            .foregroundColor(.primary)

                        Text(mealType.typicalTime)
                            .font(.poppins(.regular, size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if !entries.isEmpty {
                        Text("\(totalCalories) cal")
                            .font(.poppins(.semiBold, size: 15))
                            .foregroundColor(mealType.color)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.poppins(.medium, size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                if entries.isEmpty {
                    // Enhanced empty state
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onAddFood()
                    }) {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.poppins(.regular, size: 16))
                                    .foregroundColor(mealType.color)

                                Text("Add \(mealType.displayName.lowercased())")
                                    .font(.poppins(.medium, size: 15))
                                    .foregroundColor(mealType.color)
                            }

                            Text("Tap to log what you ate")
                                .font(.poppins(.regular, size: 12))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(mealType.color.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(mealType.color.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        )
                        .cornerRadius(10)
                    }
                } else {
                    // Food entries with swipe-to-delete
                    VStack(spacing: 8) {
                        ForEach(entries) { entry in
                            FoodEntryRow(entry: entry, mealColor: mealType.color) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onDelete(entry)
                            }
                        }
                    }

                    // Add more button with haptic
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onAddFood()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .font(.poppins(.regular, size: 14))
                            Text("Add more")
                                .font(.poppins(.medium, size: 14))
                        }
                        .foregroundColor(mealType.color)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(16)
        .background(mealType.color.opacity(0.04))
        .glass(cornerRadius: AppDimensions.cardRadius)
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
                    .font(.poppins(.regular, size: 18))
            }

            // Food details
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.foodName)
                    .font(.poppins(.medium, size: 15))
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    Text(entry.displayQuantity)
                        .font(.poppins(.regular, size: 13))
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text("\(Int(entry.calories)) cal")
                        .font(.poppins(.medium, size: 13))
                        .foregroundColor(mealColor)
                }
            }

            Spacer()

            // Macros summary
            VStack(alignment: .trailing, spacing: 2) {
                Text("P: \(Int(entry.proteinG))g")
                    .font(.poppins(.regular, size: 11))
                    .foregroundColor(.secondary)

                Text("C: \(Int(entry.carbsG))g")
                    .font(.poppins(.regular, size: 11))
                    .foregroundColor(.secondary)

                Text("F: \(Int(entry.fatG))g")
                    .font(.poppins(.regular, size: 11))
                    .foregroundColor(.secondary)
            }

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.poppins(.medium, size: 14))
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
