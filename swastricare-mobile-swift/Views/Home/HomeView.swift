//
//  HomeView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI
import UIKit

struct HomeView: View {
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel = DependencyContainer.shared.homeViewModel
    @StateObject private var trackerViewModel = DependencyContainer.shared.trackerViewModel
    @StateObject private var authViewModel = DependencyContainer.shared.authViewModel
    @StateObject private var hydrationViewModel = DependencyContainer.shared.hydrationViewModel
    @StateObject private var medicationViewModel = DependencyContainer.shared.medicationViewModel
    @StateObject private var dietViewModel = DependencyContainer.shared.dietViewModel
    // MARK: - Local State
    
    @State private var showSyncAlert = false
    @State private var syncMessage: String?
    @State private var hasAppeared = false
    @State private var modelOpacity: Double = 0
    @State private var modelScale: CGFloat = 0.8
    @State private var quickActionsVisible = false
    @State private var showHeartRateMeasurement = false
    @State private var showReminders = false
    @State private var showDiet = false
    @State private var showARBodyScan = false
    
    // MARK: - Computed Properties
    
    private var userName: String {
        authViewModel.userName.components(separatedBy: " ").first ?? "User"
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
    
    // MARK: - Health Status Logic
    
    private enum HealthStatus {
        case optimal
        case attention
        case normal
        
        var title: String {
            switch self {
            case .optimal: return "System Optimal"
            case .attention: return "Attention Needed"
            case .normal: return "Status Normal"
            }
        }
        
        var message: String {
            switch self {
            case .optimal: return "All vitals and medications on track"
            case .attention: return "Medications pending or vitals check required"
            case .normal: return "Health metrics within normal range"
            }
        }
        
        var color: Color {
            switch self {
            case .optimal: return Color.green
            case .attention: return Color.orange
            case .normal: return Color.blue
            }
        }
        
        var glowColor: Color {
            switch self {
            case .optimal: return Color.green.opacity(0.5)
            case .attention: return Color.orange.opacity(0.5)
            case .normal: return Color.blue.opacity(0.5)
            }
        }
    }
    
    private var healthStatus: HealthStatus {
        if !viewModel.isAuthorized {
            return .attention
        }
        // Example logic: If meds taken < total, attention needed (simplified)
        // In reality, this would check times. For now, if taken == total > 0, optimal.
        if medicationViewModel.totalCount > 0 && medicationViewModel.takenCount == medicationViewModel.totalCount {
            return .optimal
        }
        if medicationViewModel.takenCount < medicationViewModel.totalCount {
             // If it's late in the day, maybe attention? For now just normal/attention differentiation
            return .normal 
        }
        return .normal
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Premium Background
            PremiumBackground()
            
            GeometryReader { screenGeo in
                // Calculate dynamic model height: screen minus fixed elements
                let headerHeight: CGFloat = 80
                let dietCardHeight: CGFloat = 130
                let quickActionsHeight: CGFloat = 88 * 2 + 8 + 8 // 2 rows × 88pt + spacing + top padding
                let fixedContent = headerHeight + dietCardHeight + quickActionsHeight + 12 // padding
                let modelHeight = max(160, screenGeo.size.height - fixedContent)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if viewModel.isLoading && !hasAppeared {
                            homeSkeletonView
                        }

                        // Living Status Header
                        LivingStatusHeader(
                            userName: userName,
                            userPhotoURL: authViewModel.userPhotoURL,
                            status: healthStatus,
                            greeting: timeBasedGreeting,
                            stepCount: viewModel.stepCount,
                            lastSyncTime: viewModel.lastSyncTime,
                            showReminders: $showReminders
                        )
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 18)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: hasAppeared)

                        // Proactive AI Nudges
                        if !viewModel.serverNudges.isEmpty {
                            NudgeCardsView(
                                nudges: viewModel.serverNudges,
                                onDismiss: { nudge in
                                    Task { await viewModel.dismissNudge(nudge) }
                                },
                                onAction: { nudge in
                                    Task { await viewModel.actOnNudge(nudge) }
                                    if let deeplink = nudge.actionDeeplink, let url = URL(string: deeplink) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            )
                            .padding(.top, 4)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 18)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: hasAppeared)
                        }

