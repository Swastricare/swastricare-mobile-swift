//
//  AIModels.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Models Layer
//

import Foundation

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    let isLoading: Bool
    let responseMode: AIResponseMode?
    var userFeedback: MessageFeedback?
    var isBookmarked: Bool
    let foodResult: SnapFoodResult?

    init(
        id: UUID = UUID(),
        content: String,
        isUser: Bool,
        timestamp: Date = Date(),
        isLoading: Bool = false,
        responseMode: AIResponseMode? = nil,
        userFeedback: MessageFeedback? = nil,
        isBookmarked: Bool = false,
        foodResult: SnapFoodResult? = nil
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.isLoading = isLoading
        self.responseMode = responseMode
        self.userFeedback = userFeedback
        self.isBookmarked = isBookmarked
        self.foodResult = foodResult
    }

    static func userMessage(_ content: String) -> ChatMessage {
        ChatMessage(content: content, isUser: true)
    }

    static func assistantMessage(_ content: String, mode: AIResponseMode = .general) -> ChatMessage {
        ChatMessage(content: content, isUser: false, responseMode: mode)
    }

    static func foodAnalysisMessage(_ content: String, foodResult: SnapFoodResult) -> ChatMessage {
        ChatMessage(content: content, isUser: false, responseMode: .foodAnalysis, foodResult: foodResult)
    }

    static func loadingMessage() -> ChatMessage {
        ChatMessage(content: "", isUser: false, isLoading: true)
    }
}

// MARK: - Message Feedback

enum MessageFeedback: String, Equatable {
    case helpful
    case notHelpful
}

// MARK: - AI Response Mode (for message badges)

enum AIResponseMode: String, Equatable {
    case general
    case medical
    case healthAnalysis
    case imageAnalysis
    case foodAnalysis

    var badgeText: String {
        switch self {
        case .general: return "Swastri"
        case .medical: return "Medical Expert"
        case .healthAnalysis: return "Health Analysis"
        case .imageAnalysis: return "Image Analysis"
        case .foodAnalysis: return "Food Analysis"
        }
    }

    var badgeIcon: String {
        switch self {
        case .general: return "sparkles"
        case .medical: return "stethoscope"
        case .healthAnalysis: return "waveform.path.ecg"
        case .imageAnalysis: return "doc.viewfinder"
        case .foodAnalysis: return "fork.knife"
        }
    }

    var badgeColor: String {
        switch self {
        case .general: return "22C5A6"
        case .medical: return "00A86B"
        case .healthAnalysis: return "4A90E2"
        case .imageAnalysis: return "8B5CF6"
        case .foodAnalysis: return "22C55E"
        }
    }
}

// MARK: - Follow-up Suggestions

struct FollowUpSuggestion: Identifiable {
    var id: String { label }
    let label: String
    let prompt: String

    static func suggestions(for mode: AIResponseMode?) -> [FollowUpSuggestion] {
        switch mode {
        case .medical:
            return [
                FollowUpSuggestion(label: "When to see a doctor?", prompt: "When should I see a doctor about this?"),
                FollowUpSuggestion(label: "Any precautions?", prompt: "What precautions should I take?"),
                FollowUpSuggestion(label: "Explain simply", prompt: "Can you explain that in simpler terms?")
            ]
        case .healthAnalysis:
            return [
                FollowUpSuggestion(label: "Compare to last week", prompt: "How does this compare to my health data from last week?"),
                FollowUpSuggestion(label: "Set a goal", prompt: "Based on this analysis, suggest a health goal for me"),
                FollowUpSuggestion(label: "Detailed breakdown", prompt: "Give me a more detailed breakdown of each metric")
            ]
        case .imageAnalysis:
            return [
                FollowUpSuggestion(label: "Explain findings", prompt: "Can you explain the key findings in more detail?"),
                FollowUpSuggestion(label: "Next steps?", prompt: "What should my next steps be based on this?"),
                FollowUpSuggestion(label: "Anything concerning?", prompt: "Is there anything concerning I should be aware of?")
            ]
        default:
            return [
                FollowUpSuggestion(label: "Tell me more", prompt: "Can you tell me more about this?"),
                FollowUpSuggestion(label: "How to improve?", prompt: "What can I do to improve in this area?"),
                FollowUpSuggestion(label: "Make a plan", prompt: "Help me create an actionable plan based on this advice")
            ]
        }
    }
}

// MARK: - AI Feature Type

