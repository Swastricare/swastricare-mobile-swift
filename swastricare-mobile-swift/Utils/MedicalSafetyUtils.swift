//
//  MedicalSafetyUtils.swift
//  swastricare-mobile-swift
//
//  Utilities for medical AI safety features
//

import Foundation
import UIKit

// MARK: - Medical Safety Utilities

struct MedicalSafetyUtils {
    
    // MARK: - Emergency Detection
    
    /// Keywords that indicate potential medical emergency
    static let emergencyKeywords: Set<String> = [
        // Cardiac emergencies
        "chest pain", "heart attack", "cardiac arrest", "heart stopped",
        
        // Respiratory emergencies
        "cant breathe", "cannot breathe", "can't breathe", "difficulty breathing",
        "choking", "suffocating", "stopped breathing",
        
        // Neurological emergencies
        "stroke", "seizure", "unconscious", "passed out", "fainting",
        "severe headache", "worst headache", "sudden confusion",
        
        // Trauma & Bleeding
        "severe bleeding", "heavy bleeding", "wont stop bleeding",
        "head injury", "serious injury", "accident",
        
        // Mental health emergencies
        "suicide", "suicidal", "want to die", "kill myself", "ending my life",
        "self harm", "hurting myself",
        
        // Overdose & Poisoning
        "overdose", "poisoning", "took too many pills", "drug overdose",
        
        // Other emergencies
        "emergency", "dying", "life threatening", "call 911",
        "ambulance", "severe allergic", "anaphylaxis"
    ]
    
    /// FAST stroke symptoms
    static let strokeSymptoms: Set<String> = [
        "face drooping", "arm weakness", "speech difficulty", "slurred speech",
        "one side weak", "facial droop", "cant lift arm", "numbness one side"
    ]
    
    /// Check if message contains emergency keywords
    static func isEmergency(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return emergencyKeywords.contains { lowercased.contains($0) } ||
               strokeSymptoms.contains { lowercased.contains($0) }
    }
    
    /// Get the type of emergency detected
    static func detectEmergencyType(_ text: String) -> EmergencyType? {
        let lowercased = text.lowercased()
        
        // Check cardiac
        if lowercased.contains("chest pain") || lowercased.contains("heart attack") ||
           lowercased.contains("cardiac") {
            return .cardiac
        }
        
        // Check respiratory
        if lowercased.contains("breathe") || lowercased.contains("choking") ||
           lowercased.contains("suffocating") {
            return .respiratory
        }
        
        // Check stroke
        if lowercased.contains("stroke") || strokeSymptoms.contains(where: { lowercased.contains($0) }) {
            return .stroke
        }
        
        // Check mental health
        if lowercased.contains("suicid") || lowercased.contains("kill myself") ||
           lowercased.contains("self harm") || lowercased.contains("want to die") {
            return .mentalHealth
        }
        
        // Check overdose
        if lowercased.contains("overdose") || lowercased.contains("poisoning") {
            return .overdose
        }
        
        // Check trauma
        if lowercased.contains("bleeding") || lowercased.contains("injury") ||
           lowercased.contains("accident") {
            return .trauma
        }
        
        // General emergency
        if isEmergency(text) {
            return .general
        }
        
        return nil
    }
    
    // MARK: - Content Filtering
    
    /// Keywords that should be filtered or flagged
    static let dangerousContentKeywords: Set<String> = [
        // Self-medication
        "how much to overdose", "lethal dose", "how to poison",
        
        // Dangerous combinations
        "mix drugs", "combine medications", "take together",
        
        // Unverified treatments
        "bleach cure", "miracle cure", "secret treatment"
    ]
    
    /// Check if content contains potentially dangerous advice requests
    static func containsDangerousRequest(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return dangerousContentKeywords.contains { lowercased.contains($0) }
    }
    
    // MARK: - Emergency Actions
    
    /// Call emergency services based on region
    static func callEmergencyServices(region: EmergencyRegion = .autoDetect) {
        let number: String
        
        switch region {
        case .us:
            number = "911"
        case .india:
            number = "108"
        case .eu:
            number = "112"
        case .uk:
            number = "999"
        case .autoDetect:
            // Default to regional based on locale
            let countryCode = Locale.current.region?.identifier ?? "US"
            switch countryCode {
            case "IN":
                number = "108"
            case "GB":
                number = "999"
            case "DE", "FR", "ES", "IT", "NL", "BE":
                number = "112"
            default:
                number = "911"
            }
        }
        
        if let url = URL(string: "tel://\(number)") {
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        }
    }
    
