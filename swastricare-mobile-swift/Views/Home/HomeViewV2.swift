//
//  HomeViewV2.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//  Home Screen Version 2 - Health Overview UI
//

import SwiftUI
import UIKit

struct HomeViewV2: View {
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel = DependencyContainer.shared.homeViewModel
    @StateObject private var trackerViewModel = DependencyContainer.shared.trackerViewModel
    @StateObject private var authViewModel = DependencyContainer.shared.authViewModel
    @StateObject private var hydrationViewModel = DependencyContainer.shared.hydrationViewModel
    @StateObject private var medicationViewModel = DependencyContainer.shared.medicationViewModel
    @StateObject private var aiViewModel = DependencyContainer.shared.aiViewModel
    
    // MARK: - Local State
    
    @State private var hasAppeared = false
    @State private var selectedMood: MoodType? = nil
    @State private var showMoodOverlay = false
    @State private var moodAIGeneratedText: String? = nil
    @State private var isGeneratingMoodAI = false
    @State private var showMedications = false
    @State private var showHydration = false
    @State private var showReminders = false
    @State private var cardOffset: CGFloat = 0
    @State private var animationProgress: CGFloat = 0
    @State private var animationTimer: Timer?
    @State private var leftSuggestion: String? = nil
    @State private var rightSuggestion: String? = nil
    @State private var isGeneratingSuggestions = false
    @State private var leftCardRotation: Double = 0
    @State private var rightCardRotation: Double = 0
    @State private var leftCardScale: CGFloat = 0.8
    @State private var rightCardScale: CGFloat = 0.8
    @State private var leftCardOffsetX: CGFloat = -70
    @State private var leftCardOffsetY: CGFloat = 80
    @State private var rightCardOffsetX: CGFloat = 70
    @State private var rightCardOffsetY: CGFloat = -80
    @State private var suggestionTimer: Timer?
    
    // Heart animation state
    @State private var isHeartPressed = false
    @State private var heartBeatScale: CGFloat = 1.0 // Pulsing scale during heartbeat
    @State private var heartBaseScale: CGFloat = 1.0 // Base scale that grows with each step
    @State private var heartbeatTimer: Timer?
    @State private var heartbeatPhase: Int = 0 // 0: rest, 1: first beat, 2: second beat
    @State private var continuousHeartbeatScale: CGFloat = 1.0 // Continuous small heartbeat
    @State private var continuousHeartbeatTimer: Timer?
    @State private var fillOpacity: Double = 0.0 // Fill overlay opacity (0.2, 0.4, 0.6, 0.8)
    @State private var showFillOverlay = false
    
    // MARK: - Computed Properties
    
    // Sleep percentage calculation (70% = Good Sleep)
    private var sleepPercentage: Int {
        let sleepHours = parseSleepHours(viewModel.sleepHours)
        // Assuming 8 hours is 100%, calculate percentage
        let targetHours = 8.0
        return min(100, Int((sleepHours / targetHours) * 100))
    }
    
    private var sleepHoursValue: String {
        let hours = parseSleepHours(viewModel.sleepHours)
        return String(format: "%.0fh", hours)
    }
    
    // Stress level calculation (80% = Good)
    private var stressLevel: Int {
        // Calculate stress level based on heart rate and activity
        // Lower heart rate and good activity = lower stress
        let baseStress = 20 // Base stress level
        let heartRateFactor = max(0, min(30, (viewModel.heartRate - 60) / 2))
        let activityFactor = max(0, min(20, 20 - (viewModel.exerciseMinutes / 3)))
        let stress = baseStress + heartRateFactor + activityFactor
        return min(100, max(0, 100 - stress)) // Invert to show "Good" percentage
    }
    
    // Stress level text (Low/Medium/High)
    private var stressLevelText: String {
        if stressLevel >= 70 {
            return "Low"
        } else if stressLevel >= 40 {
            return "Medium"
        } else {
            return "High"
        }
    }
    
    // Activity distance in meters
    private var activityDistance: String {
        let meters = Int(viewModel.distance * 1000)
        return "\(meters)m"
    }
    
    private func parseSleepHours(_ sleepString: String) -> Double {
        // Parse "8h 30m" or "8h" format
        let components = sleepString.components(separatedBy: " ")
        var hours = 0.0
        var minutes = 0.0
        
        for component in components {
            if component.hasSuffix("h") {
                hours = Double(component.dropLast()) ?? 0
            } else if component.hasSuffix("m") {
                minutes = Double(component.dropLast()) ?? 0
            }
        }
        
        return hours + (minutes / 60.0)
    }
    
    private var userName: String {
        authViewModel.userName.components(separatedBy: " ").first ?? "User"
    }
    
    // MARK: - Enums
    
    enum MoodType: String, CaseIterable {
        case happy = "😊"
        case sad = "😔"
        case annoyed = "😤"
        case angry = "😠"
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Premium Background
            PremiumBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Greeting Section
                    greetingSection
                        .padding(.top, 8)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    
                    // Daily Activity Section
                    dailyActivitySection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 25)
                    
                    // Mood Question Section
                    moodQuestionSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    
                    // Heart Rate Waveform Card
                    // ECG waveform commented out
                    // heartRateWaveformCard
                    //     .padding(.horizontal, 20)
                    //     .padding(.bottom, 0)
                    
