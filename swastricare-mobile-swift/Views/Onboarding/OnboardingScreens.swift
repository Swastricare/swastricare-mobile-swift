//
//  OnboardingScreens.swift
//  swastricare-mobile-swift
//
//  Individual Onboarding Screen Components
//

import SwiftUI
import CoreLocation

// MARK: - Screen 1: Profile Setup

struct ProfileSetupScreen: View {
    @Binding var formState: ComprehensiveOnboardingFormState
    @ObservedObject var viewModel: ComprehensiveOnboardingViewModel
    @FocusState private var isNameFocused: Bool
    @FocusState private var isCityFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Spacer().frame(height: 20)
                
                ScreenTitleView(
                    title: "Profile Setup",
                    subtitle: "Let's start with the basics"
                )
                
                // Full Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Full Name")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    TextField("Enter your name", text: $formState.fullName)
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                        .tint(Color(hex: "2E3192"))
                        .focused($isNameFocused)
                        .padding()
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Gender
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gender")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        ForEach(Gender.allCases, id: \.self) { gender in
                            SingleSelectOption(
                                title: gender.displayName,
                                isSelected: formState.gender == gender
                            ) {
                                formState.gender = gender
                            }
                        }
                    }
                }
                
                // Date of Birth
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date of Birth")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    DatePicker("", selection: $formState.dateOfBirth, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                
                // Location
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        ForEach(LocationType.allCases, id: \.self) { type in
                            SingleSelectOption(
                                title: type.displayName,
                                isSelected: formState.locationType == type
                            ) {
                                formState.locationType = type
                                if type == .current {
                                    viewModel.fetchCurrentLocation()
                                }
                            }
                        }
                    }
                    
                    if formState.locationType == .manual {
                        TextField("Enter city", text: $formState.city)
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                            .tint(Color(hex: "2E3192"))
                            .focused($isCityFocused)
                            .padding()
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.top, 8)
                    }
                }
                
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            isNameFocused = true
        }
    }
}

// MARK: - Screen 2: Body Metrics

struct BodyMetricsScreen: View {
    @Binding var formState: ComprehensiveOnboardingFormState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Spacer().frame(height: 40)
                
                ScreenTitleView(
                    title: "Body Metrics",
                    subtitle: "Help us understand your body"
                )
                
                // Height
                VStack(alignment: .leading, spacing: 16) {
                    Text("Height")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // Unit selector
                    Picker("Unit", selection: $formState.heightUnit) {
                        Text("cm").tag(MeasurementUnit.metric)
                        Text("ft/in").tag(MeasurementUnit.imperial)
                    }
                    .pickerStyle(.segmented)
                    
                    if formState.heightUnit == .metric {
                        VStack(spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(formState.heightCm))")
                                    .font(.system(size: 64, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("cm")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $formState.heightCm, in: 100...250, step: 1)
                                .tint(Color(hex: "2E3192"))
                        }
                    } else {
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                VStack {
                                    Text("\(formState.heightFeet)")
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                    Text("ft")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    Stepper("", value: $formState.heightFeet, in: 3...8)
                                        .labelsHidden()
                                }
                                
                                VStack {
                                    Text("\(formState.heightInches)")
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                    Text("in")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    Stepper("", value: $formState.heightInches, in: 0...11)
                                        .labelsHidden()
                                }
                            }
                        }
                    }
                }
                
                // Weight
                VStack(alignment: .leading, spacing: 16) {
                    Text("Weight")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Picker("Unit", selection: $formState.weightUnit) {
                        Text("kg").tag(MeasurementUnit.metric)
                        Text("lbs").tag(MeasurementUnit.imperial)
                    }
                    .pickerStyle(.segmented)
                    
                    if formState.weightUnit == .metric {
                        VStack(spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(formState.weightKg))")
                                    .font(.system(size: 64, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("kg")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $formState.weightKg, in: 30...200, step: 0.5)
                                .tint(Color(hex: "2E3192"))
                        }
                    } else {
                        VStack(spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(formState.weightLbs))")
                                    .font(.system(size: 64, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("lbs")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $formState.weightLbs, in: 66...440, step: 1)
                                .tint(Color(hex: "2E3192"))
                        }
                    }
                }
                
                // Body Goal (Optional)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Body Goal (Optional)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 12) {
                        ForEach(BodyGoal.allCases, id: \.self) { goal in
                            SingleSelectOption(
                                title: goal.displayName,
                                isSelected: formState.bodyGoal == goal
                            ) {
                                formState.bodyGoal = goal
                            }
                        }
                    }
                }
                
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Screen 3: Goals & Family History

