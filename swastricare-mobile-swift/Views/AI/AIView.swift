//
//  AIView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI
import UIKit
import SceneKit
import Combine
import PhotosUI

struct AIView: View {
    
    // MARK: - ViewModel

    @StateObject private var viewModel = DependencyContainer.shared.aiViewModel
    @StateObject private var trackerViewModel = DependencyContainer.shared.trackerViewModel
    @StateObject private var authViewModel = DependencyContainer.shared.authViewModel
    @StateObject private var hydrationViewModel = DependencyContainer.shared.hydrationViewModel
    
    // MARK: - Local State
    
    @FocusState private var isInputFocused: Bool
    @State private var showEmptyState = false
    @State private var sendButtonScale: CGFloat = 1.0
    @StateObject private var speechManager = SpeechManager.shared
    @State private var isModeSwitching = false
    @ObservedObject private var networkMonitor = NetworkMonitorService.shared
    @StateObject private var referralViewModel = DependencyContainer.shared.referralViewModel

    // MARK: - Image Picker State
    
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var showImageSourceSheet = false
    @State private var showImageTypeSheet = false
    @State private var selectedImageType: MedicalImageAnalysisType = .general
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var useCamera = false  // Track user's source preference
    @State private var isFoodPhotoMode = false  // Track if user selected Food Photo

    // MARK: - Add to Diet State
    @State private var showMealTypePicker = false
    @State private var pendingFoodForDiet: SnapFoodResult?
    @StateObject private var dietViewModel = DependencyContainer.shared.dietViewModel
    
    // MARK: - Toast State
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIcon = ""
    @State private var toastColor: Color = .blue
    
    // MARK: - Mode Switch Confirmation
    @State private var showModeSwitchConfirmation = false
    @State private var pendingModeSwitch: AIMode?
    
    // MARK: - First-time Tooltip
    @State private var showModeTooltip = false

    // MARK: - Typewriter Animation Tracking
    @State private var typewriterAnimatedIds: Set<UUID> = []

    // MARK: - Mode Transition Animation
    @State private var modeTransitionProgress: CGFloat = 0
    @State private var modeTransitionColor: Color = .clear

    // MARK: - Onboarding Tour
    @State private var showOnboardingTour = false
    @State private var onboardingStep = 0

    // MARK: - Feedback Reaction
    @State private var showHelpfulReaction = false
    @State private var reactionMessageId: UUID?
    
    // MARK: - Body
    
