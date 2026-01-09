//
//  DrinkingPatternLearner.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Services Layer
//  Learns user's drinking patterns for intelligent notification scheduling
//

import Foundation

// MARK: - Drinking Pattern Data Models

/// Represents a time window when user is likely to drink water
struct DrinkingTimeWindow: Codable, Equatable {
    let startHour: Int
    let endHour: Int
    let probability: Double
    let averageIntake: Int // ml
    
    var description: String {
        "\(startHour):00 - \(endHour):00 (\(Int(probability * 100))%)"
    }
}

/// User's learned drinking patterns
struct DrinkingPattern: Codable, Equatable {
    /// Probability of drinking for each hour (0-23)
    var hourlyProbability: [Int: Double]
    
    /// Average intake per hour in ml
    var averageIntakePerHour: [Int: Int]
    
    /// Number of entries recorded per hour (for weighted averaging)
    var entryCountPerHour: [Int: Int]
    
    /// Peak drinking time windows (high-probability periods)
    var preferredWindows: [DrinkingTimeWindow]
    
    /// Last time patterns were updated
    var lastUpdated: Date
    
    /// Total days of data collected
    var daysOfData: Int
    
    /// Average response time to notifications (in seconds)
    var avgNotificationResponseTime: TimeInterval?
    
    init() {
        self.hourlyProbability = [:]
        self.averageIntakePerHour = [:]
        self.entryCountPerHour = [:]
        self.preferredWindows = []
        self.lastUpdated = Date()
        self.daysOfData = 0
        self.avgNotificationResponseTime = nil
    }
    
    /// Check if we have enough data to make predictions
    var hasEnoughData: Bool {
        daysOfData >= 3
    }
    
    /// Get best hours to send reminders (low intake, but not quiet hours)
    func getBestReminderHours(quietHoursStart: Int = 22, quietHoursEnd: Int = 7) -> [Int] {
        guard hasEnoughData else { return [] }
        
        // Find hours with low probability of natural drinking
        var candidates: [(hour: Int, probability: Double)] = []
        
        for hour in 0..<24 {
            // Skip quiet hours
            if hour >= quietHoursStart || hour < quietHoursEnd {
                continue
            }
            
            let probability = hourlyProbability[hour] ?? 0
            // Look for hours where user doesn't naturally drink
            if probability < 0.3 {
                candidates.append((hour, probability))
            }
        }
        
        // Sort by probability (lowest first - best for reminders)
        return candidates.sorted { $0.probability < $1.probability }.map { $0.hour }
    }
    
    /// Get hours to avoid sending reminders (user drinks naturally)
    func getHoursToAvoidReminders() -> [Int] {
        guard hasEnoughData else { return [] }
        
        return hourlyProbability
            .filter { $0.value > 0.6 }
            .map { $0.key }
            .sorted()
    }
}

// MARK: - Drinking Pattern Learner Protocol

protocol DrinkingPatternLearnerProtocol {
    func recordDrinkingEntry(at timestamp: Date, amountMl: Int)
    func recordNotificationResponse(responseTime: TimeInterval)
    func getPattern() -> DrinkingPattern
    func getOptimalReminderHours(quietHoursStart: Int, quietHoursEnd: Int) -> [Int]
    func shouldSendReminderNow() -> Bool
    func reset()
}

// MARK: - Drinking Pattern Learner Implementation

final class DrinkingPatternLearner: DrinkingPatternLearnerProtocol {
    
    static let shared = DrinkingPatternLearner()
    
    // MARK: - Properties
    
    private let userDefaults = UserDefaults.standard
    private let patternKey = "drinking_pattern_data"
    private let responseTimesKey = "notification_response_times"
    
    private var pattern: DrinkingPattern {
        didSet {
            savePattern()
        }
    }
    
    /// Recent notification response times for averaging
    private var recentResponseTimes: [TimeInterval] = []
    
    // MARK: - Init
    
    private init() {
        self.pattern = DrinkingPatternLearner.loadPattern()
        self.recentResponseTimes = DrinkingPatternLearner.loadResponseTimes()
    }
    
    // MARK: - Recording Methods
    
