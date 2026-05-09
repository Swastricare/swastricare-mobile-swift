//
//  AllMedicationsView.swift
//  swastricare-mobile-swift
//

import SwiftUI

// MARK: - Filter

private enum MedFilter: String, CaseIterable {
    case all, active, completed, discontinued

    var label: String {
        switch self {
        case .all:          return "All"
        case .active:       return "Active"
        case .completed:    return "Completed"
        case .discontinued: return "Discontinued"
        }
    }
}

// MARK: - Type Icon Colors

private let typeColors: [MedicationType: (bg: Color, icon: Color)] = [
    .pill:      (Color(hex: "E3F2FD"), Color(hex: "5BA4CF")),
    .liquid:    (Color(hex: "E8F9F3"), Color(hex: "22C5A6")),
    .injection: (Color(hex: "FDE8F4"), Color(hex: "CF5BA4")),
    .inhaler:   (Color(hex: "EFE8FE"), Color(hex: "8B5BCF")),
    .drops:     (Color(hex: "E3F5FD"), Color(hex: "42A5DC")),
    .cream:     (Color(hex: "FEF3E8"), Color(hex: "CF8B5B")),
    .other:     (Color(hex: "F5F5F5"), Color(hex: "888888")),
]

private let fallbackPalette: [(bg: Color, icon: Color)] = [
    (Color(hex: "E3F2FD"), Color(hex: "5BA4CF")),
    (Color(hex: "FFF3E0"), Color(hex: "FFB74D")),
    (Color(hex: "E8F5E9"), Color(hex: "66BB6A")),
    (Color(hex: "FCE4EC"), Color(hex: "EC407A")),
    (Color(hex: "EDE7F6"), Color(hex: "7E57C2")),
    (Color(hex: "E0F7FA"), Color(hex: "26C6DA")),
    (Color(hex: "FFF9C4"), Color(hex: "FFCA28")),
]

private func iconColors(for type: MedicationType, index: Int) -> (bg: Color, icon: Color) {
    typeColors[type] ?? fallbackPalette[index % fallbackPalette.count]
}

private struct MedBadge {
    let label: String
    let bg: Color
    let text: Color
}

private let tips: [(icon: String, color: Color, text: String)] = [
    ("clock",            Color(hex: "22C5A6"), "Take at the same time each day for best results."),
    ("drop.fill",        Color(hex: "5BA4CF"), "Always take pills with a full glass of water."),
    ("bell.fill",        Color(hex: "8B5BCF"), "Enable reminders so you never miss a dose."),
    ("heart",            Color(hex: "EC407A"), "Consistency is the key to effective treatment."),
    ("checkmark.circle", Color(hex: "66BB6A"), "Mark doses taken right after you take them."),
]

// MARK: - AllMedicationsView