    @ViewBuilder
    private var mainContent: some View {
        if referralViewModel.isAIUnlocked {
            chatView
        } else {
            AIReferralGateView(viewModel: referralViewModel)
                .task {
                    await referralViewModel.loadReferralState()
                }
        }
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            guard !trackerViewModel.showAnalysisSheet else { return }
                            Task {
                                await viewModel.loadAllConversations()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    viewModel.showHistorySheet = true
                                }
                            }
                        }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 18, weight: .medium))
                                .overlay(Circle().stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
                        }
                    }

                    ToolbarItem(placement: .principal) {
                        Menu {
                            ForEach(AIMode.allCases) { mode in
                                Button(action: {
                                    guard !viewModel.showMedicalDisclaimer,
                                          !viewModel.showEmergencyAlert,
                                          !showCamera,
                                          !trackerViewModel.showAnalysisSheet else { return }
                                    guard mode != viewModel.selectedAIMode else { return }
                                    guard !isModeSwitching else { return }

                                    if !viewModel.messages.isEmpty {
                                        pendingModeSwitch = mode
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            showModeSwitchConfirmation = true
                                        }
                                        return
                                    }
                                    performModeSwitch(to: mode)
                                }) {
                                    Label {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(mode.displayName)
                                            Text(mode.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    } icon: {
                                        Image(systemName: mode.icon)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: viewModel.selectedAIMode.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(viewModel.selectedAIMode == .medical ? Color(hex: "00A86B") : Color(hex: "2E3192"))
                                    .symbolEffect(.bounce, value: viewModel.selectedAIMode)
                                Text(viewModel.selectedAIMode.displayName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        viewModel.selectedAIMode == .medical
                                            ? Color(hex: "00A86B").opacity(0.2)
                                            : Color(hex: "2E3192").opacity(0.15),
                                        lineWidth: 0.5
                                    )
                            )
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.selectedAIMode)
                        }
                        .disabled(viewModel.showMedicalDisclaimer || viewModel.showEmergencyAlert || showCamera || trackerViewModel.showAnalysisSheet || isModeSwitching)
                    }

                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            isInputFocused = false
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(viewModel.selectedAIMode == .medical ? Color(hex: "00A86B") : Color(hex: "2E3192"))
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(action: {
                                viewModel.showBookmarksSheet = true
                            }) {
                                Label("Saved Advice", systemImage: "bookmark.fill")
                            }
                            Button(role: .destructive, action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    viewModel.clearChat()
                                    showEmptyState = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                            showEmptyState = true
                                        }
                                    }
                                }
                            }) {
                                Label("Clear Chat", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .medium))
                        }
                    }
                }
        }
        // Only show alert for non-chat errors (like history loading failures)
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil && viewModel.currentErrorState == nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        // Mode switch confirmation dialog
        .alert("Switch Mode?", isPresented: $showModeSwitchConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingModeSwitch = nil
            }
            Button("Clear & Switch", role: .destructive) {
                if let mode = pendingModeSwitch {
                    viewModel.clearChat()
                    performModeSwitch(to: mode)
                }
                pendingModeSwitch = nil
            }
        } message: {
            if let mode = pendingModeSwitch {
                Text("Switching to \(mode.displayName) will clear your current conversation. Continue?")
            }
        }
        .sheet(isPresented: $trackerViewModel.showAnalysisSheet) {
            AnalysisResultView(
                state: trackerViewModel.analysisState,
                onDismiss: { trackerViewModel.dismissAnalysis() }
            )
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showHistorySheet && !trackerViewModel.showAnalysisSheet },
            set: { viewModel.showHistorySheet = $0 }
        )) {
            ConversationHistoryView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showBookmarksSheet) {
            BookmarkedMessagesView(viewModel: viewModel)
        }
        // Medical Disclaimer Sheet
        .sheet(isPresented: $viewModel.showMedicalDisclaimer) {
            MedicalDisclaimerView(
                onAcknowledge: {
                    viewModel.acknowledgeMedicalDisclaimer()
                },
                onCancel: {
                    viewModel.showMedicalDisclaimer = false
                }
            )
            .presentationDetents([.large])
        }
        // Emergency Alert Sheet
        .sheet(isPresented: $viewModel.showEmergencyAlert) {
            EmergencyAlertView(
                onDismiss: {
                    viewModel.dismissEmergencyAlert()
                },
                onCallEmergency: {
                    // Emergency call functionality removed
                }
            )
            .presentationDetents([.medium])
        }
        // Image Source Selection Sheet (Camera or Library)
        .confirmationDialog("Choose Image Source", isPresented: $showImageSourceSheet, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") {
                    useCamera = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showImageTypeSheet = true
                    }
                }
            }
            Button("Choose from Library") {
                useCamera = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showImageTypeSheet = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        // Image Type Selection Sheet
        .confirmationDialog("What are you scanning?", isPresented: $showImageTypeSheet, titleVisibility: .visible) {
            Button("Food Photo") {
                isFoodPhotoMode = true
                openImageSource()
            }
            Button("Prescription") {
                isFoodPhotoMode = false
                selectedImageType = .prescription
                openImageSource()
            }
            Button("Lab Report") {
                isFoodPhotoMode = false
                selectedImageType = .labReport
                openImageSource()
            }
            Button("Medical Document") {
                isFoodPhotoMode = false
                selectedImageType = .medicalDocument
                openImageSource()
            }
            Button("X-Ray / Scan") {
                isFoodPhotoMode = false
                selectedImageType = .xray
                openImageSource()
            }
            Button("Other Medical Image") {
                isFoodPhotoMode = false
                selectedImageType = .general
                openImageSource()
            }
            Button("Cancel", role: .cancel) {
                useCamera = false
            }
        }
        // Photo Picker
        .photosPicker(
            isPresented: $showImagePicker,
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                guard let newItem = newItem else { return }
                defer { selectedPhotoItem = nil }
                do {
                    guard let data = try await newItem.loadTransferable(type: Data.self) else {
                        toastMessage = "Could not load image"
                        toastIcon = "exclamationmark.triangle"
                        toastColor = .orange
                        withAnimation { showToast = true }
                        return
                    }
                    if isFoodPhotoMode {
                        await viewModel.analyzeFoodImage(data)
                        isFoodPhotoMode = false
                    } else {
                        viewModel.setSelectedImage(data)
                        await viewModel.analyzeSelectedImage(type: selectedImageType)
                    }
                } catch {
                    toastMessage = "Failed to load image"
                    toastIcon = "exclamationmark.triangle"
                    toastColor = .orange
                    withAnimation { showToast = true }
                }
            }
        }
        // Camera Sheet
        .sheet(isPresented: $showCamera) {
            CameraImagePicker(image: $capturedImage, sourceType: .camera)
                .ignoresSafeArea()
        }
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage, let imageData = image.jpegData(compressionQuality: 0.8) {
                if isFoodPhotoMode {
                    Task {
                        await viewModel.analyzeFoodImage(imageData)
                        isFoodPhotoMode = false
                    }
                } else {
                    viewModel.setSelectedImage(imageData)
                    Task {
                        await viewModel.analyzeSelectedImage(type: selectedImageType)
                    }
                }
                capturedImage = nil
            }
        }
        .task {
            await trackerViewModel.loadData()
            await hydrationViewModel.loadData()
            await viewModel.loadHistory()
            // Mark loaded history messages as already animated (no typewriter for history)
            typewriterAnimatedIds = Set(viewModel.messages.map(\.id))
        }
        // Meal Type Picker for Add to Diet
        .confirmationDialog("Add to which meal?", isPresented: $showMealTypePicker, titleVisibility: .visible) {
            ForEach(MealType.allCases) { meal in
                Button(meal.displayName) {
                    if let food = pendingFoodForDiet {
                        Task {
                            await dietViewModel.logFoodFromSnap(result: food, mealType: meal, quantity: food.servingSize)
                            toastMessage = "\(food.name) added to \(meal.displayName)"
                            toastIcon = "checkmark.circle.fill"
                            toastColor = Color(hex: "22C55E")
                            withAnimation { showToast = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { showToast = false }
                            }
                        }
                        pendingFoodForDiet = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                pendingFoodForDiet = nil
            }
        }
    }
    
    // MARK: - Chat View
    
    private var chatView: some View {
        ZStack {
            // Premium Background
            PremiumBackground()
            
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            if viewModel.messages.isEmpty {
                                // Intro / Landing UI
                                introView
                                    .padding(.top, 60)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            } else {
                                ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                                    ChatBubble(
                                        message: message,
                                        loadingOperation: viewModel.currentLoadingOperation,
                                        shouldTypewrite: !message.isUser && !message.isLoading && !typewriterAnimatedIds.contains(message.id),
                                        onFeedback: { feedback in
                                            viewModel.submitFeedback(messageId: message.id, feedback: feedback)
                                            if feedback == .helpful {
                                                reactionMessageId = message.id
                                                withAnimation(.spring(response: 0.3)) { showHelpfulReaction = true }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                                    withAnimation { showHelpfulReaction = false }
                                                    reactionMessageId = nil
                                                }
                                            }
                                        },
                                        onTypewriteComplete: {
                                            typewriterAnimatedIds.insert(message.id)
                                        },
                                        onBookmark: !message.isUser && !message.isLoading ? {
                                            viewModel.toggleBookmark(messageId: message.id)
                                        } : nil,
                                        onSpeak: !message.isUser && !message.isLoading ? { text in
                                            if speechManager.isSpeaking {
                                                speechManager.stopSpeaking()
                                                // If tapping the same message that's speaking, just stop
                                                // If tapping a different message, switch to it
                                                if speechManager.lastSpokenText != text {
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                        speechManager.speak(text)
                                                    }
                                                }
                                            } else {
                                                speechManager.speak(text)
                                            }
                                        } : nil,
                                        onAddToDiet: message.foodResult != nil ? { food in
                                            pendingFoodForDiet = food
                                            showMealTypePicker = true
                                        } : nil,
                                        isSpeaking: speechManager.isSpeaking && !message.isUser && !message.isLoading
                                    )
                                    .id(message.id)
                                    .transition(
                                            .asymmetric(
                                                insertion: .move(edge: message.isUser ? .trailing : .leading)
                                                    .combined(with: .opacity)
                                                    .combined(with: .scale(scale: 0.8)),
                                                removal: .opacity.combined(with: .scale(scale: 0.9))
                                            )
                                        )
                                }
                                
                                // Follow-up suggestions after last AI response
                                if let lastMessage = viewModel.messages.last,
                                   !lastMessage.isUser,
                                   !lastMessage.isLoading,
                                   !viewModel.chatState.isBusy {
                                    FollowUpSuggestionsView(
                                        suggestions: FollowUpSuggestion.suggestions(for: lastMessage.responseMode),
                                        onSelect: { suggestion in
                                            viewModel.inputText = suggestion.prompt
                                            Task { await viewModel.sendMessage() }
                                        }
                                    )
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                                }

                                // Inline error view
                                if let errorState = viewModel.currentErrorState {
                                    InlineErrorView(
                                        errorState: errorState,
                                        onRetry: {
                                            Task { await viewModel.retryLastMessage() }
                                        },
                                        onSwitchMode: {
                                            Task { await viewModel.switchToGeneralAndRetry() }
                                        },
                                        onDismiss: {
                                            viewModel.dismissError()
                                        }
                                    )
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isInputFocused = false
                        }
                        .padding()
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.messages.count)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                            // Subtle haptic when AI responds
                            if !lastMessage.isUser && !lastMessage.isLoading {
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            }
                        }
                    }
                }
                
                // Suggestions + Input Bar
                chatInputBar
            }
        }
        .overlay(alignment: .top) {
            // Toast notification
            if showToast {
                ToastView(message: toastMessage, icon: toastIcon, color: toastColor)
                    .padding(.top, 60)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            
            // First-time mode selector tooltip
            if showModeTooltip {
                ModeTooltipView(onDismiss: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showModeTooltip = false
                    }
                    // Mark as seen
                    UserDefaults.standard.set(true, forKey: "ai_mode_tooltip_seen")
                })
                .padding(.top, 50)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        // Mode transition color wave overlay
        .overlay {
            if modeTransitionProgress > 0 {
                Circle()
                    .fill(modeTransitionColor.opacity(0.15))
                    .scaleEffect(modeTransitionProgress * 4)
                    .opacity(1 - modeTransitionProgress)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .onChange(of: viewModel.selectedAIMode) { _, newMode in
            // Trigger mode transition color wave
            modeTransitionColor = newMode == .medical ? Color(hex: "00A86B") : Color(hex: "2E3192")
            modeTransitionProgress = 0
            withAnimation(.easeOut(duration: 0.6)) {
                modeTransitionProgress = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                modeTransitionProgress = 0
            }
        }
        .onAppear {
            AppAnalyticsService.shared.logScreen("AI", durationSeconds: 0)
            // Trigger landing animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    showEmptyState = true
                }
            }
            // Check if we should show the tooltip
            checkFirstTimeTooltip()
            // Check if we should show onboarding tour
            if !UserDefaults.standard.bool(forKey: "ai_onboarding_completed") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.spring(response: 0.4)) {
                        showOnboardingTour = true
                        onboardingStep = 0
                    }
                }
            }
        }
        // Onboarding tour overlay
        .overlay {
            if showOnboardingTour {
                AIOnboardingOverlay(
                    step: $onboardingStep,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.3)) { showOnboardingTour = false }
                        UserDefaults.standard.set(true, forKey: "ai_onboarding_completed")
                    }
                )
                .transition(.opacity)
            }
        }
        // Helpful reaction overlay
        .overlay {
            if showHelpfulReaction {
                HelpfulReactionView()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
    }
    
    private func checkFirstTimeTooltip() {
        let tooltipSeen = UserDefaults.standard.bool(forKey: "ai_mode_tooltip_seen")
        let visitCount = UserDefaults.standard.integer(forKey: "ai_view_visit_count")
        
        // Increment visit count
        UserDefaults.standard.set(visitCount + 1, forKey: "ai_view_visit_count")
        
        // Show tooltip on first 2 visits if not dismissed
        if !tooltipSeen && visitCount < 2 {
            // Delay to let the view settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showModeTooltip = true
                }
            }
        }
    }
    
    // MARK: - Intro View
    
    // MARK: - Greeting Helpers

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let firstName = authViewModel.userName.components(separatedBy: " ").first ?? "there"
        switch hour {
        case 5..<12: return "Good morning, \(firstName)"
        case 12..<17: return "Good afternoon, \(firstName)"
        case 17..<22: return "Good evening, \(firstName)"
        default: return "Hey, \(firstName)"
        }
    }

    private var greetingSubtitle: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "How are you feeling today?\nLet's check in on your health."
        case 12..<17: return "Need a midday health check?\nI'm here to help."
        case 17..<22: return "Let's review your day.\nAsk me anything about your health."
        default: return "Can't sleep?\nI'm here if you need health advice."
        }
    }

    @ViewBuilder
    private var proactiveNudgesView: some View {
        let nudges = HealthNudge.generate(
            steps: trackerViewModel.stepCount,
            heartRate: trackerViewModel.heartRate,
            calories: trackerViewModel.activeCalories,
            lastWaterLog: hydrationViewModel.todaysEntries.first?.timestamp
        )
        if !nudges.isEmpty {
            VStack(spacing: 8) {
                ForEach(nudges) { nudge in
                    ProactiveNudgeCard(nudge: nudge) {
                        viewModel.inputText = nudge.prompt
                        Task { await viewModel.sendMessage() }
                    }
                }
            }
            .padding(.horizontal, 16)
            .opacity(showEmptyState ? 1 : 0)
            .offset(y: showEmptyState ? 0 : 15)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.22), value: showEmptyState)
        }
    }

    private var introView: some View {
        VStack(spacing: 0) {
            // Particle Orb - Hero element
            ParticleOrbView(state: orbState, isMedicalMode: viewModel.selectedAIMode == .medical)
                .frame(width: 160, height: 160)
                .scaleEffect(showEmptyState ? 1 : 0.6)
                .opacity(showEmptyState ? 1 : 0)
                .animation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.05), value: showEmptyState)

            VStack(spacing: 6) {
                Text(greeting)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(greetingSubtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineSpacing(3)
            }
            .offset(y: showEmptyState ? 0 : 20)
            .opacity(showEmptyState ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15), value: showEmptyState)
            .padding(.bottom, 20)

            // AI Personality Roster (Swastri, Coach, Nutri, Zen, Luna)
            if viewModel.selectedAIMode == .general {
                AIRosterPicker(selected: $viewModel.selectedPersonality)
                    .opacity(showEmptyState ? 1 : 0)
                    .offset(y: showEmptyState ? 0 : 12)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: showEmptyState)
                    .padding(.bottom, 16)
            }

            // Health Vitals Strip
            HealthVitalsStrip(
                steps: trackerViewModel.stepCount,
                heartRate: trackerViewModel.heartRate,
                calories: trackerViewModel.activeCalories,
                onTapMetric: { prompt in
                    viewModel.inputText = prompt
                    Task { await viewModel.sendMessage() }
                }
            )
            .padding(.horizontal, 16)
            .opacity(showEmptyState ? 1 : 0)
            .offset(y: showEmptyState ? 0 : 12)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.22), value: showEmptyState)
            .padding(.bottom, 14)

            // Proactive Health Nudges (client-side)
            proactiveNudgesView
                .padding(.bottom, 14)

            // Server-side AI Nudges
            NudgeCardsView(
                nudges: DependencyContainer.shared.homeViewModel.serverNudges,
                onDismiss: { nudge in
                    Task { await DependencyContainer.shared.homeViewModel.dismissNudge(nudge) }
                },
                onAction: { nudge in
                    Task { await DependencyContainer.shared.homeViewModel.actOnNudge(nudge) }
                    if let deeplink = nudge.actionDeeplink, let url = URL(string: deeplink) {
                        UIApplication.shared.open(url)
                    }
                }
            )
            .opacity(showEmptyState ? 1 : 0)
            .offset(y: showEmptyState ? 0 : 12)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.25), value: showEmptyState)
            .padding(.bottom, 14)

            // Quick Action Grid
            QuickActionGrid(
                actions: Array(QuickAction.suggestions.prefix(4)),
                showEmptyState: showEmptyState,
                onAction: { action in
                    Task { await viewModel.sendQuickAction(action) }
                }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            // Deep Dive CTA
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task { await trackerViewModel.requestAIAnalysis() }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Deep Health Analysis")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(Color(hex: "2E3192"))
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .background(
                    Capsule()
                        .fill(Color(hex: "2E3192").opacity(0.1))
                )
                .overlay(
                    Capsule()
                        .stroke(Color(hex: "2E3192").opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(trackerViewModel.analysisState.isAnalyzing)
            .opacity(showEmptyState ? 1 : 0)
            .offset(y: showEmptyState ? 0 : 15)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.35), value: showEmptyState)
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Orb State Determination
    
    private var orbState: ParticleOrbView.OrbState {
        // Listening state takes priority
        if speechManager.isRecording {
            return .listening
        }
        
        // Thinking state when processing
        if viewModel.chatState.isBusy || viewModel.messages.contains(where: { $0.isLoading }) {
            return .thinking
        }
        
        // Default idle state
        return .idle
    }
    
    // MARK: - Suggestions Scroll
    
    private var suggestionsScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(QuickAction.suggestions.prefix(5).enumerated()), id: \.element.id) { index, action in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        Task { await viewModel.sendQuickAction(action) }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: action.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "2E3192"))
                            Text(action.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color(hex: "2E3192").opacity(0.06))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color(hex: "2E3192").opacity(0.12), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .opacity(showEmptyState ? 1 : 0)
                    .offset(y: showEmptyState ? 0 : 12)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.06 + 0.3),
                        value: showEmptyState
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Image Source Helper
    
    private func openImageSource() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if useCamera && UIImagePickerController.isSourceTypeAvailable(.camera) {
                showCamera = true
            } else {
                // Fallback to library if camera not available (e.g., Simulator)
                showImagePicker = true
            }
        }
    }
    
    private func performModeSwitch(to mode: AIMode) {
        isModeSwitching = true
        
        // Delay to allow menu/dialog to dismiss first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.selectedAIMode = mode
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            
            // Show toast notification
            toastMessage = "Switched to \(mode.displayName)"
            toastIcon = mode.icon
            toastColor = mode == .medical ? Color(hex: "00A86B") : Color(hex: "2E3192")
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showToast = true
            }
            
            // Auto-hide toast after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showToast = false
                }
            }
            
            // Reset debounce flag after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isModeSwitching = false
            }
        }
    }
    
    private var chatInputBar: some View {
        VStack(spacing: 0) {
            // Medical disclaimer banner when in Medical Expert mode
            if viewModel.selectedAIMode == .medical {
                MedicalDisclaimerBanner()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Voice recording status badge
            if speechManager.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    Text("Listening...")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(viewModel.selectedAIMode == .medical ? Color(hex: "00A86B") : Color(hex: "2E3192"))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill((viewModel.selectedAIMode == .medical ? Color(hex: "00A86B") : Color(hex: "2E3192")).opacity(0.1))
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .padding(.bottom, 8)
            }

            // Modern floating input container
            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 0) {
                    // Attachment + Mic row (left side)
                    HStack(spacing: 4) {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showImageSourceSheet = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(viewModel.isAnalyzingImage ? Color(hex: "2E3192") : .secondary.opacity(0.6))
                        }
                        .disabled(viewModel.isAnalyzingImage)

                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            Task {
                                if speechManager.isRecording {
                                    speechManager.stopRecording()
                                } else {
                                    do {
                                        try await speechManager.startRecording()
                                    } catch {
                                        print("Voice input error: \(error)")
                                    }
                                }
                            }
                        }) {
                            Image(systemName: speechManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(
                                    speechManager.isRecording
                                        ? (viewModel.selectedAIMode == .medical ? Color(hex: "00A86B") : Color(hex: "2E3192"))
                                        : .secondary.opacity(0.6)
                                )
                                .symbolEffect(.bounce, value: speechManager.isRecording)
                        }
                    }
                    .padding(.leading, 8)
                    .padding(.bottom, 8)

                    // Text input
                    TextField(networkMonitor.isConnected ? "Ask anything..." : "AI chat requires internet", text: $viewModel.inputText, axis: .vertical)
                        .disabled(!networkMonitor.isConnected)
                        .font(.system(size: 15))
                        .focused($isInputFocused)
                        .lineLimit(1...5)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 15)
                        .onChange(of: speechManager.recognizedText) { _, newValue in
                            if speechManager.isRecording {
                                viewModel.inputText = newValue
                            }
                        }

                    // Send button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if speechManager.isRecording { speechManager.stopRecording() }
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { sendButtonScale = 0.8 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { sendButtonScale = 1.0 }
                        }
                        Task { await viewModel.sendMessage() }
                        isInputFocused = false
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(viewModel.canSend ? Color(hex: "2E3192") : .gray.opacity(0.25))
                            .scaleEffect(sendButtonScale)
                    }
                    .disabled(!viewModel.canSend || !networkMonitor.isConnected)
                    .padding(.trailing, 6)
                    .padding(.bottom, 5)
                    .padding(.top, 5)
                }
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(
                            isInputFocused
                                ? Color(hex: "2E3192").opacity(0.3)
                                : Color.primary.opacity(0.08),
                            lineWidth: isInputFocused ? 1 : 0.5
                        )
                )
                .animation(.easeOut(duration: 0.2), value: isInputFocused)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            .padding(.top, 10)

        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.selectedAIMode)
        .onChange(of: speechManager.isRecording) { _, isRecording in
            if !isRecording && !speechManager.recognizedText.isEmpty {
                viewModel.inputText = speechManager.recognizedText
            }
        }
    }
    
}