                        // Health Authorization Banner
                        if !viewModel.isAuthorized && !viewModel.hasRequestedAuth {
                            authorizationBanner
                        }

                        // Human Body Image with Daily Activity Details (tap for AR scan)
                        humanBodyImageWithDetails
                            .frame(height: modelHeight)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 24)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: hasAppeared)
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                showARBodyScan = true
                            }

                        // Diet Summary
                        healthVitalsSection
                            .padding(.top, 4)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 24)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: hasAppeared)

                        // Quick Actions
                        quickActionsSection
                            .padding(.top, 8)
                            .modifier(ScrollAnimationModifier(isVisible: $quickActionsVisible))
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 30)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35), value: hasAppeared)
                    }
                    .padding(.top, 4)
                }
            }
            .coordinateSpace(name: "scroll")
        .alert("Sync Status", isPresented: $showSyncAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(syncMessage ?? "")
        }
        .sheet(isPresented: $showHeartRateMeasurement) {
            NavigationStack {
                HeartRateView()
            }
        }
        .sheet(isPresented: $showReminders) {
            RemindersView()
        }
        .fullScreenCover(isPresented: $showARBodyScan) {
            ARBodyScanView()
        }
        .onAppear {
            AppAnalyticsService.shared.logScreen("Home")
            // Haptic feedback when opening vitals screen
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()

            // Trigger entrance animations with staggered cascade
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    hasAppeared = true
                }
            }
            // Animate 3D model
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                modelOpacity = 0.8
                modelScale = 1.20 // Reduced size
            }
        }
        .task {
            await viewModel.loadTodaysData()
            await trackerViewModel.loadData()
            await hydrationViewModel.loadData()
            await medicationViewModel.loadMedications()
            await dietViewModel.loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkOpenHydration)) { _ in
            showHydration = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkOpenMedications)) { _ in
            showMedications = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkOpenHeartRate)) { _ in
            showHeartRateMeasurement = true
        }
        .refreshable {
            await viewModel.refresh()
            await trackerViewModel.refresh()
            await hydrationViewModel.refresh()
            await medicationViewModel.refresh()
            await dietViewModel.refresh()
        }
        }
    }
    
    // MARK: - Helper Methods
    
    // MARK: - Subviews
    
    private var humanBodyImageWithDetails: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Human Body 3D Model on the right — aligned to top
                HStack {
                    Spacer()
                    ModelViewer(modelName: "anatomy", allowsInteraction: false)
                        .frame(maxHeight: .infinity)
                        .opacity(modelOpacity)
                        .scaleEffect(modelScale)
                        .offset(x: geometry.size.width * 0.10)
                        .allowsHitTesting(false)
                        .clipped()
                        .mask(
                            LinearGradient(
                                colors: [.black, .black.opacity(0.8), .black.opacity(0.3), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                // All 6 health stats — 2 columns × 3 rows, top-aligned
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 6),
                    GridItem(.flexible(), spacing: 6)
                ], spacing: 6) {
                    CompactStatCell(icon: "flame.fill", color: .orange, value: viewModel.activeCalories > 0 ? "\(viewModel.activeCalories)" : "—", unit: "Cal")
                    CompactStatCell(icon: "clock.fill", color: .blue, value: viewModel.exerciseMinutes > 0 ? "\(viewModel.exerciseMinutes)" : "—", unit: "Min")
                    CompactStatCell(icon: "figure.stand", color: .purple, value: viewModel.standHours > 0 ? "\(viewModel.standHours)" : "—", unit: "Stand")

                    Button(action: { showHeartRateMeasurement = true }) {
                        CompactStatCell(icon: "heart.fill", color: .red, value: viewModel.heartRate > 0 ? "\(viewModel.heartRate)" : "—", unit: "BPM")
                    }
                    .buttonStyle(PlainButtonStyle())

                    CompactStatCell(icon: "bed.double.fill", color: .indigo, value: viewModel.sleepHours == "0h 0m" ? "—" : viewModel.sleepHours, unit: "Sleep")
                    CompactStatCell(icon: "figure.walk", color: .green, value: viewModel.distance > 0 ? String(format: "%.1f", viewModel.distance) : "—", unit: "km")
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .frame(maxWidth: geometry.size.width * 0.55, alignment: .leading)
                .opacity(hasAppeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: hasAppeared)
            }
        }
        // Height is set by parent via .frame(height: modelHeight)
    }
    
    private var authorizationBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square.fill")
            .font(.largeTitle)
            .foregroundColor(.red)
            .shadow(color: .red.opacity(0.5), radius: 10)
            
            Text("Enable Health Access")
                .font(.headline)
            
            Text("Allow Swastricare to read your health data for personalized insights")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                Task {
                    await viewModel.requestAuthorization()
                }
            }) {
                Text("Allow Access")
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(PremiumColor.royalBlue)
                    .cornerRadius(12)
            }
        }
        .padding()
        .glass(cornerRadius: 16)
        .padding(.horizontal)
    }
    
    // MARK: - Skeleton Loading

    private var homeSkeletonView: some View {
        VStack(spacing: 16) {
            // Header skeleton
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonShape(width: 100, height: 14)
                    SkeletonShape(width: 140, height: 20)
                }
                Spacer()
                SkeletonCircle(size: 36)
            }
            .padding(.horizontal)

            // Activity stats skeleton
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: 10) {
                        SkeletonCircle(size: 35)
                        VStack(alignment: .leading, spacing: 4) {
                            SkeletonShape(width: 40, height: 18)
                            SkeletonShape(width: 60, height: 10)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .glass(cornerRadius: 16)
                }
            }
            .padding(.horizontal)

            // Vitals grid skeleton
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 10) {
                        SkeletonCircle(size: 32)
                        VStack(alignment: .leading, spacing: 4) {
                            SkeletonShape(width: 50, height: 10)
                            SkeletonShape(width: 40, height: 22)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glass(cornerRadius: 20)
                }
            }
            .padding(.horizontal)

            // Quick actions skeleton
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonShape(height: 150, cornerRadius: 24)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    private var dietCalorieProgress: Double {
        let goal = dietViewModel.dietGoals.dailyCalories
        guard goal > 0 else { return 0 }
        return min(Double(dietViewModel.totalCalories) / Double(goal), 1.0)
    }

    private var healthVitalsSection: some View {
        // Diet Summary Card — replaces old vitals grid
        Button(action: { showDiet = true }) {
            dietSummaryContent
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 16)
    }

    private var dietSummaryContent: some View {
        ZStack {
            // Gradient background
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.dietOrange.opacity(0.12),
                            AppColors.dietOrangeLight.opacity(0.06),
                            AppColors.dietOrangeLight.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 16) {
                // Top row: ring + info + chevron
                HStack(spacing: 16) {
                    dietCalorieRing

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Today's Diet")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.6)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(dietViewModel.totalCalories)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("/ \(dietViewModel.dietGoals.dailyCalories)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("cal")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.dietOrange)
                        .frame(width: 30, height: 30)
                        .background(AppColors.dietOrange.opacity(0.12))
                        .clipShape(Circle())
                }

                // Macro progress bars
                HStack(spacing: 10) {
                    MacroBar(label: "Protein", value: dietViewModel.nutritionSummary.totalProteinG, goal: dietViewModel.proteinGoalGrams, color: AppColors.dietOrange)
                    MacroBar(label: "Carbs", value: dietViewModel.nutritionSummary.totalCarbsG, goal: dietViewModel.carbsGoalGrams, color: AppColors.macroBlue)
                    MacroBar(label: "Fat", value: dietViewModel.nutritionSummary.totalFatG, goal: dietViewModel.fatGoalGrams, color: AppColors.macroViolet)
                }
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppColors.dietOrange.opacity(0.12), lineWidth: 0.5)
        )
    }

    private var dietCalorieRing: some View {
        ZStack {
            Circle()
                .stroke(AppColors.dietOrange.opacity(0.12), lineWidth: 8)
                .frame(width: 68, height: 68)
            Circle()
                .trim(from: 0, to: dietCalorieProgress)
                .stroke(AppColors.dietOrangeGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 68, height: 68)
                .rotationEffect(.degrees(-90))
            Image(systemName: "fork.knife")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColors.dietOrangeGradient)
        }
    }
    
    @State private var showMedications = false
    @State private var showHydration = false
    @State private var showMenstrualCycle = false
    @State private var showFamily = false


    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                alignment: .center,
                spacing: 8
            ) {
                MedicationQuickActionButton(
                    takenCount: medicationViewModel.takenCount,
                    totalCount: medicationViewModel.totalCount
                ) {
                    showMedications = true
                }
                .opacity(quickActionsVisible ? 1 : 0)
                .scaleEffect(quickActionsVisible ? 1 : 0.92)
                .animation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.05), value: quickActionsVisible)
                
                HydrationQuickActionButton(
                    currentIntake: hydrationViewModel.effectiveIntake,
                    dailyGoal: hydrationViewModel.dailyGoal
                ) {
                    showHydration = true
                }
                .opacity(quickActionsVisible ? 1 : 0)
                .scaleEffect(quickActionsVisible ? 1 : 0.92)
                .animation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.12), value: quickActionsVisible)
                
                CycleTrackerQuickActionButton {
                    showMenstrualCycle = true
                }
                .opacity(quickActionsVisible ? 1 : 0)
                .scaleEffect(quickActionsVisible ? 1 : 0.92)
                .animation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.19), value: quickActionsVisible)

                // Family card
                Button(action: { showFamily = true }) {
                    FamilyQuickActionCard()
                }
                .buttonStyle(ScaleButtonStyle())
                .opacity(quickActionsVisible ? 1 : 0)
                .scaleEffect(quickActionsVisible ? 1 : 0.92)
                .animation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.26), value: quickActionsVisible)
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showMedications) {
            MedicationsView(viewModel: medicationViewModel)
        }
        .sheet(isPresented: $showHydration) {
            HydrationView(viewModel: hydrationViewModel)
        }
        .sheet(isPresented: $showDiet) {
            DietView(viewModel: dietViewModel)
        }
        .sheet(isPresented: $showMenstrualCycle) {
            MenstrualCycleView()
        }
        .sheet(isPresented: $showFamily) {
            NavigationStack {
                FamilyView()
            }
        }
    }
    
    private var profileButton: some View {
        Button(action: {
            // Haptic feedback on navbar tap
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            // Navigation will be handled by NavigationLink if needed
        }) {
            Group {
                if let imageURL = authViewModel.userPhotoURL {
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Living Status Header
    
    private struct LivingStatusHeader: View {
        let userName: String
        let userPhotoURL: URL?
        let status: HealthStatus
        let greeting: String
        let stepCount: Int
        let lastSyncTime: Date?
        @Binding var showReminders: Bool

        @State private var isPulsing = false

        var body: some View {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    // Left: Greeting + Name + Heart
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(status.color)

                        HStack(alignment: .center, spacing: 8) {
                            Text(userName)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            // Pulsing Heart
                            Image(systemName: "heart.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.red)
                                .scaleEffect(isPulsing ? 1.2 : 1.0)
                                .opacity(isPulsing ? 1.0 : 0.8)
                                .animation(
                                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                    value: isPulsing
                                )
                        }

                        // Step progress + last updated
                        HStack(spacing: 12) {
                            // Steps
                            HStack(spacing: 4) {
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppColors.accentGreen)
                                Text(stepCount > 0 ? "\(stepCount.formatted()) steps" : "No steps yet")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(stepCount > 0 ? AppColors.accentGreen : .secondary)
                            }

                            // Last updated
                            if let syncTime = lastSyncTime {
                                Text("· \(syncTime.formatted(.relative(presentation: .named)))")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 2)
                    }

                    Spacer()

                    // Right: Actions
                    HStack(spacing: 16) {
                        Button(action: { showReminders = true }) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                        }

                        NavigationLink(destination: HealthAnalyticsView()) {
                            Image(systemName: "target")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 40, height: 40)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .onAppear { isPulsing = true }
        }
    }
}

// MARK: - Scroll Animation Modifier

struct ScrollAnimationModifier: ViewModifier {
    @Binding var isVisible: Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).minY
                        )
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                // Trigger animation when view enters visible area
                let screenHeight = UIScreen.main.bounds.height
                if !isVisible && offset < screenHeight + 100 && offset > -100 {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        isVisible = true
                    }
                }
            }
            .onAppear {
                // Fallback: animate on appear if not already visible
                if !isVisible {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            isVisible = true
                        }
                    }
                }
            }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Supporting Views

    // DailyActivityStatItem removed — replaced by CompactStatCell

