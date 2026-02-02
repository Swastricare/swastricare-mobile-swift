//
//  WorkoutErrorHandler.swift
//  swastricare-mobile-swift
//
//  Centralized error handling for workout sessions
//  Provides user-friendly error messages and recovery actions
//

import Foundation
import CoreLocation

// MARK: - Workout Error Category

enum WorkoutErrorCategory {
    case authorization
    case location
    case healthKit
    case network
    case state
    case system
    case unknown
}

// MARK: - Workout Error Handler

final class WorkoutErrorHandler {
    
    static let shared = WorkoutErrorHandler()
    
    private init() {}
    
    // MARK: - Error Analysis
    
    func categorize(_ error: Error) -> WorkoutErrorCategory {
        switch error {
        case is WorkoutError:
            return .state
        case is LocationTrackingError:
            return .location
        case let clError as CLError:
            switch clError.code {
            case .denied, .promptDeclined:
                return .authorization
            case .network:
                return .network
            case .locationUnknown, .headingFailure:
                return .location
            default:
                return .system
            }
        case is URLError:
            return .network
        default:
            return .unknown
        }
    }
    
    // MARK: - User-Friendly Messages
    
    func userFriendlyMessage(for error: Error) -> String {
        let category = categorize(error)
        
        switch category {
        case .authorization:
            return "Location access is required to track your workout. Please enable location permissions in Settings."
            
        case .location:
            if let locationError = error as? LocationTrackingError {
                switch locationError {
                case .notAuthorized:
                    return "Please allow location access to track your route."
                case .backgroundNotAuthorized:
                    return "Enable 'Always' location access in Settings to track workouts in the background."
                case .servicesDisabled:
                    return "Location services are disabled. Please enable them in Settings."
                case .accuracyInsufficient:
                    return "Unable to get accurate GPS signal. Try moving to an open area."
                case .restricted:
                    return "Location access is restricted on this device."
                }
            }
            return "Location tracking error. Please try again."
            
        case .healthKit:
            return "Unable to save workout to Apple Health. Please check Health app permissions."
            
        case .network:
            return "Network connection error. Workout is saved locally and will sync when online."
            
        case .state:
            if let workoutError = error as? WorkoutError {
                return workoutError.localizedDescription
            }
            return "Workout state error. Please try starting a new workout."
            
        case .system:
            return "A system error occurred. Your workout data is safe and will be recovered."
            
        case .unknown:
            return error.localizedDescription
        }
    }
    
    // MARK: - Recovery Actions
    
    func recoveryActions(for error: Error) -> [WorkoutErrorRecoveryAction] {
        let category = categorize(error)
        
        switch category {
        case .authorization:
            return [
                .openSettings,
                .retry
            ]
            
        case .location:
            if let locationError = error as? LocationTrackingError {
                switch locationError {
                case .notAuthorized, .backgroundNotAuthorized:
                    return [.openSettings, .retry]
                case .servicesDisabled:
                    return [.openSettings]
                case .accuracyInsufficient:
                    return [.wait, .retry]
                case .restricted:
                    return [.contactSupport]
                }
            }
            return [.retry]
            
        case .healthKit:
            return [.openHealthSettings, .continueWithoutSaving]
            
        case .network:
            return [.continueOffline, .retry]
            
        case .state:
            return [.restartWorkout, .discardWorkout]
            
        case .system:
            return [.retry, .reportIssue]
            
        case .unknown:
            return [.retry, .reportIssue]
        }
    }
    
    // MARK: - Severity Assessment
    
    func severity(of error: Error) -> WorkoutErrorSeverity {
        let category = categorize(error)
        
        switch category {
        case .authorization:
            return .critical // Can't track without permissions
        case .location:
            if let locationError = error as? LocationTrackingError {
                switch locationError {
                case .accuracyInsufficient:
                    return .warning // Can continue, but accuracy is poor
                default:
                    return .critical
                }
            }
            return .critical
        case .healthKit:
            return .warning // Workout can continue without HealthKit
        case .network:
            return .info // Can work offline
        case .state:
            return .error
        case .system:
            return .error
        case .unknown:
            return .error
        }
    }
    
    // MARK: - Should Stop Workout
    
    func shouldStopWorkout(for error: Error) -> Bool {
        let severity = severity(of: error)
        
        switch severity {
        case .critical:
            return true
        case .error, .warning, .info:
            return false
        }
    }
}

// MARK: - Error Severity

enum WorkoutErrorSeverity {
    case critical  // Must stop workout
    case error     // Significant error but can continue
    case warning   // Minor issue, can continue with degraded functionality
    case info      // Informational, no impact on workout
    
    var color: String {
        switch self {
        case .critical: return "red"
        case .error: return "orange"
        case .warning: return "yellow"
        case .info: return "blue"
        }
    }
}

// MARK: - Recovery Actions

enum WorkoutErrorRecoveryAction: Identifiable {
    case retry
    case openSettings
    case openHealthSettings
    case continueWithoutSaving
    case continueOffline
    case restartWorkout
    case discardWorkout
    case wait
    case contactSupport
    case reportIssue
    
    var id: String {
        switch self {
        case .retry: return "retry"
        case .openSettings: return "openSettings"
        case .openHealthSettings: return "openHealthSettings"
        case .continueWithoutSaving: return "continueWithoutSaving"
        case .continueOffline: return "continueOffline"
        case .restartWorkout: return "restartWorkout"
        case .discardWorkout: return "discardWorkout"
        case .wait: return "wait"
        case .contactSupport: return "contactSupport"
        case .reportIssue: return "reportIssue"
        }
    }
    
    var title: String {
        switch self {
        case .retry: return "Try Again"
        case .openSettings: return "Open Settings"
        case .openHealthSettings: return "Open Health Settings"
        case .continueWithoutSaving: return "Continue Without Saving"
        case .continueOffline: return "Continue Offline"
        case .restartWorkout: return "Start New Workout"
        case .discardWorkout: return "Discard Workout"
        case .wait: return "Wait for Better Signal"
        case .contactSupport: return "Contact Support"
        case .reportIssue: return "Report Issue"
        }
    }
    
    var icon: String {
        switch self {
        case .retry: return "arrow.clockwise"
        case .openSettings: return "gear"
        case .openHealthSettings: return "heart.text.square"
        case .continueWithoutSaving: return "arrow.forward"
        case .continueOffline: return "wifi.slash"
        case .restartWorkout: return "play.circle"
        case .discardWorkout: return "trash"
        case .wait: return "clock"
        case .contactSupport: return "bubble.left.and.bubble.right"
        case .reportIssue: return "exclamationmark.bubble"
        }
    }
}

// MARK: - Error Logger

extension WorkoutErrorHandler {
    
    /// Log error for analytics/debugging
    func logError(_ error: Error, context: String? = nil) {
        let category = categorize(error)
        let severity = severity(of: error)
        
        var logMessage = "🔴 Workout Error"
        logMessage += "\n   Category: \(category)"
        logMessage += "\n   Severity: \(severity)"
        logMessage += "\n   Message: \(error.localizedDescription)"
        
        if let context = context {
            logMessage += "\n   Context: \(context)"
        }
        
        print(logMessage)
        
        AppAnalyticsService.shared.logError(error, context: context, properties: [
            "workout_category": String(describing: category),
            "workout_severity": String(describing: severity)
        ])
    }
}