// MARK: - Markdown Text View

private struct MarkdownTextView: View {
    let content: String

    var body: some View {
        if let attributed = try? AttributedString(markdown: content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
                .font(.system(size: 15))
                .tint(Color(hex: "2E3192"))
        } else {
            Text(content)
                .font(.system(size: 15))
        }
    }
}

// MARK: - Typewriter Markdown View

private struct TypewriterMarkdownView: View {
    let content: String
    let onComplete: () -> Void

    @State private var visibleWordCount: Int = 0
    @State private var isComplete = false
    @State private var wordChunks: [String] = []

    private static func splitIntoWords(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for char in text {
            current.append(char)
            if char == " " || char == "\n" {
                result.append(current)
                current = ""
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    var body: some View {
        Group {
            if isComplete {
                MarkdownTextView(content: content)
            } else {
                Text(wordChunks.prefix(visibleWordCount).joined())
                    .font(.system(size: 15))
            }
        }
        .task {
            defer {
                isComplete = true
                onComplete()
            }
            guard !content.isEmpty else {
                return
            }
            let allWords = Self.splitIntoWords(content)
            wordChunks = allWords
            let total = allWords.count

            // Word-by-word streaming with variable delays for natural feel
            // Simulates real API token streaming
            while visibleWordCount < total && !Task.isCancelled {
                // Burst 1-3 words at a time (like token chunks from API)
                let burst = min(Int.random(in: 1...3), total - visibleWordCount)
                visibleWordCount += burst

                // Variable delay: shorter for mid-sentence, longer at punctuation
                let lastWord = allWords[min(visibleWordCount - 1, total - 1)]
                let isPunctuation = lastWord.last == "." || lastWord.last == "!" || lastWord.last == "?" || lastWord.last == ":"
                let isNewline = lastWord.contains("\n")

                let delay: UInt64
                if isPunctuation || isNewline {
                    delay = UInt64.random(in: 40_000_000...80_000_000)  // 40-80ms pause at sentences
                } else if total > 100 {
                    delay = UInt64.random(in: 12_000_000...25_000_000)  // 12-25ms for long responses
                } else {
                    delay = UInt64.random(in: 20_000_000...40_000_000)  // 20-40ms for short responses
                }
                try? await Task.sleep(nanoseconds: delay)
            }
        }
    }
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let message: ChatMessage
    let loadingOperation: LoadingOperationType
    let onFeedback: ((MessageFeedback) -> Void)?
    let shouldTypewrite: Bool
    let onTypewriteComplete: (() -> Void)?
    let onBookmark: (() -> Void)?
    let onSpeak: ((String) -> Void)?
    let onAddToDiet: ((SnapFoodResult) -> Void)?
    let isSpeaking: Bool
    @State private var appeared = false
    @State private var showFeedbackButtons = false
    @State private var showCopied = false

    init(message: ChatMessage, loadingOperation: LoadingOperationType, shouldTypewrite: Bool = false, onFeedback: ((MessageFeedback) -> Void)? = nil, onTypewriteComplete: (() -> Void)? = nil, onBookmark: (() -> Void)? = nil, onSpeak: ((String) -> Void)? = nil, onAddToDiet: ((SnapFoodResult) -> Void)? = nil, isSpeaking: Bool = false) {
        self.message = message
        self.loadingOperation = loadingOperation
        self.shouldTypewrite = shouldTypewrite
        self.onFeedback = onFeedback
        self.onTypewriteComplete = onTypewriteComplete
        self.onBookmark = onBookmark
        self.onSpeak = onSpeak
        self.onAddToDiet = onAddToDiet
        self.isSpeaking = isSpeaking
    }
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
            if !message.isUser {
                HStack(spacing: 5) {
                    MiniAIOrb(size: 16)
                    Text("Swastri")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "2E3192"))
                    if let mode = message.responseMode {
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text(mode.badgeText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: mode.badgeColor))
                    }
                    Text(formatMessageTime(message.timestamp))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .padding(.leading, 2)
            }

            HStack {
                if message.isUser { Spacer(minLength: 60) }

                if message.isLoading {
                    TypingIndicator(loadingOperation: loadingOperation)
                } else {
                    VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                        // Food Analysis Card — show card only, no raw text
                        if let foodResult = message.foodResult {
                            FoodAnalysisCardView(foodResult: foodResult, onAddToDiet: onAddToDiet)
                                .scaleEffect(appeared ? 1 : 0.85)
                                .opacity(appeared ? 1 : 0)
                        } else {
                        Group {
                            if message.isUser {
                                Text(message.content)
                                    .font(.system(size: 15))
                            } else if shouldTypewrite {
                                TypewriterMarkdownView(content: message.content) {
                                    onTypewriteComplete?()
                                }
                            } else {
                                MarkdownTextView(content: message.content)
                            }
                        }
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .foregroundColor(message.isUser ? .white : .primary)
                        .background(
                            Group {
                                if message.isUser {
                                    LinearGradient(
                                        colors: [Color(hex: "2E3192"), Color(hex: "4A5FD5")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                } else {
                                    Color(UIColor.secondarySystemBackground).opacity(0.8)
                                }
                            }
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 18)
                        )
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = message.content
                                showCopied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showCopied = false }
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            ShareLink(item: message.content) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                        .scaleEffect(appeared ? 1 : 0.85)
                        .opacity(appeared ? 1 : 0)
                        } // end else (non-food message)

                        // Inline health metric pills (skip for food analysis)
                        if !message.isUser && !message.isLoading && message.foodResult == nil {
                            let metrics = Self.detectHealthMetrics(in: message.content)
                            if !metrics.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(metrics, id: \.label) { metric in
                                            InlineHealthMetricCard(icon: metric.icon, label: metric.label, value: metric.value, color: metric.color)
                                        }
                                    }
                                }
                                .scaleEffect(appeared ? 1 : 0.9)
                                .opacity(appeared ? 1 : 0)
                                .animation(.spring(response: 0.5).delay(0.2), value: appeared)
                            }
                        }

