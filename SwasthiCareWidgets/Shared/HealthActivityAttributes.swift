//
//  HealthActivityAttributes.swift
//  SwasthiCareWidgetsExtension
//
//  Shared ActivityAttributes for health tracking Live Activity / Dynamic Island
//

import ActivityKit
import Foundation

// MARK: - Health Tracking Live Activity Attributes

struct HealthActivityAttributes: ActivityAttributes {
    public var userName: String
    public var startTime: Date

    public struct ContentState: Codable, Hashable {
        var steps: Int
        var heartRate: Int
        var calories: Int
        var hydrationMl: Int
        var hydrationGoalMl: Int
        var stepGoal: Int

        var formattedSteps: String {
            if steps >= 1000 {
                return String(format: "%.1fk", Double(steps) / 1000)
            }
            return "\(steps)"
        }

        var stepProgress: Double {
            guard stepGoal > 0 else { return 0 }
            return min(Double(steps) / Double(stepGoal), 1.0)
        }

        var hydrationProgress: Double {
            guard hydrationGoalMl > 0 else { return 0 }
            return min(Double(hydrationMl) / Double(hydrationGoalMl), 1.0)
        }

        var formattedHydration: String {
            if hydrationMl >= 1000 {
                return String(format: "%.1fL", Double(hydrationMl) / 1000)
            }
            return "\(hydrationMl)ml"
        }

        static var initial: ContentState {
            ContentState(
                steps: 0,
                heartRate: 0,
                calories: 0,
                hydrationMl: 0,
                hydrationGoalMl: 2500,
                stepGoal: 8000
            )
        }
    }
}
