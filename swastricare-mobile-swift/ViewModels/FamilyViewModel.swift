//
//  FamilyViewModel.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - ViewModels Layer
//

import Foundation
import Combine

@MainActor
final class FamilyViewModel: ObservableObject {

    // MARK: - Published State

    @Published var familyGroup: FamilyGroup?
    @Published var members: [FamilyMember] = []
    @Published var currentMemberRole: FamilyRole?
    @Published var inviteCode: String = ""
    @Published var joinCode: String = ""
    @Published var isLoading: Bool = false
    @Published var isJoining: Bool = false
    @Published var error: String?
    @Published var successMessage: String?

    // MARK: - Computed Properties

    var isOwner: Bool {
        currentMemberRole == .owner
    }

    var hasFamily: Bool {
        familyGroup != nil
    }

    var memberCount: Int {
        members.count
    }

    var shareLink: String {
        guard let code = familyGroup?.inviteCode, !code.isEmpty else {
            return ""
        }
        return "swastricare://family/join?code=\(code)"
    }

    // MARK: - Private

    private let supabase = SupabaseManager.shared

    // MARK: - Load Family

    func loadFamily() async {
        isLoading = true
        error = nil

        do {
            // Fetch the user's family group
            let group = try await supabase.fetchMyFamilyGroup()
            self.familyGroup = group

            if let group = group {
                self.inviteCode = group.inviteCode ?? ""

                // Fetch members
                let fetchedMembers = try await supabase.fetchFamilyMembers(groupId: group.id)
                self.members = fetchedMembers

                // Determine current user's role
                let myMember = try await supabase.fetchMyFamilyMember(groupId: group.id)
                self.currentMemberRole = myMember?.role
            } else {
                self.members = []
                self.currentMemberRole = nil
                self.inviteCode = ""
            }
        } catch {
            self.error = error.localizedDescription
            print("FamilyViewModel: Error loading family - \(error)")
        }

        isLoading = false
    }

    // MARK: - Create Family

    func createFamily(name: String) async {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Please enter a family name."
            return
        }

        isLoading = true
        error = nil

        do {
            let group = try await supabase.createFamilyGroup(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
            self.familyGroup = group
            self.inviteCode = group.inviteCode ?? ""
            self.currentMemberRole = .owner
            self.successMessage = "Family group created!"

            // Reload members
            let fetchedMembers = try await supabase.fetchFamilyMembers(groupId: group.id)
            self.members = fetchedMembers
        } catch {
            self.error = error.localizedDescription
            print("FamilyViewModel: Error creating family - \(error)")
        }

        isLoading = false
    }

    // MARK: - Join Family

    func joinFamily() async {
        let code = joinCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else {
            error = "Please enter an invite code."
            return
        }

        isJoining = true
        error = nil

        do {
            _ = try await supabase.joinFamilyByCode(code)
            self.successMessage = "You have joined the family!"
            self.joinCode = ""

            // Reload everything
            await loadFamily()
        } catch {
            self.error = error.localizedDescription
            print("FamilyViewModel: Error joining family - \(error)")
        }

        isJoining = false
    }

    // MARK: - Join Family with Code (from deep link)

    func joinFamily(withCode code: String) async {
        joinCode = code
        await joinFamily()
    }

    // MARK: - Leave Family

    func leaveFamily() async {
        guard let group = familyGroup else { return }

        isLoading = true
        error = nil

        do {
            if let myMember = try await supabase.fetchMyFamilyMember(groupId: group.id) {
                try await supabase.leaveFamilyGroup(memberId: myMember.id)
            }

            self.familyGroup = nil
            self.members = []
            self.currentMemberRole = nil
            self.inviteCode = ""
            self.successMessage = "You have left the family group."
        } catch {
            self.error = error.localizedDescription
            print("FamilyViewModel: Error leaving family - \(error)")
        }

        isLoading = false
    }

    // MARK: - Remove Member (Owner only)

    func removeMember(_ member: FamilyMember) async {
        guard isOwner else {
            error = "Only the group owner can remove members."
            return
        }

        error = nil

        do {
            try await supabase.removeFamilyMember(memberId: member.id)
            self.members.removeAll { $0.id == member.id }
            self.successMessage = "Member removed."
        } catch {
            self.error = error.localizedDescription
            print("FamilyViewModel: Error removing member - \(error)")
        }
    }

    // MARK: - Regenerate Invite Code

    func regenerateCode() async {
        guard let group = familyGroup else { return }

        error = nil

        do {
            let newCode = try await supabase.regenerateInviteCode(groupId: group.id)
            self.inviteCode = newCode
            self.familyGroup?.inviteCode = newCode
            self.successMessage = "Invite code regenerated."
        } catch {
            self.error = error.localizedDescription
            print("FamilyViewModel: Error regenerating code - \(error)")
        }
    }

    // MARK: - Clear Messages

    func clearError() {
        error = nil
    }

    func clearSuccess() {
        successMessage = nil
    }
}