enum AIFeature: String, CaseIterable, Identifiable {
    case chat = "Chat"
    case analysis = "Analysis"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .analysis: return "waveform.path.ecg"
        }
    }
    
    var description: String {
        switch self {
        case .chat: return "Ask health questions"
        case .analysis: return "Analyze your vitals"
        }
    }
}

// MARK: - AI Chat State

enum AIChatState: Equatable {
    case idle
    case sending
    case streaming(String)
    case error(String)
    
    var isBusy: Bool {
        switch self {
        case .sending, .streaming: return true
        default: return false
        }
    }
}

// MARK: - AI Error State

/// User-friendly error state with retry capability
struct AIErrorState: Equatable {
    let message: String
    let errorType: AIErrorType
    let canRetry: Bool
    let canSwitchMode: Bool
    
    enum AIErrorType: Equatable {
        case network
        case timeout
        case medicalServiceUnavailable
        case imageProcessingFailed
        case rateLimited
        case unknown
    }
    
    static func fromError(_ error: Error, mode: AIMode) -> AIErrorState {
        let errorString = error.localizedDescription.lowercased()
        
        if errorString.contains("timeout") || errorString.contains("timed out") {
            return AIErrorState(
                message: "Request timed out. Please try again.",
                errorType: .timeout,
                canRetry: true,
                canSwitchMode: mode == .medical
            )
        } else if errorString.contains("network") || errorString.contains("connection") || errorString.contains("offline") {
            return AIErrorState(
                message: "Unable to connect. Check your internet and try again.",
                errorType: .network,
                canRetry: true,
                canSwitchMode: false
            )
        } else if errorString.contains("rate") || errorString.contains("limit") || errorString.contains("quota") {
            return AIErrorState(
                message: "Too many requests. Please wait a moment and try again.",
                errorType: .rateLimited,
                canRetry: true,
                canSwitchMode: false
            )
        } else if mode == .medical && (errorString.contains("failed") || errorString.contains("unavailable")) {
            return AIErrorState(
                message: "Medical service temporarily unavailable.",
                errorType: .medicalServiceUnavailable,
                canRetry: true,
                canSwitchMode: true
            )
        } else if errorString.contains("image") {
            return AIErrorState(
                message: "Couldn't process the image. Try a different one.",
                errorType: .imageProcessingFailed,
                canRetry: true,
                canSwitchMode: false
            )
        } else {
            return AIErrorState(
                message: "Something went wrong. Please try again.",
                errorType: .unknown,
                canRetry: true,
                canSwitchMode: mode == .medical
            )
        }
    }
}

// MARK: - Loading Operation Type

/// Tracks what kind of AI operation is in progress for contextual UI
enum LoadingOperationType: Equatable {
    case generalChat
    case medicalQuery
    case healthAnalysis
    case imageAnalysis
    
    var loadingMessage: String {
        switch self {
        case .generalChat:
            return "Thinking..."
        case .medicalQuery:
            return "Consulting medical database..."
        case .healthAnalysis:
            return "Analyzing your health data..."
        case .imageAnalysis:
            return "Processing image..."
        }
    }
    
    var icon: String {
        switch self {
        case .generalChat:
            return "sparkles"
        case .medicalQuery:
            return "stethoscope"
        case .healthAnalysis:
            return "waveform.path.ecg"
        case .imageAnalysis:
            return "doc.viewfinder"
        }
    }
}

// MARK: - Health Analysis Request

struct HealthAnalysisRequest: Codable {
    let steps: Int
    let heartRate: Int
    let sleepHours: Double
    let activeCalories: Int
    let exerciseMinutes: Int
    let weight: Double?
    let bloodPressure: String?
}

// MARK: - Health Analysis Response

struct HealthAnalysisResponse: Codable, Equatable {
    let assessment: String
    let insights: String
    let recommendations: [String]
    
    static let empty = HealthAnalysisResponse(
        assessment: "",
        insights: "",
        recommendations: []
    )
}

// MARK: - Health Analysis Result

struct HealthAnalysisResult: Identifiable, Equatable {
    let id: UUID
    let metrics: HealthMetrics
    let analysis: HealthAnalysisResponse
    let timestamp: Date
    
    init(
        id: UUID = UUID(),
        metrics: HealthMetrics,
        analysis: HealthAnalysisResponse,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.metrics = metrics
        self.analysis = analysis
        self.timestamp = timestamp
    }
}

// MARK: - Analysis State

enum AnalysisState: Equatable {
    case idle
    case analyzing
    case completed(HealthAnalysisResult)
    case error(String)
    
