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
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Living Status Header
                    LivingStatusHeader(
                        userName: userName,
                        userPhotoURL: authViewModel.userPhotoURL,
                        status: healthStatus,
                        greeting: timeBasedGreeting,
                        showReminders: $showReminders
                    )
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: hasAppeared)
                    
                    // Health Authorization Banner
                    if !viewModel.isAuthorized && !viewModel.hasRequestedAuth {
                        authorizationBanner
                    }
                    
                    // Human Body Image with Daily Activity Details
                    humanBodyImageWithDetails
                        .padding(.top, 0)
                    
                    // Health Vitals Grid
                    healthVitalsSection
                        .padding(.top, 8)
                    
                    // Quick Actions
                    quickActionsSection
                        .padding(.top, 8)
                        .modifier(ScrollAnimationModifier(isVisible: $quickActionsVisible))
                    
                }
                .padding(.top)
                .padding(.bottom, 20)
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
        .onAppear {
            AppAnalyticsService.shared.logScreen("Home")
            // Haptic feedback when opening vitals screen
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()

            // Trigger entrance animations with staggered delays for cards
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
            ZStack(alignment: .leading) {
                
              
                // Human Body 3D Model on the right
                HStack {
                    Spacer()
                    ModelViewer(modelName: "anatomy", allowsInteraction: false)
                        .frame(height: 340) // Reduced height
                        .opacity(modelOpacity)
                        .scaleEffect(modelScale)
                        .offset(x: geometry.size.width * 0.16)
                        .offset(y: geometry.size.height * 0.0) // Moved upward
                        .allowsHitTesting(false) // Disable all touch interactions
                        .clipped()
                        .mask(
                            // Gradient mask for bottom blend
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .black,
                                    .black.opacity(0.8),
                                    .black.opacity(0.4),
                                    .clear
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.8)),
                            removal: .opacity
                        ))
                }
                
                // Daily Activity Details on the left (without card)
                VStack(alignment: .leading, spacing: 12) {
                    
                    // Stats List - Vertical
                    VStack(alignment: .leading, spacing: 10) { // Tighter spacing for cards
                        DailyActivityStatItem(
                            icon: "flame.fill",
                            color: .orange,
                            value: "\(viewModel.activeCalories)",
                            unit: "Active Calories",
                            animationDelay: 0.3,
                            hasAppeared: hasAppeared
                        )
                        
                        DailyActivityStatItem(
                            icon: "figure.walk",
                            color: .green,
                            value: "\(viewModel.stepCount)",
                            unit: "Step Count",
                            animationDelay: 0.4,
                            hasAppeared: hasAppeared
                        )
                        
                        DailyActivityStatItem(
                            icon: "clock.fill",
                            color: .blue,
                            value: "\(viewModel.exerciseMinutes)",
                            unit: "Exercise Min",
                            animationDelay: 0.5,
                            hasAppeared: hasAppeared
                        )
                        
                        DailyActivityStatItem(
                            icon: "figure.stand",
                            color: .purple,
                            value: "\(viewModel.standHours)",
                            unit: "Stand Hours",
                            animationDelay: 0.6,
                            hasAppeared: hasAppeared
                        )
                    }
                }
                .padding(.horizontal, 20)
                // .padding(.top, -10) // Move metrics upward
                .frame(maxWidth: geometry.size.width * 0.55, alignment: .leading) // Give slightly more space to stats
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: hasAppeared)
            }
        }
        .frame(height: 320) // Reduced height to match model
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
    
    private var dailyActivityCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Daily Activity")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Sync button
                Button(action: {
                    Task {
                        await viewModel.syncToCloud()
                        syncMessage = "Health data synced successfully!"
                        showSyncAlert = true
                    }
                }) {
                    HStack(spacing: 4) {
                        if viewModel.isSyncing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(viewModel.formatSyncTime())
                            .font(.caption2)
                    }
                    .foregroundColor(.primary.opacity(0.8))
                }
                .disabled(viewModel.isSyncing)
            }
            
            HStack(alignment: .top, spacing: 20) {
                // Progress Ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 8)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: viewModel.stepProgress)
                        .stroke(
                            LinearGradient(colors: [.green, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: viewModel.stepProgress)
                    
                    VStack(spacing: 2) {
                        Text("\(Int(viewModel.stepProgress * 100))%")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Goal")
                            .font(.caption2)
                            .opacity(0.8)
                    }
                    .foregroundColor(.primary)
                }
                
                // Stats
                VStack(alignment: .leading, spacing: 8) {
                    StatRow(icon: "flame.fill", color: .orange, value: "\(viewModel.activeCalories)", unit: "kcal")
                    StatRow(icon: "figure.walk", color: .green, value: "\(viewModel.stepCount)", unit: "steps")
                    StatRow(icon: "clock.fill", color: .blue, value: "\(viewModel.exerciseMinutes)", unit: "mins")
                    StatRow(icon: "figure.stand", color: .purple, value: "\(viewModel.standHours)", unit: "/ 12 hrs")
                }
                .foregroundColor(.white)
            }
        }
        .padding(20)
        .background(PremiumColor.royalBlue.opacity(0.9))
        .cornerRadius(24)
        .shadow(color: AppColors.accentBlue.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(.horizontal)
    }
    
    private var healthVitalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // Heart Rate card - tappable to measure
                Button(action: {
                    showHeartRateMeasurement = true
                }) {
                    VitalCard(
                        icon: "heart.fill",
                        title: "Heart Rate",
                        value: "\(viewModel.heartRate)",
                        unit: "BPM",
                        color: .red,
                        animationDelay: 0.8,
                        hasAppeared: hasAppeared,
                        showCameraBadge: true
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                VitalCard(
                    icon: "bed.double.fill",
                    title: "Sleep",
                    value: viewModel.sleepHours,
                    unit: "",
                    color: .indigo,
                    animationDelay: 0.9,
                    hasAppeared: hasAppeared
                )
                
                VitalCard(
                    icon: "figure.walk",
                    title: "Distance",
                    value: String(format: "%.1f", viewModel.distance),
                    unit: "km",
                    color: .green,
                    animationDelay: 1.0,
                    hasAppeared: hasAppeared
                )
            }
            .padding(.horizontal)
        }
    }
    
    @State private var showMedications = false
    @State private var showHydration = false
    @State private var showMenstrualCycle = false


    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // First Row
            HStack(spacing: 12) {
                MedicationQuickActionButton(
                    takenCount: medicationViewModel.takenCount,
                    totalCount: medicationViewModel.totalCount
                ) {
                    showMedications = true
                }
                .opacity(quickActionsVisible ? 1 : 0)
                .scaleEffect(quickActionsVisible ? 1 : 0.8)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: quickActionsVisible)
                
                HydrationQuickActionButton(
                    currentIntake: hydrationViewModel.effectiveIntake,
                    dailyGoal: hydrationViewModel.dailyGoal
                ) {
                    showHydration = true
                }
                .opacity(quickActionsVisible ? 1 : 0)
                .scaleEffect(quickActionsVisible ? 1 : 0.8)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: quickActionsVisible)
            }
            .padding(.horizontal)
            
            // Second Row
            HStack(spacing: 12) {
                DietQuickActionButton(
                    currentCalories: dietViewModel.totalCalories,
                    dailyGoal: dietViewModel.dietGoals.dailyCalories
                ) {
                    showDiet = true
                }
                .opacity(quickActionsVisible ? 1 : 0)
                .scaleEffect(quickActionsVisible ? 1 : 0.8)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: quickActionsVisible)
                
                CycleTrackerQuickActionButton {
                    showMenstrualCycle = true
                }
                .opacity(quickActionsVisible ? 1 : 0)
                .scaleEffect(quickActionsVisible ? 1 : 0.8)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4), value: quickActionsVisible)
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
        @Binding var showReminders: Bool
        
        @State private var isPulsing = false
        
        var body: some View {
            HStack(alignment: .top) {
                // Left: Text Info
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
                        ZStack {
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
                        .onAppear {
                            isPulsing = true
                        }
                    }
                }
                
                Spacer()
                
                // Right: Actions
                HStack(spacing: 16) {
                    // Notification Bell
                    Button(action: {
                        showReminders = true
                    }) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                    }
                    
                    // Track Button
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

    private struct DailyActivityStatItem: View {
        let icon: String
        let color: Color
        let value: String
        let unit: String
        let animationDelay: Double
        let hasAppeared: Bool
        
        var body: some View {
            HStack(spacing: 12) {
                // Icon with background
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 35, height: 35)
                    
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(color)
                }
                
                // Value and unit
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.system(size: 24, weight: .bold)) // Larger & Bold
                        .foregroundColor(.primary)
                    
                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            // .background(
            //     RoundedRectangle(cornerRadius: 16)
            //         .fill(Color.white.opacity(0.05)) // Subtle glass effect
            // )
            // .overlay(
            //     RoundedRectangle(cornerRadius: 16)
            //         .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            // )
            .opacity(hasAppeared ? 1 : 0)
            .offset(x: hasAppeared ? 0 : -20)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(animationDelay), value: hasAppeared)
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

