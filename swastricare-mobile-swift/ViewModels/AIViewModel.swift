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
    @Published private(set) var isLoadingHistory = false
    @Published var showHistorySheet = false
    @Published private(set) var conversations: [ConversationSummary] = []
    @Published private(set) var isLoadingConversations = false
    
    // MARK: - Computed Properties
    
    var isBusy: Bool { chatState.isBusy }
    var hasMessages: Bool { !messages.isEmpty }
    var canSend: Bool { !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chatState.isBusy }
    
    // MARK: - Dependencies
    
    private let aiService: AIServiceProtocol
    private let healthService: HealthKitServiceProtocol
    
    // MARK: - Private State
    
    private var currentConversationId: UUID?
    
    // MARK: - Init
    
    init(aiService: AIServiceProtocol = AIService.shared,
         healthService: HealthKitServiceProtocol = HealthKitService.shared) {
        self.aiService = aiService
        self.healthService = healthService
    }
    
    // MARK: - Lifecycle
    
    func loadHistory() async {
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        
        do {
            let (history, conversationId) = try await aiService.loadChatHistory()
            messages = history
            currentConversationId = conversationId
        } catch {
            // Silently fail if history can't be loaded (e.g., not authenticated)
            print("Failed to load chat history: \(error.localizedDescription)")
        }
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
            
            // Save chat history
            do {
                // #region agent log
                do {
                    let logData: [String: Any] = [
                        "sessionId": "debug-session",
                        "runId": "verify-storage",
                        "hypothesisId": "E",
                        "location": "AIViewModel.swift:94",
                        "message": "calling saveChatHistory",
                        "data": [
                            "messageCount": messages.count,
                            "hasConversationId": currentConversationId != nil
                        ],
                        "timestamp": Int(Date().timeIntervalSince1970 * 1000)
                    ]
                    if let logFile = FileHandle(forWritingAtPath: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log") {
                        try? logFile.seekToEnd()
                        try? logFile.write(Data((try? JSONSerialization.data(withJSONObject: logData)) ?? Data()))
                        try? logFile.write(Data("\n".utf8))
                        try? logFile.close()
                    }
                } catch {}
                // #endregion
                
                currentConversationId = try await aiService.saveChatHistory(messages, conversationId: currentConversationId)
                
                // #region agent log
                do {
                    let logData: [String: Any] = [
                        "sessionId": "debug-session",
                        "runId": "verify-storage",
                        "hypothesisId": "E",
                        "location": "AIViewModel.swift:115",
                        "message": "saveChatHistory completed",
                        "data": [
                            "conversationId": currentConversationId?.uuidString ?? "nil",
                            "saveSuccess": true
                        ],
                        "timestamp": Int(Date().timeIntervalSince1970 * 1000)
                    ]
                    if let logFile = FileHandle(forWritingAtPath: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log") {
                        try? logFile.seekToEnd()
                        try? logFile.write(Data((try? JSONSerialization.data(withJSONObject: logData)) ?? Data()))
                        try? logFile.write(Data("\n".utf8))
                        try? logFile.close()
                    }
                } catch {}
                // #endregion
                
                print("✅ Chat history saved successfully")
            } catch {
                // #region agent log
                do {
                    let logData: [String: Any] = [
                        "sessionId": "debug-session",
                        "runId": "verify-storage",
                        "hypothesisId": "E",
                        "location": "AIViewModel.swift:132",
                        "message": "saveChatHistory failed",
                        "data": [
                            "error": error.localizedDescription,
                            "saveSuccess": false
                        ],
                        "timestamp": Int(Date().timeIntervalSince1970 * 1000)
                    ]
                    if let logFile = FileHandle(forWritingAtPath: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log") {
                        try? logFile.seekToEnd()
                        try? logFile.write(Data((try? JSONSerialization.data(withJSONObject: logData)) ?? Data()))
                        try? logFile.write(Data("\n".utf8))
                        try? logFile.close()
                    }
                } catch {}
                // #endregion
                
                print("❌ Failed to save chat history: \(error.localizedDescription)")
            }
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
    
    // MARK: - Conversation Management
    
    func setConversationId(_ id: UUID?) {
        currentConversationId = id
    }
    
    func loadAllConversations() async {
        isLoadingConversations = true
        defer { isLoadingConversations = false }
        
        do {
            let loadedConversations = try await aiService.loadAllConversations()
            print("✅ Loaded \(loadedConversations.count) conversations")
            conversations = loadedConversations
            // Clear error if successful
            if errorMessage?.contains("chat history") == true {
                errorMessage = nil
            }
        } catch {
            print("❌ Failed to load conversations: \(error.localizedDescription)")
            print("Error details: \(error)")
            conversations = []
            // Only show error if it's not a network/auth issue (user might not be logged in)
            if let aiError = error as? AIError, aiError == .networkError {
                // Silently fail for network/auth errors - user might not be authenticated
                print("⚠️ Network/auth error - user may not be authenticated")
            } else {
                errorMessage = "Failed to load chat history: \(error.localizedDescription)"
            }
        }
    }
    
    func loadConversation(id: UUID) async {
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        
        do {
            let messages = try await aiService.loadConversation(id: id)
            self.messages = messages
            self.currentConversationId = id
            showHistorySheet = false
        } catch {
            errorMessage = "Failed to load conversation"
            print("Failed to load conversation: \(error.localizedDescription)")
        }
    }
    
    func deleteConversation(id: UUID) async {
        do {
            try await aiService.deleteConversation(id: id)
            // Remove from local list
            conversations.removeAll { $0.id == id }
            // If this was the current conversation, clear it
            if currentConversationId == id {
                messages = []
                currentConversationId = nil
            }
        } catch {
            errorMessage = "Failed to delete conversation"
            print("Failed to delete conversation: \(error.localizedDescription)")
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
            
            // Save chat history
            do {
                currentConversationId = try await aiService.saveChatHistory(messages, conversationId: currentConversationId)
            } catch {
                print("Failed to save chat history: \(error.localizedDescription)")
            }
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
        currentConversationId = nil
        
        // Archive current conversation in background
        Task {
            do {
                try await aiService.clearChatHistory()
            } catch {
                print("Failed to clear chat history: \(error.localizedDescription)")
            }
        }
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

