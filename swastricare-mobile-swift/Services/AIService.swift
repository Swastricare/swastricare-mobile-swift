//
//  AIService.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Services Layer
//  Handles AI chat and analysis via Supabase Edge Functions
//

import Foundation
import Supabase

// MARK: - AI Service Protocol

protocol AIServiceProtocol {
    func sendChatMessage(_ message: String, context: [ChatMessage], systemContext: String?) async throws -> String
    func sendSmartMessage(_ message: String, context: [ChatMessage], systemContext: String?) async throws -> AIResponse
    func sendMedicalQuery(_ message: String, context: [ChatMessage], healthContext: String?) async throws -> AIResponse
    func analyzeMedicalImage(_ imageData: Data, analysisType: MedicalImageAnalysisType, question: String?) async throws -> AIResponse
    func analyzeHealth(_ metrics: HealthMetrics) async throws -> HealthAnalysisResponse
    func generateHealthSummary(_ metrics: HealthMetrics) async throws -> String
    func loadChatHistory() async throws -> (messages: [ChatMessage], conversationId: UUID?)
    func loadAllConversations() async throws -> [ConversationSummary]
    func loadConversation(id: UUID) async throws -> [ChatMessage]
    func saveChatHistory(_ messages: [ChatMessage], conversationId: UUID?) async throws -> UUID
    func deleteConversation(id: UUID) async throws
    func archiveConversation(id: UUID) async throws
    func clearChatHistory() async throws
}

// MARK: - Medical Image Analysis Types

enum MedicalImageAnalysisType: String {
    case prescription = "prescription"
    case labReport = "lab_report"
    case medicalDocument = "medical_document"
    case xray = "xray"
    case general = "general"
}

// MARK: - AI Response Model

struct AIResponse {
    let text: String
    let model: String
    let isMedical: Bool
    let isEmergency: Bool
    let hasDisclaimer: Bool
    let isImageAnalysis: Bool
    
    init(
        text: String,
        model: String = "gemini",
        isMedical: Bool = false,
        isEmergency: Bool = false,
        hasDisclaimer: Bool = false,
        isImageAnalysis: Bool = false
    ) {
        self.text = text
        self.model = model
        self.isMedical = isMedical
        self.isEmergency = isEmergency
        self.hasDisclaimer = hasDisclaimer
        self.isImageAnalysis = isImageAnalysis
    }
}

// MARK: - AI Service Implementation

final class AIService: AIServiceProtocol {
    
    static let shared = AIService()
    
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    // MARK: - Chat
    
    func sendChatMessage(_ message: String, context: [ChatMessage], systemContext: String? = nil) async throws -> String {
        print("💬 === BASIC CHAT MESSAGE ===")
        print("💬 User message: \(message.prefix(100))...")
        print("💬 Has system context: \(systemContext != nil)")
        print("💬 History length: \(context.count)")
        
        // Format context for API
        // Backend expects 'conversationHistory' (not 'context')
        let conversationHistory = context.suffix(10).map { msg in
            ["role": msg.isUser ? "user" : "assistant", "content": msg.content]
        }
        
        // Prepare the message payload
        // We prepend the system context to the message because the backend 
        // treats 'message' as the user's prompt and doesn't support a separate system role.
        var finalMessage = message
        if let systemContext = systemContext {
            finalMessage = "CONTEXT_DATA:\n\(systemContext)\n\nUSER_QUERY:\n\(message)"
        }
        
        let payload: [String: Any] = [
            "message": finalMessage,
            "conversationHistory": conversationHistory
        ]
        
        print("💬 Calling Supabase function: ai-chat")
        print("💬 Payload: message length = \(finalMessage.count) chars, history items = \(conversationHistory.count)")
        
        let response = try await supabase.invokeFunction(
            name: "ai-chat",
            payload: payload
        )
        
        print("💬 === AI CHAT RESPONSE ===")
        
        guard let responseText = response["response"] as? String else {
            print("❌ No 'response' field in response!")
            throw AIError.invalidResponse
        }
        
        print("💬 Response length: \(responseText.count) characters")
        print("💬 Response preview: \(responseText.prefix(200))...")
        
        return responseText
    }
    
    // MARK: - Smart Message (Auto-routes to appropriate AI)
    