    /// Record a drinking entry to learn patterns
    func recordDrinkingEntry(at timestamp: Date, amountMl: Int) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: timestamp)
        
        // Update entry count for this hour
        let currentCount = pattern.entryCountPerHour[hour] ?? 0
        pattern.entryCountPerHour[hour] = currentCount + 1
        
        // Update average intake for this hour (weighted moving average)
        let currentAvg = pattern.averageIntakePerHour[hour] ?? 0
        if currentCount == 0 {
            pattern.averageIntakePerHour[hour] = amountMl
        } else {
            // Use exponential moving average with alpha = 0.3 for recent bias
            let alpha = 0.3
            pattern.averageIntakePerHour[hour] = Int(Double(currentAvg) * (1 - alpha) + Double(amountMl) * alpha)
        }
        
        // Recalculate hourly probabilities
        recalculateProbabilities()
        
        // Update preferred windows
        updatePreferredWindows()
        
        // Track days of data
        updateDaysTracked(timestamp: timestamp)
        
        pattern.lastUpdated = Date()
        
        print("🧠 PatternLearner: Recorded entry at hour \(hour), \(amountMl)ml")
    }
    
    /// Record how long user took to respond to a notification
    func recordNotificationResponse(responseTime: TimeInterval) {
        // Keep last 20 response times
        recentResponseTimes.append(responseTime)
        if recentResponseTimes.count > 20 {
            recentResponseTimes.removeFirst()
        }
        
        // Update average
        let avgTime = recentResponseTimes.reduce(0, +) / Double(recentResponseTimes.count)
        pattern.avgNotificationResponseTime = avgTime
        
        saveResponseTimes()
        
        print("🧠 PatternLearner: Recorded notification response time: \(Int(responseTime))s")
    }
    
    // MARK: - Query Methods
    
    /// Get the current learned pattern
    func getPattern() -> DrinkingPattern {
        return pattern
    }
    
    /// Get optimal hours for sending reminders based on learned patterns
    func getOptimalReminderHours(quietHoursStart: Int = 22, quietHoursEnd: Int = 7) -> [Int] {
        return pattern.getBestReminderHours(
            quietHoursStart: quietHoursStart,
            quietHoursEnd: quietHoursEnd
        )
    }
    
    /// Determine if now is a good time to send a reminder
    func shouldSendReminderNow() -> Bool {
        guard pattern.hasEnoughData else {
            // Not enough data - use default behavior
            return true
        }
        
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: Date())
        
        // If this is an hour the user typically drinks, skip the reminder
        let probability = pattern.hourlyProbability[currentHour] ?? 0
        
        // If probability > 60%, user will likely drink on their own
        if probability > 0.6 {
            print("🧠 PatternLearner: Hour \(currentHour) has high natural drinking probability (\(Int(probability * 100))%), skipping reminder")
            return false
        }
        
        return true
    }
    
    /// Get a personalized message based on patterns
    func getPatternBasedMessage() -> String? {
        guard pattern.hasEnoughData else { return nil }
        
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: Date())
        let probability = pattern.hourlyProbability[currentHour] ?? 0
        
        if probability > 0.5 {
            return "You usually drink water around now!"
        } else if probability < 0.2 {
            return "You don't usually drink much at this time - good time to hydrate!"
        }
        
        return nil
    }
    
    /// Reset all learned patterns
    func reset() {
        pattern = DrinkingPattern()
        recentResponseTimes = []
        savePattern()
        saveResponseTimes()
        print("🧠 PatternLearner: Patterns reset")
    }
    
    // MARK: - Private Helpers
    
    private func recalculateProbabilities() {
        // Find the maximum entry count to normalize probabilities
        let maxCount = pattern.entryCountPerHour.values.max() ?? 1
        guard maxCount > 0 else { return }
        
        // Calculate probability as ratio of entries to max
        for hour in 0..<24 {
            let count = pattern.entryCountPerHour[hour] ?? 0
            pattern.hourlyProbability[hour] = Double(count) / Double(maxCount)
        }
    }
    
    private func updatePreferredWindows() {
        var windows: [DrinkingTimeWindow] = []
        var currentWindowStart: Int? = nil
        var windowProbabilities: [Double] = []
        var windowIntakes: [Int] = []
        
        // Find consecutive hours with high probability
        for hour in 0..<24 {
            let probability = pattern.hourlyProbability[hour] ?? 0
            let intake = pattern.averageIntakePerHour[hour] ?? 0
            
            if probability > 0.4 {
                if currentWindowStart == nil {
                    currentWindowStart = hour
                }
                windowProbabilities.append(probability)
                windowIntakes.append(intake)
            } else if let start = currentWindowStart {
                // End of window
                let avgProb = windowProbabilities.reduce(0, +) / Double(windowProbabilities.count)
                let avgIntake = windowIntakes.reduce(0, +) / max(1, windowIntakes.count)
                
                windows.append(DrinkingTimeWindow(
                    startHour: start,
                    endHour: hour,
                    probability: avgProb,
                    averageIntake: avgIntake
                ))
                
                currentWindowStart = nil
                windowProbabilities = []
                windowIntakes = []
            }
        }
        
        // Close any remaining window
        if let start = currentWindowStart {
            let avgProb = windowProbabilities.reduce(0, +) / Double(windowProbabilities.count)
            let avgIntake = windowIntakes.reduce(0, +) / max(1, windowIntakes.count)
            
            windows.append(DrinkingTimeWindow(
                startHour: start,
                endHour: 24,
                probability: avgProb,
                averageIntake: avgIntake
            ))
        }
        
        // Sort by probability (highest first)
        pattern.preferredWindows = windows.sorted { $0.probability > $1.probability }
    }
    
    private func updateDaysTracked(timestamp: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: timestamp)
        let lastTrackedDay = calendar.startOfDay(for: pattern.lastUpdated)
        
        if today > lastTrackedDay {
            pattern.daysOfData += 1
        }
    }
    
    // MARK: - Persistence
    
    private func savePattern() {
        if let encoded = try? JSONEncoder().encode(pattern) {
            userDefaults.set(encoded, forKey: patternKey)
        }
    }
    
    private static func loadPattern() -> DrinkingPattern {
        guard let data = UserDefaults.standard.data(forKey: "drinking_pattern_data"),
              let pattern = try? JSONDecoder().decode(DrinkingPattern.self, from: data) else {
            return DrinkingPattern()
        }
        return pattern
    }
    
    private func saveResponseTimes() {
        userDefaults.set(recentResponseTimes, forKey: responseTimesKey)
    }
    
    private static func loadResponseTimes() -> [TimeInterval] {
        return UserDefaults.standard.array(forKey: "notification_response_times") as? [TimeInterval] ?? []
    }
}

