//
//  YogaLibraryView.swift
//  swastricare-mobile-swift
//
//  Full library view for browsing all yoga poses and categories
//

import SwiftUI
import Combine

struct YogaLibraryView: View {
    
    // MARK: - State
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = YogaLibraryViewModel()
    @State private var selectedPose: YogaPose?
    @State private var searchText = ""
    @State private var selectedTab = 0
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                searchBarView
                segmentedControl
                
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(message: error)
                } else {
                    contentView
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.loadData()
        }
        .sheet(item: $selectedPose) { pose in
            NavigationStack {
                YogaPoseDetailView(pose: pose)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
            
            Text("Yoga Library")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            Circle()
                .fill(Color.clear)
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Search Bar
    
    private var searchBarView: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.5))
            
            TextField("Search poses...", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .autocapitalization(.none)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(MovementsColors.cardDark)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Segmented Control
    
    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(["All Poses", "Categories"], id: \.self) { tab in
                let index = tab == "All Poses" ? 0 : 1
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tab)
                            .font(.system(size: 14, weight: selectedTab == index ? .bold : .medium))
                            .foregroundColor(selectedTab == index ? .white : .white.opacity(0.5))
                        
                        Rectangle()
                            .fill(selectedTab == index ? MovementsColors.limeGreen : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if selectedTab == 0 {
            posesListView
        } else {
            categoriesListView
        }
    }
    
    // MARK: - Poses List
    
    private var posesListView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                difficultyFilters
                
                ForEach(filteredPoses) { pose in
                    YogaPoseListItem(pose: pose) {
                        selectedPose = pose
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Difficulty Filters
    
    private var difficultyFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                DifficultyFilterChip(
                    title: "All (\(viewModel.poses.count))",
                    isSelected: viewModel.selectedLevel == nil
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.selectedLevel = nil
                    }
                }
                
                ForEach(YogaDifficultyLevel.allCases) { level in
                    let count = viewModel.poses.filter { $0.difficulty == level }.count
                    DifficultyFilterChip(
                        title: "\(level.displayName) (\(count))",
                        isSelected: viewModel.selectedLevel == level,
                        color: level.color
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectedLevel = level
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Categories List
    
    private var categoriesListView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                ForEach(filteredCategories) { category in
                    YogaCategoryCard(category: category) { pose in
                        selectedPose = pose
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Filtered Data
    
    private var filteredPoses: [YogaPose] {
        var poses = viewModel.poses
        
        if let level = viewModel.selectedLevel {
            poses = poses.filter { $0.difficulty == level }
        }
        
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            poses = poses.filter {
                $0.englishName.lowercased().contains(query) ||
                $0.sanskritNameAdapted.lowercased().contains(query) ||
                ($0.categoryName?.lowercased().contains(query) ?? false)
            }
        }
        
        return poses
    }
    
    private var filteredCategories: [YogaCategory] {
        if searchText.isEmpty {
            return viewModel.categories
        }
        
        let query = searchText.lowercased()
        return viewModel.categories.filter {
            $0.categoryName.lowercased().contains(query) ||
            $0.categoryDescription.lowercased().contains(query)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: MovementsColors.limeGreen))
                .scaleEffect(1.5)
            
            Text("Loading yoga library...")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
        }
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            
            Text(message)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            
            Button(action: {
                Task { await viewModel.loadData() }
            }) {
                Text("Try Again")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(MovementsColors.limeGreen)
                    .cornerRadius(24)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Yoga Pose List Item

struct YogaPoseListItem: View {
    let pose: YogaPose
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                AsyncImage(url: pose.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    default:
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                Image(systemName: "figure.yoga")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white.opacity(0.3))
                            )
                    }
                }
                .frame(width: 70, height: 70)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(pose.englishName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(pose.sanskritNameAdapted)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                    
                    if let category = pose.categoryName {
                        Text(category)
                            .font(.system(size: 11))
                            .foregroundColor(MovementsColors.limeGreen.opacity(0.8))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    if let difficulty = pose.difficulty {
                        Text(difficulty.displayName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(difficulty.color)
                            .cornerRadius(6)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(MovementsColors.cardDark)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Yoga Category Card

struct YogaCategoryCard: View {
    let category: YogaCategory
    let onPoseSelected: (YogaPose) -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(category.color.opacity(0.2))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: category.icon)
                            .font(.system(size: 20))
                            .foregroundColor(category.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.categoryName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("\(category.poses.count) poses")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(16)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text(category.categoryDescription)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(4)
                        .padding(.horizontal, 16)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(category.poses) { pose in
                                YogaPoseCard(pose: pose) {
                                    onPoseSelected(pose)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(MovementsColors.cardDark)
        )
    }
}

// MARK: - ViewModel

@MainActor
class YogaLibraryViewModel: ObservableObject {
    @Published var poses: [YogaPose] = []
    @Published var categories: [YogaCategory] = []
    @Published var selectedLevel: YogaDifficultyLevel?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let yogaService = YogaService.shared
    
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let posesTask = yogaService.fetchAllPoses()
            async let categoriesTask = yogaService.fetchAllCategories()
            
            let (fetchedPoses, fetchedCategories) = try await (posesTask, categoriesTask)
            
            poses = fetchedPoses
            categories = fetchedCategories
        } catch {
            if let yogaError = error as? YogaServiceError {
                errorMessage = yogaError.localizedDescription
            } else {
                errorMessage = "Unable to load yoga data: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    YogaLibraryView()
}
