//
//  TrackerView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI

struct TrackerView: View {
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel = DependencyContainer.shared.trackerViewModel
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Date Selector
                dateSelector
                
                // Stats Overview
                statsOverview
                
                // Weekly Chart
                weeklyChart
                
                // Detailed Metrics
                detailedMetrics
            }
            .padding(.top)
        }
        .navigationTitle("Health Tracker")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    Task { await viewModel.refresh() }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    // MARK: - Subviews
    
    private var dateSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.weekDates, id: \.self) { date in
                    DateButton(
                        date: date,
                        isSelected: viewModel.isSelected(date),
                        dayName: viewModel.dayName(for: date)
                    ) {
                        Task {
                            await viewModel.selectDate(date)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var statsOverview: some View {
        HStack(spacing: 12) {
            StatCard(
                icon: "figure.walk",
                title: "Steps",
                value: "\(viewModel.stepCount)",
                color: .green
            )
            
            StatCard(
                icon: "heart.fill",
                title: "Heart Rate",
                value: "\(viewModel.heartRate)",
                color: .red
            )
            
            StatCard(
                icon: "flame.fill",
                title: "Calories",
                value: "\(viewModel.activeCalories)",
                color: .orange
            )
        }
        .padding(.horizontal)
    }
    
    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Steps")
                .font(.headline)
            
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(viewModel.weeklySteps) { metric in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                Calendar.current.isDate(metric.date, inSameDayAs: viewModel.selectedDate)
                                    ? Color(hex: "2E3192")
                                    : Color.gray.opacity(0.3)
                            )
                            .frame(
                                width: 30,
                                height: CGFloat(metric.steps) / CGFloat(max(viewModel.maxWeeklySteps, 1)) * 120
                            )
                            .animation(.easeInOut, value: metric.steps)
                        
                        Text(metric.dayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150, alignment: .bottom)
        }
        .padding()
        .glass(cornerRadius: 16)
        .padding(.horizontal)
    }
    
    private var detailedMetrics: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Detailed Metrics")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                MetricRow(icon: "figure.walk", title: "Steps", value: "\(viewModel.stepCount)", color: .green)
                MetricRow(icon: "heart.fill", title: "Heart Rate", value: "\(viewModel.heartRate) BPM", color: .red)
                MetricRow(icon: "flame.fill", title: "Active Calories", value: "\(viewModel.activeCalories) kcal", color: .orange)
                MetricRow(icon: "clock.fill", title: "Exercise", value: "\(viewModel.exerciseMinutes) mins", color: .blue)
                MetricRow(icon: "figure.stand", title: "Stand Hours", value: "\(viewModel.standHours) hrs", color: .purple)
                MetricRow(icon: "moon.fill", title: "Sleep", value: viewModel.sleepHours, color: .indigo)
                MetricRow(icon: "arrow.left.and.right", title: "Distance", value: String(format: "%.2f km", viewModel.distance), color: .cyan)
            }
            .padding()
            .glass(cornerRadius: 16)
            .padding(.horizontal)
        }
    }
}

// MARK: - Supporting Views

private struct DateButton: View {
    let date: Date
    let isSelected: Bool
    let dayName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(dayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .secondary)
                
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 50, height: 60)
            .background(
                isSelected
                    ? Color(hex: "2E3192")
                    : Color.clear
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

private struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glass(cornerRadius: 16)
    }
}

private struct MetricRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        TrackerView()
    }
}