                    // Quick Action Section
                    quickActionSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    
                    // Health Vitals Section
                    healthVitalsSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 25)
                    
                    Spacer()
                }
            }
            
            // Mood Overlay
            if showMoodOverlay {
                moodOverlayView
            }
            
            // Fill Overlay - synchronized with heartbeat steps
            if showFillOverlay {
                FillOverlay(opacity: fillOpacity)
            }
        }
        .onAppear {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    hasAppeared = true
                }
            }
            
            // Start continuous small heartbeat animation
            startContinuousHeartbeat()
        }
        .onDisappear {
            // Stop continuous heartbeat when view disappears
            stopContinuousHeartbeat()
        }
        .task {
            await viewModel.loadTodaysData()
            await trackerViewModel.loadData()
            await hydrationViewModel.loadData()
            await medicationViewModel.loadMedications()
            
            // Start background task to generate AI suggestions
            Task.detached(priority: .background) {
                await generateHealthSuggestions()
            }
            
            // Start timer to regenerate suggestions every 5 seconds
            startSuggestionTimer()
        }
        .onDisappear {
            // Clean up timers when view disappears
            suggestionTimer?.invalidate()
            suggestionTimer = nil
            stopContinuousHeartbeat()
        }
        .onChange(of: viewModel.heartRate) { _, newValue in
            // Restart heartbeat with new rate when heart rate changes
            if hasAppeared {
                startContinuousHeartbeat()
            }
        }
        .refreshable {
            await viewModel.refresh()
            await trackerViewModel.refresh()
            await hydrationViewModel.refresh()
            await medicationViewModel.refresh()
            
            // Regenerate suggestions after refresh
            Task.detached(priority: .background) {
                await generateHealthSuggestions()
            }
        }
        .sheet(isPresented: $showMedications) {
            MedicationsView(viewModel: medicationViewModel)
        }
        .sheet(isPresented: $showHydration) {
            HydrationView(viewModel: hydrationViewModel)
        }
        .sheet(isPresented: $showReminders) {
            NotificationSettingsView(viewModel: hydrationViewModel)
        }
    }
    
    // MARK: - Heart Animation Functions
    
    private func startContinuousHeartbeat() {
        // Stop any existing timer
        continuousHeartbeatTimer?.invalidate()
        
        // Calculate heartbeat interval based on actual heart rate (default to 70 BPM if not available)
        let bpm = viewModel.heartRate > 0 ? viewModel.heartRate : 70
        let heartbeatInterval = 60.0 / Double(bpm) // Time between beats in seconds
        
        // Minimal heartbeat animation: subtle single beat
        continuousHeartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { _ in
            // Minimal beat: scale from 1.0 to 1.03 and back
            withAnimation(.easeOut(duration: 0.15)) {
                continuousHeartbeatScale = 1.03
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeIn(duration: 0.15)) {
                    continuousHeartbeatScale = 1.0
                }
            }
        }
        
        // Add timer to common run loop modes so it continues during scrolling
        if let timer = continuousHeartbeatTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func stopContinuousHeartbeat() {
        continuousHeartbeatTimer?.invalidate()
        continuousHeartbeatTimer = nil
        continuousHeartbeatScale = 1.0
    }
    
    private func startHeartAnimation() {
        // Initial haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Reset base scale to starting size (1.0)
        heartBaseScale = 1.0
        fillOpacity = 0.0
        showFillOverlay = true
        
        // Start synchronized heartbeat and heart growth animation
        // 4 steps = 4 heartbeats, each heartbeat cycle makes heart bigger
        startSynchronizedHeartbeatAndGrowth()
    }
    
    private func startSynchronizedHeartbeatAndGrowth() {
        heartbeatPhase = 0
        heartbeatTimer?.invalidate()
        
        let stepCount = 4
        let totalDuration: TimeInterval = 2.5
        let heartbeatCycleDuration = totalDuration / Double(stepCount) // ~0.625 seconds per heartbeat cycle
        
        var currentStep = 0
        
        // Realistic heartbeat pattern: lub-dub (double beat) synchronized with heart growth
        func performHeartbeatWithGrowth() {
            guard currentStep < stepCount else {
                // Animation complete
                heartbeatTimer?.invalidate()
                
                // Strong haptic feedback on completion
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)
                
                // Navigate to AI tab
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToAITab"), object: nil)
                    
                    // Reset animation state after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        stopHeartAnimation()
                    }
                }
                return
            }
            
            // Advance step and grow heart bigger at the start of each heartbeat cycle
            currentStep += 1
            
            // Grow heart base scale progressively: 1.0 -> 1.1 -> 1.2 -> 1.3
            let targetScale: CGFloat = {
                switch currentStep {
                case 1: return 1.0
                case 2: return 1.1
                case 3: return 1.2
                case 4: return 1.3
                default: return 1.0
                }
            }()
            
            // Fill opacity progressively: 0.2 -> 0.4 -> 0.6 -> 0.8
            let targetOpacity: Double = {
                switch currentStep {
                case 1: return 0.2
                case 2: return 0.4
                case 3: return 0.6
                case 4: return 0.8
                default: return 0.0
                }
            }()
            
            // Update heart base scale synchronized with heartbeat
            withAnimation(.easeOut(duration: 0.15)) {
                heartBaseScale = targetScale
            }
            
            // Update fill opacity synchronized with heartbeat
            withAnimation(.easeOut(duration: 0.15)) {
                fillOpacity = targetOpacity
            }
            
            // First beat (lub) - stronger (pulse on top of base scale)
            heartbeatPhase = 1
            withAnimation(.easeOut(duration: 0.12)) {
                heartBeatScale = 1.25
            }
            let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
            mediumFeedback.impactOccurred()
            
            // Return slightly, then second beat
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeIn(duration: 0.08)) {
                    heartBeatScale = 1.05
                }
                
                // Second beat (dub) - slightly weaker
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    heartbeatPhase = 2
                    withAnimation(.easeOut(duration: 0.1)) {
                        heartBeatScale = 1.2
                    }
                    let lightFeedback = UIImpactFeedbackGenerator(style: .light)
                    lightFeedback.impactOccurred()
                    
                    // Return heart to rest after second beat
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        heartbeatPhase = 0
                        withAnimation(.easeIn(duration: 0.15)) {
                            heartBeatScale = 1.0
                        }
                    }
                }
            }
        }
        
        // Perform initial heartbeat with growth
        performHeartbeatWithGrowth()
        
        // Schedule next heartbeat cycles synchronized with growth steps
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatCycleDuration, repeats: true) { [self] _ in
            performHeartbeatWithGrowth()
        }
        
        // Add timer to common run loop modes
        if let timer = heartbeatTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func stopHeartAnimation() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            heartBeatScale = 1.0
            heartBaseScale = 1.0
            heartbeatPhase = 0
            fillOpacity = 0.0
            showFillOverlay = false
        }
    }
    
    // MARK: - Background Health Analysis
    
    private func startSuggestionTimer() {
        // Invalidate existing timer if any
        suggestionTimer?.invalidate()
        
        // Create new timer that fires every 5 seconds
        suggestionTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: true) { _ in
            // Regenerate suggestions in background
            Task.detached(priority: .background) {
                await self.generateHealthSuggestions()
            }
        }
        
        // Add timer to common run loop modes so it continues during scrolling
        if let timer = suggestionTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func generateHealthSuggestions() async {
        // Check and set flag on main actor
        let shouldProceed = await MainActor.run {
            if isGeneratingSuggestions {
                return false
            }
            isGeneratingSuggestions = true
            return true
        }
        
        guard shouldProceed else { return }
        
        defer {
            Task { @MainActor in
                isGeneratingSuggestions = false
            }
        }
        
        do {
            // Fetch current health metrics
            let healthService = HealthKitService.shared
            let metrics = await healthService.fetchHealthMetrics(for: Date())
            
            // Fetch health history for better context
            let history = await healthService.fetchHealthMetricsHistory(days: 7)
            
            // Check medication adherence
            let medicationInfo = await MainActor.run {
                let total = medicationViewModel.totalCount
                let taken = medicationViewModel.takenCount
                return (total: total, taken: taken, hasMedications: total > 0)
            }
            
            // Detect health issues and generate contextual prompts
            let contextualPrompts = detectHealthIssuesAndGeneratePrompts(
                metrics: metrics,
                history: history,
                medicationInfo: medicationInfo
            )
            
            // Generate suggestions in parallel with random positions (no rotation change)
            let aiService = AIService.shared
            
            // Helper function to calculate distance between two points
            func distanceBetween(_ p1: (x: CGFloat, y: CGFloat), _ p2: (x: CGFloat, y: CGFloat)) -> CGFloat {
                let dx = p1.x - p2.x
                let dy = p1.y - p2.y
                return sqrt(dx * dx + dy * dy)
            }
            
            // Random positions - choose from 4 quadrants (top-left, top-right, bottom-left, bottom-right)
            let positions: [(x: CGFloat, y: CGFloat)] = [
                (x: -80, y: -90),  // Top-left
                (x: 80, y: -90),   // Top-right
                (x: -80, y: 90),   // Bottom-left
                (x: 80, y: 90),    // Bottom-right
                (x: -100, y: 0),   // Left-center
                (x: 100, y: 0),    // Right-center
                (x: 0, y: -100),   // Top-center
                (x: 0, y: 100)     // Bottom-center
            ]
            
            // Select two different random positions that don't overlap
            // Minimum distance between cards (card width ~180 + padding)
            let minDistance: CGFloat = 200
            var shuffledPositions = positions.shuffled()
            var leftPosition = shuffledPositions[0]
            var rightPosition: (x: CGFloat, y: CGFloat)
            
            // Find a second position that's far enough from the first
            var attempts = 0
            repeat {
                if shuffledPositions.count > 1 {
                    rightPosition = shuffledPositions[1]
                    shuffledPositions.removeFirst()
                } else {
                    // If we've tried all positions, use opposite side
                    rightPosition = (-leftPosition.x, -leftPosition.y)
                    break
                }
                attempts += 1
            } while distanceBetween(leftPosition, rightPosition) < minDistance && attempts < 10
            
            async let leftSuggestionTask = generateSingleSuggestion(
                prompt: contextualPrompts.left,
                aiService: aiService
            )
            async let rightSuggestionTask = generateSingleSuggestion(
                prompt: contextualPrompts.right,
                aiService: aiService
            )
            
            let (leftResult, rightResult) = await (leftSuggestionTask, rightSuggestionTask)
            
            // Update UI on main thread with animations
            await MainActor.run {
                // Reset scales for pop-up animation
                leftCardScale = 0.8
                rightCardScale = 0.8
                
                // Keep rotations fixed (don't change angles)
                // leftCardRotation and rightCardRotation remain unchanged
                
                // Set random positions
                leftCardOffsetX = leftPosition.x
                leftCardOffsetY = leftPosition.y
                rightCardOffsetX = rightPosition.x
                rightCardOffsetY = rightPosition.y
                
                // Set suggestions
                leftSuggestion = leftResult
                rightSuggestion = rightResult
                
                // Animate pop-up
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    leftCardScale = 1.0
                    rightCardScale = 1.0
                }
            }
        } catch {
            print("Failed to generate health suggestions: \(error.localizedDescription)")
            // Set fallback suggestions on error
            await MainActor.run {
                leftSuggestion = "How are you feeling today?"
                rightSuggestion = "Remember to take care of yourself!"
            }
        }
    }
    
    private func generateSingleSuggestion(prompt: String, aiService: AIService) async -> String {
        do {
            let response = try await aiService.sendChatMessage(prompt, context: [], systemContext: nil)
            // Clean up response - remove quotes, extra whitespace, etc.
            var cleaned = response
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "'", with: "")
            
            // Remove common AI prefixes
            let prefixes = ["Sure!", "Of course!", "Here's", "I'd suggest", "I suggest", "You could", "Try", "Consider"]
            for prefix in prefixes {
                if cleaned.lowercased().hasPrefix(prefix.lowercased()) {
                    cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // Limit to short conversational length (max 50 chars for human-like)
            if cleaned.count > 50 {
                // Try to cut at a sentence boundary
                let prefix50 = cleaned.prefix(50)
                if let periodIndex = prefix50.lastIndex(of: ".") {
                    let offset = cleaned.distance(from: cleaned.startIndex, to: periodIndex)
                    cleaned = String(cleaned.prefix(offset + 1))
                } else if let questionIndex = prefix50.lastIndex(of: "?") {
                    let offset = cleaned.distance(from: cleaned.startIndex, to: questionIndex)
                    cleaned = String(cleaned.prefix(offset + 1))
                } else {
                    cleaned = String(cleaned.prefix(47)) + "..."
                }
            }
            
            return cleaned.isEmpty ? "How are you feeling?" : cleaned
        } catch {
            print("Failed to generate suggestion: \(error.localizedDescription)")
            return "Take care of yourself today!"
        }
    }
    
    private func detectHealthIssuesAndGeneratePrompts(
        metrics: HealthMetrics,
        history: [HealthMetrics],
        medicationInfo: (total: Int, taken: Int, hasMedications: Bool)
    ) -> (left: String, right: String) {
        var issues: [String] = []
        var prompts: [String] = []
        
        // Check medication adherence
        if medicationInfo.hasMedications {
            let adherenceRate = medicationInfo.total > 0 ? Double(medicationInfo.taken) / Double(medicationInfo.total) : 1.0
            if adherenceRate < 0.5 {
                prompts.append("I noticed you haven't taken all your medications today. Ask me why in a friendly, caring way (max 8 words, like a friend would ask).")
            } else if adherenceRate < 1.0 {
                prompts.append("You've missed some medications today. Ask me why in a gentle, supportive way (max 8 words).")
            }
        }
        
        // Check sleep quality
        let sleepHours = parseSleepHours(metrics.sleep)
        if sleepHours < 6 {
            prompts.append("I see you didn't sleep well last night. Ask me why in a caring, conversational way (max 8 words, like a friend checking in).")
        } else if sleepHours < 7 {
            prompts.append("Your sleep was a bit short. Ask me about it in a friendly way (max 8 words).")
        }
        
        // Check activity levels
        if history.count >= 2 {
            let avgSteps = history.map { $0.steps }.reduce(0, +) / history.count
            if metrics.steps < avgSteps / 2 {
                prompts.append("You've been less active today. Ask me why in a friendly, non-judgmental way (max 8 words).")
            }
        }
        
        // Check heart rate
        if history.count >= 2 {
            let avgHR = history.map { $0.heartRate }.reduce(0, +) / history.count
            if metrics.heartRate > avgHR + 15 {
                prompts.append("Your heart rate seems elevated. Ask me how I'm feeling in a caring way (max 8 words).")
            }
        }
        
        // If no specific issues, use general friendly prompts
        if prompts.isEmpty {
            prompts = [
                "Say something friendly and encouraging about my health today (max 8 words, like a friend would).",
                "Give me a quick, friendly wellness tip based on my day (max 8 words).",
                "Ask me how I'm doing in a warm, caring way (max 8 words).",
                "Share a brief, friendly health reminder (max 8 words).",
                "Give me a short, encouraging health message (max 8 words)."
            ]
        }
        
        // Select two different prompts
        let shuffled = prompts.shuffled()
        let leftPrompt = shuffled.first ?? "How are you feeling today?"
        let rightPrompt = shuffled.count > 1 ? shuffled[1] : shuffled.first ?? "Take care of yourself!"
        
        return (left: leftPrompt, right: rightPrompt)
    }
    
    private func formatHealthDataForAnalysis(metrics: HealthMetrics, history: [HealthMetrics]) -> String {
        var parts: [String] = []
        
        // Current metrics
        parts.append("Today: Steps:\(metrics.steps), HR:\(metrics.heartRate), Sleep:\(metrics.sleep), Exercise:\(metrics.exerciseMinutes)m, Calories:\(metrics.activeCalories)")
        
        // Calculate trends
        if history.count >= 2 {
            let avgSteps = history.map { $0.steps }.reduce(0, +) / history.count
            let avgHR = history.map { $0.heartRate }.reduce(0, +) / history.count
            let avgExercise = history.map { $0.exerciseMinutes }.reduce(0, +) / history.count
            
            parts.append("7-day avg: Steps:\(avgSteps), HR:\(avgHR), Exercise:\(avgExercise)m")
            
            // Compare today vs average
            if metrics.steps < Int(Double(avgSteps) * 0.8) {
                parts.append("Steps below average")
            }
            if metrics.heartRate > Int(Double(avgHR) * 1.1) {
                parts.append("Heart rate elevated")
            }
            if metrics.exerciseMinutes < Int(Double(avgExercise) * 0.7) {
                parts.append("Exercise below average")
            }
        }
        
        return parts.joined(separator: ". ")
    }
    
    // MARK: - Subviews
    
    private var greetingSection: some View {
        HStack(alignment: .center, spacing: 12) {
            // Profile Picture
            Group {
                if let imageURL = authViewModel.userPhotoURL {
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
            
            // Greeting Text
            HStack(spacing: 4) {
                Text("Hi")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("\(userName)!")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Reminder Button - Show Notification Settings
            Button(action: {
                showReminders = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "bell.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : -20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: hasAppeared)
    }
    
    private var moodQuestionSection: some View {
        ZStack {
            // Heart Image - Centered with tap and hold gesture
            Image("heart-blue")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .opacity(hasAppeared ? 1 : 0)
                .scaleEffect((hasAppeared ? 1.0 : 0.8) * heartBaseScale * heartBeatScale * continuousHeartbeatScale)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: hasAppeared)
                .animation(.easeOut(duration: 0.15), value: heartBaseScale)
                .animation(.easeOut(duration: 0.12), value: heartBeatScale)
                .animation(.easeOut(duration: 0.12), value: continuousHeartbeatScale)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isHeartPressed {
                                isHeartPressed = true
                            }
                        }
                        .onEnded { _ in
                            isHeartPressed = false
                        }
                )
            
            // Left Suggestion Card - Random position
            if let suggestion = leftSuggestion {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundColor(.blue.opacity(0.7))
                        Text("Swastri")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.primary.opacity(0.6))
                    }
                    
                    Text(suggestion)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                )
                .frame(width: 180)
                .offset(x: leftCardOffsetX, y: leftCardOffsetY + cardOffset) // Random position with floating animation
                .rotationEffect(.degrees(leftCardRotation))
                .scaleEffect(leftCardScale)
                .opacity(hasAppeared && leftSuggestion != nil ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: leftSuggestion)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: leftCardScale)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: leftCardOffsetX)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: leftCardOffsetY)
            }
            
            // Right Suggestion Card - Random position
            if let suggestion = rightSuggestion {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundColor(.blue.opacity(0.7))
                        Text("Swastri")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.primary.opacity(0.6))
                    }
                    
                    Text(suggestion)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                )
                .frame(width: 180)
                .offset(x: rightCardOffsetX, y: rightCardOffsetY - cardOffset) // Random position with floating animation (opposite direction)
                .rotationEffect(.degrees(rightCardRotation))
                .scaleEffect(rightCardScale)
                .opacity(hasAppeared && rightSuggestion != nil ? 1 : 0)
                .offset(y: hasAppeared ? 0 : -20)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: rightSuggestion)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: rightCardScale)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: rightCardOffsetX)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: rightCardOffsetY)
            }
        }
        .frame(height: 250)
        .frame(maxWidth: .infinity)
        .onAppear {
            // Start continuous floating animation
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                cardOffset = 8
            }
        }
        .onChange(of: isHeartPressed) { _, newValue in
            if newValue {
                startHeartAnimation()
            } else {
                stopHeartAnimation()
            }
        }
    }
    
    // MARK: - Heart Rate Waveform Card
    // ECG waveform commented out
    
    /*
    private var heartRateWaveformCard: some View {
        // Waveform only - no heading, values, or background
        HeartRateWaveform(
            heartRate: viewModel.heartRate,
            animationProgress: animationProgress
        )
        .frame(height: 80)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 10)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: hasAppeared)
        .onAppear {
            // Start waveform animation
            startWaveformAnimation()
        }
        .onDisappear {
            // Clean up animation timer
            animationTimer?.invalidate()
        }
    }
    
    private func startWaveformAnimation() {
        // Stop any existing timer
        animationTimer?.invalidate()
        
        // Calculate duration based on heart rate (very slow animation - 8 seconds per cycle)
        let beatsPerMinute = Double(max(40, min(120, viewModel.heartRate)))
        let baseDuration: Double = 8.0 // Base duration for very slow, smooth animation
        
        // Reset progress
        animationProgress = 0
        
        // Use a timer to animate the blue line tracing through the outline
        let timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [self] timer in
            // Increment progress very slowly
            animationProgress += CGFloat(0.016 / baseDuration)
            
            // Loop back to 0 when reaching 1.0 for continuous animation
            if animationProgress >= 1.0 {
                animationProgress = 0
            }
        }
        
        // Add timer to common run loop modes so it continues during scrolling
        RunLoop.current.add(timer, forMode: .common)
        animationTimer = timer
    }
    */
    
    // MARK: - Daily Activity Section
    
    private var dailyActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(alignment: .center) {
                Text("Daily Activity")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Daily Activity Cards Grid
            HStack(spacing: 16) {
                // Steps Card
                StepsCard(
                    steps: viewModel.stepCount,
                    hasAppeared: hasAppeared
                )
                .frame(maxWidth: .infinity)
                
                // Distance Card
                DistanceCard(
                    distance: viewModel.distance,
                    hasAppeared: hasAppeared
                )
                .frame(maxWidth: .infinity)
                
                // Kcal Card
                KcalCard(
                    calories: viewModel.activeCalories,
                    hasAppeared: hasAppeared
                )
                .frame(maxWidth: .infinity)
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: hasAppeared)
    }
    
    // MARK: - Health Vitals Section
    
    private var healthVitalsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(alignment: .center) {
                Text("Health Vitals")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Health Vitals Cards Grid
            HStack(alignment: .center, spacing: 16) {
                // Sleep Card (Large, Left)
                SleepCard(
                    percentage: sleepPercentage,
                    hours: sleepHoursValue,
                    hasAppeared: hasAppeared
                )
                .frame(maxWidth: .infinity)
                .frame(height: 172)
                
                // Right Column (Stress & BPM) - Centered Vertically
                VStack(alignment: .leading, spacing: 12) {
                    // Stress Level Card
                    StressLevelCard(
                        percentage: stressLevel,
                        hasAppeared: hasAppeared
                    )
                    
                    // BPM Card
                    BPMPriorityCard(
                        heartRate: viewModel.heartRate,
                        hasAppeared: hasAppeared
                    )
                }
                .frame(maxWidth: .infinity)
                .frame(height: 172)
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: hasAppeared)
    }
    
    // MARK: - Quick Action Section
    
    private var quickActionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(alignment: .center) {
                Text("Quick Action")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Quick Action Cards Grid
            HStack(spacing: 16) {
                // Hydration Card
                Button(action: {
                    showHydration = true
                }) {
                    HydrationQuickActionCard(
                        currentIntake: hydrationViewModel.effectiveIntake,
                        dailyGoal: hydrationViewModel.dailyGoal,
                        hasAppeared: hasAppeared
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity)
                
                // Medication Card
                Button(action: {
                    showMedications = true
                }) {
                    MedicationQuickActionCard(
                        takenCount: medicationViewModel.takenCount,
                        totalCount: medicationViewModel.totalCount,
                        hasAppeared: hasAppeared
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: hasAppeared)
    }
    
    // MARK: - Mood Handling
    
    private func handleMoodSelection(_ mood: MoodType) async {
        // Show overlay with animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showMoodOverlay = true
            isGeneratingMoodAI = true
            moodAIGeneratedText = nil
        }
        
        // Generate AI content based on mood
        let moodPrompt = getMoodPrompt(for: mood)
        
        do {
            // Fetch health history for context
            let healthService = HealthKitService.shared
            let history = await healthService.fetchHealthMetricsHistory(days: 7)
            let systemContext = formatHealthHistoryForChat(history)
            
            // Generate AI response using AIService directly
            let aiService = AIService.shared
            let response = try await aiService.sendChatMessage(
                moodPrompt,
                context: [],
                systemContext: systemContext
            )
            
            // Update UI with response
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    moodAIGeneratedText = response
                    isGeneratingMoodAI = false
                }
            }
        } catch {
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    moodAIGeneratedText = "I understand how you're feeling. Would you like to talk more about it?"
                    isGeneratingMoodAI = false
                }
            }
        }
    }
    
    private func getMoodPrompt(for mood: MoodType) -> String {
        switch mood {
        case .happy:
            return "I'm feeling happy today! Can you give me some personalized wellness tips and encouragement to maintain this positive energy?"
        case .sad:
            return "I'm feeling a bit down today. Can you provide some gentle, supportive wellness advice and suggestions to help improve my mood?"
        case .annoyed:
            return "I'm feeling annoyed and frustrated. Can you suggest some calming techniques and wellness practices to help me feel better?"
        case .angry:
            return "I'm feeling angry. Can you help me with some stress management techniques and wellness strategies to help me calm down?"
        }
    }
    
    private func formatHealthHistoryForChat(_ history: [HealthMetrics]) -> String {
        var parts: [String] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM"
        
        parts.append("Past 7 Days Health:")
        
        for metrics in history {
            let dateStr = dateFormatter.string(from: metrics.timestamp)
            let sleepVal = (metrics.sleep == "0h 0m") ? "N/A" : metrics.sleep
            let stepsK = String(format: "%.1fk", Double(metrics.steps)/1000.0)
            
            let line = "\(dateStr): Steps:\(stepsK), Sleep:\(sleepVal), HR:\(metrics.heartRate), Cal:\(metrics.activeCalories), Ex:\(metrics.exerciseMinutes)m"
            parts.append(line)
        }
        
        return parts.joined(separator: "\n")
    }
    
    // MARK: - Mood Overlay View
    
    private var moodOverlayView: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showMoodOverlay = false
                        selectedMood = nil
                        moodAIGeneratedText = nil
                    }
                }
            
            // Content Card
            VStack(spacing: 24) {
                // Close Button
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showMoodOverlay = false
                            selectedMood = nil
                            moodAIGeneratedText = nil
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Mood Emoji
                if let mood = selectedMood {
                    Text(mood.rawValue)
                        .font(.system(size: 80))
                        .scaleEffect(showMoodOverlay ? 1.0 : 0.5)
                        .opacity(showMoodOverlay ? 1.0 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showMoodOverlay)
                }
                
                // Animated Orb
                AnimatedOrbView(isAnimating: isGeneratingMoodAI)
                    .frame(width: 200, height: 200)
                    .opacity(isGeneratingMoodAI ? 1.0 : 0.3)
                    .scaleEffect(isGeneratingMoodAI ? 1.0 : 0.8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isGeneratingMoodAI)
                
                // AI Generated Text
                if let aiText = moodAIGeneratedText {
                    ScrollView {
                        Text(aiText)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .padding(.horizontal, 8)
                    }
                    .frame(maxHeight: 200)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else if isGeneratingMoodAI {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Swastri is thinking...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 100)
                }
                
                // Action Button
                if moodAIGeneratedText != nil {
                    Button(action: {
                        // Navigate to AI tab to continue conversation
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToAITab"), object: nil)
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showMoodOverlay = false
                            selectedMood = nil
                            moodAIGeneratedText = nil
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Continue with Swastri AI")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "2E3192"), Color(hex: "4A90E2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color(hex: "2E3192").opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .scaleEffect(showMoodOverlay ? 1.0 : 0.9)
            .opacity(showMoodOverlay ? 1.0 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showMoodOverlay)
        }
        .transition(.opacity)
    }
}

// MARK: - Sleep Card

private struct SleepCard: View {
    let percentage: Int
    let hours: String
    let hasAppeared: Bool
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Dark blue-black gradient background
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.1, green: 0.15, blue: 0.3),
                            Color(red: 0.05, green: 0.05, blue: 0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 172)
            
            VStack(alignment: .leading, spacing: 0) {
                // Top Section
                HStack(alignment: .top) {
                    Image(systemName: "bed.double.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                
                // Percentage Text
                Text("\(percentage)% Good Sleep")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.top, 6)
                    .padding(.horizontal, 16)
                
                // Hours Display
                Text(hours)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                
                Spacer()
                
                // Waveform at bottom
                SleepWaveform()
                    .frame(height: 50)
                    .padding(.bottom, 16)
            }
            .frame(height: 172, alignment: .top)
        }
        .frame(height: 172)
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Stress Level Card

private struct StressLevelCard: View {
    let percentage: Int
    let hasAppeared: Bool
    
    var body: some View {
        ZStack {
            // Purple-orange gradient background
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.6, green: 0.3, blue: 0.8),
                            Color(red: 1.0, green: 0.4, blue: 0.5)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 80)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(percentage)% Good")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Stress Level")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                // Bar graph icon
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .frame(height: 80, alignment: .center)
        }
        .shadow(color: Color.purple.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Activity Card

private struct ActivityCard: View {
    let distance: String
    let hasAppeared: Bool
    
    var body: some View {
        ZStack {
            // Green-blue gradient background
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.4, green: 0.8, blue: 0.5),
                            Color(red: 0.3, green: 0.7, blue: 0.9)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 80)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(distance)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Running person icon with circular progress
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2.5)
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: "figure.run")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .frame(height: 80, alignment: .center)
        }
        .shadow(color: Color.green.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Sleep Waveform

private struct SleepWaveform: View {
    @State private var phase: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let centerY = height / 2
                let amplitude: CGFloat = 8
                let frequency: Double = 0.02
                
                path.move(to: CGPoint(x: 0, y: centerY))
                
                for x in stride(from: 0, through: width, by: 2) {
                    let relativeX = Double(x) / Double(width)
                    let y = centerY + CGFloat(sin(relativeX * .pi * 4 + phase) * amplitude)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(0.6),
                        Color.blue.opacity(0.4)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
        }
        .onAppear {
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Steps Card

private struct StepsCard: View {
    let steps: Int
    let hasAppeared: Bool
    
    @State private var cardAppeared = false
    
    private var formattedSteps: String {
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000.0)
        }
        return "\(steps)"
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.8),
                            Color.mint.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 120)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedSteps)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Steps")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(16)
        }
        .frame(height: 120)
        .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
        .opacity(cardAppeared ? 1 : 0)
        .scaleEffect(cardAppeared ? 1 : 0.95)
        .onChange(of: hasAppeared) { _, newValue in
            if newValue && !cardAppeared {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        cardAppeared = true
                    }
                }
            }
        }
    }
}

