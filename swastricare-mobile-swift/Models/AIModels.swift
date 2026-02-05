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
    
    init(
        id: UUID = UUID(),
        content: String,
        isUser: Bool,
        timestamp: Date = Date(),
        isLoading: Bool = false,
        responseMode: AIResponseMode? = nil,
        userFeedback: MessageFeedback? = nil
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.isLoading = isLoading
        self.responseMode = responseMode
        self.userFeedback = userFeedback
    }
    
    static func userMessage(_ content: String) -> ChatMessage {
        ChatMessage(content: content, isUser: true)
    }
    
    static func assistantMessage(_ content: String, mode: AIResponseMode = .general) -> ChatMessage {
        ChatMessage(content: content, isUser: false, responseMode: mode)
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
    case opus

    var badgeText: String {
        switch self {
        case .general: return "Swastri"
        case .medical: return "Medical Expert"
        case .healthAnalysis: return "Health Analysis"
        case .imageAnalysis: return "Image Analysis"
        case .opus: return "Opus 4.6"
        }
    }

    var badgeIcon: String {
        switch self {
        case .general: return "sparkles"
        case .medical: return "stethoscope"
        case .healthAnalysis: return "waveform.path.ecg"
        case .imageAnalysis: return "doc.viewfinder"
        case .opus: return "brain.head.profile"
        }
    }

    var badgeColor: String {
        switch self {
        case .general: return "2E3192"
        case .medical: return "00A86B"
        case .healthAnalysis: return "4A90E2"
        case .imageAnalysis: return "8B5CF6"
        case .opus: return "D97706"
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
                canSwitchMode: mode != .general
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
        } else if mode == .opus && (errorString.contains("failed") || errorString.contains("unavailable")) {
            return AIErrorState(
                message: "Opus service temporarily unavailable.",
                errorType: .unknown,
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
                canSwitchMode: mode != .general
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
    case opusChat

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
        case .opusChat:
            return "Deep reasoning with Opus..."
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
        case .opusChat:
            return "brain.head.profile"
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
    let id = UUID()
    let title: String
    let icon: String
    let prompt: String
    
    static let suggestions: [QuickAction] = [
        QuickAction(title: "Analyze My Health", icon: "waveform.path.ecg", prompt: "Analyze my current health metrics and give me insights"),
        QuickAction(title: "Sleep Tips", icon: "moon.fill", prompt: "How can I improve my sleep quality?"),
        QuickAction(title: "Exercise Ideas", icon: "figure.run", prompt: "What exercises are good for beginners?"),
        QuickAction(title: "Nutrition", icon: "leaf.fill", prompt: "What should I eat for better heart health?")
    ]
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
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: updatedAt, relativeTo: Date())
    }
}