struct GoalsScreen: View {
    @Binding var formState: ComprehensiveOnboardingFormState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Spacer().frame(height: 20)
                
                ScreenTitleView(
                    title: "Your Goals",
                    subtitle: "What do you want to achieve?"
                )
                
                // Primary Goal
                VStack(alignment: .leading, spacing: 8) {
                    Text("Primary Goal")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        ForEach(PrimaryGoal.allCases, id: \.self) { goal in
                            SingleSelectOption(
                                title: goal.displayName,
                                isSelected: formState.primaryGoal == goal
                            ) {
                                formState.primaryGoal = goal
                            }
                        }
                    }
                }
                
                // Tracking Preferences
                VStack(alignment: .leading, spacing: 8) {
                    Text("What would you like to track?")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Select all that apply")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        ForEach(TrackingPreference.allCases, id: \.self) { preference in
                            MultiSelectOption(
                                title: preference.displayName,
                                isSelected: formState.trackingPreferences.contains(preference)
                            ) {
                                if formState.trackingPreferences.contains(preference) {
                                    formState.trackingPreferences.remove(preference)
                                } else {
                                    formState.trackingPreferences.insert(preference)
                                }
                            }
                        }
                    }
                }
                
                // Family History (Combined)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Family Medical History (Optional)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Select all that apply")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        ForEach(FamilyHistoryCondition.allCases, id: \.self) { condition in
                            MultiSelectOption(
                                title: condition.displayName,
                                isSelected: formState.familyHistory.contains(condition)
                            ) {
                                if condition == .none {
                                    formState.familyHistory.removeAll()
                                    formState.familyHistory.insert(.none)
                                } else {
                                    formState.familyHistory.remove(.none)
                                    if formState.familyHistory.contains(condition) {
                                        formState.familyHistory.remove(condition)
                                    } else {
                                        formState.familyHistory.insert(condition)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Screen 4: Lifestyle

struct LifestyleScreen: View {
    @Binding var formState: ComprehensiveOnboardingFormState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Spacer().frame(height: 20)
                
                ScreenTitleView(
                    title: "Lifestyle",
                    subtitle: "Tell us about your daily routine"
                )
                
                // Activity Level
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity Level")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        ForEach(OnboardingActivityLevel.allCases, id: \.self) { level in
                            SingleSelectOption(
                                title: level.displayName,
                                isSelected: formState.activityLevel == level
                            ) {
                                formState.activityLevel = level
                            }
                        }
                    }
                }
                
                // Sleep Duration
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sleep Duration")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        ForEach(SleepDuration.allCases, id: \.self) { duration in
                            SingleSelectOption(
                                title: duration.displayName,
                                isSelected: formState.sleepDuration == duration
                            ) {
                                formState.sleepDuration = duration
                            }
                        }
                    }
                }
                
                // Diet Type
                VStack(alignment: .leading, spacing: 8) {
                    Text("Diet Type")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        ForEach(DietType.allCases, id: \.self) { diet in
                            SingleSelectOption(
                                title: diet.displayName,
                                isSelected: formState.dietType == diet
                            ) {
                                formState.dietType = diet
                            }
                        }
                    }
                }
                
                // Water Intake
                VStack(alignment: .leading, spacing: 8) {
                    Text("Water Intake")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        ForEach(WaterIntake.allCases, id: \.self) { intake in
                            SingleSelectOption(
                                title: intake.displayName,
                                isSelected: formState.waterIntake == intake
                            ) {
                                formState.waterIntake = intake
                            }
                        }
                    }
                }
                
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Screen 5: Health