// MARK: - Distance Card

private struct DistanceCard: View {
    let distance: Double
    let hasAppeared: Bool
    
    @State private var cardAppeared = false
    
    private var formattedDistance: String {
        if distance >= 1.0 {
            return String(format: "%.1f km", distance)
        } else {
            let meters = Int(distance * 1000)
            return "\(meters) m"
        }
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.8),
                            Color.cyan.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 120)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDistance)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Text("Distance")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(16)
        }
        .frame(height: 120)
        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
        .opacity(cardAppeared ? 1 : 0)
        .scaleEffect(cardAppeared ? 1 : 0.95)
        .onChange(of: hasAppeared) { _, newValue in
            if newValue && !cardAppeared {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        cardAppeared = true
                    }
                }
            }
        }
    }
}

// MARK: - Kcal Card

private struct KcalCard: View {
    let calories: Int
    let hasAppeared: Bool
    
    @State private var cardAppeared = false
    
    var body: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.8),
                            Color.red.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 120)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(calories)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Kcal")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(16)
        }
        .frame(height: 120)
        .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 4)
        .opacity(cardAppeared ? 1 : 0)
        .scaleEffect(cardAppeared ? 1 : 0.95)
        .onChange(of: hasAppeared) { _, newValue in
            if newValue && !cardAppeared {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        cardAppeared = true
                    }
                }
            }
        }
    }
}