    func sendSmartMessage(_ message: String, context: [ChatMessage], systemContext: String? = nil) async throws -> AIResponse {
        print("🤖 === AI SMART MESSAGE ===")
        print("🤖 User message: \(message.prefix(100))...")
        print("🤖 Has context: \(systemContext != nil)")
        print("🤖 History length: \(context.count)")
        
        // Format context for API
        let conversationHistory = context.suffix(10).map { msg in
            ["role": msg.isUser ? "user" : "assistant", "content": msg.content]
        }
        
        var finalMessage = message
        if let systemContext = systemContext {
            finalMessage = "CONTEXT_DATA:\n\(systemContext)\n\nUSER_QUERY:\n\(message)"
        }
        
        let payload: [String: Any] = [
            "message": finalMessage,
            "conversationHistory": conversationHistory
        ]
        
        print("🤖 Calling Supabase function: ai-router")
        print("🤖 Payload: message length = \(finalMessage.count) chars, history items = \(conversationHistory.count)")
        
        let response = try await supabase.invokeFunction(
            name: "ai-router",
            payload: payload
        )
        
        print("🤖 === AI ROUTER RESPONSE ===")
        print("🤖 Raw response keys: \(response.keys.joined(separator: ", "))")
        
        guard let responseText = response["response"] as? String else {
            print("❌ No 'response' field in response!")
            throw AIError.invalidResponse
        }
        
        let model = response["model"] as? String ?? "gemini"
        let isMedical = response["isMedical"] as? Bool ?? false
        let isEmergency = response["isEmergency"] as? Bool ?? false
        let hasDisclaimer = response["hasDisclaimer"] as? Bool ?? isMedical
        
        print("🤖 Model used: \(model)")
        print("🤖 Is medical: \(isMedical)")
        print("🤖 Is emergency: \(isEmergency)")
        print("🤖 Has disclaimer: \(hasDisclaimer)")
        print("🤖 Response length: \(responseText.count) characters")
        print("🤖 Response preview: \(responseText.prefix(200))...")
        
        return AIResponse(
            text: responseText,
            model: model,
            isMedical: isMedical,
            isEmergency: isEmergency,
            hasDisclaimer: hasDisclaimer
        )
    }
    
    // MARK: - Medical Query (Direct to MedGemma)
    
    func sendMedicalQuery(_ message: String, context: [ChatMessage], healthContext: String? = nil) async throws -> AIResponse {
        print("🏥 === MEDICAL QUERY ===")
        print("🏥 User message: \(message.prefix(100))...")
        print("🏥 Has health context: \(healthContext != nil)")
        print("🏥 History length: \(context.count)")
        
        let conversationHistory = context.suffix(10).map { msg in
            ["role": msg.isUser ? "user" : "assistant", "content": msg.content]
        }
        
        var payload: [String: Any] = [
            "message": message,
            "conversationHistory": conversationHistory
        ]
        
        if let healthContext = healthContext {
            payload["healthContext"] = healthContext
            print("🏥 Health context: \(healthContext.prefix(100))...")
        }
        
        print("🏥 Calling Supabase function: medgemma-chat")
        
        let response = try await supabase.invokeFunction(
            name: "medgemma-chat",
            payload: payload
        )
        
        print("🏥 === MEDGEMMA RESPONSE ===")
        print("🏥 Raw response keys: \(response.keys.joined(separator: ", "))")
        
        guard let responseText = response["response"] as? String else {
            print("❌ No 'response' field in response!")
            throw AIError.invalidResponse
        }
        
        let model = response["model"] as? String ?? "medgemma-27b"
        
        print("🏥 Model used: \(model)")
        print("🏥 Response length: \(responseText.count) characters")
        print("🏥 Response preview: \(responseText.prefix(200))...")
        
        return AIResponse(
            text: responseText,
            model: model,
            isMedical: true,
            isEmergency: false,
            hasDisclaimer: true
        )
    }
    
    // MARK: - Medical Image Analysis (MedGemma 4B Vision)
    
