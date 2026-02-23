//
//  ActiveProfileManager.swift
//  swastricare-mobile-swift
//
//  Manages the currently active health profile for viewing family member data
//

import Foundation
import Combine
import Supabase

// MARK: - Active Profile

struct ActiveProfile: Equatable {
    let healthProfileId: UUID
    let name: String
    let relationship: String?
    let isOwnProfile: Bool
    
    static func own(id: UUID, name: String) -> ActiveProfile {
        ActiveProfile(healthProfileId: id, name: name, relationship: nil, isOwnProfile: true)
    }
    
    static func familyMember(id: UUID, name: String, relationship: String?) -> ActiveProfile {
        ActiveProfile(healthProfileId: id, name: name, relationship: relationship, isOwnProfile: false)
    }
}

// MARK: - Active Profile Manager

@MainActor
final class ActiveProfileManager: ObservableObject {
    
    static let shared = ActiveProfileManager()
    
    @Published private(set) var activeProfile: ActiveProfile?
    @Published private(set) var ownProfile: ActiveProfile?
    @Published private(set) var isViewingFamilyMember: Bool = false
    
    private let supabaseManager = SupabaseManager.shared
    
    private init() {}
    
    // MARK: - Public Methods
    
    var activeHealthProfileId: UUID? {
        activeProfile?.healthProfileId
    }
    
    var activeProfileName: String {
        activeProfile?.name ?? "You"
    }
    
    func loadOwnProfile() async {
        guard let userId = try? await supabaseManager.client.auth.session.user.id else {
            return
        }
        
        do {
            struct ProfileRow: Decodable {
                let id: UUID
                let full_name: String?
            }
            
            let profiles: [ProfileRow] = try await supabaseManager.client
                .from("health_profiles")
                .select("id, full_name")
                .eq("user_id", value: userId.uuidString)
                .eq("is_primary", value: true)
                .limit(1)
                .execute()
                .value
            
            if let profile = profiles.first {
                let own = ActiveProfile.own(id: profile.id, name: profile.full_name ?? "You")
                self.ownProfile = own
                
                if activeProfile == nil {
                    self.activeProfile = own
                    self.isViewingFamilyMember = false
                }
            }
        } catch {
            print("⚠️ ActiveProfileManager: Failed to load own profile - \(error)")
        }
    }
    
    func switchToOwnProfile() {
        guard let own = ownProfile else { return }
        activeProfile = own
        isViewingFamilyMember = false
        notifyProfileChanged()
    }
    
    func switchToFamilyMember(healthProfileId: UUID, name: String, relationship: String?) {
        let member = ActiveProfile.familyMember(id: healthProfileId, name: name, relationship: relationship)
        activeProfile = member
        isViewingFamilyMember = true
        notifyProfileChanged()
    }
    
    func reset() {
        activeProfile = ownProfile
        isViewingFamilyMember = false
        notifyProfileChanged()
    }
    
    // MARK: - Notification
    
    private func notifyProfileChanged() {
        NotificationCenter.default.post(name: .activeProfileChanged, object: nil)
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let activeProfileChanged = Notification.Name("activeProfileChanged")
}
