//
//  AIService.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Services Layer
//  Handles AI chat and analysis via Supabase Edge Functions
//

import Foundation

// MARK: - AI Service Protocol

protocol AIServiceProtocol {
    func sendChatMessage(_ message: String, context: [ChatMessage]) async throws -> String
    func analyzeHealth(_ metrics: HealthMetrics) async throws -> HealthAnalysisResponse
    func generateHealthSummary(_ metrics: HealthMetrics) async throws -> String
}

// MARK: - AI Service Implementation

final class AIService: AIServiceProtocol {
    
    static let shared = AIService()
    
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    // MARK: - Chat
    
    func sendChatMessage(_ message: String, context: [ChatMessage]) async throws -> String {
        // Format context for API
        let formattedContext = context.suffix(10).map { msg in
            ["role": msg.isUser ? "user" : "assistant", "content": msg.content]
        }
        
        let payload: [String: Any] = [
            "message": message,
            "context": formattedContext
        ]
        
        let response = try await supabase.invokeFunction(
            name: "ai-chat",
            payload: payload
        )
        
        guard let responseText = response["response"] as? String else {
            throw AIError.invalidResponse
        }
        
        return responseText
    }
    
    // MARK: - Health Analysis
    
    func analyzeHealth(_ metrics: HealthMetrics) async throws -> HealthAnalysisResponse {
        let sleepHours = parseSleepHours(metrics.sleep)
        let weight = Double(metrics.weight) ?? 0
        
        let payload: [String: Any] = [
            "steps": metrics.steps,
            "heartRate": metrics.heartRate,
            "sleepHours": sleepHours,
            "activeCalories": metrics.activeCalories,
            "exerciseMinutes": metrics.exerciseMinutes,
            "weight": weight,
            "bloodPressure": metrics.bloodPressure
        ]
        
        let response = try await supabase.invokeFunction(
            name: "ai-health-analysis",
            payload: payload
        )
        
        // Parse response
        guard let summary = response["summary"] as? String else {
            throw AIError.invalidResponse
        }
        
        let insights = response["insights"] as? [String] ?? []
        let recommendations = response["recommendations"] as? [String] ?? []
        let riskFactors = response["riskFactors"] as? [String] ?? []
        let overallScore = response["overallScore"] as? Int ?? 0
        
        return HealthAnalysisResponse(
            summary: summary,
            insights: insights,
            recommendations: recommendations,
            riskFactors: riskFactors,
            overallScore: overallScore
        )
    }
    
    // MARK: - Health Summary
    
    func generateHealthSummary(_ metrics: HealthMetrics) async throws -> String {
        let sleepHours = parseSleepHours(metrics.sleep)
        
        let payload: [String: Any] = [
            "type": "daily_summary",
            "data": [
                "steps": metrics.steps,
                "heartRate": metrics.heartRate,
                "sleepHours": sleepHours,
                "activeCalories": metrics.activeCalories,
                "exerciseMinutes": metrics.exerciseMinutes
            ]
        ]
        
        let response = try await supabase.invokeFunction(
            name: "ai-text-generation",
            payload: payload
        )
        
        guard let text = response["text"] as? String else {
            throw AIError.invalidResponse
        }
        
        return text
    }
    
    // MARK: - Helpers
    
    private func parseSleepHours(_ sleepString: String) -> Double {
        // Parse "7h 30m" format
        let components = sleepString.components(separatedBy: " ")
        var hours: Double = 0
        
        for component in components {
            if component.hasSuffix("h") {
                hours += Double(component.dropLast()) ?? 0
            } else if component.hasSuffix("m") {
                hours += (Double(component.dropLast()) ?? 0) / 60
            }
        }
        
        return hours
    }
}

// MARK: - AI Errors

enum AIError: LocalizedError {
    case invalidResponse
    case networkError
    case rateLimited
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from AI"
        case .networkError: return "Network connection failed"
        case .rateLimited: return "Too many requests. Please wait."
        case .serverError: return "Server error. Try again later."
        }
    }
}

