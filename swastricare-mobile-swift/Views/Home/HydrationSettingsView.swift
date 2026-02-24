//
//  HydrationSettingsView.swift
//  swastricare-mobile-swift
//
//  Hydration preferences with Movements+ Design
//

import SwiftUI

struct HydrationSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
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
    @State private var hasAppeared = false
    
    // MARK: - Theme Colors
    
    private var hydrationBlue: Color { Color(hex: "5AC8FA") }
    private var hydrationTeal: Color { Color(hex: "4ECDC4") }
    
    var body: some View {
        NavigationView {
            ZStack {
                (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        personalInfoSection
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: hasAppeared)
                        
                        activitySection
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: hasAppeared)
                        
                        specialConditionsSection
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: hasAppeared)
                        
                        notificationsSection
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: hasAppeared)
                        
                        advancedSection
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: hasAppeared)
                        
                        aboutSection
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35), value: hasAppeared)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Hydration Settings")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.08))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { savePreferences() }) {
                        Text("Save")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(hydrationBlue)
                    }
                }
            }
            .onAppear {
                loadCurrentPreferences()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    hasAppeared = true
                }
            }
            .sheet(isPresented: $showNotificationSettings) {
                NotificationSettingsView(viewModel: viewModel)
            }
        }
    }
    
    // MARK: - Personal Info Section
    
    private var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "Personal Info", icon: "person.fill", color: hydrationBlue)
            
            VStack(spacing: 12) {
                SettingsToggleRow(
                    icon: "heart.fill",
                    iconColor: .red,
                    title: "Auto from HealthKit",
                    subtitle: "Sync weight automatically",
                    isOn: $useHealthKitWeight,
                    colorScheme: colorScheme
                )
                
                if !useHealthKitWeight {
                    SettingsInputRow(
                        icon: "scalemass.fill",
                        iconColor: hydrationBlue,
                        title: "Weight",
                        value: $weightText,
                        unit: "kg",
                        placeholder: "Enter weight",
                        colorScheme: colorScheme
                    )
                } else if let weight = viewModel.preferences.weightKg {
                    SettingsInfoRow(
                        icon: "scalemass.fill",
                        iconColor: hydrationBlue,
                        title: "Current Weight",
                        value: String(format: "%.1f kg", weight),
                        colorScheme: colorScheme
                    )
                }
                
                SettingsInputRow(
                    icon: "ruler.fill",
                    iconColor: hydrationTeal,
                    title: "Height",
                    value: $heightText,
                    unit: "cm",
                    placeholder: "Enter height",
                    colorScheme: colorScheme
                )
            }
            
            Text("Your daily water goal is calculated based on your weight (33ml per kg)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Activity Section
    
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "Activity Level", icon: "figure.run", color: MovementsColors.limeGreen)
            
            VStack(spacing: 10) {
                ForEach(ActivityLevel.allCases) { level in
                    ActivityLevelCard(
                        level: level,
                        isSelected: activityLevel == level,
                        colorScheme: colorScheme
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            activityLevel = level
                        }
                    }
                }
            }
            
            Text("Higher activity levels increase your hydration goal. Multiplier: \(String(format: "%.2fx", activityLevel.multiplier))")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Special Conditions Section
    
    private var specialConditionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "Special Conditions", icon: "heart.circle.fill", color: .pink)
            
            VStack(spacing: 12) {
                SpecialConditionToggle(
                    icon: "figure.and.child.holdinghands",
                    iconColor: .pink,
                    title: "Pregnant",
                    subtitle: "+300ml daily",
                    isOn: $isPregnant,
                    colorScheme: colorScheme
                )
                
                SpecialConditionToggle(
                    icon: "heart.circle.fill",
                    iconColor: .purple,
                    title: "Breastfeeding",
                    subtitle: "+700ml daily",
                    isOn: $isBreastfeeding,
                    colorScheme: colorScheme
                )
            }
        }
    }
    
    // MARK: - Notifications Section
    
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "Reminders", icon: "bell.badge.fill", color: .orange)
            
            Button(action: { showNotificationSettings = true }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notification Settings")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Configure reminders and quiet hours")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(MovementsColors.card(for: colorScheme))
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
    
    // MARK: - Advanced Section
    
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "Advanced", icon: "slider.horizontal.3", color: hydrationTeal)
            
            VStack(spacing: 12) {
                SettingsInputRow(
                    icon: "target",
                    iconColor: hydrationBlue,
                    title: "Custom Goal",
                    value: $customGoalText,
                    unit: "ml",
                    placeholder: "Override calculated",
                    colorScheme: colorScheme
                )
                
                SettingsToggleRow(
                    icon: "heart.text.square.fill",
                    iconColor: .red,
                    title: "Sync to HealthKit",
                    subtitle: "Save hydration data",
                    isOn: $syncToHealthKit,
                    colorScheme: colorScheme
                )
                
                SettingsToggleRow(
                    icon: "sun.max.fill",
                    iconColor: .orange,
                    title: "Weather Adjustments",
                    subtitle: "Increase goal on hot days",
                    isOn: $useWeatherAdjustment,
                    colorScheme: colorScheme
                )
            }
            
            Text("Custom goal overrides the calculated value. Weather adjustments increase your goal on hot days (>30°C).")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showAboutCalculation.toggle()
                }
            }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(hydrationBlue.opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(hydrationBlue)
                    }
                    
                    Text("About the Calculation")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: showAboutCalculation ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(MovementsColors.card(for: colorScheme))
                )
            }
            .buttonStyle(ScaleButtonStyle())
            
            if showAboutCalculation {
                VStack(spacing: 10) {
                    CalculationRow(label: "Base Formula", value: "Weight (kg) × 33ml")
                    CalculationRow(label: "Sedentary", value: "×0.9 multiplier")
                    CalculationRow(label: "Moderate", value: "×1.0 multiplier")
                    CalculationRow(label: "High Activity", value: "×1.15 multiplier")
                    CalculationRow(label: "Hot Climate", value: "×1.2 multiplier")
                    CalculationRow(label: "Pregnancy", value: "+300ml")
                    CalculationRow(label: "Breastfeeding", value: "+700ml")
                    CalculationRow(label: "Exercise", value: "+500ml per hour")
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(MovementsColors.card(for: colorScheme))
                )
                
                Text("This calculation is based on evidence-based hydration science. Individual needs may vary.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
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
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        Task {
            await viewModel.updatePreferences(prefs)
        }
        
        dismiss()
    }
}

