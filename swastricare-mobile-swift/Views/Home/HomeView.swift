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
    
    // MARK: - Local State
    
    @State private var showSyncAlert = false
    @State private var syncMessage: String?
    @State private var hasAppeared = false
    @State private var modelOpacity: Double = 0
    @State private var modelScale: CGFloat = 0.8
    @State private var quickActionsVisible = false
    @State private var trackerVisible = false
    @State private var showHeartRateMeasurement = false
    
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
                        greeting: timeBasedGreeting
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
                    
                    // Tracker Section
                    trackerSection
                        .padding(.top, 16)
                        .modifier(ScrollAnimationModifier(isVisible: $trackerVisible))
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
        .onAppear {
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
                modelScale = 1.40 // Zoomed in (was 1.0)
            }
        }
        .task {
            await viewModel.loadTodaysData()
            await trackerViewModel.loadData()
            await hydrationViewModel.loadData()
            await medicationViewModel.loadMedications()
        }
        .refreshable {
            await viewModel.refresh()
            await trackerViewModel.refresh()
            await hydrationViewModel.refresh()
            await medicationViewModel.refresh()
        }
        }
    }
    
    // MARK: - Helper Methods
    
    // MARK: - Subviews
    
    private var humanBodyImageWithDetails: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                
                // 3. Ambient Glow behind the model
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "2E3192").opacity(0.3), // Brand Blue Glow
                        Color.clear
                    ]),
                    center: .trailing, // Center glow on the right side
                    startRadius: 50,
                    endRadius: 250
                )
                .offset(x: 50, y: 0) // Shift slightly right
                .opacity(hasAppeared ? 1 : 0)
                .animation(.easeIn(duration: 1.0), value: hasAppeared)

                // Human Body 3D Model on the right
                HStack {
                    Spacer()
                    ModelViewer(modelName: "anatomy", allowsInteraction: false)
                        .frame(height: 380) // Slightly taller
                        .opacity(modelOpacity)
                        .scaleEffect(modelScale)
                        .offset(x: geometry.size.width * 0.16)
                        .offset(y: geometry.size.height * 0.15) // Adjusted vertical offset
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
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Stats List - Vertical
                    VStack(alignment: .leading, spacing: 12) { // Tighter spacing for cards
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
                .frame(maxWidth: geometry.size.width * 0.55, alignment: .leading) // Give slightly more space to stats
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: hasAppeared)
            }
        }
        .frame(height: 380) // Match model height
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
        .shadow(color: Color(hex: "2E3192").opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(.horizontal)
    }
    
    private var healthVitalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Vitals")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : -10)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.7), value: hasAppeared)
            
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

    private var trackerSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Date Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(trackerViewModel.weekDates, id: \.self) { date in
                        DateButton(
                            date: date,
                            isSelected: trackerViewModel.isSelected(date),
                            dayName: trackerViewModel.dayName(for: date)
                        ) {
                            Task {
                                await trackerViewModel.selectDate(date)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .opacity(trackerVisible ? 1 : 0)
            .offset(y: trackerVisible ? 0 : 20)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: trackerVisible)
            
            // Weekly Chart
            VStack(alignment: .leading, spacing: 12) {
                Text("Weekly Steps")
                    .font(.headline)
                
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(trackerViewModel.weeklySteps) { metric in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    Calendar.current.isDate(metric.date, inSameDayAs: trackerViewModel.selectedDate)
                                        ? Color(hex: "2E3192")
                                        : Color.gray.opacity(0.3)
                                )
                                .frame(
                                    width: 30,
                                    height: CGFloat(metric.steps) / CGFloat(max(trackerViewModel.maxWeeklySteps, 1)) * 120
                                )
                                .animation(.easeInOut, value: metric.steps)
                            
                            Text(metric.dayName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150, alignment: .bottom)
            }
            .padding()
            .glass(cornerRadius: 16)
            .padding(.horizontal)
            .opacity(trackerVisible ? 1 : 0)
            .scaleEffect(trackerVisible ? 1 : 0.9)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: trackerVisible)
            
            // Detailed Metrics
            VStack(alignment: .leading, spacing: 15) {
                Text("Detailed Metrics")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.horizontal)
                    .opacity(trackerVisible ? 1 : 0)
                    .offset(y: trackerVisible ? 0 : -10)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: trackerVisible)
                
                VStack(spacing: 12) {
                    MetricRow(icon: "figure.walk", title: "Steps", value: "\(trackerViewModel.stepCount)", color: .green)
                        .opacity(trackerVisible ? 1 : 0)
                        .offset(x: trackerVisible ? 0 : -20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: trackerVisible)
                    
                    // Heart Rate row with measure button
                    HStack {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .frame(width: 30)
                            
                            Text("Heart Rate")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(trackerViewModel.heartRate) BPM")
                                .fontWeight(.semibold)
                        }
                        
                        Button(action: {
                            showHeartRateMeasurement = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                    .font(.caption)
                                Text("Measure")
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 4)
                    .opacity(trackerVisible ? 1 : 0)
                    .offset(x: trackerVisible ? 0 : -20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4), value: trackerVisible)
                    
                    MetricRow(icon: "flame.fill", title: "Active Calories", value: "\(trackerViewModel.activeCalories) kcal", color: .orange)
                        .opacity(trackerVisible ? 1 : 0)
                        .offset(x: trackerVisible ? 0 : -20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5), value: trackerVisible)
                    
                    MetricRow(icon: "clock.fill", title: "Exercise", value: "\(trackerViewModel.exerciseMinutes) mins", color: .blue)
                        .opacity(trackerVisible ? 1 : 0)
                        .offset(x: trackerVisible ? 0 : -20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.6), value: trackerVisible)
                    
                    MetricRow(icon: "figure.stand", title: "Stand Hours", value: "\(trackerViewModel.standHours) hrs", color: .purple)
                        .opacity(trackerVisible ? 1 : 0)
                        .offset(x: trackerVisible ? 0 : -20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.7), value: trackerVisible)
                    
                    MetricRow(icon: "moon.fill", title: "Sleep", value: trackerViewModel.sleepHours, color: .indigo)
                        .opacity(trackerVisible ? 1 : 0)
                        .offset(x: trackerVisible ? 0 : -20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.8), value: trackerVisible)
                    
                    MetricRow(icon: "arrow.left.and.right", title: "Distance", value: String(format: "%.2f km", trackerViewModel.distance), color: .cyan)
                        .opacity(trackerVisible ? 1 : 0)
                        .offset(x: trackerVisible ? 0 : -20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.9), value: trackerVisible)
                }
                .padding()
                .glass(cornerRadius: 16)
                .padding(.horizontal)
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
                .opacity(quickActionsVisible ? 1 : 0)
                .offset(y: quickActionsVisible ? 0 : -10)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: quickActionsVisible)
            
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
        }
        .sheet(isPresented: $showMedications) {
            MedicationsView()
        }
        .sheet(isPresented: $showHydration) {
            HydrationView()
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
                    Button(action: {}) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    
                    // Profile Image
                    Button(action: {}) {
                        Group {
                            if let imageURL = userPhotoURL {
                                AsyncImage(url: imageURL) { image in
                                    image.resizable()
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                }
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
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
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
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
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05)) // Subtle glass effect
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
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
                        .background(Color.white.opacity(0.1))
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

private struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glass(cornerRadius: 12)
        }
    }
}

