//
//  AnalyticsService.swift
//  swastricare-mobile-swift
//
//  Firebase Analytics wrapper for screen views and custom events.
//

import Foundation
import FirebaseAnalytics

/// Wraps Firebase Analytics for consistent event logging across the app.
enum AnalyticsService {
    
    // MARK: - Screen tracking
    
    /// Log a screen view (e.g. when user opens a tab or view).
    static func logScreen(name: String, screenClass: String? = nil) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: name,
            AnalyticsParameterScreenClass: screenClass ?? name
        ])
    }
    
    // MARK: - Custom events
    
    /// Log a custom event with optional parameters.
    static func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        if let parameters = parameters {
            Analytics.logEvent(name, parameters: parameters)
        } else {
            Analytics.logEvent(name, parameters: nil)
        }
    }
    
    /// Log when user completes onboarding.
    static func logOnboardingComplete() {
        logEvent("onboarding_complete")
    }
    
    /// Log when user starts a workout/run.
    static func logWorkoutStart(activityType: String) {
        logEvent("workout_start", parameters: ["activity_type": activityType])
    }
    
    /// Log when user completes a workout.
    static func logWorkoutComplete(durationSeconds: Int, activityType: String) {
        logEvent("workout_complete", parameters: [
            "duration_seconds": durationSeconds,
            "activity_type": activityType
        ])
    }
    
    /// Log hydration log.
    static func logHydrationLogged(amountMl: Int) {
        logEvent("hydration_logged", parameters: ["amount_ml": amountMl])
    }
    
    /// Log medication reminder interaction.
    static func logMedicationReminder(action: String, medicationId: String? = nil) {
        var params: [String: Any] = ["action": action]
        if let id = medicationId { params["medication_id"] = id }
        logEvent("medication_reminder", parameters: params)
    }
    
    /// Set user ID for analytics (e.g. after login). Pass nil to clear.
    static func setUserId(_ userId: String?) {
        Analytics.setUserID(userId)
    }
    
    /// Set a user property for segmentation.
    static func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }
}
