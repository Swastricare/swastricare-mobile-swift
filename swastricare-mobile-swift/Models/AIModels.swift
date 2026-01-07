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
    
    init(
        id: UUID = UUID(),
        content: String,
        isUser: Bool,
        timestamp: Date = Date(),
        isLoading: Bool = false
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.isLoading = isLoading
    }
    
    static func userMessage(_ content: String) -> ChatMessage {
        ChatMessage(content: content, isUser: true)
    }
    
    static func assistantMessage(_ content: String) -> ChatMessage {
        ChatMessage(content: content, isUser: false)
    }
    
    static func loadingMessage() -> ChatMessage {
        ChatMessage(content: "", isUser: false, isLoading: true)
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
        QuickAction(title: "Sleep Tips", icon: "moon.fill", prompt: "How can I improve my sleep quality?"),
        QuickAction(title: "Exercise Ideas", icon: "figure.run", prompt: "What exercises are good for beginners?"),
        QuickAction(title: "Nutrition", icon: "leaf.fill", prompt: "What should I eat for better heart health?"),
        QuickAction(title: "Stress Relief", icon: "brain.head.profile", prompt: "How can I reduce stress naturally?")
    ]
}

