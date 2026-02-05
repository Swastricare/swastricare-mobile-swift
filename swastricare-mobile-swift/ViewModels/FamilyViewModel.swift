//
//  FamilyViewModel.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - ViewModel Layer
//  State management for family sharing module
//

import Foundation
import Combine
import SwiftUI

// MARK: - Family ViewModel

@MainActor
final class FamilyViewModel: ObservableObject {

    // MARK: - Published State

    @Published var dataState: FamilyDataState = .idle
    @Published var groups: [FamilyGroupWithMembers] = []
    @Published var emergencyContacts: [EmergencyContact] = []
    @Published var memberHealthSummaries: [UUID: MemberHealthSummary] = [:]

    // Sheet state
    @Published var showCreateGroupSheet = false
    @Published var showAddMemberSheet = false
    @Published var showAddEmergencyContactSheet = false
    @Published var showEditPermissionsSheet = false
    @Published var showMemberDetailSheet = false

    // Form state
    @Published var newGroupName = ""
    @Published var newGroupDescription = ""
    @Published var selectedGroup: FamilyGroupWithMembers?
    @Published var selectedMember: FamilyMember?

    // Error / alert
    @Published var alertMessage: String?
    @Published var showAlert = false

    // MARK: - Dependencies

    private let familyService: FamilyServiceProtocol

    // MARK: - Init

    init(familyService: FamilyServiceProtocol = FamilyService.shared) {
        self.familyService = familyService
    }

    // MARK: - Computed

    var hasGroups: Bool { !groups.isEmpty }
    var hasEmergencyContacts: Bool { !emergencyContacts.isEmpty }
    var totalFamilyMembers: Int { groups.reduce(0) { $0 + $1.activeMembers.count } }

    // MARK: - Load All Data

    func loadData() async {
        dataState = .loading

        do {
            async let groupsResult = familyService.fetchMyGroups()
            async let contactsResult = familyService.fetchEmergencyContacts()

            let fetchedGroups = try await groupsResult
            let fetchedContacts = try await contactsResult

            // For each group, fetch members
            var groupsWithMembers: [FamilyGroupWithMembers] = []
            for group in fetchedGroups {
                let members = try await familyService.fetchMembers(groupId: group.id)
                groupsWithMembers.append(FamilyGroupWithMembers(group: group, members: members))
            }

            self.groups = groupsWithMembers
            self.emergencyContacts = fetchedContacts
            self.dataState = groups.isEmpty && emergencyContacts.isEmpty ? .empty : .loaded

            // Fetch health summaries for active members
            await loadMemberSummaries()

        } catch {
            print("👨‍👩‍👧‍👦 Failed to load family data: \(error.localizedDescription)")
            self.dataState = .error(error.localizedDescription)
        }
    }

    // MARK: - Member Summaries

