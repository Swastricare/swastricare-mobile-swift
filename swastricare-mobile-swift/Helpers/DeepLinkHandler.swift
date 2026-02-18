//
//  DeepLinkHandler.swift
//  swastricare-mobile-swift
//
//  Handles deep links from widgets and pending workout detection
//

import Foundation
import SwiftUI
import Combine
import WidgetKit

enum DeepLink: Equatable {
    case home
    case hydration
    case medications
    case steps
    case run
    case startRun(type: String)
    case heartRate
    case activeWorkout
    case familyJoin(code: String)
    
    init?(url: URL) {
        // Supported schemes:
        // - swastricareapp://... (primary, also used for OAuth redirect)
        // - swasthicare://...    (legacy widget scheme)
        // - swastricare://...    (family invite links)
        guard let scheme = url.scheme else { return nil }
        guard scheme == "swastricareapp" || scheme == "swasthicare" || scheme == "swastricare" else { return nil }
        
        let host = url.host ?? ""
        let path = url.path
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        
        switch host {
        case "auth-callback":
            // OAuth redirect (Supabase). Not a UI deep link.
            return nil
        case "home":
            self = .home
        case "hydration":
            self = .hydration
        case "medications":
            self = .medications
        case "steps":
            self = .steps
        case "run":
            // Check if this is a start action
            if path == "/start" {
                let activityType = queryItems?.first(where: { $0.name == "type" })?.value ?? "run"
                self = .startRun(type: activityType)
            } else {
                self = .run
            }
        case "heartrate":
            self = .heartRate
        case "workout":
            // e.g. swastricareapp://workout/live
            self = .activeWorkout
        case "family":
            // e.g. swastricare://family/join?code=ABC12345
            if path == "/join" || path.hasPrefix("/join") {
                if let code = queryItems?.first(where: { $0.name == "code" })?.value, !code.isEmpty {
                    self = .familyJoin(code: code)
                } else {
                    return nil
                }
            } else {
                return nil
            }
        default:
            return nil
        }
    }
}

// MARK: - Deep Link Notifications (for view-level UI actions)

extension Notification.Name {
    static let deepLinkOpenHydration = Notification.Name("DeepLink.OpenHydration")
    static let deepLinkOpenMedications = Notification.Name("DeepLink.OpenMedications")
    static let deepLinkOpenHeartRate = Notification.Name("DeepLink.OpenHeartRate")
    static let deepLinkOpenLiveTracking = Notification.Name("DeepLink.OpenLiveTracking")
    static let deepLinkFamilyJoin = Notification.Name("DeepLink.FamilyJoin")
}

enum DeepLinkUserInfoKey {
    static let workoutType = "workoutType" // String: "run" | "walk" | "commute" | etc.
    static let familyInviteCode = "familyInviteCode" // String: invite code
}

// MARK: - Pending Workout from Widget

struct PendingWidgetWorkout {
    let type: String
    let workoutId: UUID
    let startTime: Date
}

// MARK: - Deep Link Handler for SwiftUI

@MainActor
class DeepLinkHandler: ObservableObject {
    @Published var currentDeepLink: DeepLink?
    @Published var pendingWorkout: PendingWidgetWorkout?
    @Published var pendingFamilyInviteCode: String?
    
    private let appGroupSuiteName = "group.com.swasthicare.shared"
    
    func handle(_ url: URL) {
        print("🔗 Handling deep link: \(url.absoluteString)")
        
        guard let deepLink = DeepLink(url: url) else {
            print("⚠️ Invalid deep link URL")
            return
        }
        
        // Handle family invite deep link specially
        if case .familyJoin(let code) = deepLink {
            print("👨‍👩‍👧‍👦 Family invite deep link with code: \(code)")
            pendingFamilyInviteCode = code
            NotificationCenter.default.post(
                name: .deepLinkFamilyJoin,
                object: nil,
                userInfo: [DeepLinkUserInfoKey.familyInviteCode: code]
            )
        }
        
        currentDeepLink = deepLink
    }
    
    func clearFamilyInviteCode() {
        pendingFamilyInviteCode = nil
    }
    
    /// Check for workouts started from widget (call on app launch/foreground)
    func checkForPendingWidgetWorkout() {
        guard let defaults = UserDefaults(suiteName: appGroupSuiteName) else { return }
        
        // Check for pending start workout
        guard let data = defaults.data(forKey: "widget_pending_start_workout") else { return }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        struct PendingStart: Codable {
            let type: String
            let workoutId: UUID
            let startTime: Date
        }
        
        if let pending = try? decoder.decode(PendingStart.self, from: data) {
            print("🏃 Found pending widget workout: \(pending.type) started at \(pending.startTime)")
            
            // Clear it so we don't process it again
            defaults.removeObject(forKey: "widget_pending_start_workout")
            defaults.synchronize()
            
            // Set pending workout for main app to handle
            pendingWorkout = PendingWidgetWorkout(
                type: pending.type,
                workoutId: pending.workoutId,
                startTime: pending.startTime
            )
        }
    }
    
    /// Check for active workout state (workout running in background)
    func checkForActiveWorkout() -> (isActive: Bool, type: String, startTime: Date)? {
        guard let defaults = UserDefaults(suiteName: appGroupSuiteName) else { return nil }
        guard let data = defaults.data(forKey: "widget_active_workout") else { return nil }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        struct WorkoutState: Codable {
            let id: UUID
            let activityType: String
            let startTime: Date
            let isActive: Bool
        }
        
        if let state = try? decoder.decode(WorkoutState.self, from: data), state.isActive {
            return (isActive: true, type: state.activityType, startTime: state.startTime)
        }
        
        return nil
    }
    
    /// Clear active workout state (call when workout ends in main app)
    func clearActiveWorkout() {
        guard let defaults = UserDefaults(suiteName: appGroupSuiteName) else { return }
        defaults.removeObject(forKey: "widget_active_workout")
        defaults.synchronize()
        
        // Refresh widget to show normal state
        WidgetCenter.shared.reloadTimelines(ofKind: "RunWidget")
    }
}
