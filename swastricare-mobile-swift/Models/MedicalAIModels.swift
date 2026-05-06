//
//  MedicalAIModels.swift
//  swastricare-mobile-swift
//
//  Models for Medical AI (MedGemma) integration
//

import Foundation

// MARK: - AI Mode Selection

/// User-selectable AI mode for chat
enum AIMode: String, CaseIterable, Identifiable {
    case general = "general"
    case medical = "medical"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .general: return "Swastri Assistant"
        case .medical: return "Medical Expert"
        }
    }
    
    var description: String {
        switch self {
        case .general: return "General health & wellness companion"
        case .medical: return "Specialized medical information"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "sparkles"
        case .medical: return "stethoscope"
        }
    }
    
    var accentColor: String {
        switch self {
        case .general: return "22C5A6"  // App primary blue
        case .medical: return "00A86B"  // Medical green
        }
    }
}

// MARK: - AI Personality Roster

/// Selectable AI personality within General mode
enum AIPersonality: String, CaseIterable, Identifiable {
    case assistant = "assistant"
    case coach = "coach"
    case nutritionist = "nutritionist"
    case therapist = "therapist"
    case sleep = "sleep"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .assistant: return "Swastri"
        case .coach: return "Coach"
        case .nutritionist: return "Nutri"
        case .therapist: return "Zen"
        case .sleep: return "Luna"
        }
    }

    var fullTitle: String {
        switch self {
        case .assistant: return "Swastri Assistant"
        case .coach: return "Fitness Coach"
        case .nutritionist: return "Nutritionist"
        case .therapist: return "Wellness Therapist"
        case .sleep: return "Sleep Specialist"
        }
    }

    var icon: String {
        switch self {
        case .assistant: return "sparkles"
        case .coach: return "figure.run"
        case .nutritionist: return "leaf.fill"
        case .therapist: return "brain.head.profile"
        case .sleep: return "moon.stars.fill"
        }
    }

    var color: String {
        switch self {
        case .assistant: return "22C5A6"
        case .coach: return "EF4444"
        case .nutritionist: return "22C55E"
        case .therapist: return "8B5CF6"
        case .sleep: return "6366F1"
        }
    }

    var tagline: String {
        switch self {
        case .assistant: return "Your all-round health companion"
        case .coach: return "Push harder, recover smarter"
        case .nutritionist: return "Eat well, feel great"
        case .therapist: return "Breathe, reflect, grow"
        case .sleep: return "Better nights, brighter days"
        }
    }

    /// System prompt personality layer injected before the health context
    var systemPrompt: String {
        switch self {
        case .assistant:
            return "You are Swastri, a friendly and knowledgeable health companion by Swastricare. Be warm, concise, and helpful."
        case .coach:
            return "You are Coach, a high-energy fitness coach by Swastricare. Be motivational, direct, and action-oriented. Use encouraging language. Focus on exercise, movement, recovery, and physical performance. Push the user to do better while respecting their limits."
        case .nutritionist:
            return "You are Nutri, a calm and evidence-based nutritionist by Swastricare. Focus on balanced eating, meal planning, macros, hydration, and dietary habits. Give practical food suggestions. Avoid prescribing specific diets without context."
        case .therapist:
            return "You are Zen, a gentle wellness therapist by Swastricare. Focus on mental health, stress management, mindfulness, breathing exercises, and emotional wellbeing. Be empathetic, non-judgmental, and soothing. Never diagnose conditions."
        case .sleep:
            return "You are Luna, a sleep specialist by Swastricare. Focus on sleep hygiene, bedtime routines, circadian rhythm, insomnia tips, and rest quality. Be calming and reassuring. Use sleep science to give practical advice."
        }
    }
}

// MARK: - Medical AI Model Types

/// Available AI models
enum MedicalAIModel: String, Codable {
    case minimax = "minimax"                     // General chat (MiniMax M2.5)
    case minimaxMedical = "minimax-medical"       // Medical chat (MiniMax with medical prompt)
    case medgemmaVision = "medgemma-vision"       // Multimodal vision (Gemini, for images only)

    var displayName: String {
        switch self {
        case .minimax: return "Swastri AI"
        case .minimaxMedical: return "Medical Assistant"
        case .medgemmaVision: return "MedGemma Vision"
        }
    }

    var isMedical: Bool {
        switch self {
        case .minimaxMedical, .medgemmaVision:
            return true
        case .minimax:
            return false
        }
    }

    var supportsImages: Bool {
        self == .medgemmaVision
    }
}

// MARK: - Medical Query Classification

/// Classification of medical queries
enum MedicalQueryType: String, Codable {
    case symptomAnalysis = "symptom_analysis"
    case medicationQuery = "medication_query"
    case conditionExplanation = "condition_explanation"
    case treatmentInformation = "treatment_information"
    case labResultInterpretation = "lab_result_interpretation"
    case prescriptionAnalysis = "prescription_analysis"
    case generalHealth = "general_health"
    case emergency = "emergency"
    case nonMedical = "non_medical"
}

// MARK: - Medical Response Metadata

/// Metadata about a medical AI response
struct MedicalResponseMetadata: Codable {
    let modelUsed: String
    let isMedical: Bool
    let isEmergency: Bool
    let queryType: MedicalQueryType?
    let confidenceScore: Double?
    let processingTimeMs: Int?
    let hasDisclaimer: Bool
    let recommendsProfessionalConsultation: Bool
    