    func analyzeMedicalImage(_ imageData: Data, analysisType: MedicalImageAnalysisType = .general, question: String? = nil) async throws -> AIResponse {
        print("📸 === MEDICAL IMAGE ANALYSIS ===")
        print("📸 Analysis type: \(analysisType.rawValue)")
        print("📸 Image data size: \(imageData.count) bytes")
        print("📸 Has question: \(question != nil)")
        if let question = question {
            print("📸 Question: \(question.prefix(100))...")
        }
        
        // Convert image data to base64
        let base64String = imageData.base64EncodedString()
        
        // Detect image type from data
        let imageType = detectImageType(from: imageData)
        print("📸 Detected image type: \(imageType)")
        print("📸 Base64 string length: \(base64String.count) characters")
        
        var payload: [String: Any] = [
            "imageData": base64String,
            "imageType": imageType,
            "analysisType": analysisType.rawValue
        ]
        
        if let question = question {
            payload["message"] = question
        }
        
        print("📸 Calling Supabase function: medgemma-vision")
        
        let response = try await supabase.invokeFunction(
            name: "medgemma-vision",
            payload: payload
        )
        
        print("📸 === VISION RESPONSE ===")
        print("📸 Raw response keys: \(response.keys.joined(separator: ", "))")
        
        guard let responseText = response["response"] as? String else {
            print("❌ No 'response' field in response!")
            throw AIError.invalidResponse
        }
        
        let model = response["model"] as? String ?? "medgemma-4b"
        
        print("📸 Model used: \(model)")
        print("📸 Response length: \(responseText.count) characters")
        print("📸 Response preview: \(responseText.prefix(200))...")
        
        return AIResponse(
            text: responseText,
            model: model,
            isMedical: true,
            isEmergency: false,
            hasDisclaimer: true,
            isImageAnalysis: true
        )
    }
    
    // MARK: - Image Type Detection
    
    private func detectImageType(from data: Data) -> String {
        guard data.count >= 4 else { return "jpeg" }
        
        let bytes = [UInt8](data.prefix(4))
        
        // JPEG: FF D8 FF
        if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return "jpeg"
        }
        
