//
//  HomeView.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import SwiftUI
import Auth

struct HomeView: View {
    @StateObject private var healthManager = HealthManager.shared
    @StateObject private var authManager = AuthManager.shared
    @State private var isSyncing = false
    @State private var syncMessage: String?
    @State private var showSyncAlert = false
    @State private var lastSyncTime: Date?
    
    // MARK: - Computed Properties
    
    /// Get user's display name from auth metadata or email
    private var userName: String {
        // Try to get full name from user metadata (works for both email signup and Google)
        if let metadata = authManager.currentUser?.userMetadata {
            // Check for full_name (email signup) or name (Google OAuth)
            if let fullName = metadata["full_name"], let name = fullName.stringValue, !name.isEmpty {
                return name.components(separatedBy: " ").first ?? name
            }
            if let nameVal = metadata["name"], let nameStr = nameVal.stringValue, !nameStr.isEmpty {
                return nameStr.components(separatedBy: " ").first ?? nameStr
            }
        }
        // Fallback to email prefix
        if let email = authManager.userEmail {
            return email.components(separatedBy: "@").first?.capitalized ?? "User"
        }
        return "User"
    }
    
    /// Dynamic greeting based on time of day
    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good Morning,"
        case 12..<17:
            return "Good Afternoon,"
        case 17..<21:
            return "Good Evening,"
        default:
            return "Good Night,"
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Premium Header
                HeroHeader(
                    title: userName,
                    subtitle: timeBasedGreeting,
                    icon: "person.circle.fill"
                )
                
                // Health Authorization Banner
                if !healthManager.isAuthorized {
                    VStack(spacing: 12) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                            .shadow(color: .red.opacity(0.5), radius: 10)
                        
                        Text("Enable Health Access")
                            .font(.headline)
                        
                        Text("Allow Swastricare to read your health data for personalized insights")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            Task {
                                await healthManager.requestAuthorization()
                            }
                        }) {
                            Text("Allow Access")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(PremiumColor.royalBlue)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                    .glass(cornerRadius: 16)
                }
                
                // Daily Activity Card (Hero Card)
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("Daily Activity")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Sync Button
                        Button(action: {
                            Task {
                                await syncHealthData()
                            }
                        }) {
                            HStack(spacing: 4) {
                                if isSyncing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.subheadline)
                                }
                                Text(isSyncing ? "Syncing..." : "Sync")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                        }
                        .disabled(isSyncing || !healthManager.isAuthorized)
                    }
                    
                    HStack(spacing: 20) {
                        // Progress Ring
                        let progress = min(Double(healthManager.stepCount) / 10000.0, 1.0)
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 10)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    LinearGradient(colors: [.white, .white.opacity(0.8)], startPoint: .top, endPoint: .bottom),
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .shadow(color: .white.opacity(0.5), radius: 5)
                            
                            VStack {
                                Text("\(Int(progress * 100))%")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 80, height: 80)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "flame.fill")
                                Text("\(healthManager.activeCalories) kcal")
                            }
                            HStack {
                                Image(systemName: "figure.walk")
                                Text("\(healthManager.stepCount) steps")
                            }
                            HStack {
                                Image(systemName: "clock.fill")
                                Text("\(healthManager.exerciseMinutes) mins")
                            }
                        }
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        
                        Spacer()
                    }
                    
                    // Last sync time
                    if let lastSync = lastSyncTime {
                        Text("Last synced: \(formatSyncTime(lastSync))")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(20)
                .background(PremiumColor.royalBlue.opacity(0.9))
                .cornerRadius(24)
                .shadow(color: Color(hex: "2E3192").opacity(0.4), radius: 15, x: 0, y: 8)
                .padding(.horizontal)
                
                // Health Vitals Grid
                VStack(alignment: .leading, spacing: 15) {
                    Text("Health Vitals")
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                        HealthMetricCard(
                            title: "Heart Rate",
                            value: healthManager.heartRate > 0 ? "\(healthManager.heartRate)" : "--",
                            unit: "bpm",
                            icon: "heart.fill",
                            color: .red
                        )
                        
                        HealthMetricCard(
                            title: "Sleep",
                            value: healthManager.sleepHours,
                            unit: "hrs",
                            icon: "bed.double.fill",
                            color: .indigo
                        )
                        
                        HealthMetricCard(
                            title: "Blood Pressure",
                            value: "120/80",
                            unit: "mmHg",
                            icon: "drop.fill",
                            color: .pink
                        )
                        
                        HealthMetricCard(
                            title: "Weight",
                            value: "68.5",
                            unit: "kg",
                            icon: "scalemass.fill",
                            color: .green
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Recent Activity / Quick Actions
                VStack(alignment: .leading, spacing: 15) {
                    Text("Quick Actions")
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            QuickActionButton(title: "Log Water", icon: "drop.fill", color: .cyan)
                            QuickActionButton(title: "Workout", icon: "figure.run", color: .orange)
                            QuickActionButton(title: "Meditate", icon: "brain.head.profile", color: .purple)
                            QuickActionButton(title: "Journal", icon: "book.fill", color: .yellow)
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Extra padding at bottom to clear the fixed nav bar
                Color.clear.frame(height: 100)
            }
            .padding(.top)
        }
        .alert("Sync Status", isPresented: $showSyncAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(syncMessage ?? "")
        }
        .onAppear {
            if healthManager.isAuthorized {
                Task {
                    await healthManager.fetchAllHealthData()
                }
            }
        }
    }
    
    private func syncHealthData() async {
        isSyncing = true
        await healthManager.fetchAllHealthData()
        
        do {
            let _ = try await SupabaseManager.shared.syncHealthData(
                steps: healthManager.stepCount,
                heartRate: healthManager.heartRate,
                sleepDuration: healthManager.sleepHours,
                activeCalories: healthManager.activeCalories,
                exerciseMinutes: healthManager.exerciseMinutes,
                standHours: healthManager.standHours,
                distance: healthManager.distance
            )
            lastSyncTime = Date()
            syncMessage = "Health data synced successfully!"
            showSyncAlert = true
        } catch {
            syncMessage = "Sync failed: \(error.localizedDescription)"
            showSyncAlert = true
        }
        isSyncing = false
    }
    
    private func formatSyncTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Helper Views

struct HealthMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                    .padding(8)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                Spacer()
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .glass(cornerRadius: 20)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [color.opacity(0.2), color.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 65, height: 65)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.5), radius: 5)
            }
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}
