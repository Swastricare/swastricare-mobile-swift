//
//  ContentView.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import SwiftUI
import Auth

struct ContentView: View {
    @State private var currentTab: Tab = .home
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Premium Background Layer
            PremiumBackground()
            
            // Main Content Layer
            Group {
                switch currentTab {
                case .home:
                    HomeView()
                case .tracker:
                    TrackerView()
                case .ai:
                    FunctionalAIView()
                case .vault:
                    VaultView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Fixed Bottom Navigation Bar
            GlassDock(currentTab: $currentTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Activity Logging Modal

struct ActivityLoggingModal: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var activityLogger = ActivityLogger.shared
    
    @State private var selectedType: ActivityType = .water
    @State private var waterAmount: String = "250"
    @State private var workoutType: String = "Running"
    @State private var workoutDuration: String = "30"
    @State private var mealName: String = ""
    @State private var mealCalories: String = ""
    @State private var meditationDuration: String = "10"
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    let workoutTypes = ["Running", "Walking", "Cycling", "Swimming", "Yoga", "Gym", "Other"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Activity Type Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Activity Type")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Picker("Activity Type", selection: $selectedType) {
                            ForEach(ActivityType.allCases, id: \.self) { type in
                                HStack {
                                    Image(systemName: iconForType(type))
                                    Text(type.displayName)
                                }
                                .tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Dynamic Form Based on Type
                    Group {
                        switch selectedType {
                        case .water:
                            waterForm
                        case .workout:
                            workoutForm
                        case .meal:
                            mealForm
                        case .meditation:
                            meditationForm
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // Save Button
                    Button(action: saveActivity) {
                        Text("Log Activity")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(16)
                    }
                    .padding(.top, 20)
                }
                .padding()
            }
            .navigationTitle("Log Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Activity Logged", isPresented: $showAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Form Views
    
    private var waterForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Water Intake")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                TextField("Amount", text: $waterAmount)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                
                Text("ml")
                    .foregroundColor(.secondary)
            }
            
            // Quick Actions
            HStack(spacing: 12) {
                ForEach([250, 500, 750, 1000], id: \.self) { amount in
                    Button("\(amount)ml") {
                        waterAmount = "\(amount)"
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.cyan.opacity(0.2))
                    .foregroundColor(.cyan)
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var workoutForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Workout Details")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Picker("Type", selection: $workoutType) {
                ForEach(workoutTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }
            .pickerStyle(.menu)
            
            HStack {
                TextField("Duration", text: $workoutDuration)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                
                Text("minutes")
                    .foregroundColor(.secondary)
            }
            
            // Quick Actions
            HStack(spacing: 12) {
                ForEach([15, 30, 45, 60], id: \.self) { duration in
                    Button("\(duration)m") {
                        workoutDuration = "\(duration)"
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var mealForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Meal Information")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("Meal name", text: $mealName)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                TextField("Calories (optional)", text: $mealCalories)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                
                Text("kcal")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var meditationForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Meditation Session")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                TextField("Duration", text: $meditationDuration)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                
                Text("minutes")
                    .foregroundColor(.secondary)
            }
            
            // Quick Actions
            HStack(spacing: 12) {
                ForEach([5, 10, 15, 20], id: \.self) { duration in
                    Button("\(duration)m") {
                        meditationDuration = "\(duration)"
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func iconForType(_ type: ActivityType) -> String {
        switch type {
        case .water: return "drop.fill"
        case .workout: return "figure.run"
        case .meal: return "fork.knife"
        case .meditation: return "brain.head.profile"
        }
    }
    
    private func saveActivity() {
        switch selectedType {
        case .water:
            guard let amount = Int(waterAmount), amount > 0 else {
                alertMessage = "Please enter a valid water amount"
                showAlert = true
                return
            }
            activityLogger.logWater(amount: amount)
            alertMessage = "Logged \(amount)ml of water"
            
        case .workout:
            guard let duration = Int(workoutDuration), duration > 0 else {
                alertMessage = "Please enter a valid workout duration"
                showAlert = true
                return
            }
            activityLogger.logWorkout(type: workoutType, duration: duration)
            alertMessage = "Logged \(duration) min \(workoutType)"
            
        case .meal:
            guard !mealName.isEmpty else {
                alertMessage = "Please enter a meal name"
                showAlert = true
                return
            }
            let calories = Int(mealCalories)
            activityLogger.logMeal(name: mealName, calories: calories)
            alertMessage = "Logged meal: \(mealName)"
            
        case .meditation:
            guard let duration = Int(meditationDuration), duration > 0 else {
                alertMessage = "Please enter a valid meditation duration"
                showAlert = true
                return
            }
            activityLogger.logMeditation(duration: duration)
            alertMessage = "Logged \(duration) min meditation"
        }
        
        showAlert = true
    }
}

#Preview {
    ContentView()
}