private struct VitalCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color
    let animationDelay: Double
    let hasAppeared: Bool
    var showCameraBadge: Bool = false
    
    @State private var cardAppeared = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.gray.opacity(0.05) : Color.gray.opacity(0.05)
    }
    
    private var cardBorderColor: Color {
        colorScheme == .dark ? Color.gray.opacity(0.1) : Color.gray.opacity(0.1)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Icon and Camera Badge
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                }
                .scaleEffect(cardAppeared ? 1 : 0)
                .rotationEffect(.degrees(cardAppeared ? 0 : -180))
                
                Spacer()
                
                if showCameraBadge {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(cardBackgroundColor)
                        .clipShape(Circle())
                        .opacity(cardAppeared ? 1 : 0)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .opacity(cardAppeared ? 1 : 0)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.primary)
                        .opacity(cardAppeared ? 1 : 0)
                        .offset(x: cardAppeared ? 0 : -10)
                    
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .opacity(cardAppeared ? 1 : 0)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .opacity(cardAppeared ? 1 : 0)
        .scaleEffect(cardAppeared ? 1 : 0.9)
        .offset(y: cardAppeared ? 0 : 20)
        .onChange(of: hasAppeared) { oldValue, newValue in
            if newValue && !cardAppeared {
                DispatchQueue.main.asyncAfter(deadline: .now() + animationDelay) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        cardAppeared = true
                    }
                }
            }
        }
        .onAppear {
            if hasAppeared && !cardAppeared {
                DispatchQueue.main.asyncAfter(deadline: .now() + animationDelay) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        cardAppeared = true
                    }
                }
            }
        }
    }
}

