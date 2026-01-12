//
//  AIViewModel.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - ViewModel Layer
//

import Foundation
import Combine

@MainActor
final class AIViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var chatState: AIChatState = .idle
    @Published private(set) var errorMessage: String?
    @Published var inputText = ""
    
    // MARK: - Computed Properties
    
    var isBusy: Bool { chatState.isBusy }
    var hasMessages: Bool { !messages.isEmpty }
    var canSend: Bool { !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chatState.isBusy }
    
    // MARK: - Dependencies
    
    private let aiService: AIServiceProtocol
    private let healthService: HealthKitServiceProtocol
    
    // MARK: - Init
    
    init(aiService: AIServiceProtocol = AIService.shared,
         healthService: HealthKitServiceProtocol = HealthKitService.shared) {
        self.aiService = aiService
        self.healthService = healthService
    }
    
    // MARK: - Chat Actions
    
    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Add user message
        let userMessage = ChatMessage.userMessage(text)
        messages.append(userMessage)
        inputText = ""
        
        // Add loading message
        let loadingMessage = ChatMessage.loadingMessage()
        messages.append(loadingMessage)
        
        chatState = .sending
        
        do {
            // Fetch health history for the last 7 days
            let history = await healthService.fetchHealthMetricsHistory(days: 7)
            let systemContext = formatHealthHistoryForChat(history)
            
            let response = try await aiService.sendChatMessage(text, context: messages.dropLast(), systemContext: systemContext)
            
            // Remove loading message and add response
            messages.removeLast()
            messages.append(ChatMessage.assistantMessage(response))
            chatState = .idle
        } catch {
            messages.removeLast()
            chatState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }
    
    func sendQuickAction(_ action: QuickAction) async {
        // Check if this is the health analysis quick action
        if action.title == "Analyze My Health" {
            await analyzeCurrentHealth()
        } else {
            inputText = action.prompt
            await sendMessage()
        }
    }
    
    func analyzeCurrentHealth() async {
        // Add user message
        let userMessage = ChatMessage.userMessage("Analyze my current health metrics")
        messages.append(userMessage)
        
        // Add loading message
        let loadingMessage = ChatMessage.loadingMessage()
        messages.append(loadingMessage)
        
        chatState = .sending
        
        do {
            // Fetch current health metrics
            let metrics = await healthService.fetchHealthMetrics(for: Date())
            
            // Format metrics into a natural language context
            let metricsContext = formatHealthMetricsForChat(metrics)
            
            // Send to AI with health context
            let prompt = "Here are my current health metrics:\n\n\(metricsContext)\n\nPlease analyze my health and provide insights and recommendations."
            
            let response = try await aiService.sendChatMessage(prompt, context: messages.dropLast(), systemContext: nil)
            
            // Remove loading message and add response
            messages.removeLast()
            messages.append(ChatMessage.assistantMessage(response))
            chatState = .idle
        } catch {
            messages.removeLast()
            chatState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }
    
    func clearChat() {
        messages = []
        chatState = .idle
        errorMessage = nil
    }
    
    // MARK: - Helpers
    
    func clearError() {
        errorMessage = nil
        if case .error = chatState {
            chatState = .idle
        }
    }
    
    private func formatHealthHistoryForChat(_ history: [HealthMetrics]) -> String {
        var parts: [String] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM"
        
        parts.append("Past 7 Days Health:")
        
        for metrics in history {
            let dateStr = dateFormatter.string(from: metrics.timestamp)
            // Compact format: "12/01: Steps:10k, Sleep:7h30m, HR:72, Cal:500, Ex:30m"
            
            let sleepVal = (metrics.sleep == "0h 0m") ? "N/A" : metrics.sleep
            let stepsK = String(format: "%.1fk", Double(metrics.steps)/1000.0)
            
            let line = "\(dateStr): Steps:\(stepsK), Sleep:\(sleepVal), HR:\(metrics.heartRate), Cal:\(metrics.activeCalories), Ex:\(metrics.exerciseMinutes)m"
            parts.append(line)
        }
        
        return parts.joined(separator: "\n")
    }
    
    private func formatHealthMetricsForChat(_ metrics: HealthMetrics) -> String {
        var parts: [String] = []
        
        parts.append("📊 Today's Activity:")
        parts.append("• Steps: \(metrics.steps.formatted())")
        parts.append("• Distance: \(String(format: "%.1f", metrics.distance)) km")
        parts.append("• Exercise: \(metrics.exerciseMinutes) minutes")
        parts.append("• Stand Hours: \(metrics.standHours)")
        parts.append("• Active Calories: \(metrics.activeCalories) cal")
        parts.append("")
        parts.append("❤️ Vitals:")
        parts.append("• Heart Rate: \(metrics.heartRate) bpm")
        parts.append("• Blood Pressure: \(metrics.bloodPressure)")
        parts.append("• Weight: \(metrics.weight) kg")
        parts.append("")
        parts.append("😴 Rest:")
        parts.append("• Sleep: \(metrics.sleep)")
        
        return parts.joined(separator: "\n")
    }
}

