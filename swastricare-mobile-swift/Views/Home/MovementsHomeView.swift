//
//  MovementsHomeView.swift
//  swastricare-mobile-swift
//
//  Today, Movements+ Home Dashboard
//

import SwiftUI

struct MovementsHomeView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - State
    
    @StateObject private var authViewModel = DependencyContainer.shared.authViewModel
    @StateObject private var homeViewModel = DependencyContainer.shared.homeViewModel
    @StateObject private var hydrationViewModel = DependencyContainer.shared.hydrationViewModel
    @StateObject private var medicationViewModel = DependencyContainer.shared.medicationViewModel
    @StateObject private var dietViewModel = DependencyContainer.shared.dietViewModel
    @StateObject private var menstrualCycleViewModel = MenstrualCycleViewModel()
    @State private var selectedFilter = "All"
    @State private var showDailyActivities = false
    @State private var showRunningActivity = false
    @State private var showHydration = false
    @State private var showMedications = false
    @State private var showDiet = false
    @State private var showMenstrualCycle = false
    @State private var showSettings = false
    @State private var showAIChat = false
    @State private var showVitalsDetail = false
    @State private var hasAppeared = false
    @State private var isAnimatingToChat = false
    @State private var animatedFieldAtBottom = false
    @State private var aiFieldGlobalFrame: CGRect = .zero
    
    // Animation namespace for expanding effect
    @Namespace private var aiTextFieldNamespace
    
    private let filters = ["All", "Meditation", "Yoga", "Hydration", "Menstrual cycle", "Diet", "Running"]
    
    // MARK: - Computed Properties
    
    private var userName: String {
        authViewModel.userName.isEmpty ? "User" : authViewModel.userName
    }
    
    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<21: return "Good Evening"
        default: return "Good Night"
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerSection
                            .padding(.top, 8)
                            .padding(.horizontal, 20)
                        
                        topSection
                            .padding(.top, 24)
                            .padding(.horizontal, 20)
                        
                        workoutProgressSection
                            .padding(.top, 24)
                            .padding(.horizontal, 20)
                        
                        // aiTextFieldSection (home screen AI text field - commented out)
                        // aiTextFieldSection
                        //     .padding(.top, 16)
                        //     .padding(.horizontal, 20)
                        
                        filterChipsSection
                            .padding(.top, 24)
                        
                        activityCardsSection
                            .padding(.top, 16)
                        
                        nutrientsSection
                            .padding(.top, 24)
                            .padding(.horizontal, 20)
                    }
                }
                // Tab bar is configured with a transparent/blur appearance, so ScrollView content can
                // render underneath it. Add an explicit bottom inset so the last section isn't cut off.
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 52 + geo.safeAreaInsets.bottom)
                }
                
                if isAnimatingToChat {
                    animatedAIFieldOverlay
                }
            }
        }
        .onPreferenceChange(AIFieldFramePreference.self) { frame in
            aiFieldGlobalFrame = frame
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showDailyActivities) {
            NavigationStack {
                DailyActivitiesView()
            }
        }
        .fullScreenCover(isPresented: $showRunningActivity) {
            NavigationStack {
                RunActivityView(presentationStyle: .movementsModal)
            }
        }
        .sheet(isPresented: $showHydration) {
            NavigationStack {
                HydrationView(viewModel: hydrationViewModel)
            }
        }
        .sheet(isPresented: $showMedications) {
            NavigationStack {
                MedicationsView(viewModel: medicationViewModel)
            }
        }
        .sheet(isPresented: $showDiet) {
            NavigationStack {
                DietView(viewModel: dietViewModel)
            }
        }
        .sheet(isPresented: $showMenstrualCycle) {
            MenstrualCycleView(viewModel: menstrualCycleViewModel)
        }
        .fullScreenCover(isPresented: $showAIChat) {
            MovementsAIChatView(
                animationNamespace: aiTextFieldNamespace,
                textFieldID: "aiTextField"
            )
            .transition(.asymmetric(
                insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity),
                removal: .scale(scale: 0.95).combined(with: .opacity)
            ))
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showVitalsDetail) {
            NavigationStack {
                VitalsDetailView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkOpenHydration)) { _ in
            showHydration = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkOpenMedications)) { _ in
            showMedications = true
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
        }
        .task {
            await homeViewModel.loadTodaysData()
            await hydrationViewModel.loadData()
            await medicationViewModel.loadMedications()
            await dietViewModel.loadData()
            await menstrualCycleViewModel.onAppear()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(alignment: .center) {
            HStack(spacing: 12) {
                if let photoURL = authViewModel.userPhotoURL {
                    AsyncImage(url: photoURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "4ECDC4"), Color(hex: "45B7D1")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "4ECDC4"), Color(hex: "45B7D1")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(String(userName.prefix(1)).uppercased())
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(timeBasedGreeting)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Text(userName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            Button(action: { showSettings = true }) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : -20)
    }
    
    // MARK: - AI Text Field Section
    
    private var aiTextFieldSection: some View {
        AnimatedAITextField {
            triggerChatTransition()
        }
        .opacity(isAnimatingToChat ? 0 : (hasAppeared ? 1 : 0))
        .offset(y: hasAppeared ? 0 : 10)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.22), value: hasAppeared)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: AIFieldFramePreference.self, value: geo.frame(in: .global))
            }
        )
    }
    
    // MARK: - Top Section
    
    private var topSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(formattedDate)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Text("Today,\nMovements+")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.primary)
                .lineSpacing(4)
            
            NavigationLink(destination: FamilyView()) {
                HStack(spacing: 8) {
                    AvatarStackView(count: 215, avatarSize: 28)
                    
                    Text("View Family →")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: hasAppeared)
    }
    
    // MARK: - Vitals Section (Replaces Workout Progress)
    
    private var workoutProgressSection: some View {
        AnimatedVitalsCard(
            steps: homeViewModel.stepCount,
            heartRate: homeViewModel.heartRate,
            calories: homeViewModel.activeCalories,
            sleepHours: homeViewModel.sleepHours,
            exerciseMinutes: homeViewModel.exerciseMinutes
        ) {
            showVitalsDetail = true
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: hasAppeared)
    }
    
    // MARK: - Filter Chips Section
    
    private var filterChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filters, id: \.self) { filter in
                    FilterChip(
                        title: filter,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFilter = filter
                        }
                        switch filter {
                        case "All":
                            showDailyActivities = true
                        case "Meditation":
                            showMedications = true
                        case "Hydration":
                            showHydration = true
                        case "Diet":
                            showDiet = true
                        case "Menstrual cycle":
                            showMenstrualCycle = true
                        case "Running":
                            showRunningActivity = true
                        default:
                            break
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: hasAppeared)
    }
    
    // MARK: - Activity Cards Section
    
    private var activityCardsSection: some View {
        let medTaken = medicationViewModel.takenCount
        let medTotal = medicationViewModel.totalCount
        let medProgress = medTotal > 0 ? Double(medTaken) / Double(medTotal) : 0
        let medSubtitle = medTotal > 0 ? "\(medTaken)/\(medTotal) taken" : "No doses today"
        let medBg = medicationViewModel.hasOverdueDoses ? Color(hex: "FF6B6B") : Color(hex: "5856D6")
        
        let hydrationProgress = hydrationViewModel.progress
        let hydrationSubtitle = hydrationViewModel.dailyGoal > 0
        ? "\(hydrationViewModel.effectiveIntake) / \(hydrationViewModel.dailyGoal) ml"
        : "Set your goal"
        
        let dietProgress = dietViewModel.calorieProgress
        let dietGoalCal = dietViewModel.dietGoals.dailyCalories
        let dietSubtitle = dietGoalCal > 0
        ? "\(dietViewModel.totalCalories)/\(dietGoalCal) cal"
        : "Set your goal"
        
        let cycleProgress = menstrualCycleViewModel.cycleProgress
        let cycleSubtitle = menstrualCycleViewModel.periodStatusText
        let cycleBg = menstrualCycleViewModel.currentPhase.color
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                MovementsActivityCard(
                    title: "Running",
                    subtitle: "5.2 km today",
                    progress: 0.80,
                    icon: "figure.run",
                    backgroundColor: MovementsColors.limeGreen,
                    progressColor: .white,
                    contentColor: .black,
                    showGeometricPattern: true
                ) {
                    showRunningActivity = true
                } onExpandTapped: {
                    showRunningActivity = true
                }
                
                MovementsActivityCard(
                    title: "Meditation",
                    subtitle: medSubtitle,
                    progress: medProgress,
                    icon: "pills.fill",
                    backgroundColor: medBg,
                    progressColor: .white,
                    contentColor: .white,
                    showGeometricPattern: false
                ) {
                    showMedications = true
                } onExpandTapped: {
                    showMedications = true
                }
                
                MovementsActivityCard(
                    title: "Hydration",
                    subtitle: hydrationSubtitle,
                    progress: hydrationProgress,
                    icon: "drop.fill",
                    backgroundColor: Color(hex: "5AC8FA"),
                    progressColor: .white,
                    contentColor: .white,
                    showGeometricPattern: false
                ) {
                    showHydration = true
                } onExpandTapped: {
                    showHydration = true
                }
                
                MovementsActivityCard(
                    title: "Diet",
                    subtitle: dietSubtitle,
                    progress: dietProgress,
                    icon: "fork.knife",
                    backgroundColor: MovementsColors.darkGreen,
                    progressColor: MovementsColors.limeGreen,
                    contentColor: .white,
                    showGeometricPattern: false
                ) {
                    showDiet = true
                } onExpandTapped: {
                    showDiet = true
                }
                
                MovementsActivityCard(
                    title: "Menstrual cycle",
                    subtitle: cycleSubtitle,
                    progress: cycleProgress,
                    icon: "calendar",
                    backgroundColor: cycleBg,
                    progressColor: .white,
                    contentColor: .white,
                    showGeometricPattern: false
                ) {
                    showMenstrualCycle = true
                } onExpandTapped: {
                    showMenstrualCycle = true
                }
                
                YogaMovementCard()
            }
            .padding(.horizontal, 20)
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: hasAppeared)
    }
    
    // MARK: - Nutrients Section
    
    private var nutrientsSection: some View {
        Button(action: { showDailyActivities = true }) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nutrients Details")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Track your daily nutrition intake")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(MovementsColors.limeGreen.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 18))
                        .foregroundColor(MovementsColors.limeGreen)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(MovementsColors.card(for: colorScheme))
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: hasAppeared)
    }
    
    // MARK: - Chat Transition Animation
    
    private func triggerChatTransition() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isAnimatingToChat = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                animatedFieldAtBottom = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            showAIChat = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isAnimatingToChat = false
                animatedFieldAtBottom = false
            }
        }
    }
    
    private var animatedAIFieldOverlay: some View {
        GeometryReader { geo in
            let globalOriginY = geo.frame(in: .global).minY
            let startY = aiFieldGlobalFrame.midY - globalOriginY
            let endY = geo.size.height - geo.safeAreaInsets.bottom - 25
            
            Color.black.opacity(animatedFieldAtBottom ? 0.3 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
            aiFieldSnapshotView
                .padding(.horizontal, 20)
                .opacity(animatedFieldAtBottom ? 0.8 : 1.0)
                .scaleEffect(animatedFieldAtBottom ? 0.92 : 1.0)
                .position(
                    x: geo.size.width / 2,
                    y: animatedFieldAtBottom ? endY : startY
                )
                .shadow(color: MovementsColors.limeGreen.opacity(animatedFieldAtBottom ? 0.4 : 0), radius: 20, y: 5)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    private var aiFieldSnapshotView: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [
                                MovementsColors.limeGreen,
                                Color(hex: "4ECDC4"),
                                Color(hex: "45B7D1"),
                                MovementsColors.limeGreen
                            ],
                            center: .center
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("Ask me anything about health...")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Spacer()
            
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 26))
                .foregroundColor(MovementsColors.limeGreen)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(MovementsColors.card(for: colorScheme))
                
                RoundedRectangle(cornerRadius: 24)
                    .stroke(MovementsColors.limeGreen.opacity(0.6), lineWidth: 1.5)
            }
        )
    }
}

// MARK: - AI Field Frame Preference Key

private struct AIFieldFramePreference: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MovementsHomeView()
    }
}