// MARK: - Compact Stat Cell (2-col grid in model area)

// MARK: - Family Quick Action Card

private struct FamilyQuickActionCard: View {
    private let accent = AppColors.family
    @State private var orbFloat: Bool = false
    @State private var personBounce: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )

            // Floating orbs
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 60, height: 60)
                .offset(x: orbFloat ? 25 : 35, y: orbFloat ? -15 : -5)
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 40, height: 40)
                .offset(x: orbFloat ? -20 : -10, y: orbFloat ? 20 : 30)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 32, height: 32)
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(personBounce ? 1.1 : 1.0)
                    }

                    Spacer()

                    // Animated heart
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                        .scaleEffect(personBounce ? 1.2 : 0.9)
                }

                Spacer()

                Text("Family")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                Text("Health Hub")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(12)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                orbFloat = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.5)) {
                personBounce = true
            }
        }
    }
}

private struct CompactStatCell: View {
    let icon: String
    let color: Color
    let value: String
    let unit: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.10), lineWidth: 0.5)
        )
    }
}

// MARK: - Macro Bar (for diet summary card)

private struct MacroBar: View {
    let label: String
    let value: Double
    let goal: Double
    let color: Color

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(value / goal, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(value))g")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
            }

            // Progress bar — no GeometryReader needed
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.12))
                    .frame(height: 5)
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(height: 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scaleEffect(x: max(progress, 0.02), y: 1, anchor: .leading)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StatRow: View {
    let icon: String
    let color: Color
    let value: String
    let unit: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color.opacity(0.9))
            Text(value)
                .fontWeight(.bold)
            Text(unit)
                .font(.caption)
                .opacity(0.8)
        }
    }
}

