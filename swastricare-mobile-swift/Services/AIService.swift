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
    func sendSmartMessage(_ message: String, context: [ChatMessage], systemContext: String?, forceModel: String?) async throws -> AIResponse
    func sendMedicalQuery(_ message: String, context: [ChatMessage], healthContext: String?) async throws -> AIResponse
    func analyzeMedicalImage(_ imageData: Data, analysisType: MedicalImageAnalysisType, question: String?) async throws -> AIResponse
    func analyzeFoodImage(_ imageData: Data) async throws -> SnapFoodResult
    func analyzeHealth(_ metrics: HealthMetrics) async throws -> HealthAnalysisResponse
    func generateHealthSummary(_ metrics: HealthMetrics) async throws -> String
    func loadChatHistory() async throws -> (messages: [ChatMessage], conversationId: UUID?)
    func loadAllConversations() async throws -> [ConversationSummary]
    func loadConversation(id: UUID) async throws -> [ChatMessage]
    func saveChatHistory(_ messages: [ChatMessage], conversationId: UUID?) async throws -> UUID
    func deleteConversation(id: UUID) async throws
    func archiveConversation(id: UUID) async throws
    func clearChatHistory() async throws
    func saveMedicalConsent() async throws
    func checkMedicalConsent() async -> Bool
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
        model: String = "minimax",
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
        
        // Build conversation history with first-message retention
        let conversationHistory = buildConversationHistory(from: context)

        var payload: [String: Any] = [
            "message": message,
            "conversationHistory": conversationHistory
        ]

        if let systemContext = systemContext {
            payload["systemContext"] = systemContext
        }

        print("💬 Calling Supabase function: ai-chat")
        print("💬 Payload: message length = \(message.count) chars, history items = \(conversationHistory.count)")
        
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
    
    func sendSmartMessage(_ message: String, context: [ChatMessage], systemContext: String? = nil, forceModel: String? = nil) async throws -> AIResponse {
        print("🤖 === AI SMART MESSAGE ===")
        print("🤖 User message: \(message.prefix(100))...")
        print("🤖 Has context: \(systemContext != nil)")
        print("🤖 Force model: \(forceModel ?? "auto")")
        print("🤖 History length: \(context.count)")

        // Build conversation history with first-message retention
        let conversationHistory = buildConversationHistory(from: context)

        var payload: [String: Any] = [
            "message": message,
            "conversationHistory": conversationHistory
        ]

        if let systemContext = systemContext {
            payload["systemContext"] = systemContext
        }

        if let forceModel = forceModel {
            payload["forceModel"] = forceModel
        }

        print("🤖 Calling Supabase function: ai-router")
        print("🤖 Payload: message length = \(message.count) chars, history items = \(conversationHistory.count)")

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
        
        let model = response["model"] as? String ?? "minimax"
        let isMedical = response["isMedical"] as? Bool ?? false
        let isEmergency = response["isEmergency"] as? Bool ?? false
        let hasDisclaimer = response["hasDisclaimer"] as? Bool ?? isMedical

        print("🤖 Model used: \(model)")
        print("🤖 Is medical: \(isMedical)")
        print("🤖 Is emergency: \(isEmergency)")
        print("🤖 Has disclaimer: \(hasDisclaimer)")
        print("🤖 Response length: \(responseText.count) characters")
        
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
        
        let conversationHistory = buildConversationHistory(from: context)

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
        
        let model = response["model"] as? String ?? "minimax-medical"
        
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

    // MARK: - Food Image Analysis (AI-powered nutrition detection)

    func analyzeFoodImage(_ imageData: Data) async throws -> SnapFoodResult {
        print("🍽️ === FOOD IMAGE ANALYSIS ===")
        print("🍽️ Image data size: \(imageData.count) bytes")

        // Convert image data to base64
        let base64String = imageData.base64EncodedString()

        // Detect image type from data
        let imageType = detectImageType(from: imageData)
        print("🍽️ Detected image type: \(imageType)")
        print("🍽️ Base64 string length: \(base64String.count) characters")

        // Build food analysis prompt (following Android implementation)
        let foodPrompt = """
        Identify the food in this image. This is likely Indian cuisine.
        Respond ONLY with this exact format:

        FOOD: <name>
        CALORIES: <number>
        PROTEIN: <grams as number>
        CARBS: <grams as number>
        FAT: <grams as number>
        FIBER: <grams as number>
        SERVING_SIZE: <number>
        SERVING_UNIT: <unit>
        CATEGORY: <category>

        For SERVING_UNIT, use one of: g, ml, piece, cup, tbsp, tsp, oz, bowl, plate
        For CATEGORY, use one of: fruits, vegetables, grains, protein, dairy, beverages, snacks, sweets, other
        """

        let payload: [String: Any] = [
            "imageData": base64String,
            "imageType": imageType,
            "analysisType": "general",
            "message": foodPrompt
        ]

        print("🍽️ Calling Supabase function: medgemma-vision")

        let response = try await supabase.invokeFunction(
            name: "medgemma-vision",
            payload: payload
        )

        print("🍽️ === FOOD VISION RESPONSE ===")
        print("🍽️ Raw response keys: \(response.keys.joined(separator: ", "))")

        guard let responseText = response["response"] as? String else {
            print("❌ No 'response' field in response!")
            throw AIError.invalidResponse
        }

        print("🍽️ Response length: \(responseText.count) characters")
        print("🍽️ Response text:\n\(responseText)")

        // Parse the structured response
        let foodResult = try parseFoodResponse(responseText)

        print("🍽️ Parsed food: \(foodResult.name)")
        print("🍽️ Calories: \(foodResult.calories)")
        print("🍽️ Macros: P:\(foodResult.proteinG)g C:\(foodResult.carbsG)g F:\(foodResult.fatG)g")

        return foodResult
    }

    private func parseFoodResponse(_ text: String) throws -> SnapFoodResult {
        var name = "Unknown Food"
        var calories: Double = 0
        var proteinG: Double = 0
        var carbsG: Double = 0
        var fatG: Double = 0
        var fiberG: Double = 0
        var servingSize: Double = 1.0
        var servingUnit: ServingUnit = .piece
        var category: FoodCategory = .other

        // Parse each line
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("FOOD:") {
                name = trimmed.replacingOccurrences(of: "FOOD:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("CALORIES:") {
                let value = trimmed.replacingOccurrences(of: "CALORIES:", with: "").trimmingCharacters(in: .whitespaces)
                calories = Double(value.components(separatedBy: .whitespaces).first ?? "0") ?? 0
            } else if trimmed.hasPrefix("PROTEIN:") {
                let value = trimmed.replacingOccurrences(of: "PROTEIN:", with: "").trimmingCharacters(in: .whitespaces)
                proteinG = Double(value.components(separatedBy: .whitespaces).first ?? "0") ?? 0
            } else if trimmed.hasPrefix("CARBS:") {
                let value = trimmed.replacingOccurrences(of: "CARBS:", with: "").trimmingCharacters(in: .whitespaces)
                carbsG = Double(value.components(separatedBy: .whitespaces).first ?? "0") ?? 0
            } else if trimmed.hasPrefix("FAT:") {
                let value = trimmed.replacingOccurrences(of: "FAT:", with: "").trimmingCharacters(in: .whitespaces)
                fatG = Double(value.components(separatedBy: .whitespaces).first ?? "0") ?? 0
            } else if trimmed.hasPrefix("FIBER:") {
                let value = trimmed.replacingOccurrences(of: "FIBER:", with: "").trimmingCharacters(in: .whitespaces)
                fiberG = Double(value.components(separatedBy: .whitespaces).first ?? "0") ?? 0
            } else if trimmed.hasPrefix("SERVING_SIZE:") {
                let value = trimmed.replacingOccurrences(of: "SERVING_SIZE:", with: "").trimmingCharacters(in: .whitespaces)
                servingSize = Double(value.components(separatedBy: .whitespaces).first ?? "1") ?? 1.0
            } else if trimmed.hasPrefix("SERVING_UNIT:") {
                let value = trimmed.replacingOccurrences(of: "SERVING_UNIT:", with: "").trimmingCharacters(in: .whitespaces).lowercased()
                servingUnit = ServingUnit(rawValue: value) ?? .piece
            } else if trimmed.hasPrefix("CATEGORY:") {
                let value = trimmed.replacingOccurrences(of: "CATEGORY:", with: "").trimmingCharacters(in: .whitespaces).lowercased()
                category = FoodCategory(rawValue: value) ?? .other
            }
        }

        return SnapFoodResult(
            name: name,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            fiberG: fiberG,
            servingSize: servingSize,
            servingUnit: servingUnit,
            category: category
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
            let messages: [[String: AnyCodableValue]]
            let updated_at: String
        }

        var conversations: [ConversationRecord] = []

        // Try to get health profile ID first, but fall back to user_id if not available
        if let profileId = try? await getHealthProfileId() {
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

        guard let conversation = conversations.first,
              !conversation.messages.isEmpty else {
            return ([], nil)
        }

        let chatMessages = Self.parseMessages(conversation.messages)
        return (chatMessages, conversation.id)
    }

    /// Shared message parser for flexible JSON decoding
    private static func parseMessages(_ rawMessages: [[String: AnyCodableValue]]) -> [ChatMessage] {
        var chatMessages: [ChatMessage] = []

        let dateFormatterWithFractional = ISO8601DateFormatter()
        dateFormatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let dateFormatterWithoutFractional = ISO8601DateFormatter()
        dateFormatterWithoutFractional.formatOptions = [.withInternetDateTime]

        for msgDict in rawMessages {
            guard let role = msgDict["role"]?.stringValue,
                  let content = msgDict["content"]?.stringValue else {
                continue
            }

            let timestamp: Date
            if let timestampStr = msgDict["timestamp"]?.stringValue {
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
            let isBookmarked = msgDict["is_bookmarked"]?.boolValue ?? false
            let feedback: MessageFeedback? = msgDict["user_feedback"]?.stringValue.flatMap { MessageFeedback(rawValue: $0) }

            chatMessages.append(ChatMessage(
                content: content,
                isUser: isUser,
                timestamp: timestamp,
                userFeedback: feedback,
                isBookmarked: isBookmarked
            ))
        }

        return chatMessages
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
            let messages: [[String: AnyCodableValue]]
            let updated_at: String
            let status: String?
        }

        // Try to get health profile ID first, but fall back to user_id if not available
        var conversations: [ConversationRecord] = []

        if let profileId = try? await getHealthProfileId() {
            print("📋 Loading conversations for profile: \(profileId.uuidString)")
            conversations = try await supabase.client
                .from("ai_conversations")
                .select("id, title, messages, updated_at, status")
                .eq("health_profile_id", value: profileId.uuidString)
                .order("updated_at", ascending: false)
                .limit(50)
                .execute()
                .value
        }

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
            let lastMessage = conv.messages.last?["content"]?.stringValue ?? "No messages"
            let updatedAt = dateFormatter.date(from: conv.updated_at) ?? Date()
            let status = conv.status ?? "active"
            
            // Extract title from first user message if title is empty
            let title: String
            if let existingTitle = conv.title, !existingTitle.isEmpty {
                title = existingTitle
            } else {
                let firstUserMessage = conv.messages.first(where: { $0["role"]?.stringValue == "user" })?["content"]?.stringValue ?? lastMessage
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
            let messages: [[String: AnyCodableValue]]
        }

        let conversation: ConversationRecord = try await supabase.client
            .from("ai_conversations")
            .select("id, messages")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value

        return Self.parseMessages(conversation.messages)
    }
    
    func saveChatHistory(_ messages: [ChatMessage], conversationId: UUID?) async throws -> UUID {
        guard let userId = try? await supabase.client.auth.session.user.id else {
            print("❌ No user ID - not authenticated")
            throw AIError.networkError
        }
        
        // Try to get health profile ID, but it's optional
        let profileId = try? await getHealthProfileId()

        // Convert ChatMessage array to JSON format
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        struct MessageItem: Codable {
            let role: String
            let content: String
            let timestamp: String
            let is_bookmarked: Bool?
            let user_feedback: String?
        }

        let messagesJSON = messages.filter { !$0.isLoading }.map { msg -> MessageItem in
            MessageItem(
                role: msg.isUser ? "user" : "assistant",
                content: msg.content,
                timestamp: dateFormatter.string(from: msg.timestamp),
                is_bookmarked: msg.isBookmarked ? true : nil,
                user_feedback: msg.userFeedback?.rawValue
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
            
            // health_profile_id is now nullable in database, so we can insert even without a profile
            let insert = ConversationInsertOptional(
                health_profile_id: profileId,
                user_id: userId,
                title: String(title),
                conversation_type: "general_health",
                messages: messagesJSON,
                status: "active",
                model_used: "minimax"
            )
            
            let created: ConversationResponse = try await supabase.client
                .from("ai_conversations")
                .insert(insert)
                .select("id")
                .single()
                .execute()
                .value
            
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
    
    // MARK: - Medical Consent

    func saveMedicalConsent() async throws {
        guard let userId = try? await supabase.client.auth.session.user.id else {
            return
        }

        struct ConsentInsert: Encodable {
            let user_id: UUID
            let consent_type: String
            let consent_version: String
            let device_type: String
            let app_version: String
        }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        let insert = ConsentInsert(
            user_id: userId,
            consent_type: "initial_disclaimer",
            consent_version: "1.0",
            device_type: "ios",
            app_version: appVersion
        )

        // ON CONFLICT DO NOTHING — upsert only if not already present
        try await supabase.client
            .from("ai_medical_consent")
            .upsert(insert, onConflict: "user_id,consent_type,consent_version", ignoreDuplicates: true)
            .execute()

        print("✅ Medical consent saved")
    }

    func checkMedicalConsent() async -> Bool {
        guard let userId = try? await supabase.client.auth.session.user.id else {
            return false
        }

        struct ConsentRecord: Decodable {
            let id: UUID
        }

        do {
            let records: [ConsentRecord] = try await supabase.client
                .from("ai_medical_consent")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .eq("consent_type", value: "initial_disclaimer")
                .limit(1)
                .execute()
                .value

            return !records.isEmpty
        } catch {
            print("⚠️ Failed to check medical consent: \(error.localizedDescription)")
            return false
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
    
    /// Build conversation history with first-message retention for topic awareness.
    /// Keeps the first user message + last 19 messages (up to 20 total).
    private func buildConversationHistory(from context: [ChatMessage]) -> [[String: String]] {
        let allMessages = context.filter { !$0.isLoading }

        if allMessages.count > 20 {
            var truncated: [[String: String]] = []

            // Always include the first user message for topic awareness
            if let firstUser = allMessages.first(where: { $0.isUser }) {
                truncated.append(["role": "user", "content": firstUser.content])
            }

            // Then add the most recent 19
            truncated += allMessages.suffix(19).map { msg in
                ["role": msg.isUser ? "user" : "assistant", "content": msg.content]
            }

            return truncated
        } else {
            return allMessages.map { msg in
                ["role": msg.isUser ? "user" : "assistant", "content": msg.content]
            }
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

// MARK: - AnyCodableValue (handles mixed JSON types like bool/string/number)

enum AnyCodableValue: Decodable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else if let v = try? container.decode(Int.self) { self = .int(v) }
        else if let v = try? container.decode(Double.self) { self = .double(v) }
        else if let v = try? container.decode(String.self) { self = .string(v) }
        else { self = .null }
    }

    var boolValue: Bool {
        switch self {
        case .bool(let v): return v
        case .string(let v): return v == "true"
        case .int(let v): return v != 0
        default: return false
        }
    }

    var stringValue: String? {
        switch self {
        case .string(let v): return v
        case .bool(let v): return String(v)
        case .int(let v): return String(v)
        case .double(let v): return String(v)
        case .null: return nil
        }
    }
}