struct AllMedicationsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: MedicationViewModel

    @State private var filter: MedFilter = .all
    @State private var searchQuery = ""
    @State private var searchActive = false
    @State private var showAddMedication = false
    @State private var selectedMed: Medication?

    private let accent = AppColors.accentBlue
    private let tipIndex = Int(Date().timeIntervalSince1970 / 60) % tips.count

    private var filtered: [Medication] {
        viewModel.medications.filter { med in
            let matchesFilter: Bool
            switch filter {
            case .all:          matchesFilter = true
            case .active:       matchesFilter = med.status == .active || med.status == .paused
            case .completed:    matchesFilter = med.status == .completed || (!med.isOngoing && (med.endDate ?? .distantFuture) < Date())
            case .discontinued: matchesFilter = med.status == .discontinued || med.status == .stopped
            }
            guard matchesFilter else { return false }
            if searchQuery.isEmpty { return true }
            return med.name.localizedCaseInsensitiveContains(searchQuery)
                || med.dosage.localizedCaseInsensitiveContains(searchQuery)
                || med.notes?.localizedCaseInsensitiveContains(searchQuery) == true
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                heroHeader
                filterTabBar
                Divider()

                if viewModel.isLoading && viewModel.medications.isEmpty {
                    skeletonList
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            if filtered.isEmpty {
                                emptyState
                            } else {
                                ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, med in
                                    MedRow(med: med, index: idx, accent: accent) {
                                        selectedMed = med
                                    }
                                }
                            }
                            stayConsistentBanner
                        }
                        .padding(.bottom, 100)
                    }
                }
            }

            // FAB
            Button { showAddMedication = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 16, weight: .semibold))
                    Text("Add Medication").font(.poppins(.semiBold, size: 15))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(accent)
                .cornerRadius(28)
                .shadow(color: accent.opacity(0.35), radius: 10, y: 4)
            }
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showAddMedication) {
            AddMedicationView(viewModel: viewModel)
        }
        .sheet(item: $selectedMed) { med in
            let mwa = viewModel.todaysMedications.first { $0.medication.id == med.id }
                ?? MedicationWithAdherence(medication: med, todayDoses: [])
            MedicationDetailView(medication: med, viewModel: viewModel)
        }
        .task { await viewModel.loadMedications() }
        .trackScreen("AllMedications")
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button {
                    if searchActive {
                        searchActive = false; searchQuery = ""
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: searchActive ? "xmark" : "arrow.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                        .frame(width: 40, height: 40)
                }

                if searchActive {
                    TextField("Search medications…", text: $searchQuery)
                        .font(.poppins(.regular, size: 16))
                        .foregroundColor(.primary)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All Medications")
                            .font(.poppins(.bold, size: 22))
                            .foregroundColor(Color(hex: "1A1A2E"))
                        Text("Manage your medications 💊")
                            .font(.poppins(.regular, size: 13))
                            .foregroundColor(Color(hex: "666666"))
                    }
                }

                Spacer()

                if !searchActive {
                    Button { withAnimation { searchActive = true } } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "1A1A2E"))
                            .frame(width: 40, height: 40)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }

            if !searchActive {
                tipCard
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }
        }
        .background(Color.white)
    }

    private var tipCard: some View {
        let tip = tips[tipIndex]
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(tip.color.opacity(0.18)).frame(width: 40, height: 40)
                Image(systemName: tip.icon)
                    .font(.system(size: 18)).foregroundColor(tip.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Tip")
                    .font(.poppins(.semiBold, size: 11)).foregroundColor(tip.color)
                Text(tip.text)
                    .font(.poppins(.regular, size: 13)).foregroundColor(Color(hex: "3C3C43"))
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(tip.color.opacity(0.10))
        .cornerRadius(16)
    }

    // MARK: - Filter Tab Bar

    private var filterTabBar: some View {
        HStack(spacing: 0) {
            ForEach(MedFilter.allCases, id: \.self) { tab in
                let isSelected = tab == filter
                VStack(spacing: 0) {
                    Button { withAnimation(.easeInOut(duration: 0.2)) { filter = tab } } label: {
                        Text(tab.label)
                            .font(.poppins(isSelected ? .semiBold : .regular, size: 13))
                            .foregroundColor(isSelected ? accent : Color(hex: "888888"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    Rectangle()
                        .fill(isSelected ? accent : Color.clear)
                        .frame(height: 2)
                        .frame(maxWidth: isSelected ? .infinity : 0)
                        .animation(.easeInOut(duration: 0.2), value: filter)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .background(Color.white)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "pills")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "CCCCCC"))
            Text(searchQuery.isEmpty
                 ? "No \(filter.label.lowercased()) medications"
                 : "No results for \"\(searchQuery)\"")
                .font(.poppins(.regular, size: 15))
                .foregroundColor(Color(hex: "888888"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - Stay Consistent Banner

    private var stayConsistentBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(accent.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20)).foregroundColor(accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Stay consistent")
                    .font(.poppins(.semiBold, size: 14)).foregroundColor(Color(hex: "1A1A2E"))
                Text("Taking your medications on time helps you stay healthy")
                    .font(.poppins(.regular, size: 12)).foregroundColor(Color(hex: "888888"))
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color(hex: "F0FBF8"))
        .cornerRadius(16)
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - Skeleton

    private var skeletonList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { _ in
                    HStack(spacing: 14) {
                        SkeletonShape(width: 48, height: 48, cornerRadius: 24)
                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonShape(width: 140, height: 14, cornerRadius: 7)
                            SkeletonShape(width: 90, height: 11, cornerRadius: 6)
                        }
                        Spacer()
                        SkeletonShape(width: 56, height: 22, cornerRadius: 11)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }
            }
        }
    }
}

// MARK: - Medication Row

private struct MedRow: View {
    let med: Medication
    let index: Int
    let accent: Color
    let onTap: () -> Void

    private var colors: (bg: Color, icon: Color) {
        typeColors[med.type] ?? fallbackPalette[index % fallbackPalette.count]
    }

    private var badge: MedBadge {
        let expired = !med.isOngoing && (med.endDate ?? .distantFuture) < Date()
        switch med.status {
        case .discontinued, .stopped:
            return MedBadge(label: "Discontinued", bg: Color(hex: "F0F0F0"), text: Color(hex: "888888"))
        case .completed:
            return MedBadge(label: "Completed", bg: Color(hex: "F0F0F0"), text: Color(hex: "888888"))
        case .paused:
            return MedBadge(label: "Paused", bg: Color(hex: "FFF3E0"), text: Color(hex: "FF9500"))
        default:
            if expired {
                return MedBadge(label: "Completed", bg: Color(hex: "F0F0F0"), text: Color(hex: "888888"))
            }
            return MedBadge(label: "Active", bg: Color(hex: "E8F9F3"), text: accent)
        }
    }

    private var scheduleLine: String {
        let times = med.scheduledTimes
        if times.isEmpty { return "As needed" }
        let fmt = DateFormatter(); fmt.timeStyle = .short
        let first = fmt.string(from: times.first ?? Date())
        return times.count == 1 ? "Every day · \(first)" : "\(times.count) times a day · \(first)"
    }

    private var dosageText: String {
        let parts = [med.dosage, med.type.displayName].filter { !$0.isEmpty }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 14) {
                    // Type icon
                    ZStack {
                        Circle().fill(colors.bg).frame(width: 48, height: 48)
                        Image(systemName: med.type.icon)
                            .font(.system(size: 22)).foregroundColor(colors.icon)
                    }

                    // Name + dosage + schedule
                    VStack(alignment: .leading, spacing: 4) {
                        Text(med.name)
                            .font(.poppins(.semiBold, size: 15))
                            .foregroundColor(Color(hex: "1A1A2E"))
                            .lineLimit(1)
                        if !dosageText.isEmpty {
                            Text(dosageText)
                                .font(.poppins(.regular, size: 12))
                                .foregroundColor(Color(hex: "888888"))
                                .lineLimit(1)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "AAAAAA"))
                            Text(scheduleLine)
                                .font(.poppins(.regular, size: 12))
                                .foregroundColor(Color(hex: "AAAAAA"))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Status badge
                    Text(badge.label)
                        .font(.poppins(.semiBold, size: 11))
                        .foregroundColor(badge.text)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(badge.bg)
                        .cornerRadius(20)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "CCCCCC"))
                }
                .padding(.horizontal, 20).padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 82)
        }
    }
}