// MARK: - Hydration Quick Action Card

private struct HydrationQuickActionCard: View {
    let currentIntake: Int
    let dailyGoal: Int
    let hasAppeared: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var cardAppeared = false
    @State private var visualProgress: Double = 0.0
    @State private var wavePhase: Double = 0.0
    
    private var targetProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1.0, Double(currentIntake) / Double(dailyGoal))
    }
    
    private var isLight: Bool { colorScheme == .light }
    private var textColor: Color { isLight ? .primary : .white }
    private var textOpacity: Double { isLight ? 0.85 : 0.9 }
    private var waveBackOpacity: Double { isLight ? 0.2 : 0.3 }
    private var waveFrontOpacities: (Double, Double) { isLight ? (0.35, 0.35) : (0.6, 0.6) }
    
    var body: some View {
        ZStack {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.cyan.opacity(isLight ? 0.12 : 0.1))
                    
                    if visualProgress > 0.01 {
                        ZStack(alignment: .bottom) {
                            WaterWaveShape(amplitude: geo.size.height * 0.04, offset: wavePhase)
                                .fill(Color.cyan.opacity(waveBackOpacity))
                                .frame(height: max(geo.size.height * visualProgress, geo.size.height * 0.05))
                            
                            WaterWaveShape(amplitude: geo.size.height * 0.03, offset: wavePhase + 1.5)
                                .fill(LinearGradient(
                                    colors: [.cyan.opacity(waveFrontOpacities.0), .blue.opacity(waveFrontOpacities.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .frame(height: max(geo.size.height * visualProgress, geo.size.height * 0.05))
                        }
                        .mask(RoundedRectangle(cornerRadius: 24))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 18))
                        .foregroundColor(textColor.opacity(textOpacity))
                    
                    Spacer()
                    
                    Text("\(Int(visualProgress * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(textColor.opacity(textOpacity))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(currentIntake)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(textColor)
                        
                        Text("/ \(dailyGoal) ml")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(textColor.opacity(isLight ? 0.75 : 0.8))
                    }
                    
                    Text("Hydration")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textColor.opacity(textOpacity))
                }
            }
            .padding(16)
        }
        .frame(height: 120)
        .shadow(color: Color.blue.opacity(isLight ? 0.2 : 0.3), radius: 8, x: 0, y: 4)
        .opacity(cardAppeared ? 1 : 0)
        .scaleEffect(cardAppeared ? 1 : 0.95)
        .onChange(of: hasAppeared) { _, newValue in
            if newValue && !cardAppeared {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        cardAppeared = true
                    }
                }
            }
        }
        .onAppear {
            // Start continuous wave animation
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
            
            // Animate progress
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.8)) {
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

// MARK: - Water Wave Shape

private struct WaterWaveShape: Shape {
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
        
        // Start at top-left
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Draw wave along top edge
        for x in stride(from: 0, to: width, by: 2) {
            let relativeX = x / width
            let angle = relativeX * .pi * 2 + offset
            let y = sin(angle) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Close the shape at the bottom
        path.addLine(to: CGPoint(x: width, y: height + amplitude))
        path.addLine(to: CGPoint(x: 0, y: height + amplitude))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Medication Quick Action Card

private struct MedicationQuickActionCard: View {
    let takenCount: Int
    let totalCount: Int
    let hasAppeared: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var cardAppeared = false
    
    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return min(1.0, Double(takenCount) / Double(totalCount))
    }
    
    private var isLight: Bool { colorScheme == .light }
    private var textColor: Color { isLight ? .primary : .white }
    private var textOpacity: Double { isLight ? 0.85 : 0.9 }
    private var gradientOpacity: Double { isLight ? 0.35 : 0.8 }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "AF52DE").opacity(gradientOpacity),
                            Color(hex: "5856D6").opacity(gradientOpacity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 120)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "pills.fill")
                        .font(.system(size: 18))
                        .foregroundColor(textColor.opacity(textOpacity))
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(textColor.opacity(textOpacity))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(takenCount)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(textColor)
                        
                        Text("/ \(totalCount)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(textColor.opacity(isLight ? 0.75 : 0.8))
                    }
                    
                    Text("Medication")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textColor.opacity(textOpacity))
                }
            }
            .padding(16)
        }
        .frame(height: 120)
        .shadow(color: Color.purple.opacity(isLight ? 0.2 : 0.3), radius: 8, x: 0, y: 4)
        .opacity(cardAppeared ? 1 : 0)
        .scaleEffect(cardAppeared ? 1 : 0.95)
        .onChange(of: hasAppeared) { _, newValue in
            if newValue && !cardAppeared {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        cardAppeared = true
                    }
                }
            }
        }
    }
}

