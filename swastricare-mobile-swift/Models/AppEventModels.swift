//
//  AppEventModels.swift
//  swastricare-mobile-swift
//
//  Models for app analytics events stored in Supabase app_events table.
//

import Foundation

/// Event type category for analytics.
enum AppEventType: String, Codable, CaseIterable {
    case navigation
    case action
    case error
    case count
    case featureUsage = "feature_usage"
    case auth
    case screen
}

/// Single app event for analytics. Encodes to DB columns (snake_case).
struct AppEvent: Codable {
    var id: UUID?
    var createdAt: Date?
    var userId: UUID?
    var eventName: String
    var eventType: String
    var properties: [String: String]
    var deviceInfo: [String: String]
    var sessionId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case userId = "user_id"
        case eventName = "event_name"
        case eventType = "event_type"
        case properties
        case deviceInfo = "device_info"
        case sessionId = "session_id"
    }

    init(
        id: UUID? = nil,
        createdAt: Date? = nil,
        userId: UUID? = nil,
        eventName: String,
        eventType: String,
        properties: [String: String] = [:],
        deviceInfo: [String: String] = [:],
        sessionId: UUID? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.userId = userId
        self.eventName = eventName
        self.eventType = eventType
        self.properties = properties
        self.deviceInfo = deviceInfo
        self.sessionId = sessionId
    }

    /// Build properties from [String: Any] by stringifying values (for counts, etc.).
    static func propertiesFrom(_ dict: [String: Any]) -> [String: String] {
        dict.mapValues { value in
            if let s = value as? String { return s }
            if let n = value as? Int { return String(n) }
            if let n = value as? Double { return String(n) }
            if let b = value as? Bool { return b ? "true" : "false" }
            return String(describing: value)
        }
    }
}