                        // Action toolbar for AI messages
                        if !message.isUser && !message.isLoading {
                            HStack(spacing: 2) {
                                if let onFeedback {
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        onFeedback(.helpful)
                                    }) {
                                        Image(systemName: message.userFeedback == .helpful ? "hand.thumbsup.fill" : "hand.thumbsup")
                                            .font(.system(size: 11))
                                            .foregroundColor(message.userFeedback == .helpful ? Color(hex: "00A86B") : .secondary.opacity(0.5))
                                            .frame(width: 28, height: 28)
                                    }

                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        onFeedback(.notHelpful)
                                    }) {
                                        Image(systemName: message.userFeedback == .notHelpful ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                            .font(.system(size: 11))
                                            .foregroundColor(message.userFeedback == .notHelpful ? .orange : .secondary.opacity(0.5))
                                            .frame(width: 28, height: 28)
                                    }
                                }

                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    UIPasteboard.general.string = message.content
                                    withAnimation(.spring(response: 0.3)) { showCopied = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        withAnimation { showCopied = false }
                                    }
                                }) {
                                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 11))
                                        .foregroundColor(showCopied ? Color(hex: "00A86B") : .secondary.opacity(0.5))
                                        .frame(width: 28, height: 28)
                                }

                                if let onBookmark {
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        onBookmark()
                                    }) {
                                        Image(systemName: message.isBookmarked ? "bookmark.fill" : "bookmark")
                                            .font(.system(size: 11))
                                            .foregroundColor(message.isBookmarked ? Color(hex: "F59E0B") : .secondary.opacity(0.5))
                                            .frame(width: 28, height: 28)
                                    }
                                }

                                if let onSpeak {
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        onSpeak(message.content)
                                    }) {
                                        Image(systemName: isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(isSpeaking ? Color(hex: "2E3192") : .secondary.opacity(0.5))
                                            .frame(width: 28, height: 28)
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                            .scaleEffect(appeared ? 1 : 0.8)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15), value: appeared)
                        }
                    }
                }

                if !message.isUser { Spacer(minLength: 60) }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.05)) {
                appeared = true
            }
        }
    }
    
    private func formatMessageTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if it's today
        if calendar.isDateInToday(date) {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            return timeFormatter.string(from: date)
        }
        
        // Check if it's yesterday
        if calendar.isDateInYesterday(date) {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            return "Yesterday \(timeFormatter.string(from: date))"
        }
        
        // Check if it's within the last week
        if let daysAgo = calendar.dateComponents([.day], from: date, to: now).day, daysAgo < 7 {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            return "\(weekdayFormatter.string(from: date)) \(timeFormatter.string(from: date))"
        }
        
        // For older dates, show the date and time
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: date)
    }

    struct DetectedMetric {
        let icon: String
        let label: String
        let value: String
        let color: String
    }

    static func detectHealthMetrics(in text: String) -> [DetectedMetric] {
        var metrics: [DetectedMetric] = []
        let lower = text.lowercased()

        // Detect step counts (e.g., "5,000 steps", "8000 steps")
        if let range = lower.range(of: #"[\d,]+\s*steps"#, options: .regularExpression) {
            let match = String(lower[range]).replacingOccurrences(of: " ", with: "")
            let value = match.replacingOccurrences(of: "steps", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            metrics.append(DetectedMetric(icon: "figure.walk", label: "Steps", value: value, color: "22C55E"))
        }

        // Detect heart rate (e.g., "72 bpm", "heart rate of 80")
        if let range = lower.range(of: #"\d+\s*bpm"#, options: .regularExpression) {
            let match = String(lower[range])
            let value = match.replacingOccurrences(of: "bpm", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            metrics.append(DetectedMetric(icon: "heart.fill", label: "Heart Rate", value: "\(value) bpm", color: "EF4444"))
        }

        // Detect calories (e.g., "300 calories", "250 kcal")
        if let range = lower.range(of: #"\d+\s*(calories|kcal)"#, options: .regularExpression) {
            let match = String(lower[range])
            let value = match.replacingOccurrences(of: "calories", with: "").replacingOccurrences(of: "kcal", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            metrics.append(DetectedMetric(icon: "flame.fill", label: "Calories", value: "\(value) kcal", color: "F97316"))
        }

        // Detect sleep (e.g., "7 hours of sleep", "8h sleep")
        if let range = lower.range(of: #"\d+\.?\d*\s*(hours? of sleep|h\s*sleep|hours? sleep)"#, options: .regularExpression) {
            let match = String(lower[range])
            let value = match.components(separatedBy: CharacterSet.letters).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            metrics.append(DetectedMetric(icon: "moon.zzz.fill", label: "Sleep", value: "\(value)h", color: "6366F1"))
        }

        return metrics
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    let loadingOperation: LoadingOperationType
    @State private var isAnimating = false

    private var accentColor: Color {
        loadingOperation == .medicalQuery ? Color(hex: "00A86B") : Color(hex: "2E3192")
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(loadingOperation.loadingMessage)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(accentColor.opacity(0.6))
                        .frame(width: 5, height: 5)
                        .offset(y: isAnimating ? -3 : 3)
                        .animation(
                            .easeInOut(duration: 0.4)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1),
                            value: isAnimating
                        )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear { isAnimating = true }
    }
}

// MARK: - Mode Selector Tooltip

private struct ModeTooltipView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Arrow pointing up
            Triangle()
                .fill(Color(UIColor.systemBackground))
                .frame(width: 20, height: 10)
                .shadow(color: Color.black.opacity(0.1), radius: 2, y: -2)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("Pro Tip")
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("Tap here to switch between:")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(Color(hex: "2E3192"))
                            .frame(width: 20)
                        Text("Swastri Assistant")
                            .font(.system(size: 13, weight: .medium))
                        Text("- General wellness chat")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "stethoscope")
                            .foregroundColor(Color(hex: "00A86B"))
                            .frame(width: 20)
                        Text("Medical Expert")
                            .font(.system(size: 13, weight: .medium))
                        Text("- Health information")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: onDismiss) {
                    Text("Got it!")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "2E3192"))
                        .cornerRadius(8)
                }
                .padding(.top, 4)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
            )
        }
        .frame(width: 280)
    }
}