    var isAnalyzing: Bool {
        if case .analyzing = self { return true }
        return false
    }
    
    var result: HealthAnalysisResult? {
        if case .completed(let result) = self { return result }
        return nil
    }
}

// MARK: - Quick Action

struct QuickAction: Identifiable, Equatable {
    var id: String { title }
    let title: String
    let icon: String
    let prompt: String

    static var suggestions: [QuickAction] { contextualSuggestions }

    static var contextualSuggestions: [QuickAction] {
        let hour = Calendar.current.component(.hour, from: Date())

        // Analyze My Health - commented out
        // var actions: [QuickAction] = [
        //     QuickAction(title: "Analyze My Health", icon: "waveform.path.ecg", prompt: "Analyze my current health metrics and give me insights")
        // ]
        var actions: [QuickAction] = []

        switch hour {
        case 5..<12:
            // Morning suggestions
            actions += [
                QuickAction(title: "Sleep Review", icon: "bed.double.fill", prompt: "How was my sleep last night? Any tips to improve it?"),
                QuickAction(title: "Morning Routine", icon: "sunrise.fill", prompt: "Suggest a healthy morning routine based on my health profile"),
                QuickAction(title: "Breakfast Ideas", icon: "cup.and.saucer.fill", prompt: "What should I eat for a healthy breakfast today?")
            ]
        case 12..<17:
            // Afternoon suggestions
            actions += [
                QuickAction(title: "Midday Check-in", icon: "heart.text.square.fill", prompt: "How am I doing today? Review my steps, hydration, and activity so far."),
                QuickAction(title: "Exercise Ideas", icon: "figure.run", prompt: "Suggest a workout I can do this afternoon based on my fitness level"),
                QuickAction(title: "Nutrition", icon: "leaf.fill", prompt: "What should I eat for a balanced lunch?")
            ]
        case 17..<22:
            // Evening suggestions
            actions += [
                QuickAction(title: "Day Summary", icon: "chart.bar.fill", prompt: "Summarize my health metrics for today. How did I do?"),
                QuickAction(title: "Wind Down", icon: "moon.stars.fill", prompt: "Help me create a relaxing evening routine for better sleep"),
                QuickAction(title: "Dinner Tips", icon: "fork.knife", prompt: "What should I eat for a light, healthy dinner?")
            ]
        default:
            // Late night suggestions
            actions += [
                QuickAction(title: "Sleep Help", icon: "moon.zzz.fill", prompt: "I can't sleep. What relaxation techniques can help me fall asleep?"),
                QuickAction(title: "Stress Relief", icon: "sparkles", prompt: "Guide me through a quick breathing exercise to relax"),
                QuickAction(title: "Tomorrow Plan", icon: "calendar", prompt: "Help me plan a healthy day for tomorrow based on my health data")
            ]
        }

        return actions
    }
}

// MARK: - Conversation Summary

struct ConversationSummary: Identifiable, Equatable {
    let id: UUID
    let title: String
    let lastMessage: String
    let updatedAt: Date
    let messageCount: Int
    let status: String

    var formattedDate: String {
        let calendar = Calendar.current
        let now = Date()

        // Check if it's today
        if calendar.isDateInToday(updatedAt) {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            return timeFormatter.string(from: updatedAt)
        }

        // Check if it's yesterday
        if calendar.isDateInYesterday(updatedAt) {
            return "Yesterday"
        }

        // Check if it's within the last week
        if let daysAgo = calendar.dateComponents([.day], from: updatedAt, to: now).day, daysAgo < 7 {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            return weekdayFormatter.string(from: updatedAt)
        }

        // For older dates, show the date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: updatedAt)
    }

    var topic: ConversationTopic {
        let combined = (title + " " + lastMessage).lowercased()
        if combined.contains("sleep") || combined.contains("insomnia") || combined.contains("rest") || combined.contains("bed") {
            return .sleep
        } else if combined.contains("diet") || combined.contains("nutrition") || combined.contains("eat") || combined.contains("food") || combined.contains("meal") || combined.contains("breakfast") || combined.contains("lunch") || combined.contains("dinner") {
            return .nutrition
        } else if combined.contains("exercise") || combined.contains("workout") || combined.contains("run") || combined.contains("walk") || combined.contains("steps") || combined.contains("fitness") || combined.contains("active") {
            return .fitness
        } else if combined.contains("doctor") || combined.contains("medication") || combined.contains("symptom") || combined.contains("pain") || combined.contains("medical") || combined.contains("diagnosis") || combined.contains("treatment") {
            return .medical
        } else if combined.contains("heart") || combined.contains("blood pressure") || combined.contains("pulse") || combined.contains("bpm") {
            return .vitals
        } else if combined.contains("water") || combined.contains("hydrat") || combined.contains("drink") {
            return .hydration
        } else if combined.contains("stress") || combined.contains("anxiety") || combined.contains("mental") || combined.contains("mood") || combined.contains("meditation") {
            return .mental
        }
        return .general
    }
}