    func loadMemberSummaries() async {
        let allMembers = groups.flatMap { $0.activeMembers }
        for member in allMembers {
            do {
                if let summary = try await familyService.fetchMemberHealthSummary(healthProfileId: member.healthProfileId) {
                    memberHealthSummaries[member.healthProfileId] = summary
                }
            } catch {
                print("👨‍👩‍👧‍👦 Failed to load summary for member \(member.id): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Group Actions

    func createGroup() async {
        let name = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            showError("Please enter a group name.")
            return
        }

        do {
            let description = newGroupDescription.trimmingCharacters(in: .whitespaces)
            let group = try await familyService.createGroup(
                name: name,
                description: description.isEmpty ? nil : description
            )
            let groupWithMembers = FamilyGroupWithMembers(group: group, members: [])
            groups.insert(groupWithMembers, at: 0)
            newGroupName = ""
            newGroupDescription = ""
            showCreateGroupSheet = false
            dataState = .loaded
            print("👨‍👩‍👧‍👦 Created family group: \(group.name)")
        } catch {
            showError("Failed to create group: \(error.localizedDescription)")
        }
    }

    func deleteGroup(_ group: FamilyGroup) async {
        do {
            try await familyService.deleteGroup(id: group.id)
            groups.removeAll { $0.id == group.id }
            if groups.isEmpty && emergencyContacts.isEmpty {
                dataState = .empty
            }
            print("👨‍👩‍👧‍👦 Deleted family group: \(group.name)")
        } catch {
            showError("Failed to delete group: \(error.localizedDescription)")
        }
    }

    func updateGroup(_ group: FamilyGroup) async {
        do {
            let updated = try await familyService.updateGroup(group)
            if let index = groups.firstIndex(where: { $0.id == updated.id }) {
                groups[index] = FamilyGroupWithMembers(group: updated, members: groups[index].members)
            }
        } catch {
            showError("Failed to update group: \(error.localizedDescription)")
        }
    }

    // MARK: - Member Actions

    func addMember(to groupId: UUID, healthProfileId: UUID, role: FamilyRole, relationship: String?) async {
        do {
            let member = try await familyService.addMember(
                groupId: groupId,
                healthProfileId: healthProfileId,
                role: role,
                relationship: relationship
            )

            if let index = groups.firstIndex(where: { $0.id == groupId }) {
                var updatedMembers = groups[index].members
                updatedMembers.append(member)
                groups[index] = FamilyGroupWithMembers(group: groups[index].group, members: updatedMembers)
            }
            showAddMemberSheet = false
            print("👨‍👩‍👧‍👦 Added member to group")
        } catch {
            showError("Failed to add member: \(error.localizedDescription)")
        }
    }

    func updateMemberRole(_ member: FamilyMember, newRole: FamilyRole) async {
        let permissions = MemberPermissions.defaults(for: newRole)
        do {
            try await familyService.updateMemberRole(memberId: member.id, role: newRole, permissions: permissions)

            // Update local state
            updateMemberInGroups(memberId: member.id) { m in
                m.role = newRole
                m.permissions = permissions
            }
            print("👨‍👩‍👧‍👦 Updated member role to \(newRole.displayName)")
        } catch {
            showError("Failed to update role: \(error.localizedDescription)")
        }
    }

    func removeMember(_ member: FamilyMember) async {
        guard member.role != .owner else {
            showError("Cannot remove the group owner.")
            return
        }

        do {
            try await familyService.removeMember(memberId: member.id)
            updateMemberInGroups(memberId: member.id) { m in
                m.status = .removed
            }
            // Remove from list
            for i in groups.indices {
                groups[i] = FamilyGroupWithMembers(
                    group: groups[i].group,
                    members: groups[i].members.filter { $0.id != member.id }
                )
            }
            print("👨‍👩‍👧‍👦 Removed member")
        } catch {
            showError("Failed to remove member: \(error.localizedDescription)")
        }
    }

    // MARK: - Emergency Contact Actions

    func addEmergencyContact(_ contact: EmergencyContact) async {
        do {
            let saved = try await familyService.addEmergencyContact(contact)
            emergencyContacts.append(saved)
            emergencyContacts.sort { $0.priority < $1.priority }
            showAddEmergencyContactSheet = false
            if dataState == .empty { dataState = .loaded }
            print("👨‍👩‍👧‍👦 Added emergency contact: \(saved.name)")
        } catch {
            showError("Failed to add emergency contact: \(error.localizedDescription)")
        }
    }

    func updateEmergencyContact(_ contact: EmergencyContact) async {
        do {
            let updated = try await familyService.updateEmergencyContact(contact)
            if let index = emergencyContacts.firstIndex(where: { $0.id == updated.id }) {
                emergencyContacts[index] = updated
            }
        } catch {
            showError("Failed to update contact: \(error.localizedDescription)")
        }
    }

    func deleteEmergencyContact(_ contact: EmergencyContact) async {
        do {
            try await familyService.deleteEmergencyContact(id: contact.id)
            emergencyContacts.removeAll { $0.id == contact.id }
            if groups.isEmpty && emergencyContacts.isEmpty {
                dataState = .empty
            }
        } catch {
            showError("Failed to delete contact: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func updateMemberInGroups(memberId: UUID, update: (inout FamilyMember) -> Void) {
        for groupIndex in groups.indices {
            if let memberIndex = groups[groupIndex].members.firstIndex(where: { $0.id == memberId }) {
                var updatedMembers = groups[groupIndex].members
                update(&updatedMembers[memberIndex])
                groups[groupIndex] = FamilyGroupWithMembers(
                    group: groups[groupIndex].group,
                    members: updatedMembers
                )
            }
        }
    }

    private func showError(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}