    init(
        modelUsed: String,
        isMedical: Bool = false,
        isEmergency: Bool = false,
        queryType: MedicalQueryType? = nil,
        confidenceScore: Double? = nil,
        processingTimeMs: Int? = nil,
        hasDisclaimer: Bool = true,
        recommendsProfessionalConsultation: Bool = false
    ) {
        self.modelUsed = modelUsed
        self.isMedical = isMedical
        self.isEmergency = isEmergency
        self.queryType = queryType
        self.confidenceScore = confidenceScore
        self.processingTimeMs = processingTimeMs
        self.hasDisclaimer = hasDisclaimer
        self.recommendsProfessionalConsultation = recommendsProfessionalConsultation
    }
}

// MARK: - Medical Image Analysis Result

/// Result of medical image analysis
struct MedicalImageAnalysisResult {
    let analysisType: String
    let summary: String
    let findings: [String]?
    let recommendations: [String]?
    let extractedData: ExtractedMedicalData?
    let requiresFollowUp: Bool
    let urgencyLevel: UrgencyLevel
    let model: String
    let timestamp: Date
    
    enum UrgencyLevel: String, Codable {
        case none = "none"
        case low = "low"
        case medium = "medium"
        case high = "high"
        case emergency = "emergency"
    }
}

/// Extracted data from medical documents
struct ExtractedMedicalData: Codable {
    // Prescription data
    let medications: [ExtractedMedication]?
    
    // Lab report data
    let labResults: [ExtractedLabResult]?
    
    // Document metadata
    let documentDate: String?
    let providerName: String?
    let patientName: String?
}

/// Extracted medication from prescription
struct ExtractedMedication: Codable {
    let name: String
    let dosage: String?
    let frequency: String?
    let duration: String?
    let instructions: String?
}

/// Extracted lab result
struct ExtractedLabResult: Codable {
    let testName: String
    let value: String
    let unit: String?
    let referenceRange: String?
    let isAbnormal: Bool?
    let interpretation: String?
}

// MARK: - Medical Consent

/// User consent for medical AI features
struct MedicalAIConsent: Codable {
    let userId: UUID
    let consentType: ConsentType
    let acknowledgedAt: Date
    let version: String
    
    enum ConsentType: String, Codable {
        case initialDisclaimer = "initial_disclaimer"
        case imageAnalysis = "image_analysis"
        case dataProcessing = "data_processing"
    }
}

// MARK: - Chat Message Extension

extension ChatMessage {
    /// Check if this message contains medical content
    var containsMedicalContent: Bool {
        let medicalKeywords = ["symptom", "pain", "medication", "medicine", "diagnosis",
                               "treatment", "doctor", "hospital", "condition", "disease"]
        let lowercased = content.lowercased()
        return medicalKeywords.contains { lowercased.contains($0) }
    }
    
    /// Check if this is an emergency message
    var isEmergencyMessage: Bool {
        MedicalSafetyUtils.isEmergency(content)
    }
}

// MARK: - Medical Keywords Helper

struct MedicalKeywords {
    
    /// Common symptom keywords
    static let symptoms: Set<String> = [
        "pain", "ache", "hurt", "sore", "fever", "nausea", "dizzy", "fatigue",
        "headache", "migraine", "cough", "cold", "flu", "infection", "swelling",
        "rash", "bleeding", "vomiting", "diarrhea", "constipation", "cramp",
        "numbness", "tingling", "weakness", "shortness of breath"
    ]
    
    /// Medication-related keywords
    static let medications: Set<String> = [
        "medication", "medicine", "drug", "prescription", "pill", "tablet",
        "capsule", "dose", "dosage", "side effect", "interaction", "generic",
        "brand", "pharmacy", "refill"
    ]
    
    /// Condition keywords
    static let conditions: Set<String> = [
        "diabetes", "hypertension", "high blood pressure", "asthma", "allergy",
        "arthritis", "cancer", "heart disease", "depression", "anxiety",
        "thyroid", "cholesterol", "obesity", "anemia"
    ]
    
    /// Body parts in medical context
    static let bodyParts: Set<String> = [
        "chest", "abdomen", "stomach", "liver", "kidney", "lung", "heart",
        "brain", "spine", "back", "joint", "muscle", "bone"
    ]
    
    /// Check if text contains medical keywords
    static func containsMedicalContent(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        return symptoms.contains { lowercased.contains($0) } ||
               medications.contains { lowercased.contains($0) } ||
               conditions.contains { lowercased.contains($0) } ||
               bodyParts.contains { lowercased.contains($0) }
    }
    
    /// Classify the type of medical query
    static func classifyQuery(_ text: String) -> MedicalQueryType {
        let lowercased = text.lowercased()
        
        // Check emergency first
        if MedicalSafetyUtils.isEmergency(text) {
            return .emergency
        }
        
        // Check for symptom-related queries
        if symptoms.contains(where: { lowercased.contains($0) }) {
            return .symptomAnalysis
        }
        
        // Check for medication queries
        if medications.contains(where: { lowercased.contains($0) }) {
            return .medicationQuery
        }
        
        // Check for condition explanations
        if conditions.contains(where: { lowercased.contains($0) }) {
            return .conditionExplanation
        }
        
        // Check for lab-related queries
        if lowercased.contains("lab") || lowercased.contains("test result") ||
           lowercased.contains("blood test") {
            return .labResultInterpretation
        }
        
        // General health if any medical content
        if containsMedicalContent(text) {
            return .generalHealth
        }
        
        return .nonMedical
    }
}
