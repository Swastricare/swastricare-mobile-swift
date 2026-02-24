//
//  YogaSectionView.swift
//  swastricare-mobile-swift
//
//  Yoga section for the home screen with poses carousel
//

import SwiftUI
import Combine

struct YogaSectionView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - State
    
    @StateObject private var viewModel = YogaSectionViewModel()
    @State private var selectedPose: YogaPose?
    @State private var showAllPoses = false
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .secondary
    }
    
    private var tertiaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.4) : .secondary.opacity(0.7)
    }
    
    private var chipUnselectedTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }
    
    private var chipUnselectedBorderColor: Color {
        colorScheme == .dark ? .white.opacity(0.3) : .primary.opacity(0.2)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView
            
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else {
                difficultyFilterView
                posesCarouselView
            }
        }
        .task {
            await viewModel.loadPoses()
        }
        .sheet(item: $selectedPose) { pose in
            NavigationStack {
                YogaPoseDetailView(pose: pose)
            }
        }
        .fullScreenCover(isPresented: $showAllPoses) {
            NavigationStack {
                YogaLibraryView()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Yoga Poses")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(primaryTextColor)
                
                Text("Find your balance")
                    .font(.system(size: 13))
                    .foregroundColor(secondaryTextColor)
            }
            
            Spacer()
            
            Button(action: { showAllPoses = true }) {
                HStack(spacing: 4) {
                    Text("See All")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(MovementsColors.limeGreen)
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: MovementsColors.limeGreen))
                    .scaleEffect(1.2)
                
                Text("Loading poses...")
                    .font(.system(size: 13))
                    .foregroundColor(secondaryTextColor)
            }
            .padding(.vertical, 40)
            Spacer()
        }
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 32))
                .foregroundColor(tertiaryTextColor)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(secondaryTextColor)
                .multilineTextAlignment(.center)
            
            Button(action: {
                Task { await viewModel.loadPoses() }
            }) {
                Text("Retry")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(MovementsColors.limeGreen)
                    .cornerRadius(20)
            }
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Difficulty Filter
    
    private var difficultyFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                DifficultyFilterChip(
                    title: "All",
                    isSelected: viewModel.selectedLevel == nil
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.selectedLevel = nil
                    }
                }
                
                ForEach(YogaDifficultyLevel.allCases) { level in
                    DifficultyFilterChip(
                        title: level.displayName,
                        isSelected: viewModel.selectedLevel == level,
                        color: level.color
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectedLevel = level
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Poses Carousel
    
    private var posesCarouselView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(viewModel.filteredPoses.prefix(10)) { pose in
                    YogaPoseCard(pose: pose) {
                        selectedPose = pose
                    }
                }
            }
        }
    }
}

// MARK: - Difficulty Filter Chip

struct DifficultyFilterChip: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let isSelected: Bool
    var color: Color = MovementsColors.limeGreen
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .black : (colorScheme == .dark ? .white : .primary))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? color : Color.clear)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : (colorScheme == .dark ? Color.white.opacity(0.3) : Color.primary.opacity(0.2)), lineWidth: 1)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Yoga Pose Card

struct YogaPoseCard: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let pose: YogaPose
    let action: () -> Void
    
    private var cardBackground: Color {
        MovementsColors.card(for: colorScheme)
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.primary.opacity(0.08)
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .secondary
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: pose.imageURL) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.primary.opacity(0.06))
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(
                                            CircularProgressViewStyle(
                                                tint: colorScheme == .dark ? .white : .secondary
                                            )
                                        )
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            Rectangle()
                                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.primary.opacity(0.06))
                                .overlay(
                                    Image(systemName: "figure.yoga")
                                        .font(.system(size: 40))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .secondary.opacity(0.6))
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 140, height: 100)
                    .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.primary.opacity(0.03))
                    
                    if let difficulty = pose.difficulty {
                        Text(difficulty.displayName)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(difficulty.color)
                            .cornerRadius(4)
                            .padding(8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(pose.englishName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(primaryTextColor)
                        .lineLimit(1)
                    
                    Text(pose.sanskritNameAdapted)
                        .font(.system(size: 11))
                        .foregroundColor(secondaryTextColor)
                        .lineLimit(1)
                    
                    if let category = pose.categoryName {
                        HStack(spacing: 4) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 8))
                            Text(category.replacingOccurrences(of: " Yoga", with: ""))
                                .font(.system(size: 10))
                        }
                        .foregroundColor(MovementsColors.limeGreen.opacity(0.8))
                        .lineLimit(1)
                    }
                }
                .padding(12)
            }
            .frame(width: 140)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - ViewModel

@MainActor
class YogaSectionViewModel: ObservableObject {
    @Published var poses: [YogaPose] = []
    @Published var selectedLevel: YogaDifficultyLevel?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let yogaService = YogaService.shared
    
    var filteredPoses: [YogaPose] {
        guard let level = selectedLevel else { return poses }
        return poses.filter { $0.difficulty == level }
    }
    
    func loadPoses() async {
        isLoading = true
        errorMessage = nil
        
        do {
            poses = try await yogaService.fetchAllPoses()
        } catch {
            if let yogaError = error as? YogaServiceError {
                errorMessage = yogaError.localizedDescription
            } else {
                errorMessage = "Unable to load yoga poses: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        ScrollView {
            YogaSectionView()
                .padding(.horizontal, 20)
        }
    }
}
