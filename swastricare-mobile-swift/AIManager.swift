//
//  AIManager.swift
//  swastricare-mobile-swift
//
//  Created by AI Assistant on 06/01/26.
//

import Foundation
import Supabase
import Combine

@MainActor
class AIManager: ObservableObject {
    static let shared = AIManager()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastAnalysis: HealthAnalysis?
    @Published var chatHistory: [ChatMessage] = []
    
    // Maximum chat history to prevent memory issues
    private let maxChatHistory = 50
    
    private init() {}
    
    // MARK: - Health Analysis
    
    func analyzeHealth(steps: Int, heartRate: Int, sleepHours: String) async throws -> HealthAnalysis {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        print("🔄 AIManager: Starting health analysis")
        print("📊 Parameters - Steps: \(steps), HR: \(heartRate), Sleep: \(sleepHours)")
        
        struct HealthParams: Encodable {
            let steps: Int
            let heartRate: Int
            let sleepDuration: String
        }
        
        let params = HealthParams(steps: steps, heartRate: heartRate, sleepDuration: sleepHours)
        
        do {
            print("📡 Calling Edge Function: ai-health-analysis")
            
            // Use direct Decodable inference as per Supabase Swift SDK
            let analysis: HealthAnalysis = try await SupabaseManager.shared.client.functions
                .invoke(
                    "ai-health-analysis",
                    options: FunctionInvokeOptions(
                        body: params
                    )
                )
            
            print("✅ Successfully decoded analysis: \(analysis.assessment.prefix(50))...")
            lastAnalysis = analysis
            return analysis
        } catch {
            print("❌ Error in analyzeHealth: \(error)")
            if let decodingError = error as? DecodingError {
                print("❌ Decoding error: \(decodingError)")
            }
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - AI Chat
    
    func sendMessage(_ message: String) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        print("🔄 AIManager: Sending chat message")
        print("💬 Message: \(message)")
        
        struct ConversationMessage: Encodable {
            let role: String
            let content: String
        }
        
        struct ChatParams: Encodable {
            let message: String
            let conversationHistory: [ConversationMessage]
        }
        
        let conversationContext = chatHistory.map { msg in
            ConversationMessage(role: msg.role, content: msg.content)
        }
        
        let params = ChatParams(message: message, conversationHistory: conversationContext)
        
        do {
            print("📡 Calling Edge Function: ai-chat")
            
            // Use direct Decodable inference as per Supabase Swift SDK
            let chatResponse: ChatResponse = try await SupabaseManager.shared.client.functions
                .invoke(
                    "ai-chat",
                    options: FunctionInvokeOptions(
                        body: params
                    )
                )
            
            let aiResponse = chatResponse.response
            print("✅ AI Response: \(aiResponse.prefix(50))...")
            
            chatHistory.append(ChatMessage(role: "user", content: message))
            chatHistory.append(ChatMessage(role: "assistant", content: aiResponse))
            
            // Trim history if it exceeds maximum
            if chatHistory.count > maxChatHistory {
                chatHistory.removeFirst(chatHistory.count - maxChatHistory)
            }
            
            return aiResponse
        } catch {
            print("❌ Error in sendMessage: \(error)")
            if let decodingError = error as? DecodingError {
                print("❌ Decoding error: \(decodingError)")
            }
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func clearChat() {
        chatHistory.removeAll()
    }
    
    // MARK: - Text Generation
    
    func generateContent(type: ContentType, data: [String: String]) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        struct ContentParams: Encodable {
            let contentType: String
            let data: [String: String]
        }
        
        let params = ContentParams(contentType: type.rawValue, data: data)
        
        do {
            // Use direct Decodable inference
            let contentResponse: GeneratedContentResponse = try await SupabaseManager.shared.client.functions
                .invoke(
                    "ai-text-generation",
                    options: FunctionInvokeOptions(
                        body: params
                    )
                )
            
            return contentResponse.content
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Image Analysis
    
    func analyzeImage(imageData: Data, analysisType: ImageAnalysisType) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        let base64Image = imageData.base64EncodedString()
        
        struct ImageParams: Encodable {
            let imageData: String
            let analysisType: String
        }
        
        let params = ImageParams(imageData: base64Image, analysisType: analysisType.rawValue)
        
        do {
            // Use direct Decodable inference
            let analysisResponse: ImageAnalysisResponse = try await SupabaseManager.shared.client.functions
                .invoke(
                    "ai-image-analysis",
                    options: FunctionInvokeOptions(
                        body: params
                    )
                )
            
            return analysisResponse.analysis
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

// MARK: - Data Models

struct HealthAnalysis: Codable {
    let assessment: String
    let insights: String
    let recommendations: [String]
}

struct ChatResponse: Codable {
    let response: String
}

struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    let role: String // "user" or "assistant"
    let content: String
    let timestamp = Date()
    
    enum CodingKeys: String, CodingKey {
        case role, content
    }
}

struct GeneratedContentResponse: Codable {
    let content: String
    let contentType: String
}

struct ImageAnalysisResponse: Codable {
    let analysis: String
    let analysisType: String
}

enum ContentType: String {
    case dailySummary = "daily_summary"
    case weeklyReport = "weekly_report"
    case goalSuggestions = "goal_suggestions"
}

enum ImageAnalysisType: String {
    case meal = "meal"
    case workout = "workout"
    case supplement = "supplement"
}
