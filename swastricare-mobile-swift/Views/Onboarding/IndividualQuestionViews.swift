//
//  IndividualQuestionViews.swift
//  swastricare-mobile-swift
//
//  Individual Question Views - One Question Per Screen
//

import SwiftUI
import CoreLocation

// MARK: - Question 1: Full Name

struct FullNameQuestionView: View {
    @ObservedObject var formState: ComprehensiveOnboardingFormState
    @FocusState private var isFocused: Bool
    var onNext: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            ScreenTitleView(
                title: "What's your name?",
                subtitle: "This is how we'll address you"
            )
            .padding(.top, 60)
            
            TextField("Enter your name", text: $formState.fullName)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.primary)
                .tint(Color(hex: "2E3192"))
                .focused($isFocused)
                .submitLabel(.done)
                .padding(.vertical, 20)
                .overlay(
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 2)
                        .padding(.top, 50),
                    alignment: .bottom
                )
                .onSubmit {
                    if !formState.fullName.trimmingCharacters(in: .whitespaces).isEmpty {
                        onNext?()
                    }
                }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { isFocused = true }
    }
}

// MARK: - Question 2: Gender

struct GenderQuestionView: View {
    @ObservedObject var formState: ComprehensiveOnboardingFormState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            ScreenTitleView(
                title: "Which gender do you identify with?",
                subtitle: "Select your gender identity"
            )
            .padding(.top, 60)
            VStack(spacing: 12) {
                ForEach(Gender.allCases, id: \.self) { gender in
                    SingleSelectOption(
                        title: gender.displayName,
                        isSelected: formState.gender == gender
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            formState.gender = gender
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Question 3: Date of Birth

struct DateOfBirthQuestionView: View {
    @ObservedObject var formState: ComprehensiveOnboardingFormState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            ScreenTitleView(
                title: "What's your date of birth?",
                subtitle: "This helps us provide age-appropriate insights"
            )
            .padding(.top, 60)
            
            DatePicker("", selection: $formState.dateOfBirth, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Question 4: Height

struct HeightQuestionView: View {
    @ObservedObject var formState: ComprehensiveOnboardingFormState
    
    var body: some View {
        VStack(spacing: 40) {
            ScreenTitleView(
                title: "How tall are you?",
                subtitle: "Select your height"
            )
            .padding(.top, 60)
            
            Picker("Unit", selection: $formState.heightUnit) {
                Text("cm").tag(MeasurementUnit.metric)
                Text("ft/in").tag(MeasurementUnit.imperial)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 32)
            
            if formState.heightUnit == .metric {
                VStack(spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(formState.heightCm))")
                            .font(.system(size: 80, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("cm")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $formState.heightCm, in: 100...250, step: 1)
                        .tint(Color(hex: "2E3192"))
                        .padding(.horizontal, 32)
                }
            } else {
                VStack(spacing: 12) {
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(formState.heightFeet)")
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("ft")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.secondary)
                            Stepper("", value: $formState.heightFeet, in: 3...8)
                                .labelsHidden()
                        }
                        
                        VStack {
                            Text("\(formState.heightInches)")
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("in")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.secondary)
                            Stepper("", value: $formState.heightInches, in: 0...11)
                                .labelsHidden()
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Question 6: Weight

struct WeightQuestionView: View {
    @ObservedObject var formState: ComprehensiveOnboardingFormState
    
    var body: some View {
        VStack(spacing: 40) {
            ScreenTitleView(
                title: "What is your weight?",
                subtitle: "Select your weight"
            )
            .padding(.top, 60)
            
            Picker("Unit", selection: $formState.weightUnit) {
                Text("kg").tag(MeasurementUnit.metric)
                Text("lbs").tag(MeasurementUnit.imperial)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 32)
            
            if formState.weightUnit == .metric {
                VStack(spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(formState.weightKg))")
                            .font(.system(size: 80, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("kg")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $formState.weightKg, in: 30...200, step: 0.5)
                        .tint(Color(hex: "2E3192"))
                        .padding(.horizontal, 32)
                }
            } else {
                VStack(spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(formState.weightLbs))")
                            .font(.system(size: 80, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("lbs")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $formState.weightLbs, in: 66...440, step: 1)
                        .tint(Color(hex: "2E3192"))
                        .padding(.horizontal, 32)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Question 7: Primary Goal

struct PrimaryGoalQuestionView: View {
    @ObservedObject var formState: ComprehensiveOnboardingFormState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            ScreenTitleView(
                title: "What's your primary health goal?",
                subtitle: "Select your main health objective"
            )
            .padding(.top, 60)
            
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(PrimaryGoal.allCases, id: \.self) { goal in
                    SingleSelectOption(
                        title: goal.displayName,
                        isSelected: formState.primaryGoal == goal
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            formState.primaryGoal = goal
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Question 9: Tracking Preferences

struct TrackingPreferencesQuestionView: View {
    @ObservedObject var formState: ComprehensiveOnboardingFormState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            ScreenTitleView(
                title: "What would you like to track?",
                subtitle: "Select all that apply"
            )
            .padding(.top, 60)
            
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(TrackingPreference.allCases, id: \.self) { preference in
                    MultiSelectOption(
                        title: preference.displayName,
                        isSelected: formState.trackingPreferences.contains(preference)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if formState.trackingPreferences.contains(preference) {
                                formState.trackingPreferences.remove(preference)
                            } else {
                                formState.trackingPreferences.insert(preference)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Question 10: Activity Level

struct ActivityLevelQuestionView: View {
    @ObservedObject var formState: ComprehensiveOnboardingFormState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            ScreenTitleView(
                title: "What's your activity level?",
                subtitle: "How active are you daily?"
            )
            .padding(.top, 60)
            
            VStack(spacing: 12) {
                ForEach(OnboardingActivityLevel.allCases, id: \.self) { level in
                    SingleSelectOption(
                        title: level.displayName,
                        isSelected: formState.activityLevel == level
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            formState.activityLevel = level
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Question 11: Sleep Duration

struct SleepDurationQuestionView: View {
    @ObservedObject var formState: ComprehensiveOnboardingFormState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            ScreenTitleView(
                title: "How many hours do you sleep?",
                subtitle: "Average hours of sleep per night"
            )
            .padding(.top, 60)
            
            VStack(spacing: 12) {
                ForEach(SleepDuration.allCases, id: \.self) { duration in
                    SingleSelectOption(
                        title: duration.displayName,
                        isSelected: formState.sleepDuration == duration
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            formState.sleepDuration = duration
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Question 12: Diet Type

struct DietTypeQuestionView: View {
    @ObservedObject var formState: ComprehensiveOnboardingFormState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            ScreenTitleView(
                title: "What's your diet type?",
                subtitle: "Describe your eating habits"
            )
            .padding(.top, 60)
            
            VStack(spacing: 12) {
                ForEach(DietType.allCases, id: \.self) { diet in
                    SingleSelectOption(
                        title: diet.displayName,
                        isSelected: formState.dietType == diet
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            formState.dietType = diet
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Question 13: Water Intake

struct WaterIntakeQuestionView: View {
    @ObservedObject var formState: ComprehensiveOnboardingFormState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            ScreenTitleView(
                title: "How much water do you drink daily?",
                subtitle: "Daily water consumption"
            )
            .padding(.top, 60)
            
            VStack(spacing: 12) {
                ForEach(WaterIntake.allCases, id: \.self) { intake in
                    SingleSelectOption(
                        title: intake.displayName,
                        isSelected: formState.waterIntake == intake
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            formState.waterIntake = intake
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Question 13: Blood Group

struct EmergencyContactNameQuestionView: View {
    @ObservedObject var formState: ComprehensiveOnboardingFormState
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            ScreenTitleView(
                    title: "Emergency contact name?",
                    subtitle: "In case of emergency"
                )
                .padding(.top, 60)
            TextField("Enter name", text: $formState.emergencyContactName)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.primary)
                    .tint(Color(hex: "2E3192"))
                    .focused($isFocused)
                    .submitLabel(.done)
                    .padding(.vertical, 20)
                    .overlay(
                        Rectangle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(height: 2)
                            .padding(.top, 50),
                        alignment: .bottom
                    )
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { isFocused = true }
    }
}

// MARK: - Question 22: Emergency Contact Phone

struct EmergencyContactPhoneQuestionView: View {
    @ObservedObject var formState: ComprehensiveOnboardingFormState
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            ScreenTitleView(
                    title: "Emergency contact phone?",
                    subtitle: "Phone number for emergency contact"
                )
            .padding(.top, 60)
            
            TextField("Enter phone number", text: $formState.emergencyContactPhone)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.primary)
                .tint(Color(hex: "2E3192"))
                .focused($isFocused)
                .keyboardType(.phonePad)
                .submitLabel(.done)
                .padding(.vertical, 20)
                .overlay(
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 2)
                        .padding(.top, 50),
                    alignment: .bottom
                )
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { isFocused = true }
    }
}

// MARK: - Question 13: Blood Group

struct BloodGroupQuestionView: View {
    @ObservedObject var formState: ComprehensiveOnboardingFormState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            ScreenTitleView(
                title: "What's your blood group?",
                subtitle: "Optional but recommended"
            )
            .padding(.top, 60)
            
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(BloodGroup.allCases, id: \.self) { group in
                    SingleSelectOption(
                        title: group.displayName,
                        isSelected: formState.bloodGroup == group
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            formState.bloodGroup = group
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

