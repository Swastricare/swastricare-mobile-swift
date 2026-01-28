//
//  WorkoutActivityAttributes.swift
//  swastricare-mobile-swift
//
//  ActivityAttributes for Live Activity / Dynamic Island workout tracking
//

import ActivityKit
import Foundation

// MARK: - Workout Live Activity Attributes

struct WorkoutActivityAttributes: ActivityAttributes {
    
    // Static attributes (set when activity starts, don't change)
    public var activityType: String
    public var activityIcon: String
    public var startTime: Date
    
    // MARK: - Content State (Dynamic data that updates)
    
    public struct ContentState: Codable, Hashable {
        // Time & Distance
        var elapsedSeconds: Int
        var distanceMeters: Double
        
        // Pace & Speed
        var currentPaceSecondsPerKm: Int
        var averagePaceSecondsPerKm: Int
        
        // Other metrics
        var caloriesBurned: Int
        var currentHeartRate: Int?
        
        // State
        var isPaused: Bool
        
        // MARK: - Computed Properties
        
        var formattedElapsedTime: String {
            let hours = elapsedSeconds / 3600
            let minutes = (elapsedSeconds % 3600) / 60
            let seconds = elapsedSeconds % 60
            
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            }
            return String(format: "%02d:%02d", minutes, seconds)
        }
        
        var formattedDistance: String {
            if distanceMeters >= 1000 {
                return String(format: "%.2f", distanceMeters / 1000)
            }
            return String(format: "%.0f", distanceMeters)
        }
        
        var distanceUnit: String {
            distanceMeters >= 1000 ? "km" : "m"
        }
        
        var formattedCurrentPace: String {
            formatPace(currentPaceSecondsPerKm)
        }
        
        var formattedAveragePace: String {
            formatPace(averagePaceSecondsPerKm)
        }
        
        private func formatPace(_ paceSeconds: Int) -> String {
            guard paceSeconds > 0 && paceSeconds < 3600 else { return "--:--" }
            let minutes = paceSeconds / 60
            let seconds = paceSeconds % 60
            return String(format: "%d'%02d\"", minutes, seconds)
        }
        
        // MARK: - Static Helpers
        
        static var initial: ContentState {
            ContentState(
                elapsedSeconds: 0,
                distanceMeters: 0,
                currentPaceSecondsPerKm: 0,
                averagePaceSecondsPerKm: 0,
                caloriesBurned: 0,
                currentHeartRate: nil,
                isPaused: false
            )
        }
    }
}

// MARK: - Workout Activity Type Extension

extension WorkoutActivityType {
    var liveActivityIcon: String {
        switch self {
        case .walking: return "figure.walk"
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .hiking: return "figure.hiking"
        }
    }
    
    var liveActivityName: String {
        rawValue
    }
}
