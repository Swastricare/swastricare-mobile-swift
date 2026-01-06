//
//  TrackerView.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import SwiftUI

struct TrackerView: View {
    @StateObject private var healthManager = HealthManager.shared
    @StateObject private var activityLogger = ActivityLogger.shared
    @State private var selectedDate = Date()
    @State private var showActivityModal = false
    @State private var isRefreshing = false
    @State private var isSyncing = false
    @State private var syncMessage: String?
    @State private var showSyncAlert = false
    
    private let calendar = Calendar.current
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with Sync Button
                HStack {
                    HeroHeader(
                        title: "Tracker",
                        subtitle: "Health Trends",
                        icon: "chart.xyaxis.line"
                    )
                    
                    Spacer()
                    
                    // Sync Button
                    Button(action: {
                        Task { await syncData() }
                    }) {
                        HStack(spacing: 4) {
                            if isSyncing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.title3)
                            }
                        }
                        .foregroundColor(.blue)
                        .padding(10)
                        .glass(cornerRadius: 12)
                    }
                    .disabled(isSyncing || !healthManager.isAuthorized)
                }
                .padding(.horizontal)
                
                // Date Navigation Strip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(0..<14) { i in
                            let date = calendar.date(byAdding: .day, value: -i, to: Date()) ?? Date()
                            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                            
                            VStack(spacing: 8) {
                                Text(monthName(for: date))
                                    .font(.caption2)
                                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(isSelected ? .white : .primary)
                            }
                            .frame(width: 50, height: 75)
                            .background(
                                isSelected ?
                                AnyView(PremiumColor.royalBlue) :
                                AnyView(Color.clear)
                            )
                            .cornerRadius(25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            )
                            .glass(cornerRadius: 25)
                            .onTapGesture {
                                selectedDate = date
                                Task {
                                    await refreshDataForSelectedDate()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Weekly Overview Chart
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Weekly Steps")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Spacer()
                        if !healthManager.weeklySteps.isEmpty {
                            let avgSteps = healthManager.weeklySteps.reduce(0) { $0 + $1.steps } / healthManager.weeklySteps.count
                            Text("Avg: \(avgSteps)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(6)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(Capsule())
                        }
                    }
                    
                    if healthManager.weeklySteps.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .frame(height: 180)
                    } else {
                        HStack(alignment: .bottom, spacing: 12) {
                            ForEach(healthManager.weeklySteps) { metric in
                                let isToday = calendar.isDate(metric.date, inSameDayAs: Date())
                                VStack {
                                    Spacer()
                                    Capsule()
                                        .fill(
                                            isToday ?
                                            PremiumColor.neonGreen :
                                            LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                                        )
                                        .frame(height: max(CGFloat(metric.steps) / 12000.0 * 150, 10))
                                        .shadow(color: isToday ? Color.green.opacity(0.4) : .clear, radius: 8)
                                    
                                    Text(metric.dayName)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(height: 180)
                    }
                }
                .padding(20)
                .glass(cornerRadius: 24)
                .padding(.horizontal)
                
                // Today's Details
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text(calendar.isDateInToday(selectedDate) ? "Today's Details" : "Daily Details")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if !calendar.isDateInToday(selectedDate) {
                            Text(formatDate(selectedDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        TrackerMetricRow(
                            title: "Active Calories",
                            value: "\(healthManager.activeCalories) kcal",
                            icon: "flame.fill",
                            color: .orange
                        )
                        TrackerMetricRow(
                            title: "Exercise",
                            value: "\(healthManager.exerciseMinutes) mins",
                            icon: "figure.run",
                            color: .green
                        )
                        TrackerMetricRow(
                            title: "Stand Hours",
                            value: "\(healthManager.standHours)/12 hr",
                            icon: "figure.stand",
                            color: .blue
                        )
                        TrackerMetricRow(
                            title: "Distance",
                            value: String(format: "%.1f km", healthManager.distance),
                            icon: "map.fill",
                            color: .cyan
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Manual Activities Section
                if !activityLogger.todayActivities.isEmpty && calendar.isDateInToday(selectedDate) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Logged Activities")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ForEach(activityLogger.todayActivities) { activity in
                                HStack {
                                    Image(systemName: activity.icon)
                                        .font(.title3)
                                        .foregroundColor(activity.color)
                                        .padding(10)
                                        .background(activity.color.opacity(0.1))
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(activity.type.displayName)
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        if let notes = activity.notes, !notes.isEmpty {
                                            Text(notes)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Text(activity.displayValue)
                                        .fontWeight(.bold)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .glass(cornerRadius: 16)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Log Activity Button
                Button(action: {
                    showActivityModal = true
                }) {
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
        .refreshable {
            await refreshData()
        }
        .sheet(isPresented: $showActivityModal) {
            ActivityLoggingModal()
        }
        .alert("Sync Status", isPresented: $showSyncAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(syncMessage ?? "")
        }
        .onAppear {
            if healthManager.isAuthorized {
                Task {
                    await loadInitialData()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func monthName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func loadInitialData() async {
        await healthManager.fetchAllHealthData()
        await healthManager.fetchWeeklySteps()
    }
    
    private func refreshData() async {
        isRefreshing = true
        await healthManager.fetchAllHealthDataForDate(selectedDate)
        await healthManager.fetchWeeklySteps()
        isRefreshing = false
    }
    
    private func refreshDataForSelectedDate() async {
        await healthManager.fetchAllHealthDataForDate(selectedDate)
    }
    
    private func syncData() async {
        isSyncing = true
        
        // Sync health data
        do {
            let _ = try await SupabaseManager.shared.syncHealthData(
                steps: healthManager.stepCount,
                heartRate: healthManager.heartRate,
                sleepDuration: healthManager.sleepHours,
                activeCalories: healthManager.activeCalories,
                exerciseMinutes: healthManager.exerciseMinutes,
                standHours: healthManager.standHours,
                distance: healthManager.distance,
                date: selectedDate
            )
            
            // Sync manual activities
            for activity in activityLogger.todayActivities {
                let record = ManualActivityRecord(
                    userId: UUID(), // Will be set by SupabaseManager
                    activityType: activity.type.rawValue,
                    value: activity.value,
                    unit: activity.unit,
                    notes: activity.notes,
                    loggedAt: activity.loggedAt
                )
                _ = try await SupabaseManager.shared.syncManualActivity(record)
            }
            
            syncMessage = "Data synced successfully!"
        } catch {
            syncMessage = "Sync failed: \(error.localizedDescription)"
        }
        
        isSyncing = false
        showSyncAlert = true
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
