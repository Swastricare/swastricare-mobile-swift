//
//  TrackerView.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import SwiftUI

struct TrackerView: View {
    // Mock Data
    private let weeklySteps: [Double] = [6500, 8000, 10200, 7500, 9000, 11000, 8432]
    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HeroHeader(
                    title: "Tracker",
                    subtitle: "Health Trends",
                    icon: "chart.xyaxis.line"
                )
                
                // Calendar Strip (Premium)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(0..<14) { i in
                            VStack(spacing: 8) {
                                Text("Jan")
                                    .font(.caption2)
                                    .foregroundColor(i == 6 ? .white.opacity(0.8) : .secondary)
                                Text("\(i + 1)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(i == 6 ? .white : .primary)
                            }
                            .frame(width: 50, height: 75)
                            .background(
                                i == 6 ?
                                AnyView(PremiumColor.royalBlue) :
                                AnyView(Color.clear)
                            )
                            .cornerRadius(25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            )
                            .glass(cornerRadius: 25) // Apply glass to all, but selected overrides bg
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Weekly Overview Chart (Glass Card)
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Weekly Steps")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("Avg: 8,661")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(Capsule())
                    }
                    
                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach(0..<weeklySteps.count, id: \.self) { index in
                            VStack {
                                Spacer()
                                Capsule()
                                    .fill(
                                        index == 6 ?
                                        PremiumColor.neonGreen :
                                        LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                                    )
                                    .frame(height: CGFloat(weeklySteps[index] / 12000.0 * 150))
                                    .shadow(color: index == 6 ? Color.green.opacity(0.4) : .clear, radius: 8)
                                
                                Text(days[index])
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(height: 180)
                }
                .padding(20)
                .glass(cornerRadius: 24)
                .padding(.horizontal)
                
                // Detailed Metrics
                VStack(alignment: .leading, spacing: 15) {
                    Text("Today's Details")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        TrackerMetricRow(title: "Active Calories", value: "650 kcal", icon: "flame.fill", color: .orange)
                        TrackerMetricRow(title: "Exercise", value: "45 mins", icon: "figure.run", color: .green)
                        TrackerMetricRow(title: "Stand Hours", value: "8/12 hr", icon: "figure.stand", color: .blue)
                        TrackerMetricRow(title: "Distance", value: "5.2 km", icon: "map.fill", color: .cyan)
                    }
                    .padding(.horizontal)
                }
                
                // Add Button (Floating Style)
                Button(action: {}) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Log Activity")
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(PremiumColor.sunset)
                    .cornerRadius(16)
                    .shadow(color: Color.orange.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Bottom Padding for Dock
                Color.clear.frame(height: 100)
            }
            .padding(.top)
        }
    }
}

struct TrackerMetricRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .padding(10)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            Text(title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
        }
        .padding()
        .glass(cornerRadius: 16)
    }
}