// MARK: - Pattern Insights for UI

extension DrinkingPatternLearner {
    
    /// Get human-readable insights about drinking patterns
    func getPatternInsights() -> [String] {
        var insights: [String] = []
        
        guard pattern.hasEnoughData else {
            insights.append("Keep logging your water intake to learn your patterns!")
            return insights
        }
        
        // Peak drinking times
        if let topWindow = pattern.preferredWindows.first {
            insights.append("You drink most often between \(topWindow.startHour):00 and \(topWindow.endHour):00")
        }
        
        // Lowest drinking periods
        let lowHours = pattern.hourlyProbability
            .filter { $0.value < 0.2 }
            .map { $0.key }
            .sorted()
        
        if !lowHours.isEmpty {
            let formatted = lowHours.prefix(3).map { "\($0):00" }.joined(separator: ", ")
            insights.append("You tend to drink less around \(formatted)")
        }
        
        // Average response time
        if let avgResponse = pattern.avgNotificationResponseTime {
            let minutes = Int(avgResponse / 60)
            if minutes > 0 {
                insights.append("You typically respond to reminders within \(minutes) minutes")
            }
        }
        
        // Days tracked
        insights.append("Based on \(pattern.daysOfData) days of data")
        
        return insights
    }
    
    /// Get a summary of the best hours for reminders
    func getReminderTimingSummary() -> String {
        let bestHours = getOptimalReminderHours()
        
        if bestHours.isEmpty {
            return "Default reminder timing"
        }
        
        let formatted = bestHours.prefix(3).map { "\($0):00" }.joined(separator: ", ")
        return "Best reminder times: \(formatted)"
    }
}