    /// Call mental health crisis line
    static func callMentalHealthCrisisLine(region: EmergencyRegion = .autoDetect) {
        let number: String
        
        switch region {
        case .us, .autoDetect:
            number = "988" // Suicide & Crisis Lifeline
        case .india:
            number = "9152987821" // iCall
        case .uk:
            number = "116123" // Samaritans
        case .eu:
            number = "112"
        }
        
        if let url = URL(string: "tel://\(number)") {
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        }
    }
    
    // MARK: - Disclaimer Helpers
    
    /// Standard medical disclaimer text
    static let standardDisclaimer = """
    ⚕️ This information is for educational purposes only and is not a substitute for professional medical advice, diagnosis, or treatment. Always consult a qualified healthcare provider with any questions about your health.
    """
    
    /// Emergency disclaimer text
    static let emergencyDisclaimer = """
    🚨 If you are experiencing a medical emergency, please call emergency services immediately (911 in US, 112 in EU, 108 in India). Do not rely on AI for emergency medical decisions.
    """
    
    /// Check if response needs medical disclaimer
    static func needsDisclaimer(for response: String) -> Bool {
        let medicalIndicators: Set<String> = [
            "symptom", "treatment", "medication", "diagnosis", "condition",
            "therapy", "dose", "prescription", "medical"
        ]
        
        let lowercased = response.lowercased()
        return medicalIndicators.contains { lowercased.contains($0) }
    }
}

// MARK: - Supporting Types

enum EmergencyType: String {
    case cardiac = "cardiac"
    case respiratory = "respiratory"
    case stroke = "stroke"
    case mentalHealth = "mental_health"
    case overdose = "overdose"
    case trauma = "trauma"
    case general = "general"
    
    var localizedDescription: String {
        switch self {
        case .cardiac:
            return "Possible cardiac emergency detected"
        case .respiratory:
            return "Possible breathing emergency detected"
        case .stroke:
            return "Possible stroke symptoms detected"
        case .mentalHealth:
            return "Mental health crisis detected"
        case .overdose:
            return "Possible overdose/poisoning detected"
        case .trauma:
            return "Possible serious injury detected"
        case .general:
            return "Emergency situation detected"
        }
    }
    
    var emergencyInstructions: String {
        switch self {
        case .cardiac:
            return "If experiencing chest pain, call emergency services immediately. Do not drive yourself to the hospital."
        case .respiratory:
            return "If someone is choking or not breathing, call emergency services. If trained, begin rescue breathing or CPR."
        case .stroke:
            return "Remember FAST: Face drooping, Arm weakness, Speech difficulty, Time to call emergency services."
        case .mentalHealth:
            return "You are not alone. Please reach out to a crisis helpline or emergency services immediately."
        case .overdose:
            return "Call emergency services immediately. Do not try to make the person vomit unless instructed by poison control."
        case .trauma:
            return "Apply pressure to stop bleeding. Keep the person still and call emergency services."
        case .general:
            return "Call emergency services immediately if you believe this is a life-threatening situation."
        }
    }
}

enum EmergencyRegion {
    case us
    case india
    case eu
    case uk
    case autoDetect
}

// MARK: - Emergency Contact Model

struct EmergencyContact {
    let name: String
    let number: String
    let flag: String
    
    static let defaultContacts: [EmergencyContact] = [
        EmergencyContact(name: "USA", number: "911", flag: "🇺🇸"),
        EmergencyContact(name: "India", number: "108", flag: "🇮🇳"),
        EmergencyContact(name: "Europe", number: "112", flag: "🇪🇺"),
        EmergencyContact(name: "UK", number: "999", flag: "🇬🇧"),
        EmergencyContact(name: "Australia", number: "000", flag: "🇦🇺"),
        EmergencyContact(name: "Canada", number: "911", flag: "🇨🇦")
    ]
    
    static let mentalHealthContacts: [EmergencyContact] = [
        EmergencyContact(name: "USA Suicide Prevention", number: "988", flag: "🇺🇸"),
        EmergencyContact(name: "India iCall", number: "9152987821", flag: "🇮🇳"),
        EmergencyContact(name: "UK Samaritans", number: "116123", flag: "🇬🇧"),
        EmergencyContact(name: "International", number: "112", flag: "🌍")
    ]
}