// VitalCard removed — vitals section replaced by diet summary card

private struct HydrationQuickActionButton: View {
    let currentIntake: Int
    let dailyGoal: Int
    let action: () -> Void

    // Start at 1.0 (100%)
    @State private var visualProgress: Double = 1.0
    @State private var wavePhase: Double = 0.0
    @State private var dropBounce: Bool = false
    @State private var dropGlow: Bool = false
    
    private var targetProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1.0, Double(currentIntake) / Double(dailyGoal))
    }
    
    private let accent: Color = AppColors.hydration
    private let textColor: Color = .white
    private let secondaryTextOpacity: Double = 0.9
    private let tertiaryTextOpacity: Double = 0.75
    private let iconCircleFill: Color = Color.white.opacity(0.18)
    private let waveBackOpacity: Double = 0.14
    private let waveFrontOpacities: (Double, Double) = (0.12, 0.10)
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background & Water Animation
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        // Base background
                        RoundedRectangle(cornerRadius: 24)
                            .fill(accent)
                            .overlay(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.22), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                            )
                        
                        // Water Waves — same geometry as Medication card (RoundedRectangle, bottom-aligned fill)
                        if visualProgress > 0.01 {
                            let waveHeight = max(geo.size.height * visualProgress, geo.size.height * 0.05)
                            let amp = min(geo.size.height * 0.04, waveHeight * 0.45)
                            let ampFront = min(geo.size.height * 0.03, waveHeight * 0.35)
                            ZStack {
                                WaterWave(amplitude: amp, offset: wavePhase)
                                    .fill(Color.white.opacity(waveBackOpacity))
                                    .frame(height: waveHeight)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                
                                WaterWave(amplitude: ampFront, offset: wavePhase + 1.5)
                                    .fill(LinearGradient(
                                        colors: [.white.opacity(waveFrontOpacities.0), .white.opacity(waveFrontOpacities.1)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                                    .frame(height: waveHeight)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                        }
                    }
                }
                
                // Content Overlay
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        ZStack {
                            Circle()
                                .fill(iconCircleFill)
                                .frame(width: 32, height: 32)
                                .shadow(color: Color.white.opacity(dropGlow ? 0.3 : 0), radius: dropGlow ? 8 : 0)
                            Image(systemName: "drop.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(textColor)
                                .offset(y: dropBounce ? -3 : 3)
                        }

                        Spacer()

                        Text("\(Int(visualProgress * 100))%")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(textColor)
                            .contentTransition(.numericText(value: visualProgress))
                    }

                    Spacer()

                    Text("Hydration")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(textColor.opacity(secondaryTextOpacity))

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(currentIntake)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(textColor)
                            .contentTransition(.numericText())
                        Text("/ \(dailyGoal) ml")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(textColor.opacity(tertiaryTextOpacity))
                    }
                }
                .padding(12)
            }
            .frame(height: 88)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // 1. Start continuous wave animation
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }

            // 2. Animate from 100% down to actual value on load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 2.0)) {
                    visualProgress = targetProgress
                }
            }

            // 3. Drop bounce
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                dropBounce = true
            }
            // 4. Icon glow
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(0.3)) {
                dropGlow = true
            }
        }
        .onChange(of: targetProgress) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                visualProgress = newValue
            }
        }
    }
}

