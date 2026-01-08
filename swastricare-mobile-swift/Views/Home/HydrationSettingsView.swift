//
//  HydrationSettingsView.swift
//  swastricare-mobile-swift
//
//  Hydration preferences configuration
//

import SwiftUI

struct HydrationSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: HydrationViewModel
    
    @State private var weightText: String = ""
    @State private var heightText: String = ""
    @State private var activityLevel: ActivityLevel = .moderate
    @State private var isPregnant = false
    @State private var isBreastfeeding = false
    @State private var customGoalText: String = ""
    @State private var useHealthKitWeight = true
    @State private var useWeatherAdjustment = true
    @State private var syncToHealthKit = true
    @State private var showAboutCalculation = false
    @State private var showNotificationSettings = false
    
    var body: some View {
        NavigationView {
            Form {
                // Personal Info Section
                personalInfoSection
                
                // Activity Level Section
                activitySection
                
                // Special Conditions Section
                specialConditionsSection
                
                // Notifications Section
                notificationsSection
                
                // Advanced Section
                advancedSection
                
                // About the Calculation
                aboutSection
            }
            .navigationTitle("Hydration Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        savePreferences()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadCurrentPreferences()
            }
            .sheet(isPresented: $showNotificationSettings) {
                NotificationSettingsView(viewModel: viewModel)
            }
        }
    }
    
    // MARK: - Personal Info Section
    
    private var personalInfoSection: some View {
        Section {
            Toggle(isOn: $useHealthKitWeight) {
                Label("Auto from HealthKit", systemImage: "heart.fill")
            }
            .tint(Color.cyan)
            
            if !useHealthKitWeight {
                HStack {
                    Label("Weight", systemImage: "scalemass.fill")
                    Spacer()
                    TextField("kg", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("kg")
                        .foregroundColor(.secondary)
                }
            } else if let weight = viewModel.preferences.weightKg {
                HStack {
                    Label("Current Weight", systemImage: "scalemass.fill")
                    Spacer()
                    Text(String(format: "%.1f kg", weight))
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Label("Height", systemImage: "ruler.fill")
                Spacer()
                TextField("cm", text: $heightText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("cm")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Personal Info")
        } footer: {
            Text("Your daily water goal is calculated based on your weight (33ml per kg)")
        }
    }
    
    // MARK: - Activity Section
    
    private var activitySection: some View {
        Section {
            Picker("Activity Level", selection: $activityLevel) {
                ForEach(ActivityLevel.allCases) { level in
                    HStack {
                        Image(systemName: level.icon)
                        Text(level.displayName)
                    }
                    .tag(level)
                }
            }
            .pickerStyle(.navigationLink)
            
            // Activity level description
            HStack {
                Image(systemName: activityLevel.icon)
                    .foregroundColor(.cyan)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(activityLevel.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(activityLevel.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Activity Level")
        } footer: {
            Text("Higher activity levels increase your hydration goal. Multiplier: \(String(format: "%.2fx", activityLevel.multiplier))")
        }
    }
    
    // MARK: - Special Conditions Section
    
    private var specialConditionsSection: some View {
        Section {
            Toggle(isOn: $isPregnant) {
                HStack {
                    Image(systemName: "figure.and.child.holdinghands")
                        .foregroundColor(.pink)
                    VStack(alignment: .leading) {
                        Text("Pregnant")
                        Text("+300ml daily")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(Color.pink)
            
            Toggle(isOn: $isBreastfeeding) {
                HStack {
                    Image(systemName: "heart.circle.fill")
                        .foregroundColor(.purple)
                    VStack(alignment: .leading) {
                        Text("Breastfeeding")
                        Text("+700ml daily")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(Color.purple)
        } header: {
            Text("Special Conditions")
        }
    }
    
    // MARK: - Notifications Section
    
    private var notificationsSection: some View {
        Section {
            Button(action: {
                showNotificationSettings = true
            }) {
                HStack {
                    Label("Notification Settings", systemImage: "bell.badge.fill")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("Configure hydration reminders, quiet hours, and notification preferences.")
        }
    }
    
    // MARK: - Advanced Section
    
    private var advancedSection: some View {
        Section {
            HStack {
                Label("Custom Goal", systemImage: "target")
                Spacer()
                TextField("ml", text: $customGoalText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("ml")
                    .foregroundColor(.secondary)
            }
            
            Toggle(isOn: $syncToHealthKit) {
                Label("Sync to HealthKit", systemImage: "heart.text.square.fill")
            }
            .tint(Color.red)
            
            Toggle(isOn: $useWeatherAdjustment) {
                Label("Weather Adjustments", systemImage: "sun.max.fill")
            }
            .tint(Color.orange)
        } header: {
            Text("Advanced")
        } footer: {
            Text("Custom goal overrides the calculated value. Weather adjustments increase your goal on hot days (>30°C).")
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showAboutCalculation) {
                VStack(alignment: .leading, spacing: 12) {
                    calculationRow("Base Formula", "Weight (kg) × 33ml")
                    calculationRow("Sedentary", "×0.9 multiplier")
                    calculationRow("Moderate", "×1.0 multiplier")
                    calculationRow("High Activity", "×1.15 multiplier")
                    calculationRow("Hot Climate", "×1.2 multiplier")
                    calculationRow("Pregnancy", "+300ml")
                    calculationRow("Breastfeeding", "+700ml")
                    calculationRow("Exercise", "+500ml per hour")
                    
                    Text("This calculation is based on evidence-based hydration science. Individual needs may vary.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .padding(.vertical, 8)
            } label: {
                Label("About the Calculation", systemImage: "info.circle.fill")
            }
        }
    }
    
    private func calculationRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Actions
    
    private func loadCurrentPreferences() {
        let prefs = viewModel.preferences
        
        if let weight = prefs.weightKg {
            weightText = String(format: "%.1f", weight)
        }
        
        if let height = prefs.heightCm {
            heightText = "\(height)"
        }
        
        activityLevel = prefs.activityLevel
        isPregnant = prefs.isPregnant
        isBreastfeeding = prefs.isBreastfeeding
        useHealthKitWeight = prefs.useHealthKitWeight
        useWeatherAdjustment = prefs.useWeatherAdjustment
        syncToHealthKit = prefs.syncToHealthKit
        
        if let customGoal = prefs.customGoalMl {
            customGoalText = "\(customGoal)"
        }
    }
    
    private func savePreferences() {
        var prefs = viewModel.preferences
        
        if !useHealthKitWeight, let weight = Double(weightText) {
            prefs.weightKg = weight
        }
        
        if let height = Int(heightText) {
            prefs.heightCm = height
        }
        
        prefs.activityLevel = activityLevel
        prefs.isPregnant = isPregnant
        prefs.isBreastfeeding = isBreastfeeding
        prefs.useHealthKitWeight = useHealthKitWeight
        prefs.useWeatherAdjustment = useWeatherAdjustment
        prefs.syncToHealthKit = syncToHealthKit
        
        if let customGoal = Int(customGoalText), customGoal > 0 {
            prefs.customGoalMl = customGoal
        } else {
            prefs.customGoalMl = nil
        }
        
        prefs.updatedAt = Date()
        
        Task {
            await viewModel.updatePreferences(prefs)
        }
        
        dismiss()
    }
}

#Preview {
    HydrationSettingsView(viewModel: HydrationViewModel())
}
