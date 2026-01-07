//
//  HomeView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI

struct HomeView: View {
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel = DependencyContainer.shared.homeViewModel
    @StateObject private var authViewModel = DependencyContainer.shared.authViewModel
    
    // MARK: - Local State
    
    @State private var showSyncAlert = false
    @State private var syncMessage: String?
    
    // MARK: - Computed Properties
    
    private var userName: String {
        authViewModel.userName.components(separatedBy: " ").first ?? "User"
    }
    
    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<21: return "Good Evening"
        default: return "Good Night"
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Health Authorization Banner
                if !viewModel.isAuthorized && !viewModel.hasRequestedAuth {
                    authorizationBanner
                }
                
                // Daily Activity Card (Hero Card)
                dailyActivityCard
                
                // Health Vitals Grid
                healthVitalsSection
                
                // Quick Actions
                quickActionsSection
            }
            .padding(.top)
        }
        .navigationTitle("\(timeBasedGreeting), \(userName)")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                profileButton
            }
        }
        .alert("Sync Status", isPresented: $showSyncAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(syncMessage ?? "")
        }
        .task {
            await viewModel.loadTodaysData()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    // MARK: - Subviews
    
    private var authorizationBanner: some View {
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
                    await viewModel.requestAuthorization()
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
        .padding(.horizontal)
    }
    
    private var dailyActivityCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Daily Activity")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Sync button
                Button(action: {
                    Task {
                        await viewModel.syncToCloud()
                        syncMessage = "Health data synced successfully!"
                        showSyncAlert = true
                    }
                }) {
                    HStack(spacing: 4) {
                        if viewModel.isSyncing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(viewModel.formatSyncTime())
                            .font(.caption2)
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                .disabled(viewModel.isSyncing)
            }
            
            HStack(alignment: .top, spacing: 20) {
                // Progress Ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 8)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: viewModel.stepProgress)
                        .stroke(
                            LinearGradient(colors: [.green, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: viewModel.stepProgress)
                    
                    VStack(spacing: 2) {
                        Text("\(Int(viewModel.stepProgress * 100))%")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Goal")
                            .font(.caption2)
                            .opacity(0.8)
                    }
                    .foregroundColor(.white)
                }
                
                // Stats
                VStack(alignment: .leading, spacing: 8) {
                    StatRow(icon: "flame.fill", color: .orange, value: "\(viewModel.activeCalories)", unit: "kcal")
                    StatRow(icon: "figure.walk", color: .green, value: "\(viewModel.stepCount)", unit: "steps")
                    StatRow(icon: "clock.fill", color: .blue, value: "\(viewModel.exerciseMinutes)", unit: "mins")
                    StatRow(icon: "figure.stand", color: .purple, value: "\(viewModel.standHours)", unit: "/ 12 hrs")
                }
                .foregroundColor(.white)
            }
        }
        .padding(20)
        .background(PremiumColor.royalBlue.opacity(0.9))
        .cornerRadius(24)
        .shadow(color: Color(hex: "2E3192").opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(.horizontal)
    }
    
    private var healthVitalsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Health Vitals")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                VitalCard(
                    icon: "heart.fill",
                    title: "Heart Rate",
                    value: "\(viewModel.heartRate)",
                    unit: "BPM",
                    color: .red
                )
                
                VitalCard(
                    icon: "moon.fill",
                    title: "Sleep",
                    value: viewModel.sleepHours,
                    unit: "",
                    color: .indigo
                )
                
                VitalCard(
                    icon: "figure.walk",
                    title: "Distance",
                    value: String(format: "%.1f", viewModel.distance),
                    unit: "km",
                    color: .green
                )
                
                VitalCard(
                    icon: "drop.fill",
                    title: "Blood Pressure",
                    value: viewModel.bloodPressure,
                    unit: "mmHg",
                    color: .orange
                )
            }
            .padding(.horizontal)
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Quick Actions")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                QuickActionButton(icon: "waveform.path.ecg", title: "Log Vitals", color: .red) {
                    // Action
                }
                
                QuickActionButton(icon: "pills.fill", title: "Medications", color: .blue) {
                    // Action
                }
                
                QuickActionButton(icon: "calendar.badge.plus", title: "Schedule", color: .green) {
                    // Action
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var profileButton: some View {
        Group {
            if let imageURL = authViewModel.userPhotoURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Supporting Views

private struct StatRow: View {
    let icon: String
    let color: Color
    let value: String
    let unit: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color.opacity(0.9))
            Text(value)
                .fontWeight(.bold)
            Text(unit)
                .font(.caption)
                .opacity(0.8)
        }
    }
}

private struct VitalCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .glass(cornerRadius: 16)
    }
}

private struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glass(cornerRadius: 12)
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}