// MARK: - Supporting Views

struct SectionHeaderView: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
        }
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(iconColor)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(MovementsColors.card(for: colorScheme))
        )
    }
}

struct SettingsInputRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    @Binding var value: String
    let unit: String
    let placeholder: String
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 6) {
                TextField(placeholder, text: $value)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 80)
                
                Text(unit)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(MovementsColors.card(for: colorScheme))
        )
    }
}

struct SettingsInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(MovementsColors.card(for: colorScheme))
        )
    }
}

struct ActivityLevelCard: View {
    let level: ActivityLevel
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? MovementsColors.limeGreen.opacity(0.15) : Color.primary.opacity(0.08))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: level.icon)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? MovementsColors.limeGreen : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(level.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(isSelected ? MovementsColors.limeGreen : Color.primary.opacity(0.2), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(MovementsColors.limeGreen)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(MovementsColors.card(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? MovementsColors.limeGreen.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct SpecialConditionToggle: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let colorScheme: ColorScheme
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isOn ? iconColor.opacity(0.15) : Color.primary.opacity(0.08))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(isOn ? iconColor : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isOn ? iconColor : Color.primary.opacity(0.1))
                        .frame(width: 44, height: 26)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 22, height: 22)
                        .offset(x: isOn ? 9 : -9)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(MovementsColors.card(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isOn ? iconColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct CalculationRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    HydrationSettingsView(viewModel: HydrationViewModel())
}