// Helper shape for tooltip arrow
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Toast View

private struct ToastView: View {
    let message: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .overlay(
            Capsule()
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Inline Error View

private struct InlineErrorView: View {
    let errorState: AIErrorState
    let onRetry: () -> Void
    let onSwitchMode: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
                
                Text(errorState.message)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color(UIColor.tertiarySystemFill))
                        .clipShape(Circle())
                }
            }
            
            HStack(spacing: 12) {
                if errorState.canRetry {
                    Button(action: onRetry) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Try Again")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(hex: "2E3192"))
                        .cornerRadius(8)
                    }
                }
                
                if errorState.canSwitchMode {
                    Button(action: onSwitchMode) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Use General Mode")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "2E3192"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(hex: "2E3192").opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Health Vitals Strip

private struct HealthVitalsStrip: View {
    let steps: Int
    let heartRate: Int
    let calories: Int
    let onTapMetric: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            VitalPill(
                icon: "figure.walk",
                value: steps >= 1000 ? String(format: "%.1fk", Double(steps) / 1000.0) : "\(steps)",
                label: "Steps",
                color: "22C55E",
                onTap: { onTapMetric("How are my steps today? Am I on track?") }
            )

            Divider().frame(height: 28).opacity(0.2)

            VitalPill(
                icon: "heart.fill",
                value: heartRate > 0 ? "\(heartRate)" : "--",
                label: "BPM",
                color: "EF4444",
                onTap: { onTapMetric("Analyze my heart rate. Is it healthy?") }
            )

            Divider().frame(height: 28).opacity(0.2)

            VitalPill(
                icon: "flame.fill",
                value: "\(calories)",
                label: "kcal",
                color: "F97316",
                onTap: { onTapMetric("Review my calorie burn today. How can I improve?") }
            )
        }
        .padding(.vertical, 12)
        .glass(cornerRadius: 16)
    }
}

private struct VitalPill: View {
    let icon: String
    let value: String
    let label: String
    let color: String
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: color))
                VStack(alignment: .leading, spacing: 0) {
                    Text(value)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Quick Action Grid

private struct QuickActionGrid: View {
    let actions: [QuickAction]
    let showEmptyState: Bool
    let onAction: (QuickAction) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onAction(action)
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: action.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "2E3192"))
                            .frame(width: 32, height: 32)
                            .background(Color(hex: "2E3192").opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text(action.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glass(cornerRadius: 14)
                }
                .buttonStyle(ScaleButtonStyle())
                .opacity(showEmptyState ? 1 : 0)
                .offset(y: showEmptyState ? 0 : 12)
                .animation(
                    .spring(response: 0.45, dampingFraction: 0.7).delay(Double(index) * 0.06 + 0.28),
                    value: showEmptyState
                )
            }
        }
    }
}

