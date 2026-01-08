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
    
    // MARK: - Local State
    
    @State private var showSyncAlert = false
    @State private var syncMessage: String?
    @State private var hasAppeared = false
    @State private var modelOpacity: Double = 0
    @State private var modelScale: CGFloat = 0.8
    @State private var currentQuoteIndex = 0
    @State private var quoteOpacity: Double = 1
    @State private var quickActionsVisible = false
    @State private var trackerVisible = false
    
    private let vitalQuotes = [
        "Track your vital signs and understand your body better",
        "Monitor essential body signals that matter every day",
        "Your vital health data clearly measured and monitored",
        "Stay aware of your vital signs with real-time health tracking",
        "Essential vitals, simplified for everyday health awareness",
        "Know what your body is telling you through your vital signs",
        "Daily vital measurements for smarter health decisions",
        "Keep track of your body's vitals and stay informed",
        "Vital signs that reflect your health updated throughout the day",
        "Understand your body better by monitoring your vitals"
    ]
    
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
    
    // MARK: - Body
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Custom Header with Subheading
                VStack(alignment: .leading, spacing: 4) {
                    Text("Body Vitals")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.primary)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : -10)
                    
                    // Animated rotating quotes - Fixed height for 2 lines
                    Text(vitalQuotes[currentQuoteIndex])
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .opacity(quoteOpacity)
                        .offset(y: hasAppeared ? 0 : -10)
                        .animation(.easeInOut(duration: 0.3), value: quoteOpacity)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: hasAppeared)
                        .lineLimit(2)
                        .lineSpacing(4)
                        .frame(height: 44, alignment: .topLeading) // Fixed height for 2 lines
                        .fixedSize(horizontal: false, vertical: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: hasAppeared)
                
                // Health Authorization Banner
                if !viewModel.isAuthorized && !viewModel.hasRequestedAuth {
                    authorizationBanner
                }
                
                // Human Body Image with Daily Activity Details
                humanBodyImageWithDetails
                    .padding(.top, 8)
                
                // Health Vitals Grid
                healthVitalsSection
                
                // Quick Actions
                quickActionsSection
                    .modifier(ScrollAnimationModifier(isVisible: $quickActionsVisible))
                
                // Tracker Section
                trackerSection
                    .modifier(ScrollAnimationModifier(isVisible: $trackerVisible))
            }
            .padding(.top)
            .padding(.bottom, 20)
        }
        .coordinateSpace(name: "scroll")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                // Empty to hide default title
                Text("")
            }
            ToolbarItem(placement: .topBarTrailing) {
                profileButton
            }
        }
        .alert("Sync Status", isPresented: $showSyncAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(syncMessage ?? "")
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
            // Start quote rotation
            startQuoteRotation()
        }
        .task {
            await viewModel.loadTodaysData()
            await trackerViewModel.loadData()
        }
        .refreshable {
            await viewModel.refresh()
            await trackerViewModel.refresh()
        }
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Helper Methods
    
    private func startQuoteRotation() {
        // Wait for initial appearance animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            rotateQuotes()
        }
    }
    
    private func rotateQuotes() {
        // Fade out
        withAnimation(.easeInOut(duration: 0.5)) {
            quoteOpacity = 0
        }
        
        // Change quote after fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            currentQuoteIndex = (currentQuoteIndex + 1) % vitalQuotes.count
            // Fade in
            withAnimation(.easeInOut(duration: 0.5)) {
                quoteOpacity = 1
            }
            
            // Schedule next rotation after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                rotateQuotes()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var humanBodyImageWithDetails: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Human Body 3D Model on the right
                HStack {
                    Spacer()
                    ModelViewer(modelName: "anatomy", allowsInteraction: false)
                        .frame(height: 350)
                        .opacity(modelOpacity)
                        .scaleEffect(modelScale)
                        .offset(x: geometry.size.width * 0.16)
                        .offset(y: geometry.size.height * 0.20)
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
                    // Title Section
                    Text("Daily Activity")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(x: hasAppeared ? 0 : -20)
                    
                    // Stats List - Vertical
                    VStack(alignment: .leading, spacing: 14) {
                        DailyActivityStatItem(
                            icon: "flame.fill",
                            color: .orange,
                            value: "\(viewModel.activeCalories)",
                            unit: "kcal",
                            animationDelay: 0.3,
                            hasAppeared: hasAppeared
                        )
                        
                        DailyActivityStatItem(
                            icon: "figure.walk",
                            color: .green,
                            value: "\(viewModel.stepCount)",
                            unit: "steps",
                            animationDelay: 0.4,
                            hasAppeared: hasAppeared
                        )
                        
                        DailyActivityStatItem(
                            icon: "clock.fill",
                            color: .blue,
                            value: "\(viewModel.exerciseMinutes)",
                            unit: "mins",
                            animationDelay: 0.5,
                            hasAppeared: hasAppeared
                        )
                        
                        DailyActivityStatItem(
                            icon: "figure.stand",
                            color: .purple,
                            value: "\(viewModel.standHours)",
                            unit: "/ 12 hrs",
                            animationDelay: 0.6,
                            hasAppeared: hasAppeared
                        )
                    }
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: geometry.size.width * 0.5, alignment: .leading) // Left half of screen
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: hasAppeared)
            }
        }
        .frame(height: 350)
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
        VStack(alignment: .leading, spacing: 15) {
            Text("Health Vitals")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : -10)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.7), value: hasAppeared)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                VitalCard(
                    icon: "heart.fill",
                    title: "Heart Rate",
                    value: "\(viewModel.heartRate)",
                    unit: "BPM",
                    color: .red,
                    animationDelay: 0.8,
                    hasAppeared: hasAppeared
                )
                
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
                
                VitalCard(
                    icon: "drop.fill",
                    title: "Blood Pressure",
                    value: viewModel.bloodPressure,
                    unit: "mmHg",
                    color: .orange,
                    animationDelay: 1.1,
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
                    
                    MetricRow(icon: "heart.fill", title: "Heart Rate", value: "\(trackerViewModel.heartRate) BPM", color: .red)
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
        VStack(alignment: .leading, spacing: 15) {
            Text("Quick Actions")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)
                .opacity(quickActionsVisible ? 1 : 0)
                .offset(y: quickActionsVisible ? 0 : -10)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: quickActionsVisible)
            
            HStack(spacing: 12) {
                QuickActionButton(icon: "waveform.path.ecg", title: "Log Vitals", color: .red) {
                    // Action
                }
                .opacity(quickActionsVisible ? 1 : 0)
                .scaleEffect(quickActionsVisible ? 1 : 0.8)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: quickActionsVisible)
                
                QuickActionButton(icon: "pills.fill", title: "Medications", color: .blue) {
                    showMedications = true
                }
                .opacity(quickActionsVisible ? 1 : 0)
                .scaleEffect(quickActionsVisible ? 1 : 0.8)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: quickActionsVisible)
                
                QuickActionButton(icon: "drop.fill", title: "Hydration", color: .cyan) {
                    showHydration = true
                }
                .opacity(quickActionsVisible ? 1 : 0)
                .scaleEffect(quickActionsVisible ? 1 : 0.8)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: quickActionsVisible)
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
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            
            // Value and unit
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(unit)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
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
    
    @State private var cardAppeared = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .scaleEffect(cardAppeared ? 1 : 0)
                    .rotationEffect(.degrees(cardAppeared ? 0 : -180))
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .opacity(cardAppeared ? 1 : 0)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .opacity(cardAppeared ? 1 : 0)
                    .offset(x: cardAppeared ? 0 : -10)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(cardAppeared ? 1 : 0)
                }
            }
        }
        .padding()
        .glass(cornerRadius: 16)
        .opacity(cardAppeared ? 1 : 0)
        .scaleEffect(cardAppeared ? 1 : 0.7)
        .offset(y: cardAppeared ? 0 : 30)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
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

