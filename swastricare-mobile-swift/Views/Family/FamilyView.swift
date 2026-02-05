//
//  FamilyView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//  Family sharing hub with premium UI
//

import SwiftUI

// MARK: - Main Family View

struct FamilyView: View {

    // MARK: - ViewModel

    @ObservedObject private var viewModel = DependencyContainer.shared.familyViewModel

    // MARK: - Local State

    @State private var selectedSection: FamilySection = .members
    @State private var showDeleteGroupConfirmation = false
    @State private var groupToDelete: FamilyGroup?
    @State private var memberToRemove: FamilyMember?
    @State private var showRemoveMemberConfirmation = false
    @State private var contactToDelete: EmergencyContact?
    @State private var showDeleteContactConfirmation = false
    @State private var hasAppeared = false

    enum FamilySection: String, CaseIterable {
        case members = "Members"
        case emergency = "Emergency"

        var icon: String {
            switch self {
            case .members: return "person.2.fill"
            case .emergency: return "phone.fill"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            PremiumBackground()

            VStack(spacing: 0) {
                // Header
                familyHeader

                // Content
                switch viewModel.dataState {
                case .loading where !hasAppeared:
                    loadingView
                case .error(let message):
                    errorView(message: message)
                default:
                    mainContent
                }
            }

            // Floating action button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    floatingActionButton
                }
            }
        }
        .task {
            await viewModel.loadData()
            hasAppeared = true
        }
        .refreshable {
            await viewModel.loadData()
        }
        .sheet(isPresented: $viewModel.showCreateGroupSheet) {
            CreateGroupSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showAddMemberSheet) {
            AddMemberSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showAddEmergencyContactSheet) {
            AddEmergencyContactSheet(viewModel: viewModel)
        }
        .sheet(item: $viewModel.selectedMember) { member in
            MemberDetailSheet(member: member, viewModel: viewModel)
        }
        .alert("Error", isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage ?? "Something went wrong.")
        }
        .confirmationDialog("Delete Group?", isPresented: $showDeleteGroupConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let group = groupToDelete {
                    Task { await viewModel.deleteGroup(group) }
                }
            }
        } message: {
            Text("This will remove all members from the group. This cannot be undone.")
        }
        .confirmationDialog("Remove Member?", isPresented: $showRemoveMemberConfirmation, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let member = memberToRemove {
                    Task { await viewModel.removeMember(member) }
                }
            }
        } message: {
            Text("This member will lose access to shared health data.")
        }
        .confirmationDialog("Delete Contact?", isPresented: $showDeleteContactConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let contact = contactToDelete {
                    Task { await viewModel.deleteEmergencyContact(contact) }
                }
            }
        }
    }

    // MARK: - Header

    private var familyHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("CARE CIRCLE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(1.5)
                    .foregroundStyle(PremiumColor.deepPurple)

                Text("Family")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Spacer()

            // Member count badge
            if viewModel.totalFamilyMembers > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                    Text("\(viewModel.totalFamilyMembers)")
                        .font(.subheadline.bold())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glass(cornerRadius: 20)
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Section Picker
                sectionPicker
                    .padding(.top, 8)

                switch selectedSection {
                case .members:
                    membersSection
                case .emergency:
                    emergencySection
                }
            }
            .padding(.bottom, 100)
        }
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(FamilySection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedSection = section
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: section.icon)
                            .font(.caption)
                        Text(section.rawValue)
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedSection == section
                            ? AnyShapeStyle(.ultraThinMaterial)
                            : AnyShapeStyle(.clear)
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                selectedSection == section
                                    ? Color.primary.opacity(0.15)
                                    : Color.clear,
                                lineWidth: 0.5
                            )
                    )
                }
                .foregroundStyle(selectedSection == section ? .primary : .secondary)
            }
        }
        .padding(4)
        .glass(cornerRadius: 25)
        .padding(.horizontal)
    }

    // MARK: - Members Section

    private var membersSection: some View {
        VStack(spacing: 16) {
            if viewModel.groups.isEmpty {
                emptyGroupsView
            } else {
                ForEach(viewModel.groups) { groupWithMembers in
                    FamilyGroupCard(
                        groupWithMembers: groupWithMembers,
                        summaries: viewModel.memberHealthSummaries,
                        onMemberTap: { member in
                            viewModel.selectedMember = member
                        },
                        onRemoveMember: { member in
                            memberToRemove = member
                            showRemoveMemberConfirmation = true
                        },
                        onDeleteGroup: { group in
                            groupToDelete = group
                            showDeleteGroupConfirmation = true
                        },
                        onAddMember: {
                            viewModel.selectedGroup = groupWithMembers
                            viewModel.showAddMemberSheet = true
                        }
                    )
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Emergency Section

    private var emergencySection: some View {
        VStack(spacing: 16) {
            if viewModel.emergencyContacts.isEmpty {
                emptyEmergencyView
            } else {
                ForEach(viewModel.emergencyContacts) { contact in
                    EmergencyContactCard(
                        contact: contact,
                        onDelete: {
                            contactToDelete = contact
                            showDeleteContactConfirmation = true
                        }
                    )
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Empty States

    private var emptyGroupsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .symbolEffect(.pulse, options: .repeating)

            Text("No Family Groups Yet")
                .font(.title3.bold())

            Text("Create a group to share health data with your loved ones and keep everyone connected.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button {
                viewModel.showCreateGroupSheet = true
            } label: {
                Label("Create Family Group", systemImage: "plus.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .glass(cornerRadius: 24)
    }

    private var emptyEmergencyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cross.case.circle")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .symbolEffect(.pulse, options: .repeating)

            Text("No Emergency Contacts")
                .font(.title3.bold())

            Text("Add emergency contacts so they can be reached quickly in case of a health crisis.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button {
                viewModel.showAddEmergencyContactSheet = true
            } label: {
                Label("Add Emergency Contact", systemImage: "plus.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .glass(cornerRadius: 24)
    }

    // MARK: - Loading / Error

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading family data...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Retry") {
                Task { await viewModel.loadData() }
            }
            .buttonStyle(.bordered)
            Spacer()
        }
    }

    // MARK: - FAB

    private var floatingActionButton: some View {
        Menu {
            Button {
                viewModel.showCreateGroupSheet = true
            } label: {
                Label("New Family Group", systemImage: "person.2.badge.plus")
            }

            Button {
                viewModel.showAddEmergencyContactSheet = true
            } label: {
                Label("Add Emergency Contact", systemImage: "cross.case")
            }
        } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(Circle())
                .shadow(color: .blue.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }
}

// MARK: - Family Group Card

struct FamilyGroupCard: View {
    let groupWithMembers: FamilyGroupWithMembers
    let summaries: [UUID: MemberHealthSummary]
    let onMemberTap: (FamilyMember) -> Void
    let onRemoveMember: (FamilyMember) -> Void
    let onDeleteGroup: (FamilyGroup) -> Void
    let onAddMember: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Group header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(groupWithMembers.name)
                        .font(.headline.bold())
                    Text("\(groupWithMembers.memberCount) member\(groupWithMembers.memberCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button {
                        onAddMember()
                    } label: {
                        Label("Add Member", systemImage: "person.badge.plus")
                    }

                    Divider()

                    Button(role: .destructive) {
                        onDeleteGroup(groupWithMembers.group)
                    } label: {
                        Label("Delete Group", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            // Pending invites banner
            if !groupWithMembers.pendingMembers.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundStyle(.orange)
                    Text("\(groupWithMembers.pendingMembers.count) pending invite\(groupWithMembers.pendingMembers.count == 1 ? "" : "s")")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                    Spacer()
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Member list
            if groupWithMembers.activeMembers.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Add your first family member")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(groupWithMembers.activeMembers) { member in
                        FamilyMemberRow(
                            member: member,
                            summary: summaries[member.healthProfileId],
                            onTap: { onMemberTap(member) },
                            onRemove: { onRemoveMember(member) }
                        )
                    }
                }
            }
        }
        .padding(16)
        .glass(cornerRadius: 20)
    }
}

// MARK: - Family Member Row

struct FamilyMemberRow: View {
    let member: FamilyMember
    let summary: MemberHealthSummary?
    let onTap: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(member.role.color.opacity(0.15))
                        .frame(width: 48, height: 48)

                    if let avatarURL = member.profileAvatarURL, let url = URL(string: avatarURL) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: member.role.icon)
                                .foregroundStyle(member.role.color)
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: member.role.icon)
                            .font(.title3)
                            .foregroundStyle(member.role.color)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(member.displayName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        // Role badge
                        Text(member.role.displayName)
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(member.role.color.opacity(0.15))
                            .foregroundStyle(member.role.color)
                            .clipShape(Capsule())

                        // Relationship
                        if let rel = member.relationshipType {
                            Text(rel.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Quick health glance
                if let summary = summary {
                    VStack(alignment: .trailing, spacing: 3) {
                        if let hr = summary.heartRate {
                            HStack(spacing: 3) {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                                Text("\(hr)")
                                    .font(.caption.monospacedDigit())
                            }
                        }

                        if let steps = summary.stepsToday {
                            HStack(spacing: 3) {
                                Image(systemName: "figure.walk")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                                Text("\(steps)")
                                    .font(.caption.monospacedDigit())
                            }
                        }
                    }
                    .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(ScaleButtonStyle())
        .contextMenu {
            if member.role != .owner {
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Label("Remove Member", systemImage: "person.badge.minus")
                }
            }
        }
    }
}

// MARK: - Emergency Contact Card

struct EmergencyContactCard: View {
    let contact: EmergencyContact
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                // Priority indicator
                ZStack {
                    Circle()
                        .fill(contact.priority == 1
                              ? LinearGradient(colors: [.red, .orange], startPoint: .top, endPoint: .bottom)
                              : LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom))
                        .frame(width: 44, height: 44)

                    Text("\(contact.priority)")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(contact.name)
                        .font(.headline.bold())
                    HStack(spacing: 6) {
                        Text(contact.priorityLabel)
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(contact.priority == 1 ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                            .foregroundStyle(contact.priority == 1 ? .red : .blue)
                            .clipShape(Capsule())
                        if let relType = contact.relationshipType {
                            Text(relType.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(contact.relationship)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Call button
                if let phoneURL = URL(string: "tel:\(contact.phonePrimary)") {
                    Link(destination: phoneURL) {
                        Image(systemName: "phone.circle.fill")
                            .font(.title)
                            .foregroundStyle(.green)
                    }
                }
            }

            // Info row
            HStack(spacing: 16) {
                Label(contact.phonePrimary, systemImage: "phone.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let email = contact.email, !email.isEmpty {
                    Label(email, systemImage: "envelope.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Permissions badges
            if contact.canMakeMedicalDecisions || contact.hasMedicalPowerOfAttorney {
                HStack(spacing: 8) {
                    if contact.canMakeMedicalDecisions {
                        Label("Medical Decisions", systemImage: "checkmark.shield.fill")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                    if contact.hasMedicalPowerOfAttorney {
                        Label("Power of Attorney", systemImage: "doc.badge.gearshape.fill")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.1))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(16)
        .glass(cornerRadius: 20)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Contact", systemImage: "trash")
            }
        }
    }
}

// MARK: - Create Group Sheet

struct CreateGroupSheet: View {
    @ObservedObject var viewModel: FamilyViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(colors: [.blue.opacity(0.2), .purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 80, height: 80)
                            Image(systemName: "person.2.badge.plus")
                                .font(.largeTitle)
                                .foregroundStyle(
                                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                        }
                        .padding(.top, 20)

                        Text("Create a group to share health data with family.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Group Name")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                TextField("e.g. My Family", text: $viewModel.newGroupName)
                                    .textFieldStyle(.plain)
                                    .padding(14)
                                    .glass(cornerRadius: 14)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description (Optional)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                TextField("e.g. Health sharing for the Smith family", text: $viewModel.newGroupDescription)
                                    .textFieldStyle(.plain)
                                    .padding(14)
                                    .glass(cornerRadius: 14)
                            }
                        }
                        .padding(.horizontal)

                        Button {
                            Task { await viewModel.createGroup() }
                        } label: {
                            Text("Create Group")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(viewModel.newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(viewModel.newGroupName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("New Family Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Add Member Sheet

struct AddMemberSheet: View {
    @ObservedObject var viewModel: FamilyViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRole: FamilyRole = .viewer
    @State private var selectedRelationship: RelationshipType = .other
    @State private var healthProfileIdText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(selectedRole.color.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Image(systemName: selectedRole.icon)
                                .font(.largeTitle)
                                .foregroundStyle(selectedRole.color)
                        }
                        .padding(.top, 20)
                        .animation(.easeInOut, value: selectedRole)

                        // Role selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Role")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            VStack(spacing: 8) {
                                ForEach(FamilyRole.allCases.filter { $0 != .owner }) { role in
                                    Button {
                                        withAnimation { selectedRole = role }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: role.icon)
                                                .foregroundStyle(role.color)
                                                .frame(width: 24)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(role.displayName)
                                                    .font(.subheadline.bold())
                                                    .foregroundStyle(.primary)
                                                Text(role.description)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            if selectedRole == role {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.blue)
                                            }
                                        }
                                        .padding(12)
                                        .background(selectedRole == role ? role.color.opacity(0.08) : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedRole == role ? role.color.opacity(0.3) : Color.clear, lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            .glass(cornerRadius: 16)
                        }
                        .padding(.horizontal)

                        // Relationship
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Relationship")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(RelationshipType.allCases) { rel in
                                        Button {
                                            withAnimation { selectedRelationship = rel }
                                        } label: {
                                            VStack(spacing: 4) {
                                                Image(systemName: rel.icon)
                                                    .font(.title3)
                                                Text(rel.displayName)
                                                    .font(.caption2)
                                            }
                                            .frame(width: 72, height: 64)
                                            .background(selectedRelationship == rel ? Color.blue.opacity(0.1) : Color.clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(selectedRelationship == rel ? Color.blue.opacity(0.3) : Color.primary.opacity(0.1), lineWidth: 0.5)
                                            )
                                        }
                                        .foregroundStyle(selectedRelationship == rel ? .blue : .secondary)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Health Profile ID input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Health Profile ID")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            TextField("Enter member's profile ID", text: $healthProfileIdText)
                                .textFieldStyle(.plain)
                                .padding(14)
                                .glass(cornerRadius: 14)
                        }
                        .padding(.horizontal)

                        // Add button
                        Button {
                            guard let profileId = UUID(uuidString: healthProfileIdText),
                                  let group = viewModel.selectedGroup else { return }
                            Task {
                                await viewModel.addMember(
                                    to: group.id,
                                    healthProfileId: profileId,
                                    role: selectedRole,
                                    relationship: selectedRelationship.rawValue
                                )
                            }
                        } label: {
                            Text("Add Member")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(UUID(uuidString: healthProfileIdText) == nil)
                        .opacity(UUID(uuidString: healthProfileIdText) == nil ? 0.5 : 1)
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Add Emergency Contact Sheet

struct AddEmergencyContactSheet: View {
    @ObservedObject var viewModel: FamilyViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var selectedRelationship: RelationshipType = .spouse
    @State private var priority = 1
    @State private var canMakeMedicalDecisions = false
    @State private var hasPowerOfAttorney = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        phone.count >= 10
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(colors: [.red.opacity(0.2), .orange.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 80, height: 80)
                            Image(systemName: "cross.case.fill")
                                .font(.largeTitle)
                                .foregroundStyle(
                                    LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                        }
                        .padding(.top, 20)

                        // Form fields
                        VStack(spacing: 16) {
                            formField(title: "Full Name", placeholder: "Contact name", text: $name)
                            formField(title: "Phone Number", placeholder: "+1 (555) 123-4567", text: $phone)
                                .keyboardType(.phonePad)
                            formField(title: "Email (Optional)", placeholder: "email@example.com", text: $email)
                                .keyboardType(.emailAddress)
                        }
                        .padding(.horizontal)

                        // Relationship
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Relationship")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(RelationshipType.allCases) { rel in
                                        Button {
                                            withAnimation { selectedRelationship = rel }
                                        } label: {
                                            Text(rel.displayName)
                                                .font(.caption.bold())
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(selectedRelationship == rel ? Color.blue.opacity(0.15) : Color.clear)
                                                .foregroundStyle(selectedRelationship == rel ? .blue : .secondary)
                                                .clipShape(Capsule())
                                                .overlay(
                                                    Capsule()
                                                        .stroke(selectedRelationship == rel ? Color.blue.opacity(0.3) : Color.primary.opacity(0.1), lineWidth: 0.5)
                                                )
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Priority
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Priority")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Picker("Priority", selection: $priority) {
                                Text("Primary (#1)").tag(1)
                                Text("Secondary (#2)").tag(2)
                                Text("Tertiary (#3)").tag(3)
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.horizontal)

                        // Medical permissions
                        VStack(spacing: 12) {
                            Toggle(isOn: $canMakeMedicalDecisions) {
                                Label("Can Make Medical Decisions", systemImage: "checkmark.shield.fill")
                                    .font(.subheadline)
                            }
                            Toggle(isOn: $hasPowerOfAttorney) {
                                Label("Has Medical Power of Attorney", systemImage: "doc.badge.gearshape.fill")
                                    .font(.subheadline)
                            }
                        }
                        .padding(16)
                        .glass(cornerRadius: 16)
                        .padding(.horizontal)

                        // Save button
                        Button {
                            Task { await saveContact() }
                        } label: {
                            Text("Save Emergency Contact")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(!isValid)
                        .opacity(isValid ? 1 : 0.5)
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Emergency Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func formField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(14)
                .glass(cornerRadius: 14)
        }
    }

    private func saveContact() async {
        // Fetch the user's primary health profile ID
        guard let userId = try? await SupabaseManager.shared.client.auth.session.user.id else { return }

        struct ProfileId: Decodable { let id: UUID }
        guard let profiles: [ProfileId] = try? await SupabaseManager.shared.client
            .from("health_profiles")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .eq("is_primary", value: true)
            .limit(1)
            .execute()
            .value,
              let profileId = profiles.first?.id else { return }

        let contact = EmergencyContact(
            healthProfileId: profileId,
            name: name.trimmingCharacters(in: .whitespaces),
            relationship: selectedRelationship.rawValue,
            phonePrimary: phone.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces).isEmpty ? nil : email.trimmingCharacters(in: .whitespaces),
            priority: priority,
            canMakeMedicalDecisions: canMakeMedicalDecisions,
            hasMedicalPowerOfAttorney: hasPowerOfAttorney
        )
        await viewModel.addEmergencyContact(contact)
    }
}

// MARK: - Member Detail Sheet

struct MemberDetailSheet: View {
    let member: FamilyMember
    @ObservedObject var viewModel: FamilyViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRole: FamilyRole

    init(member: FamilyMember, viewModel: FamilyViewModel) {
        self.member = member
        self.viewModel = viewModel
        _selectedRole = State(initialValue: member.role)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        // Profile header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(member.role.color.opacity(0.15))
                                    .frame(width: 90, height: 90)
                                Image(systemName: member.role.icon)
                                    .font(.system(size: 36))
                                    .foregroundStyle(member.role.color)
                            }

                            Text(member.displayName)
                                .font(.title2.bold())

                            if let rel = member.relationshipType {
                                Text(rel.displayName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            // Status badge
                            HStack(spacing: 6) {
                                Image(systemName: member.status.icon)
                                Text(member.status.displayName)
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(member.status.color.opacity(0.15))
                            .foregroundStyle(member.status.color)
                            .clipShape(Capsule())
                        }
                        .padding(.top, 20)

                        // Health summary card
                        if let summary = viewModel.memberHealthSummaries[member.healthProfileId] {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Health Overview")
                                    .font(.headline)

                                HStack(spacing: 0) {
                                    healthMetricTile(
                                        icon: "figure.walk",
                                        color: .blue,
                                        value: summary.stepsToday.map { "\($0)" } ?? "--",
                                        label: "Steps"
                                    )
                                    healthMetricTile(
                                        icon: "heart.fill",
                                        color: .red,
                                        value: summary.heartRate.map { "\($0)" } ?? "--",
                                        label: "BPM"
                                    )
                                    healthMetricTile(
                                        icon: "pills.fill",
                                        color: .green,
                                        value: summary.adherencePercentageText ?? "--",
                                        label: "Meds"
                                    )
                                    healthMetricTile(
                                        icon: "drop.fill",
                                        color: .cyan,
                                        value: summary.hydrationPercentageText ?? "--",
                                        label: "Water"
                                    )
                                }
                            }
                            .padding(16)
                            .glass(cornerRadius: 20)
                            .padding(.horizontal)
                        }

                        // Role management
                        if member.role != .owner {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Access Role")
                                    .font(.headline)

                                ForEach(FamilyRole.allCases.filter { $0 != .owner }) { role in
                                    Button {
                                        withAnimation { selectedRole = role }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: role.icon)
                                                .foregroundStyle(role.color)
                                                .frame(width: 24)
                                            VStack(alignment: .leading) {
                                                Text(role.displayName)
                                                    .font(.subheadline.bold())
                                                    .foregroundStyle(.primary)
                                                Text(role.description)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            if selectedRole == role {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.blue)
                                            }
                                        }
                                        .padding(12)
                                        .background(selectedRole == role ? role.color.opacity(0.08) : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }

                                if selectedRole != member.role {
                                    Button {
                                        Task {
                                            await viewModel.updateMemberRole(member, newRole: selectedRole)
                                            dismiss()
                                        }
                                    } label: {
                                        Text("Update Role")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(
                                                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                    }
                                }
                            }
                            .padding(16)
                            .glass(cornerRadius: 20)
                            .padding(.horizontal)
                        }

                        // Permissions display
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Permissions")
                                .font(.headline)

                            permissionRow(label: "View Health Data", granted: member.permissions.canView)
                            permissionRow(label: "Edit Health Data", granted: member.permissions.canEdit)
                            permissionRow(label: "Add Medications", granted: member.permissions.canAddMedications)
                            permissionRow(label: "Add Appointments", granted: member.permissions.canAddAppointments)
                            permissionRow(label: "View Medical Documents", granted: member.permissions.canViewMedicalDocuments)
                            permissionRow(label: "Manage Members", granted: member.permissions.canManageMembers)
                        }
                        .padding(16)
                        .glass(cornerRadius: 20)
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Member Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func healthMetricTile(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func permissionRow(label: String, granted: Bool) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(granted ? .green : .red.opacity(0.5))
            Text(label)
                .font(.subheadline)
            Spacer()
        }
    }
}