// MARK: - Proactive Nudge Card

private struct ProactiveNudgeCard: View {
    let nudge: HealthNudge
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            HStack(spacing: 10) {
                Image(systemName: nudge.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: nudge.color))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: nudge.color).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                Text(nudge.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: nudge.color).opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(hex: nudge.color).opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: nudge.color).opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - AI Roster Picker

private struct AIRosterPicker: View {
    @Binding var selected: AIPersonality

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AIPersonality.allCases) { personality in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selected = personality
                        }
                    }) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: personality.color).opacity(selected == personality ? 0.18 : 0.08))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                selected == personality ? Color(hex: personality.color).opacity(0.4) : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                Image(systemName: personality.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(hex: personality.color))
                            }

                            Text(personality.displayName)
                                .font(.system(size: 11, weight: selected == personality ? .bold : .medium))
                                .foregroundColor(selected == personality ? Color(hex: personality.color) : .secondary)
                        }
                        .frame(width: 64)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Daily Digest Card (used in history context)

private struct DailyDigestCard: View {
    let steps: Int
    let heartRate: Int
    let calories: Int
    let onAskAI: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onAskAI()
        }) {
            HStack(spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "22C55E"))
                    Text(steps.formatted())
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "EF4444"))
                    Text(heartRate > 0 ? "\(heartRate)" : "--")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "F97316"))
                    Text("\(calories)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "2E3192"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glass(cornerRadius: 12)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Bookmarked Messages View

struct BookmarkedMessagesView: View {
    @ObservedObject var viewModel: AIViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()

                if viewModel.bookmarkedMessages.isEmpty {
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "F59E0B").opacity(0.1))
                                .frame(width: 80, height: 80)
                            Image(systemName: "bookmark")
                                .font(.system(size: 36))
                                .foregroundColor(Color(hex: "F59E0B").opacity(0.5))
                        }
                        VStack(spacing: 6) {
                            Text("No Saved Advice")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.primary)
                            Text("Tap the bookmark icon on any AI response to save it here.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.bookmarkedMessages) { message in
                                BookmarkedMessageCard(message: message, onRemove: {
                                    viewModel.toggleBookmark(messageId: message.id)
                                })
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Saved Advice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct BookmarkedMessageCard: View {
    let message: ChatMessage
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let mode = message.responseMode {
                HStack(spacing: 4) {
                    Image(systemName: mode.badgeIcon)
                        .font(.system(size: 9, weight: .semibold))
                    Text(mode.badgeText)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(Color(hex: mode.badgeColor))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color(hex: mode.badgeColor).opacity(0.12)))
            }

            MarkdownTextView(content: message.content)
                .lineLimit(6)

            HStack {
                Text(message.timestamp, style: .date)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    UIPasteboard.general.string = message.content
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onRemove()
                }) {
                    Image(systemName: "bookmark.slash.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "F59E0B"))
                }
            }
        }
        .padding(14)
        .glass(cornerRadius: 14)
    }
}

// MARK: - Rich Health Card (Inline in AI response)

private struct InlineHealthMetricCard: View {
    let icon: String
    let label: String
    let value: String
    let color: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: color))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(hex: color).opacity(0.06))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color(hex: color).opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - AI Onboarding Overlay

private struct AIOnboardingOverlay: View {
    @Binding var step: Int
    let onDismiss: () -> Void

    private let tourSteps: [(icon: String, title: String, description: String)] = [
        ("bubble.left.and.bubble.right.fill", "Chat with Swastri AI", "Ask any health question. I use your real health data to give personalised advice."),
        ("stethoscope", "Switch Modes", "Tap the mode selector at the top to switch between General and Medical Expert mode."),
        ("mic.fill", "Voice Input", "Tap the mic icon to ask questions with your voice. I'll listen and respond."),
        ("doc.viewfinder", "Image Analysis", "Upload prescriptions, lab reports, or X-rays for AI-powered analysis."),
        ("bookmark.fill", "Save Advice", "Bookmark important AI responses to review them later from the menu.")
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { advanceOrDismiss() }

            VStack(spacing: 20) {
                Spacer()

                VStack(spacing: 16) {
                    // Step indicator
                    HStack(spacing: 6) {
                        ForEach(0..<tourSteps.count, id: \.self) { i in
                            Capsule()
                                .fill(i == step ? Color(hex: "2E3192") : Color.white.opacity(0.3))
                                .frame(width: i == step ? 24 : 8, height: 4)
                                .animation(.spring(response: 0.3), value: step)
                        }
                    }

                    ZStack {
                        Circle()
                            .fill(Color(hex: "2E3192").opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: tourSteps[step].icon)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(Color(hex: "2E3192"))
                    }

                    Text(tourSteps[step].title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text(tourSteps[step].description)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    HStack(spacing: 12) {
                        Button("Skip") { onDismiss() }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))

                        Button(action: { advanceOrDismiss() }) {
                            Text(step < tourSteps.count - 1 ? "Next" : "Get Started")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color(hex: "2E3192"))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(28)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }

    private func advanceOrDismiss() {
        if step < tourSteps.count - 1 {
            withAnimation(.spring(response: 0.3)) { step += 1 }
        } else {
            onDismiss()
        }
    }
}

// MARK: - Helpful Reaction View

private struct HelpfulReactionView: View {
    @State private var particles: [(offset: CGSize, opacity: Double, scale: CGFloat)] = []

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Text(["✨", "🎉", "💚", "⭐️", "✨", "💪", "🌟", "💚"][i])
                    .font(.system(size: 24))
                    .offset(particles.indices.contains(i) ? particles[i].offset : .zero)
                    .opacity(particles.indices.contains(i) ? particles[i].opacity : 0)
                    .scaleEffect(particles.indices.contains(i) ? particles[i].scale : 0.5)
            }
        }
        .onAppear {
            particles = (0..<8).map { _ in
                (
                    offset: .zero,
                    opacity: 1.0,
                    scale: CGFloat(0.5)
                )
            }
            withAnimation(.easeOut(duration: 1.0)) {
                particles = (0..<8).map { i in
                    let angle = Double(i) * .pi / 4
                    let distance = CGFloat.random(in: 60...120)
                    return (
                        offset: CGSize(width: cos(angle) * distance, height: sin(angle) * distance - 40),
                        opacity: 0.0,
                        scale: CGFloat.random(in: 0.8...1.4)
                    )
                }
            }
        }
    }
}

// MARK: - Follow-Up Suggestions View

private struct FollowUpSuggestionsView: View {
    let suggestions: [FollowUpSuggestion]
    let onSelect: (FollowUpSuggestion) -> Void
    @State private var appeared = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSelect(suggestion)
                    }) {
                        Text(suggestion.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "2E3192"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "2E3192").opacity(0.06))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color(hex: "2E3192").opacity(0.1), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.7).delay(Double(index) * 0.06 + 0.15),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            withAnimation { appeared = true }
        }
    }
}

// MARK: - Ethereal AI Orb (Premium Fluid Design)

private struct AIOrb: View {
    let size: CGFloat
    let showGlow: Bool
    
    // Animation States for 4 fluid blobs
    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero
    @State private var offset3: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0
    
    init(size: CGFloat = 80, showGlow: Bool = true) {
        self.size = size
        self.showGlow = showGlow
    }
    
