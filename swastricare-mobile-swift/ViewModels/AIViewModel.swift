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
    
    // MARK: - AI Mode Selection
    
    @Published var selectedAIMode: AIMode = .general {
        didSet {
            // Persist mode selection
            UserDefaults.standard.set(selectedAIMode.rawValue, forKey: "ai_selected_mode")
        }
    }
    
    // MARK: - MedGemma State
    
    @Published private(set) var lastResponseModel: String = "gemini"
    @Published private(set) var lastResponseWasMedical: Bool = false
    @Published var showEmergencyAlert: Bool = false
    @Published var showMedicalDisclaimer: Bool = false
    @Published var hasAcknowledgedMedicalDisclaimer: Bool = false
    @Published private(set) var selectedImage: Data?
    @Published private(set) var isAnalyzingImage: Bool = false
    @Published private(set) var currentLoadingOperation: LoadingOperationType = .generalChat
    @Published private(set) var currentErrorState: AIErrorState?
    @Published private(set) var lastFailedMessage: String?
    
    // MARK: - Computed Properties
    
    var isBusy: Bool { chatState.isBusy }
    var hasMessages: Bool { !messages.isEmpty }
    var canSend: Bool { !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chatState.isBusy }
    var isMedicalMode: Bool { selectedAIMode == .medical || lastResponseWasMedical }
    
    // MARK: - Medical Keywords Detection
    
    private static let medicalKeywords: Set<String> = [
        // Symptoms
        "symptom", "pain", "ache", "hurt", "sore", "fever", "nausea", "dizzy", "fatigue",
        "headache", "migraine", "cough", "cold", "flu", "infection", "swelling", "rash",
        "bleeding", "vomiting", "diarrhea", "constipation", "cramp", "numbness", "tingling",
        // Medical terms
        "medication", "medicine", "drug", "prescription", "dose", "dosage", "side effect",
        "diagnosis", "condition", "disease", "illness", "disorder", "syndrome",
        "treatment", "therapy", "surgery", "procedure", "test", "scan", "x-ray", "mri",
        // Healthcare
        "doctor", "physician", "hospital", "clinic", "specialist",
        // Conditions
        "diabetes", "hypertension", "asthma", "allergy", "arthritis", "cancer",
        "depression", "anxiety", "insomnia", "anemia", "thyroid"
    ]
    
    private static let emergencyKeywords: Set<String> = [
        "chest pain", "heart attack", "stroke", "cant breathe", "cannot breathe",
        "difficulty breathing", "unconscious", "seizure", "severe bleeding",
        "overdose", "suicide", "suicidal", "dying", "emergency"
    ]
    
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
        
        // Restore saved AI mode preference
        if let savedMode = UserDefaults.standard.string(forKey: "ai_selected_mode"),
           let mode = AIMode(rawValue: savedMode) {
            self.selectedAIMode = mode
        }
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
        
        // Check for emergency before proceeding
        if isEmergencyMessage(text) {
            showEmergencyAlert = true
            // Still proceed with the message but flag it
        }
        
        // Check if medical disclaimer needed when in medical mode (first time)
        if selectedAIMode == .medical && !hasAcknowledgedMedicalDisclaimer {
            showMedicalDisclaimer = true
            // Store input and wait for acknowledgment
            return
        }
        
        // Add user message
        let userMessage = ChatMessage.userMessage(text)
        messages.append(userMessage)
        inputText = ""
        
        // Add loading message
        let loadingMessage = ChatMessage.loadingMessage()
        messages.append(loadingMessage)
        
        // Set loading operation type based on mode
        switch selectedAIMode {
        case .medical: currentLoadingOperation = .medicalQuery
        case .opus: currentLoadingOperation = .opusChat
        case .general: currentLoadingOperation = .generalChat
        }
        chatState = .sending
        
        do {
            // Fetch health history for the last 7 days
            let history = await healthService.fetchHealthMetricsHistory(days: 7)
            let systemContext = formatHealthHistoryForChat(history)
            
            let response: String
            
            // Route based on selected AI mode
            switch selectedAIMode {
            case .general:
                // Use general chat (Gemini)
                print("🤖 AI Mode: General (Swastri Assistant)")
                response = try await aiService.sendChatMessage(text, context: Array(messages.dropLast()), systemContext: systemContext)
                lastResponseModel = "gemini"
                lastResponseWasMedical = false
                
            case .medical:
                // TEMPORARY: Use ai-chat with medical prompt until medgemma-chat is fixed
                print("🏥 AI Mode: Medical Expert (using ai-chat temporarily)")

                // Build medical-specific system context
                var medicalContext = """
                You are Swastrica Medical AI, a health assistant by Swastricare (Onwords). Provide accurate medical information with these guidelines:
                - Always recommend consulting healthcare professionals
                - Flag emergency symptoms immediately
                - Use clear, empathetic language
                - Never prescribe medications or dosages
                - Include appropriate disclaimers

                """
                medicalContext += systemContext

                response = try await aiService.sendChatMessage(text, context: Array(messages.dropLast()), systemContext: medicalContext)
                lastResponseModel = "gemini-medical"
                lastResponseWasMedical = true

            case .opus:
                // Use Claude Opus 4.6 for advanced reasoning
                print("🧠 AI Mode: Claude Opus 4.6")
                let opusResponse = try await aiService.sendOpusMessage(text, context: Array(messages.dropLast()), systemContext: systemContext)
                response = opusResponse.text
                lastResponseModel = opusResponse.model
                lastResponseWasMedical = false
            }
            
            // Remove loading message and add response with mode badge
            messages.removeLast()
            let responseMode: AIResponseMode
            switch selectedAIMode {
            case .medical: responseMode = .medical
            case .opus: responseMode = .opus
            case .general: responseMode = .general
            }
            messages.append(ChatMessage.assistantMessage(response, mode: responseMode))
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
            messages.removeLast() // Remove loading message
            messages.removeLast() // Remove user message (we'll restore it on retry)
            lastFailedMessage = text
            currentErrorState = AIErrorState.fromError(error, mode: selectedAIMode)
            chatState = .error(currentErrorState?.message ?? error.localizedDescription)
            // Don't set errorMessage to prevent alert popup - show inline instead
        }
    }
    
    /// Retry the last failed message
    func retryLastMessage() async {
        guard let message = lastFailedMessage else { return }
        currentErrorState = nil
        inputText = message
        lastFailedMessage = nil
        await sendMessage()
    }
    
    /// Switch to general mode and retry
    func switchToGeneralAndRetry() async {
        selectedAIMode = .general
        currentErrorState = nil
        await retryLastMessage()
    }
    
    /// Dismiss the current error
    func dismissError() {
        currentErrorState = nil
        lastFailedMessage = nil
        if case .error = chatState {
            chatState = .idle
        }
    }
    
    /// Submit feedback for a message
    func submitFeedback(messageId: UUID, feedback: MessageFeedback) {
        // Update the message locally
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            // Create new message with feedback
            let oldMessage = messages[index]
            let updatedMessage = ChatMessage(
                id: oldMessage.id,
                content: oldMessage.content,
                isUser: oldMessage.isUser,
                timestamp: oldMessage.timestamp,
                isLoading: oldMessage.isLoading,
                responseMode: oldMessage.responseMode,
                userFeedback: feedback
            )
            messages[index] = updatedMessage
            
            // Log feedback (could send to analytics or backend)
            print("📊 User feedback: \(feedback.rawValue) for message: \(messageId)")
            
            // TODO: Send to Supabase for quality monitoring
            // Task {
            //     try? await aiService.logMessageFeedback(messageId: messageId, feedback: feedback)
            // }
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
        
        currentLoadingOperation = .healthAnalysis
        chatState = .sending
        
        do {
            // Fetch current health metrics
            let metrics = await healthService.fetchHealthMetrics(for: Date())
            
            // Format metrics into a natural language context
            let metricsContext = formatHealthMetricsForChat(metrics)
            
            // Send to AI with health context
            let prompt = "Here are my current health metrics:\n\n\(metricsContext)\n\nPlease analyze my health and provide insights and recommendations."
            
            let response = try await aiService.sendChatMessage(prompt, context: messages.dropLast(), systemContext: nil)
            
            // Remove loading message and add response with health analysis mode
            messages.removeLast()
            messages.append(ChatMessage.assistantMessage(response, mode: .healthAnalysis))
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
    
    // MARK: - Medical Disclaimer Acknowledgment
    
    func acknowledgeMedicalDisclaimer() {
        hasAcknowledgedMedicalDisclaimer = true
        showMedicalDisclaimer = false
        
        // Continue with the message if there was one pending
        if !inputText.isEmpty {
            Task {
                await sendMessage()
            }
        }
    }
    
    func dismissEmergencyAlert() {
        showEmergencyAlert = false
    }
    
    // MARK: - Image Analysis
    
    func setSelectedImage(_ imageData: Data?) {
        selectedImage = imageData
    }
    
    func analyzeSelectedImage(type: MedicalImageAnalysisType = .general, question: String? = nil) async {
        guard let imageData = selectedImage else { return }
        
        isAnalyzingImage = true
        
        // Add user message
        let typeDescription: String
        switch type {
        case .prescription: typeDescription = "Analyze this prescription"
        case .labReport: typeDescription = "Analyze this lab report"
        case .medicalDocument: typeDescription = "Analyze this medical document"
        case .xray: typeDescription = "Analyze this X-ray/scan"
        case .general: typeDescription = "Analyze this medical image"
        }
        
        let userMessage = ChatMessage.userMessage(question ?? typeDescription)
        messages.append(userMessage)
        
        // Add loading message
        let loadingMessage = ChatMessage.loadingMessage()
        messages.append(loadingMessage)
        
        currentLoadingOperation = .imageAnalysis
        chatState = .sending
        
        do {
            let aiResponse = try await aiService.analyzeMedicalImage(imageData, analysisType: type, question: question)
            
            // Update state
            lastResponseModel = aiResponse.model
            lastResponseWasMedical = true
            
            // Remove loading message and add response with image analysis mode
            messages.removeLast()
            messages.append(ChatMessage.assistantMessage(aiResponse.text, mode: .imageAnalysis))
            chatState = .idle
            
            // Clear image after analysis
            selectedImage = nil
            isAnalyzingImage = false
            
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
            isAnalyzingImage = false
        }
    }
    
    // MARK: - Message Classification
    
    private func isMedicalMessage(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return Self.medicalKeywords.contains { lowercased.contains($0) }
    }
    
    private func isEmergencyMessage(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return Self.emergencyKeywords.contains { lowercased.contains($0) }
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