// MARK: - BPM Priority Card

private struct BPMPriorityCard: View {
    let heartRate: Int
    let hasAppeared: Bool
    
    @State private var cardAppeared = false
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0.8),
                            Color.pink.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 80)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Heart Rate")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(heartRate)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("BPM")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Pulsing Heart Icon
                Image(systemName: "heart.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .opacity(isPulsing ? 1.0 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
                    .onAppear {
                        isPulsing = true
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(height: 80)
        .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
        .opacity(cardAppeared ? 1 : 0)
        .scaleEffect(cardAppeared ? 1 : 0.95)
        .onChange(of: hasAppeared) { _, newValue in
            if newValue && !cardAppeared {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        cardAppeared = true
                    }
                }
            }
        }
    }
}

// MARK: - Animated Orb View

private struct AnimatedOrbView: View {
    let isAnimating: Bool
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotation: Double = 0
    @State private var sparkleOpacity: Double = 0.3
    
    var body: some View {
        ZStack {
            // Outer glow rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "2E3192").opacity(0.3),
                                Color(hex: "4A90E2").opacity(0.2),
                                Color(hex: "1BFFFF").opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 120 + CGFloat(index * 20), height: 120 + CGFloat(index * 20))
                    .scaleEffect(pulseScale + CGFloat(index) * 0.1)
                    .opacity(sparkleOpacity - Double(index) * 0.1)
            }
            