    var body: some View {
        ZStack {
            // 1. Ambient Background Glow (The "Aura")
            if showGlow {
                Circle()
                    .fill(Color(hex: "2E3192").opacity(0.25))
                    .frame(width: size * 1.6, height: size * 1.6)
                    .blur(radius: size * 0.3)
                    .scaleEffect(scale)
            }
            
            // 2. The Fluid Core Container
            ZStack {
                // Background Base
                Circle()
                    .fill(Color(hex: "0F1123")) // Deep dark void blue
                    .frame(width: size, height: size)
                
                // Fluid Blob 1: Electric Blue (Main Mover)
                FluidBlob(color: Color(hex: "4A90E2"), size: size * 0.8)
                    .offset(offset1)
                    .blur(radius: size * 0.2)
                    .blendMode(.screen)
                
                // Fluid Blob 2: Vivid Purple (Contrast)
                FluidBlob(color: Color(hex: "6B5CE7"), size: size * 0.7)
                    .offset(offset2)
                    .blur(radius: size * 0.2)
                    .blendMode(.screen)
                
                // Fluid Blob 3: Bright Cyan (Highlight)
                FluidBlob(color: Color(hex: "00F0FF"), size: size * 0.6)
                    .offset(offset3)
                    .blur(radius: size * 0.25)
                    .blendMode(.overlay)
                
                // Fluid Blob 4: White/Blue Core (Center Energy)
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: size * 0.3, height: size * 0.3)
                    .blur(radius: size * 0.15)
                    .blendMode(.overlay)
                    .scaleEffect(scale)
            }
            .mask(Circle()) // Clip everything to a perfect circle
            .overlay(
                // Glass Reflection / Gloss
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.05), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .rotationEffect(.degrees(rotation))
            
            // 3. Subtle Inner Sparkles (Stars)
            if showGlow {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 2, height: 2)
                        .offset(x: CGFloat.random(in: -size/3...size/3), y: CGFloat.random(in: -size/3...size/3))
                        .opacity(Double.random(in: 0.3...0.8))
                        .animation(
                            .easeInOut(duration: Double.random(in: 1...3)).repeatForever(autoreverses: true),
                            value: scale
                        )
                }
            }
        }
        .onAppear {
            startFluidAnimation()
        }
    }
    
    private func startFluidAnimation() {
        // Blob 1 Motion (Elliptical)
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            offset1 = CGSize(width: size * 0.15, height: -size * 0.1)
        }
        
        // Blob 2 Motion (Opposite)
        withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
            offset2 = CGSize(width: -size * 0.15, height: size * 0.15)
        }
        
        // Blob 3 Motion (Wandering)
        withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
            offset3 = CGSize(width: size * 0.1, height: size * 0.1)
        }
        
        // Breathing Scale (Heartbeat)
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            scale = 1.1
        }
        
        // Slow Rotation (Drifting)
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }
}

// Helper view for blobs
private struct FluidBlob: View {
    let color: Color
    let size: CGFloat
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

// MARK: - Mini Ethereal Orb (Chat Bubble)

private struct MiniAIOrb: View {
    let size: CGFloat
    
    @State private var rotation: Double = 0
    @State private var pulse: CGFloat = 1.0
    
    init(size: CGFloat = 14) {
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(Color(hex: "0F1123"))
                .frame(width: size, height: size)
            
            // Spinning gradients
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Color(hex: "4A90E2"),
                            Color(hex: "6B5CE7"),
                            Color(hex: "00F0FF"),
                            Color(hex: "4A90E2")
                        ],
                        center: .center
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotation))
                .blur(radius: size * 0.3)
            
            // Core highlight
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: size * 0.4, height: size * 0.4)
                .blur(radius: size * 0.2)
                .scaleEffect(pulse)
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulse = 1.2
            }
        }
    }
}

// MARK: - Animated Sparkle Icon (Legacy)

