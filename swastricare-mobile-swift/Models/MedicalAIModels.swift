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
        case .general: return "2E3192"  // App primary blue
        case .medical: return "00A86B"  // Medical green
        }
    }
}

// MARK: - Medical AI Model Types

/// Available medical AI models
enum MedicalAIModel: String, Codable {
    case medgemma27B = "medgemma-27b"    // Text-only medical conversations
    case medgemma4B = "medgemma-4b"       // Multimodal (image + text)
    case geminiMedical = "gemini-medical" // Fallback with medical prompts
    case geminiFlash = "gemini-3-flash"   // General chat (non-medical)
    
    var displayName: String {
        switch self {
        case .medgemma27B: return "MedGemma Medical AI"
        case .medgemma4B: return "MedGemma Vision"
        case .geminiMedical: return "Medical Assistant"
        case .geminiFlash: return "Swastri AI"
        }
    }
    
    var isMedical: Bool {
        switch self {
        case .medgemma27B, .medgemma4B, .geminiMedical:
            return true
        case .geminiFlash:
            return false
        }
    }
    
    var supportsImages: Bool {
        self == .medgemma4B
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