// MARK: - Cycle Tracker Quick Action Button

private struct CycleTrackerQuickActionButton: View {
    let action: () -> Void
    @State private var pulseAnimation = false
    @State private var moonRotation: Double = 0
    @State private var glowBreath: Bool = false

    private let accent: Color = AppColors.accentPurple

    var body: some View {
        Button(action: action) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [accent, Color(hex: "7C3AED")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                    )

                // Animated rings
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseAnimation ? 1.3 : 0.9)
                    .opacity(pulseAnimation ? 0.0 : 0.5)
                    .offset(x: 20, y: 10)

                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    .frame(width: 50, height: 50)
                    .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                    .opacity(pulseAnimation ? 0.0 : 0.4)
                    .offset(x: 20, y: 10)

                // Content Overlay
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 32, height: 32)
                                .shadow(color: Color.white.opacity(glowBreath ? 0.3 : 0.0), radius: glowBreath ? 8 : 0)
                            Image(systemName: "drop.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Spacer()

                        // Moon phases rotating
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .rotationEffect(.degrees(moonRotation))
                    }

                    Spacer()

                    Text("Cycle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    Text("Tracker")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(12)
            }
            .frame(height: 88)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                moonRotation = 360
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(0.5)) {
                glowBreath = true
            }
        }
    }
}