private struct AnimatedSparkleIcon: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "2E3192").opacity(0.15))
                .frame(width: 100, height: 100)
                .blur(radius: 20)
                .scaleEffect(isAnimating ? 1.2 : 0.9)
                .opacity(isAnimating ? 0.8 : 0.5)
                .animation(
                    .easeInOut(duration: 2).repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundColor(Color(hex: "2E3192"))
                .scaleEffect(isAnimating ? 1.05 : 1.0)
                .rotationEffect(.degrees(isAnimating ? 5 : -5))
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Quick Action Button Style

private struct QuickActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
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
                .foregroundColor(Color(hex: "2E3192"))
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

// MARK: - Conversation History View

struct ConversationHistoryView: View {
    @ObservedObject var viewModel: AIViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var conversationToDelete: ConversationSummary?
    @State private var showDeleteConfirmation = false
    @State private var searchText = ""

    private var filteredConversations: [ConversationSummary] {
        guard !searchText.isEmpty else { return viewModel.conversations }
        let query = searchText.lowercased()
        return viewModel.conversations.filter {
            $0.title.lowercased().contains(query) ||
            $0.lastMessage.lowercased().contains(query) ||
            $0.topic.label.lowercased().contains(query)
        }
    }

    /// Group conversations by date category (Today, Yesterday, This Week, This Month, Older)
    private var groupedConversations: [(key: String, conversations: [ConversationSummary])] {
        let calendar = Calendar.current
        let now = Date()

        let grouped = Dictionary(grouping: filteredConversations) { conv -> String in
            if calendar.isDateInToday(conv.updatedAt) {
                return "Today"
            } else if calendar.isDateInYesterday(conv.updatedAt) {
                return "Yesterday"
            } else if let daysAgo = calendar.dateComponents([.day], from: conv.updatedAt, to: now).day, daysAgo < 7 {
                return "This Week"
            } else if calendar.isDate(conv.updatedAt, equalTo: now, toGranularity: .month) {
                return "This Month"
            } else {
                return "Older"
            }
        }

        let order = ["Today", "Yesterday", "This Week", "This Month", "Older"]
        return order.compactMap { key in
            guard let convs = grouped[key], !convs.isEmpty else { return nil }
            return (key: key, conversations: convs)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()

                if viewModel.isLoadingConversations {
                    conversationsSkeletonView
                } else if viewModel.conversations.isEmpty {
                    emptyStateView
                } else {
                    conversationListView
                }
            }
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search conversations")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Delete Conversation", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    conversationToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let conversation = conversationToDelete {
                        Task {
                            await viewModel.deleteConversation(id: conversation.id)
                        }
                    }
                    conversationToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this conversation? This action cannot be undone.")
            }
        }
    }
    
    private var conversationsSkeletonView: some View {
        List {
            ForEach(0..<6, id: \.self) { _ in
                HStack(alignment: .center, spacing: 16) {
                    SkeletonCircle(size: 52)
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonShape(width: 160, height: 14)
                        SkeletonShape(height: 12)
                        SkeletonShape(width: 100, height: 10)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(hex: "2E3192").opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 50))
                    .foregroundColor(Color(hex: "2E3192").opacity(0.6))
            }
            
            VStack(spacing: 8) {
                Text("No Conversations Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Start chatting with Swastri AI to see your conversation history here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
    
    private var conversationListView: some View {
        List {
            ForEach(groupedConversations, id: \.key) { group in
                Section {
                    ForEach(group.conversations) { conversation in
                        ConversationRow(
                            conversation: conversation,
                            onTap: {
                                Task {
                                    await viewModel.loadConversation(id: conversation.id)
                                }
                            },
                            onDelete: {
                                conversationToDelete = conversation
                                showDeleteConfirmation = true
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                conversationToDelete = conversation
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
                    }
                } header: {
                    Text(group.key)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Conversation Row

private struct ConversationRow: View {
    let conversation: ConversationSummary
    let onTap: () -> Void
    let onDelete: () -> Void

    private var topic: ConversationTopic { conversation.topic }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 16) {
                // Topic-colored icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: topic.color).opacity(0.15), Color(hex: topic.color).opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)

                    Image(systemName: topic.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: topic.color))
                }
                .frame(width: 52, height: 52)
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(conversation.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Last message preview
                    Text(conversation.lastMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Metadata row
                    HStack(alignment: .center, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(conversation.formattedDate)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.4))
                        
                        HStack(spacing: 4) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("\(conversation.messageCount)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        // Topic tag
                        HStack(spacing: 3) {
                            Image(systemName: topic.icon)
                                .font(.system(size: 8, weight: .semibold))
                            Text(topic.label)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(Color(hex: topic.color))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(hex: topic.color).opacity(0.1))
                        .clipShape(Capsule())

                        if conversation.status == "archived" {
                            Spacer()
                            Text("Archived")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.3))
                    .frame(width: 20)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Particle Orb View

private struct ParticleOrbView: UIViewRepresentable {
    enum OrbState {
        case idle, listening, thinking
    }

    var state: OrbState
    var isMedicalMode: Bool = false
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X
        
        let scene = SCNScene()
        scnView.scene = scene
        
        // Camera setup
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 4)
        scene.rootNode.addChildNode(cameraNode)
        
        // Add point light for depth
        let pointLight = SCNNode()
        pointLight.light = SCNLight()
        pointLight.light?.type = .omni
        pointLight.light?.color = hexToUIColor("1A1F6B") // Darker blue
        pointLight.light?.intensity = 1000
        pointLight.position = SCNVector3(x: 0, y: 0, z: 2)
        scene.rootNode.addChildNode(pointLight)
        context.coordinator.pointLight = pointLight
        
        // Create the Orb Node
        let orbNode = SCNNode()
        scene.rootNode.addChildNode(orbNode)
        context.coordinator.orbNode = orbNode
        
        // Particle System Setup
        let particleSystem = SCNParticleSystem()
        particleSystem.birthRate = 600
        particleSystem.particleLifeSpan = 2.0
        particleSystem.particleSize = 0.015
        particleSystem.emissionDuration = 1.0
        particleSystem.loops = true
        particleSystem.particleVelocity = 0.1
        particleSystem.particleVelocityVariation = 0.05
        
        // Shape the particles into a shell/sphere
        particleSystem.emitterShape = SCNSphere(radius: 1.5)
        particleSystem.birthLocation = .surface
        particleSystem.spreadingAngle = 0
        
        // Create rounded particle image (circle)
        particleSystem.particleImage = createCircularParticleImage()
        
        // Visual Style (Additive blending like WebGL)
        // Use darker blue color
        particleSystem.particleColor = hexToUIColor("1A1F6B") // Darker blue
        particleSystem.blendMode = .additive
        particleSystem.particleColorVariation = SCNVector4(0.2, 0.2, 0.2, 0)
        
        orbNode.addParticleSystem(particleSystem)
        context.coordinator.particleSystem = particleSystem
        
        // Store references
        context.coordinator.sceneView = scnView
        
        // Initial state
        updateOrbState(orbNode: orbNode, particleSystem: particleSystem, pointLight: pointLight, state: state, isMedical: isMedicalMode)
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        if let orbNode = context.coordinator.orbNode,
           let particleSystem = context.coordinator.particleSystem {
            updateOrbState(orbNode: orbNode, particleSystem: particleSystem, pointLight: context.coordinator.pointLight, state: state, isMedical: isMedicalMode)
        }
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        uiView.scene?.rootNode.enumerateChildNodes { node, _ in
            node.removeAllParticleSystems()
            node.removeAllActions()
        }
        uiView.scene = nil
        coordinator.orbNode = nil
        coordinator.particleSystem = nil
        coordinator.sceneView = nil
        coordinator.pointLight = nil
    }

    private func updateOrbState(orbNode: SCNNode, particleSystem: SCNParticleSystem, pointLight: SCNNode?, state: OrbState, isMedical: Bool = false) {
        // Remove all actions
        orbNode.removeAllActions()
        orbNode.position = SCNVector3Zero
        orbNode.scale = SCNVector3(1, 1, 1)
        orbNode.eulerAngles = SCNVector3Zero

        // Mode-based color palettes
        let idleColor = isMedical ? "0B4D2C" : "1A1F6B"      // Dark green vs Dark blue
        let activeColor = isMedical ? "00A86B" : "2E3192"     // Green vs Royal blue
        let thinkColor = isMedical ? "064A2B" : "0F1345"      // Deep green vs Very dark blue

        // Horizontal rotation animation (around Y-axis)
        let rotateAction = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 8.0)
        orbNode.runAction(SCNAction.repeatForever(rotateAction))

        switch state {
        case .idle:
            particleSystem.particleColor = hexToUIColor(idleColor)
            particleSystem.speedFactor = 0.5
            pointLight?.light?.color = hexToUIColor(idleColor)

            // Heartbeat animation: double pulse pattern (lub-dub)
            let pulse1 = SCNAction.scale(to: 1.08, duration: 0.15)  // First beat
            let pause1 = SCNAction.wait(duration: 0.1)
            let pulse2 = SCNAction.scale(to: 1.06, duration: 0.15)  // Second beat
            let rest = SCNAction.scale(to: 1.0, duration: 0.2)      // Return to normal
            let pause2 = SCNAction.wait(duration: 0.7)              // Rest period (heartbeat frequency ~60 bpm)
            let heartbeat = SCNAction.sequence([pulse1, pause1, pulse2, rest, pause2])
            orbNode.runAction(SCNAction.repeatForever(heartbeat))

        case .listening:
            particleSystem.particleColor = hexToUIColor(activeColor)
            particleSystem.speedFactor = 2.5
            pointLight?.light?.color = hexToUIColor(activeColor)

            // Faster heartbeat (like increased heart rate)
            let pulse1 = SCNAction.scale(to: 1.1, duration: 0.1)
            let pause1 = SCNAction.wait(duration: 0.08)
            let pulse2 = SCNAction.scale(to: 1.08, duration: 0.1)
            let rest = SCNAction.scale(to: 1.0, duration: 0.15)
            let pause2 = SCNAction.wait(duration: 0.3)
            let heartbeat = SCNAction.sequence([pulse1, pause1, pulse2, rest, pause2])
            orbNode.runAction(SCNAction.repeatForever(heartbeat))

        case .thinking:
            particleSystem.particleColor = hexToUIColor(thinkColor)
            particleSystem.speedFactor = 2
            pointLight?.light?.color = hexToUIColor(thinkColor)
            
            // Moderate heartbeat
            let pulse1 = SCNAction.scale(to: 1.06, duration: 0.12)
            let pause1 = SCNAction.wait(duration: 0.09)
            let pulse2 = SCNAction.scale(to: 1.04, duration: 0.12)
            let rest = SCNAction.scale(to: 1.0, duration: 0.18)
            let pause2 = SCNAction.wait(duration: 0.5)
            let heartbeat = SCNAction.sequence([pulse1, pause1, pulse2, rest, pause2])
            orbNode.runAction(SCNAction.repeatForever(heartbeat))
        }
    }
    
    // MARK: - Helper: Create Circular Particle Image
    
    private func createCircularParticleImage() -> UIImage? {
        let size: CGFloat = 64
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        
        return renderer.image { context in
            // Fill with white circle (alpha will be handled by particle system)
            UIColor.white.setFill()
            let circlePath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size))
            circlePath.fill()
        }
    }
    
    // MARK: - Helper: Hex to UIColor
    
    private func hexToUIColor(_ hex: String) -> UIColor {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        return UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var orbNode: SCNNode?
        var particleSystem: SCNParticleSystem?
        var sceneView: SCNView?
        var pointLight: SCNNode?
    }
}

#Preview {
    NavigationStack {
        AIView()
    }
}

// MARK: - Food Analysis Card (AI Chat)

struct FoodAnalysisCardView: View {
    let foodResult: SnapFoodResult
    var onAddToDiet: ((SnapFoodResult) -> Void)? = nil

    private let greenAccent = Color(hex: "22C55E")

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 14))
                    .foregroundColor(greenAccent)
                Text(foodResult.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
            }

            // Calorie hero
            Text("\(Int(foodResult.calories)) cal")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(greenAccent)

            // Macro pills
            HStack(spacing: 8) {
                MacroPillView(label: "Protein", value: "\(Int(foodResult.proteinG))g", color: Color(hex: "3B82F6"))
                MacroPillView(label: "Carbs", value: "\(Int(foodResult.carbsG))g", color: Color(hex: "F59E0B"))
                MacroPillView(label: "Fat", value: "\(Int(foodResult.fatG))g", color: Color(hex: "EF4444"))
            }

            // Serving
            Text("Serving: \(Int(foodResult.servingSize)) \(foodResult.servingUnit.rawValue)")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            // Add to Diet button
            if onAddToDiet != nil {
                Button {
                    onAddToDiet?(foodResult)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Add to Diet")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(greenAccent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct MacroPillView: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(color.opacity(0.8))
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(RoundedCornerShape(radius: 8))
    }
}

private struct RoundedCornerShape: Shape {
    let radius: CGFloat
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: radius)
    }
}

// MARK: - Camera Image Picker

struct CameraImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    var sourceType: UIImagePickerController.SourceType = .camera
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraImagePicker
        
        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