// MARK: - Conversation Topic

enum ConversationTopic: String, Equatable {
    case sleep
    case nutrition
    case fitness
    case medical
    case vitals
    case hydration
    case mental
    case general

    var label: String {
        switch self {
        case .sleep: return "Sleep"
        case .nutrition: return "Nutrition"
        case .fitness: return "Fitness"
        case .medical: return "Medical"
        case .vitals: return "Vitals"
        case .hydration: return "Hydration"
        case .mental: return "Mental"
        case .general: return "General"
        }
    }

    var icon: String {
        switch self {
        case .sleep: return "moon.zzz.fill"
        case .nutrition: return "leaf.fill"
        case .fitness: return "figure.run"
        case .medical: return "stethoscope"
        case .vitals: return "heart.fill"
        case .hydration: return "drop.fill"
        case .mental: return "brain.head.profile"
        case .general: return "sparkles"
        }
    }

    var color: String {
        switch self {
        case .sleep: return "6366F1"
        case .nutrition: return "22C55E"
        case .fitness: return "F97316"
        case .medical: return "00A86B"
        case .vitals: return "EF4444"
        case .hydration: return "3B82F6"
        case .mental: return "A855F7"
        case .general: return "22C5A6"
        }
    }
}

// MARK: - Proactive Health Nudge

struct HealthNudge: Identifiable, Equatable {
    var id: String { type.rawValue }
    let type: NudgeType
    let message: String
    let icon: String
    let color: String
    let prompt: String

    enum NudgeType: String, Equatable {
        case hydration
        case steps
        case heartRate
        case sleep
        case activity
    }

    static func generate(steps: Int, heartRate: Int, calories: Int, lastWaterLog: Date?) -> [HealthNudge] {
        var nudges: [HealthNudge] = []
        let hour = Calendar.current.component(.hour, from: Date())

        // Hydration nudge: no water logged in 2+ hours
        if let lastWater = lastWaterLog {
            let hoursSinceWater = Date().timeIntervalSince(lastWater) / 3600
            if hoursSinceWater >= 2 {
                nudges.append(HealthNudge(
                    type: .hydration,
                    message: "You haven't logged water in \(Int(hoursSinceWater))h",
                    icon: "drop.fill",
                    color: "3B82F6",
                    prompt: "I haven't had water in a while. How much water should I drink now and any hydration tips?"
                ))
            }
        } else if hour >= 9 {
            nudges.append(HealthNudge(
                type: .hydration,
                message: "Don't forget to stay hydrated today",
                icon: "drop.fill",
                color: "3B82F6",
                prompt: "Remind me about healthy hydration habits. How much water should I drink today?"
            ))
        }

        // Steps nudge: behind pace for the day
        let expectedSteps = (hour * 10000) / 16 // Assume 10k goal spread over 16 waking hours
        if hour >= 10 && steps < expectedSteps / 2 {
            nudges.append(HealthNudge(
                type: .steps,
                message: "Only \(steps.formatted()) steps so far — let's move!",
                icon: "figure.walk",
                color: "22C55E",
                prompt: "I only have \(steps) steps today. Suggest ways to get more steps in and help me reach my goal."
            ))
        }

        // Heart rate nudge: elevated resting heart rate
        if heartRate > 100 {
            nudges.append(HealthNudge(
                type: .heartRate,
                message: "Your heart rate is elevated at \(heartRate) bpm",
                icon: "heart.fill",
                color: "EF4444",
                prompt: "My resting heart rate is \(heartRate) bpm which seems high. Should I be concerned? What can I do to lower it?"
            ))
        }

        // Low activity nudge
        if hour >= 14 && calories < 100 {
            nudges.append(HealthNudge(
                type: .activity,
                message: "Low activity today — a short walk could help",
                icon: "flame.fill",
                color: "F97316",
                prompt: "I've been inactive today with only \(calories) calories burned. Suggest a quick activity I can do right now."
            ))
        }

        return nudges
    }
}