private struct MedicationQuickActionButton: View {
    let takenCount: Int
    let totalCount: Int
    let action: () -> Void

    // Start at 0%
    @State private var visualProgress: Double = 0.0
    @State private var pillWobble: Bool = false
    @State private var iconGlow: Bool = false

    private var targetProgress: Double {
        guard totalCount > 0 else { return 0 }
        return min(1.0, Double(takenCount) / Double(totalCount))
    }

    private let accent: Color = AppColors.medication
    private let textColor: Color = .white
    private let secondaryTextOpacity: Double = 0.9
    private let tertiaryTextOpacity: Double = 0.75
    private let iconCircleFill: Color = Color.white.opacity(0.18)
    private let liquidOpacity: Double = 0.14
    private let bubblesColor: Color = Color.white.opacity(0.22)
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background & "Potion" Animation
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(accent)
                            .overlay(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.22), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                            )
                        
                        if visualProgress > 0.01 {
                            ZStack {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(liquidOpacity + 0.04),
                                                Color.white.opacity(liquidOpacity)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(height: max(geo.size.height * visualProgress, geo.size.height * 0.05))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                
                                RisingBubblesEffect(color: bubblesColor)
                                    .frame(height: max(geo.size.height * visualProgress, geo.size.height * 0.05))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                    .mask(
                                        RoundedRectangle(cornerRadius: 24)
                                            .frame(height: max(geo.size.height * visualProgress, geo.size.height * 0.05))
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                    )
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                        }
                    }
                }
                
                // Content Overlay
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        ZStack {
                            Circle()
                                .fill(iconCircleFill)
                                .frame(width: 32, height: 32)
                                .shadow(color: Color.white.opacity(iconGlow ? 0.25 : 0), radius: iconGlow ? 8 : 0)
                            Image(systemName: "pills.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(textColor)
                                .rotationEffect(.degrees(pillWobble ? 10 : -10))
                        }

                        Spacer()

                        Text("\(Int(visualProgress * 100))%")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(textColor)
                            .contentTransition(.numericText(value: visualProgress))
                    }

                    Spacer()

                    Text("Medications")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(textColor.opacity(secondaryTextOpacity))

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(takenCount)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(textColor)
                            .contentTransition(.numericText())
                        Text("/ \(totalCount) taken")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(textColor.opacity(tertiaryTextOpacity))
                    }
                }
                .padding(12)
            }
            .frame(height: 88)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // Animate from 0 to target on load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    visualProgress = targetProgress
                }
            }
            // Pill wobble
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pillWobble = true
            }
            // Icon glow
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(0.3)) {
                iconGlow = true
            }
        }
        .onChange(of: targetProgress) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                visualProgress = newValue
            }
        }
    }
}