            // Main orb
            ZStack {
                // Glow background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "2E3192").opacity(0.4),
                                Color(hex: "4A90E2").opacity(0.2),
                                Color(hex: "1BFFFF").opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 15)
                
                // Main circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "2E3192").opacity(0.6),
                                Color(hex: "4A90E2").opacity(0.4),
                                Color(hex: "1BFFFF").opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "1BFFFF").opacity(0.6),
                                        Color(hex: "4A90E2").opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: Color(hex: "2E3192").opacity(0.5), radius: 20, x: 0, y: 0)
                
                // Sparkle icon
                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: "1BFFFF"),
                                Color(hex: "4A90E2"),
                                Color(hex: "2E3192")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotation3DEffect(
                        .degrees(rotation),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 1.0
                    )
                    .symbolEffect(.pulse, options: .repeating.speed(0.5))
            }
        }
        .onAppear {
            if isAnimating {
                startAnimation()
            }
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }
    
    private func startAnimation() {
        // Pulse animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
        }
        
        // Continuous horizontal rotation (around Y-axis)
        // Use a keyframe animation for smooth continuous rotation
        let rotationAnimation = Animation
            .linear(duration: 8)
            .repeatForever(autoreverses: false)
        
        withAnimation(rotationAnimation) {
            rotation = 360
        }
        
        // Sparkle opacity animation
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            sparkleOpacity = 0.8
        }
    }
    
    private func stopAnimation() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            pulseScale = 1.0
            sparkleOpacity = 0.3
            rotation = 0
        }
    }
}

