//
//  FamilyViewModel.swift
//  swastricare-mobile-swift
//
//  Family Management ViewModel
//

import Foundation
import Combine

@MainActor
final class FamilyViewModel: ObservableObject {
    @Published var familyGroups: [FamilyGroup] = []
    @Published var sharedFamilyGroups: [FamilyGroup] = []
    @Published var selectedGroup: FamilyGroup?
    @Published var familyMembers: [FamilyMember] = []
    @Published var selectedMember: FamilyMember?

    @Published var isLoading = false
    @Published var isLoadingMembers = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // Invite
    @Published var currentInvite: FamilyInvite?
    @Published var pendingInvites: [FamilyInvite] = []
    @Published var inviteCode: String = ""
    @Published var inviteRole: FamilyMemberRole = .viewer
    @Published var lookupResult: FamilyInviteWithGroup?
    @Published var isLookingUpInvite = false
    
    // Create Group
    @Published var newGroupName: String = ""
    @Published var newGroupDescription: String = ""

    private let familyService: FamilyServiceProtocol

    init(familyService: FamilyServiceProtocol = FamilyService.shared) {
        self.familyService = familyService
    }

    var hasGroups: Bool { !familyGroups.isEmpty || !sharedFamilyGroups.isEmpty }
    var allGroups: [FamilyGroup] { familyGroups + sharedFamilyGroups }
    var isOwnerOfSelectedGroup: Bool {
        guard let g = selectedGroup else { return false }
        return familyGroups.contains(where: { $0.id == g.id })
    }
    
    var activeMembers: [FamilyMember] {
        familyMembers.filter { $0.status == .active }
    }
    
    var ownerMember: FamilyMember? {
        familyMembers.first { $0.role == .owner }
    }
    
    var nonOwnerMembers: [FamilyMember] {
        familyMembers.filter { $0.role != .owner && $0.status == .active }
    }

    func loadFamilyGroups() async {
        isLoading = true
        errorMessage = nil
        do {
            async let owned = familyService.fetchFamilyGroups()
            async let shared = familyService.fetchSharedFamilyGroups()
            familyGroups = try await owned
            sharedFamilyGroups = try await shared

            if selectedGroup == nil {
                selectedGroup = familyGroups.first ?? sharedFamilyGroups.first
            }
            if let group = selectedGroup {
                await loadFamilyMembers(groupId: group.id)
                await loadPendingInvites()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadFamilyMembers(groupId: UUID) async {
        isLoadingMembers = true
        do {
            familyMembers = try await familyService.fetchFamilyMembers(groupId: groupId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingMembers = false
    }

    func selectGroup(_ group: FamilyGroup) async {
        selectedGroup = group
        await loadFamilyMembers(groupId: group.id)
        await loadPendingInvites()
    }

    // MARK: - Invites

    func createInvite() async -> Bool {
        guard let group = selectedGroup else {
            errorMessage = "No family group selected"
            return false
        }
        isSaving = true
        errorMessage = nil
        do {
            let invite = try await familyService.createInvite(groupId: group.id, role: inviteRole, email: nil)
            currentInvite = invite
            pendingInvites.insert(invite, at: 0)
            successMessage = "Invite created! Share the code: \(invite.inviteCode)"
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }

    func loadPendingInvites() async {
        guard let group = selectedGroup else { return }
        do {
            pendingInvites = try await familyService.fetchInvitesForGroup(groupId: group.id)
        } catch {
            // Don't surface this as a blocking error; keep UI usable.
            print("❌ FamilyViewModel: loadPendingInvites failed - \(error)")
        }
    }

    func lookupInvite() async {
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count >= 6 else {
            errorMessage = "Please enter a valid invite code"
            return
        }

        isLookingUpInvite = true
        errorMessage = nil
        lookupResult = nil
        do {
            lookupResult = try await familyService.lookupInvite(code: code)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLookingUpInvite = false
    }

    func acceptInvite() async -> Bool {
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count >= 6 else {
            errorMessage = "Please enter a valid invite code"
            return false
        }

        isSaving = true
        errorMessage = nil
        do {
            let group = try await familyService.acceptInvite(code: code)
            // Refresh lists from server to keep counts correct.
            await loadFamilyGroups()
            // Try to select joined group if present.
            if let joined = (sharedFamilyGroups.first(where: { $0.id == group.id }) ?? familyGroups.first(where: { $0.id == group.id })) {
                selectedGroup = joined
                await loadFamilyMembers(groupId: joined.id)
            }

            inviteCode = ""
            lookupResult = nil
            successMessage = "Joined '\(group.name)'"
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }

    func revokeInvite(_ invite: FamilyInvite) async {
        isSaving = true
        do {
            try await familyService.revokeInvite(inviteId: invite.id)
            pendingInvites.removeAll { $0.id == invite.id }
            if currentInvite?.id == invite.id { currentInvite = nil }
            successMessage = "Invite revoked"
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    func clearError() { errorMessage = nil }
    func clearSuccess() { successMessage = nil }

    func resetInviteState() {
        currentInvite = nil
        inviteCode = ""
        inviteRole = .viewer
        lookupResult = nil
    }
    
    // MARK: - Create Group
    
    func createFamilyGroup() async -> Bool {
        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Please enter a family name"
            return false
        }
        
        isSaving = true
        errorMessage = nil
        do {
            let group = try await familyService.createFamilyGroup(
                name: name,
                description: newGroupDescription.isEmpty ? nil : newGroupDescription
            )
            familyGroups.insert(group, at: 0)
            selectedGroup = group
            newGroupName = ""
            newGroupDescription = ""
            successMessage = "Family group '\(group.name)' created!"
            await loadFamilyMembers(groupId: group.id)
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }
    
    // MARK: - Member Management
    
    func updateMemberRole(_ member: FamilyMember, to role: FamilyMemberRole) async {
        guard role != .owner else { return }
        isSaving = true
        do {
            try await familyService.updateMemberRole(memberId: member.id, role: role)
            if let index = familyMembers.firstIndex(where: { $0.id == member.id }) {
                familyMembers[index].role = role
            }
            successMessage = "Role updated to \(role.displayName)"
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
    
    func removeMember(_ member: FamilyMember) async {
        guard member.role != .owner else {
            errorMessage = "Cannot remove the owner"
            return
        }
        isSaving = true
        do {
            try await familyService.removeMember(memberId: member.id)
            familyMembers.removeAll { $0.id == member.id }
            if let group = selectedGroup {
                var updatedGroup = group
                updatedGroup.memberCount = max(0, group.memberCount - 1)
                selectedGroup = updatedGroup
                if let idx = familyGroups.firstIndex(where: { $0.id == group.id }) {
                    familyGroups[idx] = updatedGroup
                }
            }
            successMessage = "\(member.displayName) removed from family"
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
    
    func resetCreateGroupState() {
        newGroupName = ""
        newGroupDescription = ""
    }
}