        // PNG: 89 50 4E 47
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "png"
        }
        
        // WebP: RIFF....WEBP
        if data.count >= 12 {
            let webpBytes = [UInt8](data.prefix(12))
            if webpBytes[0] == 0x52 && webpBytes[1] == 0x49 && webpBytes[2] == 0x46 && webpBytes[3] == 0x46 &&
               webpBytes[8] == 0x57 && webpBytes[9] == 0x45 && webpBytes[10] == 0x42 && webpBytes[11] == 0x50 {
                return "webp"
            }
        }
        
        // Default to JPEG
        return "jpeg"
    }
    
    // MARK: - Health Analysis
    
    func analyzeHealth(_ metrics: HealthMetrics) async throws -> HealthAnalysisResponse {
        let sleepHours = parseSleepHours(metrics.sleep)
        let weight = Double(metrics.weight.replacingOccurrences(of: "--", with: "0")) ?? 0
        
        let payload: [String: Any] = [
            "steps": metrics.steps,
            "heartRate": metrics.heartRate,
            "sleepDuration": metrics.sleep,
            "activeCalories": metrics.activeCalories,
            "exerciseMinutes": metrics.exerciseMinutes,
            "standHours": metrics.standHours,
            "distance": metrics.distance,
            "bloodPressure": metrics.bloodPressure,
            "weight": weight
        ]
        
        let response = try await supabase.invokeFunction(
            name: "ai-health-analysis",
            payload: payload
        )
        
        // Parse response matching new format
        guard let assessment = response["assessment"] as? String,
              let insights = response["insights"] as? String,
              let recommendations = response["recommendations"] as? [String] else {
            throw AIError.invalidResponse
        }
        
        return HealthAnalysisResponse(
            assessment: assessment,
            insights: insights,
            recommendations: recommendations
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
    
    // MARK: - Chat History
    
    func loadChatHistory() async throws -> (messages: [ChatMessage], conversationId: UUID?) {
        // Check authentication first
        guard let userId = try? await supabase.client.auth.session.user.id else {
            print("❌ No user ID - not authenticated")
            return ([], nil)
        }
        
        struct ConversationRecord: Decodable {
            let id: UUID
            let messages: [[String: String]]
            let updated_at: String
        }
        
        var conversations: [ConversationRecord] = []
        
        // Try to get health profile ID first, but fall back to user_id if not available
        if let profileId = try? await getHealthProfileId() {
            // Try querying by health_profile_id first - only load ACTIVE conversations
            conversations = try await supabase.client
                .from("ai_conversations")
                .select("id, messages, updated_at")
                .eq("health_profile_id", value: profileId.uuidString)
                .eq("status", value: "active")
                .order("updated_at", ascending: false)
                .limit(1)
                .execute()
                .value
        }
        
        // If no conversations found by profile_id, or no profile exists, query by user_id
        if conversations.isEmpty {
            conversations = try await supabase.client
                .from("ai_conversations")
                .select("id, messages, updated_at")
                .eq("user_id", value: userId.uuidString)
                .eq("status", value: "active")
                .order("updated_at", ascending: false)
                .limit(1)
                .execute()
                .value
        }
        
        // Only return conversation if it has messages
        guard let conversation = conversations.first,
              !conversation.messages.isEmpty else {
            return ([], nil)
        }
        
        // Convert JSON messages to ChatMessage array
        var chatMessages: [ChatMessage] = []
        
        // Try parsing with fractional seconds first, then without
        let dateFormatterWithFractional = ISO8601DateFormatter()
        dateFormatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let dateFormatterWithoutFractional = ISO8601DateFormatter()
        dateFormatterWithoutFractional.formatOptions = [.withInternetDateTime]
        
        for msgDict in conversation.messages {
            guard let role = msgDict["role"],
                  let content = msgDict["content"] else {
                continue
            }
            
            let timestamp: Date
            if let timestampStr = msgDict["timestamp"] {
                // Try parsing with fractional seconds first
                if let parsedDate = dateFormatterWithFractional.date(from: timestampStr) {
                    timestamp = parsedDate
                } else if let parsedDate = dateFormatterWithoutFractional.date(from: timestampStr) {
                    timestamp = parsedDate
                } else {
                    timestamp = Date()
                }
            } else {
                timestamp = Date()
            }
            
            let isUser = role == "user"
            let message = ChatMessage(
                content: content,
                isUser: isUser,
                timestamp: timestamp
            )
            chatMessages.append(message)
        }
        
        return (chatMessages, conversation.id)
    }
    
    func loadAllConversations() async throws -> [ConversationSummary] {
        // Check authentication first
        guard let userId = try? await supabase.client.auth.session.user.id else {
            print("❌ No user ID - not authenticated")
            throw AIError.networkError
        }
        
        struct ConversationRecord: Decodable {
            let id: UUID
            let title: String?
            let messages: [[String: String]]
            let updated_at: String
            let status: String?
        }
        
        // Try to get health profile ID first, but fall back to user_id if not available
        var conversations: [ConversationRecord] = []
        
        if let profileId = try? await getHealthProfileId() {
            print("📋 Loading conversations for profile: \(profileId.uuidString)")
            // Try querying by health_profile_id first
            conversations = try await supabase.client
                .from("ai_conversations")
                .select("id, title, messages, updated_at, status")
                .eq("health_profile_id", value: profileId.uuidString)
                .order("updated_at", ascending: false)
                .limit(50)
                .execute()
                .value
        }
        
        // If no conversations found by profile_id, or no profile exists, query by user_id
        if conversations.isEmpty {
            print("📋 Loading conversations for user: \(userId.uuidString)")
            conversations = try await supabase.client
                .from("ai_conversations")
                .select("id, title, messages, updated_at, status")
                .eq("user_id", value: userId.uuidString)
                .order("updated_at", ascending: false)
                .limit(50)
                .execute()
                .value
        }
        
        print("📋 Found \(conversations.count) conversations in database")
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return conversations.map { conv in
            let lastMessage = conv.messages.last?["content"] ?? "No messages"
            let updatedAt = dateFormatter.date(from: conv.updated_at) ?? Date()
            let status = conv.status ?? "active"
            
            // Extract title from first user message if title is empty
            let title: String
            if let existingTitle = conv.title, !existingTitle.isEmpty {
                title = existingTitle
            } else {
                // Find first user message for title
                let firstUserMessage = conv.messages.first(where: { $0["role"] == "user" })?["content"] ?? lastMessage
                title = String(firstUserMessage.prefix(50))
            }
            
            return ConversationSummary(
                id: conv.id,
                title: title,
                lastMessage: lastMessage,
                updatedAt: updatedAt,
                messageCount: conv.messages.count,
                status: status
            )
        }
    }
    
    func loadConversation(id: UUID) async throws -> [ChatMessage] {
        struct ConversationRecord: Decodable {
            let id: UUID
            let messages: [[String: String]]
        }
        
        let conversation: ConversationRecord = try await supabase.client
            .from("ai_conversations")
            .select("id, messages")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        
        // Convert JSON messages to ChatMessage array
        var chatMessages: [ChatMessage] = []
        
        let dateFormatterWithFractional = ISO8601DateFormatter()
        dateFormatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let dateFormatterWithoutFractional = ISO8601DateFormatter()
        dateFormatterWithoutFractional.formatOptions = [.withInternetDateTime]
        
        for msgDict in conversation.messages {
            guard let role = msgDict["role"],
                  let content = msgDict["content"] else {
                continue
            }
            
            let timestamp: Date
            if let timestampStr = msgDict["timestamp"] {
                if let parsedDate = dateFormatterWithFractional.date(from: timestampStr) {
                    timestamp = parsedDate
                } else if let parsedDate = dateFormatterWithoutFractional.date(from: timestampStr) {
                    timestamp = parsedDate
                } else {
                    timestamp = Date()
                }
            } else {
                timestamp = Date()
            }
            
            let isUser = role == "user"
            let message = ChatMessage(
                content: content,
                isUser: isUser,
                timestamp: timestamp
            )
            chatMessages.append(message)
        }
        
        return chatMessages
    }
    
    func saveChatHistory(_ messages: [ChatMessage], conversationId: UUID?) async throws -> UUID {
        // #region agent log
        do {
            let logData: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "A",
                "location": "AIService.swift:354",
                "message": "saveChatHistory entry",
                "data": [
                    "hasConversationId": conversationId != nil,
                    "messageCount": messages.count
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
        
        guard let userId = try? await supabase.client.auth.session.user.id else {
            print("❌ No user ID - not authenticated")
            throw AIError.networkError
        }
        
        // Try to get health profile ID, but it's optional
        let profileId = try? await getHealthProfileId()
        
        // #region agent log
        do {
            let logData: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "A",
                "location": "AIService.swift:361",
                "message": "profileId check",
                "data": [
                    "userId": userId.uuidString,
                    "hasProfileId": profileId != nil,
                    "profileId": profileId?.uuidString ?? "nil"
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
        
        // Convert ChatMessage array to JSON format
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        struct MessageItem: Codable {
            let role: String
            let content: String
            let timestamp: String
        }
        
        let messagesJSON = messages.filter { !$0.isLoading }.map { msg -> MessageItem in
            MessageItem(
                role: msg.isUser ? "user" : "assistant",
                content: msg.content,
                timestamp: dateFormatter.string(from: msg.timestamp)
            )
        }
        
        if let existingId = conversationId {
            // Update existing conversation
            struct ConversationUpdate: Encodable {
                let messages: [MessageItem]
                let updated_at: String
            }
            
            struct UpdateResponse: Decodable {
                let id: UUID
            }
            
            let update = ConversationUpdate(
                messages: messagesJSON,
                updated_at: dateFormatter.string(from: Date())
            )
            
            // Build query with appropriate filter
            let updated: UpdateResponse
            if let profileId = profileId {
                updated = try await supabase.client
                    .from("ai_conversations")
                    .update(update)
                    .eq("id", value: existingId.uuidString)
                    .eq("health_profile_id", value: profileId.uuidString)
                    .select("id")
                    .single()
                    .execute()
                    .value
            } else {
                updated = try await supabase.client
                    .from("ai_conversations")
                    .update(update)
                    .eq("id", value: existingId.uuidString)
                    .eq("user_id", value: userId.uuidString)
                    .select("id")
                    .single()
                    .execute()
                    .value
            }
            
            return updated.id
        } else {
            // Create new conversation
            struct ConversationResponse: Decodable {
                let id: UUID
            }
            
            let title = messages.first(where: { $0.isUser })?.content.prefix(100) ?? "New Conversation"
            
            // Create insert with optional health_profile_id
            struct ConversationInsertOptional: Encodable {
                let health_profile_id: UUID?
                let user_id: UUID
                let title: String
                let conversation_type: String
                let messages: [MessageItem]
                let status: String
                let model_used: String
            }
            
            // #region agent log
            do {
                let logData: [String: Any] = [
                    "sessionId": "debug-session",
                    "runId": "post-fix",
                    "hypothesisId": "B",
                    "location": "AIService.swift:441",
                    "message": "before insert (post-fix)",
                    "data": [
                        "hasProfileId": profileId != nil,
                        "profileId": profileId?.uuidString ?? "nil",
                        "userId": userId.uuidString
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
            
            // health_profile_id is now nullable in database, so we can insert even without a profile
            let insert = ConversationInsertOptional(
                health_profile_id: profileId,
                user_id: userId,
                title: String(title),
                conversation_type: "general_health",
                messages: messagesJSON,
                status: "active",
                model_used: "gemini-3-flash-preview"
            )
            
            let created: ConversationResponse = try await supabase.client
                .from("ai_conversations")
                .insert(insert)
                .select("id")
                .single()
                .execute()
                .value
            
            // #region agent log
            do {
                let logData: [String: Any] = [
                    "sessionId": "debug-session",
                    "runId": "run1",
                    "hypothesisId": "B",
                    "location": "AIService.swift:490",
                    "message": "insert success",
                    "data": [
                        "conversationId": created.id.uuidString
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
            
            return created.id
        }
    }
    
    func deleteConversation(id: UUID) async throws {
        guard let userId = try? await supabase.client.auth.session.user.id else {
            print("❌ No user ID - not authenticated")
            throw AIError.networkError
        }
        
        // Delete the conversation (cascade will handle related data)
        try await supabase.client
            .from("ai_conversations")
            .delete()
            .eq("id", value: id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        print("✅ Conversation deleted: \(id.uuidString)")
    }
    
    func archiveConversation(id: UUID) async throws {
        guard let userId = try? await supabase.client.auth.session.user.id else {
            print("❌ No user ID - not authenticated")
            throw AIError.networkError
        }
        
        // Archive the conversation by setting status to 'archived'
        try await supabase.client
            .from("ai_conversations")
            .update(["status": "archived"])
            .eq("id", value: id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        print("✅ Conversation archived: \(id.uuidString)")
    }
    
    func clearChatHistory() async throws {
        guard let userId = try? await supabase.client.auth.session.user.id else {
            print("❌ No user ID - not authenticated")
            throw AIError.networkError
        }
        
        // Try to get health profile ID, but use user_id as fallback
        if let profileId = try? await getHealthProfileId() {
            // Archive all active conversations for this profile
            try await supabase.client
                .from("ai_conversations")
                .update(["status": "archived"])
                .eq("health_profile_id", value: profileId.uuidString)
                .eq("status", value: "active")
                .execute()
        } else {
            // Fall back to archiving by user_id
            try await supabase.client
                .from("ai_conversations")
                .update(["status": "archived"])
                .eq("user_id", value: userId.uuidString)
                .eq("status", value: "active")
                .execute()
        }
    }
    
    // MARK: - Helpers
    
    private func getHealthProfileId() async throws -> UUID {
        // Check authentication first
        do {
            let session = try await supabase.client.auth.session
            guard !session.isExpired else {
                print("❌ Session expired")
                throw AIError.networkError
            }
        } catch {
            print("❌ Not authenticated: \(error.localizedDescription)")
            throw AIError.networkError
        }
        
        guard let userId = try? await supabase.client.auth.session.user.id else {
            print("❌ No user ID found")
            throw AIError.networkError
        }
        
        struct ProfileId: Decodable {
            let id: UUID
        }
        
        do {
            // First, try to get primary profile
            var profiles: [ProfileId] = try await supabase.client
                .from("health_profiles")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .eq("is_primary", value: true)
                .limit(1)
                .execute()
                .value
            
            // If no primary profile found, fall back to any profile for this user
            if profiles.isEmpty {
                profiles = try await supabase.client
                    .from("health_profiles")
                    .select("id")
                    .eq("user_id", value: userId.uuidString)
                    .limit(1)
                    .execute()
                    .value
            }
            
            guard let profileId = profiles.first?.id else {
                throw AIError.networkError
            }
            
            return profileId
        } catch {
            throw AIError.networkError
        }
    }
    
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