private struct DateButton: View {
    let date: Date
    let isSelected: Bool
    let dayName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(dayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .secondary)
                
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 50, height: 60)
            .background(
                isSelected
                    ? AppColors.accentBlue
                    : Color.clear
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

private struct MetricRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Analysis Result View

private struct AnalysisResultView: View {
    let state: AnalysisState
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if state.isAnalyzing {
                            analyzingView
                        } else if let result = state.result {
                            analysisContent(result)
                        } else if case .error(let message) = state {
                            errorView(message)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("AI Health Analysis")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var analyzingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Swastrica is analyzing your health data...")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("This may take a few moments")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func analysisContent(_ result: HealthAnalysisResult) -> some View {
        VStack(spacing: 20) {
            // Sparkle Icon
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.accentBlue, Color(hex: "4A90E2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top)
            
            // Assessment Section
            VStack(alignment: .leading, spacing: 12) {
                Label("Overall Assessment", systemImage: "heart.text.square.fill")
                    .font(.headline)
                    .foregroundColor(AppColors.accentBlue)
                
                Text(result.analysis.assessment)
                    .font(.body)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glass(cornerRadius: 16)
            
            // Insights Section
            VStack(alignment: .leading, spacing: 12) {
                Label("Key Insights", systemImage: "lightbulb.fill")
                    .font(.headline)
                    .foregroundColor(AppColors.accentBlue)
                
                Text(result.analysis.insights)
                    .font(.body)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glass(cornerRadius: 16)
            
            // Recommendations Section
            VStack(alignment: .leading, spacing: 12) {
                Label("Recommendations", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundColor(AppColors.accentBlue)
                
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(result.analysis.recommendations.enumerated()), id: \.offset) { index, rec in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1).")
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentBlue)
                            Text(rec)
                                .font(.body)
                                .lineSpacing(4)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glass(cornerRadius: 16)
            
            // Timestamp
            Text("Analysis generated on \(result.timestamp.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Analysis Error")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.accentBlue)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Water Wave Shape

struct RisingBubblesEffect: View {
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<12) { i in
                    Bubble(
                        delay: Double(i) * 0.5,
                        size: CGFloat.random(in: 4...10),
                        xRange: 0...geo.size.width,
                        color: color
                    )
                }
            }
        }
    }
    
    struct Bubble: View {
        let delay: Double
        let size: CGFloat
        let xRange: ClosedRange<CGFloat>
        let color: Color
        
        @State private var offset: CGFloat = 200
        @State private var xOffset: CGFloat = 0
        @State private var opacity: Double = 0
        
        var body: some View {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .offset(x: xOffset, y: offset)
                .opacity(opacity)
                .onAppear {
                    // Randomize x position for each loop
                    xOffset = CGFloat.random(in: xRange)
                    
                    withAnimation(
                        .linear(duration: 4.0)
                        .repeatForever(autoreverses: false)
                        .delay(delay)
                    ) {
                        offset = -200 // Move up
                        opacity = 1 // Fade in/out logic handled by modifier?
                        // Simple opacity fade:
                    }
                    
                    // Separate animation for opacity to fade in and out
                    withAnimation(
                        .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true)
                        .delay(delay)
                    ) {
                       // opacity = 0.8
                    }
                }
        }
    }
}

// MARK: - Bottom Rounded Rectangle Shape

struct BottomRoundedRectangle: Shape {
    var cornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(cornerRadius, rect.height / 2, rect.width / 2)
        
        // Start from top-left (sharp corner)
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Line to top-right (sharp corner)
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        
        // Line to top of bottom-right rounded corner
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - radius))
        
        // Bottom-right rounded corner
        path.addArc(
            center: CGPoint(x: rect.width - radius, y: rect.height - radius),
            radius: radius,
            startAngle: .zero,
            endAngle: .degrees(90),
            clockwise: false
        )
        
        // Line to top of bottom-left rounded corner
        path.addLine(to: CGPoint(x: radius, y: rect.height))
        
        // Bottom-left rounded corner
        path.addArc(
            center: CGPoint(x: radius, y: rect.height - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        
        // Close path back to start
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Health Live Activity Toggle

private struct HealthLiveActivityToggle: View {
    let userName: String
    let steps: Int
    let heartRate: Int
    let calories: Int

    @ObservedObject private var manager = HealthLiveActivityManager.shared

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task {
                if manager.isActive {
                    await manager.endHealthTracking()
                } else {
                    await manager.startHealthTracking(userName: userName)
                    await manager.update(
                        steps: steps,
                        heartRate: heartRate,
                        calories: calories,
                        hydrationMl: 0,
                        hydrationGoalMl: 2500,
                        stepGoal: 10000
                    )
                }
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(manager.isActive ? Color.green.opacity(0.15) : Color(hex: "2E3192").opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: manager.isActive ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(manager.isActive ? .green : Color(hex: "2E3192"))
                        .symbolEffect(.bounce, value: manager.isActive)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Dynamic Island")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(manager.isActive ? "Health tracking live on your island" : "Show health stats on Dynamic Island")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(manager.isActive ? "ON" : "OFF")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(manager.isActive ? .green : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(manager.isActive ? Color.green.opacity(0.12) : Color.secondary.opacity(0.08))
                    )
            }
            .padding(14)
            .glass(cornerRadius: 16)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!manager.canStartActivities)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