private struct HydrationQuickActionButton: View {
    let currentIntake: Int
    let dailyGoal: Int
    let action: () -> Void
    
    private var progress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1.0, Double(currentIntake) / Double(dailyGoal))
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "drop.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.cyan)
                    }
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hydration")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 2) {
                        Text("\(currentIntake)")
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text("/ \(dailyGoal) ml")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
                
                // Enhanced Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.cyan, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 6)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: progress)
                    }
                }
                .frame(height: 6)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct MedicationQuickActionButton: View {
    let takenCount: Int
    let totalCount: Int
    let action: () -> Void
    
    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return min(1.0, Double(takenCount) / Double(totalCount))
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "pills.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Medications")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 2) {
                        Text("\(takenCount)")
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text("/ \(totalCount) taken")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
                
                // Enhanced Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .indigo],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 6)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: progress)
                    }
                }
                .frame(height: 6)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
                    ? Color(hex: "2E3192")
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
                        colors: [Color(hex: "2E3192"), Color(hex: "4A90E2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top)
            
            // Assessment Section
            VStack(alignment: .leading, spacing: 12) {
                Label("Overall Assessment", systemImage: "heart.text.square.fill")
                    .font(.headline)
                    .foregroundColor(Color(hex: "2E3192"))
                
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
                    .foregroundColor(Color(hex: "2E3192"))
                
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
                    .foregroundColor(Color(hex: "2E3192"))
                
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(result.analysis.recommendations.enumerated()), id: \.offset) { index, rec in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1).")
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: "2E3192"))
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
            .tint(Color(hex: "2E3192"))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