// MARK: - Heart Rate Waveform Component
// ECG waveform commented out

/*
struct HeartRateWaveform: View {
    let heartRate: Int
    var animationProgress: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Use 3/4 of the total width for the waveform
                let waveformWidth = geometry.size.width * 0.75
                let offsetX = geometry.size.width * 0.125 // Center offset (half of remaining 25%)
                
                // Static outline - full ECG waveform (gray)
                createECGOutline(width: waveformWidth, height: geometry.size.height)
                    .stroke(Color(red: 0.36, green: 0.36, blue: 0.45), lineWidth: 1)
                    .offset(x: offsetX)
                
                // Animated blue line tracing through the outline
                createECGOutline(width: waveformWidth, height: geometry.size.height)
                    .trim(from: 0, to: animationProgress)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.blue,
                                Color.cyan,
                                Color.blue
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )
                    .offset(x: offsetX)
                
                // Glowing dot at current tracing position
                if animationProgress > 0 {
                    let currentPoint = getPointAtProgress(
                        width: waveformWidth,
                        height: geometry.size.height,
                        progress: animationProgress
                    )
                    
                    ZStack {
                        // Outer glow
                        Circle()
                            .fill(Color.blue.opacity(0.4))
                            .frame(width: 14, height: 14)
                            .blur(radius: 5)
                        
                        // Inner glow
                        Circle()
                            .fill(Color.cyan.opacity(0.6))
                            .frame(width: 10, height: 10)
                            .blur(radius: 3)
                        
                        // Center dot
                        Circle()
                            .fill(Color.white)
                            .frame(width: 5, height: 5)
                    }
                    .position(x: currentPoint.x + offsetX, y: currentPoint.y)
                }
            }
        }
    }
    
    private func createECGOutline(width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        let centerY = height / 2
        let patternWidth: CGFloat = 120
        let numPatterns = Int(ceil(width / patternWidth)) + 1
        
        // Start at baseline
        path.move(to: CGPoint(x: 0, y: centerY))
        
        // Draw multiple ECG patterns to fill the width
        for patternIndex in 0..<numPatterns {
            let patternStartX = CGFloat(patternIndex) * patternWidth
            let patternEndX = min(width, patternStartX + patternWidth)
            
            if patternStartX < width {
                drawECGPattern(
                    path: &path,
                    patternStartX: patternStartX,
                    patternWidth: patternWidth,
                    centerY: centerY,
                    endX: patternEndX
                )
            }
        }
        
        return path
    }
    
    private func drawECGPattern(path: inout Path, patternStartX: CGFloat, patternWidth: CGFloat, centerY: CGFloat, endX: CGFloat) {
        let stepSize: CGFloat = 0.5
        var x = patternStartX
        
        while x < endX {
            let relativeX = (x - patternStartX) / patternWidth
            var y: CGFloat = centerY
            
            if relativeX < 0.05 {
                // Baseline before P wave
                y = centerY
            } else if relativeX < 0.15 {
                // P wave - small rounded bump
                let pRelative = (relativeX - 0.05) / 0.1
                y = centerY - CGFloat(sin(pRelative * .pi) * 8)
            } else if relativeX < 0.2 {
                // PR segment - flat baseline
                y = centerY
            } else if relativeX < 0.32 {
                // QRS complex - sharp spike
                let qrsRelative = (relativeX - 0.2) / 0.12
                if qrsRelative < 0.1 {
                    // Q wave - small downward dip
                    y = centerY - CGFloat(qrsRelative / 0.1 * 4)
                } else if qrsRelative < 0.3 {
                    // R wave - sharp upward spike
                    y = centerY - 4 - CGFloat((qrsRelative - 0.1) / 0.2 * 28)
                } else if qrsRelative < 0.5 {
                    // S wave - downward return
                    y = centerY - 32 + CGFloat((qrsRelative - 0.3) / 0.2 * 32)
                } else {
                    // Return to baseline
                    y = centerY + CGFloat((qrsRelative - 0.5) / 0.5 * 4)
                }
            } else if relativeX < 0.45 {
                // ST segment - flat baseline
                y = centerY
            } else if relativeX < 0.65 {
                // T wave - rounded bump
                let tRelative = (relativeX - 0.45) / 0.2
                y = centerY + CGFloat(sin(tRelative * .pi) * 12)
            } else {
                // Rest period - baseline
                y = centerY
            }
            
            path.addLine(to: CGPoint(x: x, y: y))
            x += stepSize
        }
    }
    
    private func getPointAtProgress(width: CGFloat, height: CGFloat, progress: CGFloat) -> CGPoint {
        let centerY = height / 2
        let patternWidth: CGFloat = 120
        let totalLength = width
        let currentX = totalLength * progress
        
        // Find which pattern we're in
        let patternIndex = Int(currentX / patternWidth)
        let patternStartX = CGFloat(patternIndex) * patternWidth
        let relativeX = (currentX - patternStartX) / patternWidth
        
        var y: CGFloat = centerY
        
        if relativeX < 0.05 {
            y = centerY
        } else if relativeX < 0.15 {
            let pRelative = (relativeX - 0.05) / 0.1
            y = centerY - CGFloat(sin(pRelative * .pi) * 8)
        } else if relativeX < 0.2 {
            y = centerY
        } else if relativeX < 0.32 {
            let qrsRelative = (relativeX - 0.2) / 0.12
            if qrsRelative < 0.1 {
                y = centerY - CGFloat(qrsRelative / 0.1 * 4)
            } else if qrsRelative < 0.3 {
                y = centerY - 4 - CGFloat((qrsRelative - 0.1) / 0.2 * 28)
            } else if qrsRelative < 0.5 {
                y = centerY - 32 + CGFloat((qrsRelative - 0.3) / 0.2 * 32)
            } else {
                y = centerY + CGFloat((qrsRelative - 0.5) / 0.5 * 4)
            }
        } else if relativeX < 0.45 {
            y = centerY
        } else if relativeX < 0.65 {
            let tRelative = (relativeX - 0.45) / 0.2
            y = centerY + CGFloat(sin(tRelative * .pi) * 12)
        } else {
            y = centerY
        }
        
        return CGPoint(x: currentX, y: y)
    }
}
*/

// MARK: - Heart Position Preference Key

// MARK: - Fill Overlay

private struct FillOverlay: View {
    let opacity: Double
    
    var body: some View {
        // Full screen fill with gradient
        ZStack {
            // Blue gradient fill
            LinearGradient(
                colors: [
                    Color.blue.opacity(opacity),
                    Color.cyan.opacity(opacity * 0.8),
                    Color.blue.opacity(opacity * 0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

#Preview {
    NavigationStack {
        HomeViewV2()
    }
}