struct HealthScreen: View {
    @Binding var formState: ComprehensiveOnboardingFormState
    @ObservedObject var viewModel: ComprehensiveOnboardingViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Spacer().frame(height: 20)
                
                ScreenTitleView(
                    title: "Health Information",
                    subtitle: "Your health matters"
                )
                
                // Existing Conditions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Existing Conditions")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Select all that apply")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        ForEach(HealthCondition.allCases, id: \.self) { condition in
                            MultiSelectOption(
                                title: condition.displayName,
                                isSelected: formState.existingConditions.contains(condition)
                            ) {
                                if condition == .none {
                                    formState.existingConditions.removeAll()
                                    formState.existingConditions.insert(.none)
                                } else {
                                    formState.existingConditions.remove(.none)
                                    if formState.existingConditions.contains(condition) {
                                        formState.existingConditions.remove(condition)
                                    } else {
                                        formState.existingConditions.insert(condition)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Regular Medication
                VStack(alignment: .leading, spacing: 8) {
                    Text("Regular Medication?")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            formState.hasRegularMedication = true
                        }) {
                            Text("Yes")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(formState.hasRegularMedication == true ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(formState.hasRegularMedication == true ? Color(hex: "2E3192") : Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Button(action: {
                            formState.hasRegularMedication = false
                        }) {
                            Text("No")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(formState.hasRegularMedication == false ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(formState.hasRegularMedication == false ? Color(hex: "2E3192") : Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                
                // Allergies
                VStack(alignment: .leading, spacing: 8) {
                    Text("Allergies")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Select all that apply")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        ForEach(AllergyType.allCases, id: \.self) { allergy in
                            MultiSelectOption(
                                title: allergy.displayName,
                                isSelected: formState.allergies.contains(allergy)
                            ) {
                                if allergy == .none {
                                    formState.allergies.removeAll()
                                    formState.allergies.insert(.none)
                                } else {
                                    formState.allergies.remove(.none)
                                    if formState.allergies.contains(allergy) {
                                        formState.allergies.remove(allergy)
                                    } else {
                                        formState.allergies.insert(allergy)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Screen 6: Medication Details

struct MedicationDetailsScreen: View {
    @Binding var formState: ComprehensiveOnboardingFormState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Spacer().frame(height: 40)
                
                ScreenTitleView(
                    title: "Medication Details",
                    subtitle: "Tell us about your medications"
                )
                
                ForEach($formState.medications) { $medication in
                    OnboardingMedicationCard(medication: $medication)
                }
                
                Button(action: {
                    formState.medications.append(MedicationDetail(
                        name: "",
                        dosage: "",
                        schedule: .daily
                    ))
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                        Text("Add Medication")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "2E3192"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: "2E3192").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct OnboardingMedicationCard: View {
    @Binding var medication: MedicationDetail
    @FocusState private var isNameFocused: Bool
    @FocusState private var isDosageFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Medication name", text: $medication.name)
                .font(.system(size: 17))
                .focused($isNameFocused)
                .padding()
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            TextField("Dosage", text: $medication.dosage)
                .font(.system(size: 17))
                .focused($isDosageFocused)
                .padding()
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Picker("Schedule", selection: $medication.schedule) {
                ForEach(OnboardingMedicationSchedule.allCases, id: \.self) { schedule in
                    Text(schedule.displayName).tag(schedule as OnboardingMedicationSchedule)
                }
            }
            .pickerStyle(.menu)
        }
        .padding()
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Screen 7: Habits & Emergency

struct HabitsScreen: View {
    @Binding var formState: ComprehensiveOnboardingFormState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Spacer().frame(height: 20)
                
                ScreenTitleView(
                    title: "Habits & Emergency",
                    subtitle: "Lifestyle and emergency contact"
                )
                
                // Smoking
                VStack(alignment: .leading, spacing: 8) {
                    Text("Smoking")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        ForEach(SmokingHabit.allCases, id: \.self) { habit in
                            SingleSelectOption(
                                title: habit.displayName,
                                isSelected: formState.smoking == habit
                            ) {
                                formState.smoking = habit
                            }
                        }
                    }
                }
                
                // Alcohol
                VStack(alignment: .leading, spacing: 8) {
                    Text("Alcohol")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        ForEach(AlcoholHabit.allCases, id: \.self) { habit in
                            SingleSelectOption(
                                title: habit.displayName,
                                isSelected: formState.alcohol == habit
                            ) {
                                formState.alcohol = habit
                            }
                        }
                    }
                }
                
                // Emergency Contact Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Emergency Contact Name")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    TextField("Enter name", text: $formState.emergencyContactName)
                        .font(.system(size: 17))
                        .keyboardType(.default)
                        .padding()
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Emergency Contact Phone
                VStack(alignment: .leading, spacing: 8) {
                    Text("Emergency Contact Phone")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    TextField("Enter phone number", text: $formState.emergencyContactPhone)
                        .font(.system(size: 17))
                        .keyboardType(.phonePad)
                        .padding()
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Blood Group
                VStack(alignment: .leading, spacing: 8) {
                    Text("Blood Group")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Picker("Blood Group", selection: $formState.bloodGroup) {
                        Text("Select").tag(Optional<BloodGroup>.none)
                        ForEach(BloodGroup.allCases, id: \.self) { group in
                            Text(group.displayName).tag(Optional<BloodGroup>.some(group))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Medical Alerts
                VStack(alignment: .leading, spacing: 8) {
                    Text("Medical Alerts")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Select all that apply")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        ForEach(MedicalAlert.allCases, id: \.self) { alert in
                            MultiSelectOption(
                                title: alert.displayName,
                                isSelected: formState.medicalAlerts.contains(alert)
                            ) {
                                if alert == .none {
                                    formState.medicalAlerts.removeAll()
                                    formState.medicalAlerts.insert(.none)
                                } else {
                                    formState.medicalAlerts.remove(.none)
                                    if formState.medicalAlerts.contains(alert) {
                                        formState.medicalAlerts.remove(alert)
                                    } else {
                                        formState.medicalAlerts.insert(alert)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Screen 8: Emergency (Removed - combined with Habits)

// MARK: - Screen 10: Permissions

struct PermissionsScreen: View {
    @Binding var formState: ComprehensiveOnboardingFormState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Spacer().frame(height: 20)
                
                ScreenTitleView(
                    title: "Permissions",
                    subtitle: "Enable features for better experience"
                )
                
                // Notifications
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notifications")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("Get reminders and updates")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            formState.notificationsEnabled.toggle()
                            if formState.notificationsEnabled {
                                // Request notification permission
                                Task {
                                    await NotificationService.shared.requestPermission()
                                }
                            }
                        }) {
                            Text(formState.notificationsEnabled ? "Enabled" : "Enable")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(formState.notificationsEnabled ? .white : Color(hex: "2E3192"))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(formState.notificationsEnabled ? Color(hex: "2E3192") : Color(hex: "2E3192").opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                    }
                    .padding()
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // Health Data Sync
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Health Data Sync")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("Connect Apple Health / Google Fit")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            formState.healthDataSyncEnabled.toggle()
                            if formState.healthDataSyncEnabled {
                                // Request health data permission
                                // This would typically trigger HealthKit authorization
                            }
                        }) {
                            Text(formState.healthDataSyncEnabled ? "Connected" : "Connect")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(formState.healthDataSyncEnabled ? .white : Color(hex: "2E3192"))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(formState.healthDataSyncEnabled ? Color(hex: "2E3192") : Color(hex: "2E3192").opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                    }
                    .padding()
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 24)
        }
    }
}