private struct HydrationQuickActionButton: View {
    let currentIntake: Int
    let dailyGoal: Int
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Start at 1.0 (100%)
    @State private var visualProgress: Double = 1.0
    @State private var wavePhase: Double = 0.0
    
    private var targetProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1.0, Double(currentIntake) / Double(dailyGoal))
    }
    
    private var isLight: Bool { colorScheme == .light }
    private var textColor: Color { isLight ? .primary : .white }
    private var secondaryTextOpacity: Double { isLight ? 0.75 : 0.9 }
    private var tertiaryTextOpacity: Double { isLight ? 0.6 : 0.7 }
    private var iconCircleFill: Color { isLight ? Color.primary.opacity(0.12) : Color.white.opacity(0.2) }
    private var waveBackOpacity: Double { isLight ? 0.2 : 0.3 }
    private var waveFrontOpacities: (Double, Double) { isLight ? (0.35, 0.35) : (0.6, 0.6) }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background & Water Animation
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        // Base background
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.blue.opacity(isLight ? 0.08 : 0.05))
                        
                        // Water Waves — same geometry as Medication card (RoundedRectangle, bottom-aligned fill)
                        if visualProgress > 0.01 {
                            let waveHeight = max(geo.size.height * visualProgress, geo.size.height * 0.05)
                            let amp = min(geo.size.height * 0.04, waveHeight * 0.45)
                            let ampFront = min(geo.size.height * 0.03, waveHeight * 0.35)
                            ZStack {
                                WaterWave(amplitude: amp, offset: wavePhase)
                                    .fill(Color.cyan.opacity(waveBackOpacity))
                                    .frame(height: waveHeight)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                
                                WaterWave(amplitude: ampFront, offset: wavePhase + 1.5)
                                    .fill(LinearGradient(
                                        colors: [.cyan.opacity(waveFrontOpacities.0), .blue.opacity(waveFrontOpacities.1)],
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
                                .frame(width: 44, height: 44)
                            Image(systemName: "drop.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(textColor)
                        }
                        
                        Spacer()
                        
                        Text("\(Int(visualProgress * 100))%")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(textColor)
                            .shadow(color: (isLight ? Color.clear : Color.black).opacity(0.1), radius: 2, x: 0, y: 1)
                            .contentTransition(.numericText(value: visualProgress))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hydration")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(textColor.opacity(secondaryTextOpacity))
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(currentIntake)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(textColor)
                            Text("/ \(dailyGoal) ml")
                                .font(.footnote)
                                .fontWeight(.medium)
                                .foregroundColor(textColor.opacity(tertiaryTextOpacity))
                        }
                    }
                }
                .padding(20)
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: Color.blue.opacity(isLight ? 0.12 : 0.15), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // 1. Start continuous wave animation
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
            
            // 2. Animate from 100% down to actual value on load
            // Using frame animation is robust and won't fade
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 2.0)) {
                    visualProgress = targetProgress
                }
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
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var pulseAnimation = false
    
    private var isLight: Bool { colorScheme == .light }
    private var textColor: Color { isLight ? .primary : .white }
    private var secondaryTextOpacity: Double { isLight ? 0.75 : 0.9 }
    private var tertiaryTextOpacity: Double { isLight ? 0.6 : 0.7 }
    private var iconCircleFill: Color { isLight ? Color.primary.opacity(0.12) : Color.white.opacity(0.2) }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        // Base background with gradient
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.pink.opacity(isLight ? 0.08 : 0.05),
                                        Color.red.opacity(isLight ? 0.12 : 0.08)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        // Subtle pulsing circle effect
                        Circle()
                            .fill(Color.pink.opacity(0.15))
                            .frame(width: 100, height: 100)
                            .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                            .opacity(pulseAnimation ? 0.3 : 0.6)
                            .offset(x: 30, y: 20)
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseAnimation)
                    }
                }
                
                // Content Overlay
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        ZStack {
                            Circle()
                                .fill(iconCircleFill)
                                .frame(width: 44, height: 44)
                            Image(systemName: "drop.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.pink)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(textColor.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cycle")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(textColor)
                        
                        Text("Tracker")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(textColor.opacity(secondaryTextOpacity))
                    }
                }
                .padding(20)
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.pink.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: Color.pink.opacity(isLight ? 0.12 : 0.15), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            pulseAnimation = true
        }
    }
}

private struct MedicationQuickActionButton: View {
    let takenCount: Int
    let totalCount: Int
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Start at 0%
    @State private var visualProgress: Double = 0.0
    
    private var targetProgress: Double {
        guard totalCount > 0 else { return 0 }
        return min(1.0, Double(takenCount) / Double(totalCount))
    }
    
    private var isLight: Bool { colorScheme == .light }
    private var textColor: Color { isLight ? .primary : .white }
    private var secondaryTextOpacity: Double { isLight ? 0.75 : 0.9 }
    private var tertiaryTextOpacity: Double { isLight ? 0.6 : 0.7 }
    private var iconCircleFill: Color { isLight ? Color.primary.opacity(0.12) : Color.white.opacity(0.2) }
    private var liquidOpacity: Double { isLight ? 0.35 : 0.6 }
    private var bubblesColor: Color { isLight ? Color.primary.opacity(0.2) : Color.white.opacity(0.3) }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background & "Potion" Animation
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(hex: "5856D6").opacity(isLight ? 0.08 : 0.05))
                        
                        if visualProgress > 0.01 {
                            ZStack {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "AF52DE").opacity(liquidOpacity),
                                                Color(hex: "5856D6").opacity(liquidOpacity)
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
                                .frame(width: 44, height: 44)
                            Image(systemName: "pills.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(textColor)
                        }
                        
                        Spacer()
                        
                        Text("\(Int(visualProgress * 100))%")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(textColor)
                            .shadow(color: (isLight ? Color.clear : Color.black).opacity(0.1), radius: 2, x: 0, y: 1)
                            .contentTransition(.numericText(value: visualProgress))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Medications")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(textColor.opacity(secondaryTextOpacity))
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(takenCount)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(textColor)
                            Text("/ \(totalCount) taken")
                                .font(.footnote)
                                .fontWeight(.medium)
                                .foregroundColor(textColor.opacity(tertiaryTextOpacity))
                        }
                    }
                }
                .padding(20)
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: Color(hex: "5856D6").opacity(isLight ? 0.12 : 0.15), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // Animate from 0 to target on load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    visualProgress = targetProgress
                }
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

struct WaterWave: Shape {
    var amplitude: CGFloat
    var offset: Double

    var animatableData: Double {
        get { offset }
        set { offset = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Wave oscillates around y = amplitude so it stays in [0, 2*amplitude], avoiding top cut-off.
        let cap = min(amplitude, height / 2)
        
        path.move(to: CGPoint(x: 0, y: cap * (1 + sin(offset))))
        
        for x in stride(from: 0, to: width, by: 2) {
            let relativeX = x / width
            let angle = relativeX * .pi * 2 + offset
            let y = cap * (1 + sin(angle))
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height + cap))
        path.addLine(to: CGPoint(x: 0, y: height + cap))
        path.closeSubpath()
        
        return path
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

#Preview {
    NavigationStack {
        HomeView()
    }
}
