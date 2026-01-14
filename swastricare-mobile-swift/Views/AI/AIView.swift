//
//  AIView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI
import UIKit
import Combine
import PhotosUI

struct AIView: View {
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel = DependencyContainer.shared.aiViewModel
    @StateObject private var trackerViewModel = DependencyContainer.shared.trackerViewModel
    
    // MARK: - Local State
    
    @FocusState private var isInputFocused: Bool
    @State private var showEmptyState = false
    @State private var sendButtonScale: CGFloat = 1.0
    @StateObject private var speechManager = SpeechManager.shared
    @State private var isModeSwitching = false
    
    // MARK: - Image Picker State
    
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var showImageSourceSheet = false
    @State private var showImageTypeSheet = false
    @State private var selectedImageType: MedicalImageAnalysisType = .general
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var useCamera = false  // Track user's source preference
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            chatView
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Swastri AI")
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            // Only show history if no other sheet is showing
                            guard !trackerViewModel.showAnalysisSheet else { return }
                            Task {
                                await viewModel.loadAllConversations()
                                // Use a small delay to ensure any other presentations are complete
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    viewModel.showHistorySheet = true
                                }
                            }
                        }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)

                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    
                    // AI Mode Selector (center)
                    ToolbarItem(placement: .principal) {
                        Menu {
                            ForEach(AIMode.allCases) { mode in
                                Button(action: {
                                    // Prevent switching if sheets are active
                                    guard !viewModel.showMedicalDisclaimer,
                                          !viewModel.showEmergencyAlert,
                                          !showCamera,
                                          !trackerViewModel.showAnalysisSheet else {
                                        return
                                    }
                                    
                                    // Prevent switching if already the current mode
                                    guard mode != viewModel.selectedAIMode else {
                                        return
                                    }
                                    
                                    // Prevent rapid successive switches (debounce)
                                    guard !isModeSwitching else {
                                        return
                                    }
                                    
                                    isModeSwitching = true
                                    
                                    // Delay to allow menu to dismiss first
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            viewModel.selectedAIMode = mode
                                        }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        
                                        // Reset debounce flag after animation
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                            isModeSwitching = false
                                        }
                                    }
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
                            HStack(spacing: 6) {
                                Image(systemName: viewModel.selectedAIMode.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(viewModel.selectedAIMode == .medical ? Color(hex: "00A86B") : Color(hex: "2E3192"))
                                Text(viewModel.selectedAIMode.displayName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(viewModel.selectedAIMode == .medical ? Color(hex: "00A86B").opacity(0.1) : Color(hex: "2E3192").opacity(0.1))
                            )
                        }
                        .disabled(viewModel.showMedicalDisclaimer || viewModel.showEmergencyAlert || showCamera || trackerViewModel.showAnalysisSheet || isModeSwitching)
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.clearChat()
                                showEmptyState = false
                                // Re-trigger landing animation
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                        showEmptyState = true
                                    }
                                }
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                             
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
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
                    // Call emergency services
                    if let url = URL(string: "tel://911") {
                        UIApplication.shared.open(url)
                    }
                }
            )
            .presentationDetents([.medium])
        }
        // Image Source Selection Sheet (Camera or Library)
        .confirmationDialog("Choose Image Source", isPresented: $showImageSourceSheet, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("📷 Take Photo") {
                    useCamera = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showImageTypeSheet = true
                    }
                }
            }
            Button("🖼️ Choose from Library") {
                useCamera = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showImageTypeSheet = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        // Image Type Selection Sheet
        .confirmationDialog("Select Document Type", isPresented: $showImageTypeSheet, titleVisibility: .visible) {
            Button("📋 Prescription") {
                selectedImageType = .prescription
                openImageSource()
            }
            Button("🔬 Lab Report") {
                selectedImageType = .labReport
                openImageSource()
            }
            Button("📄 Medical Document") {
                selectedImageType = .medicalDocument
                openImageSource()
            }
            Button("🩻 X-Ray / Scan") {
                selectedImageType = .xray
                openImageSource()
            }
            Button("📷 Other Medical Image") {
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
                if let newItem = newItem,
                   let data = try? await newItem.loadTransferable(type: Data.self) {
                    viewModel.setSelectedImage(data)
                    await viewModel.analyzeSelectedImage(type: selectedImageType)
                    selectedPhotoItem = nil
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
                viewModel.setSelectedImage(imageData)
                Task {
                    await viewModel.analyzeSelectedImage(type: selectedImageType)
                }
                capturedImage = nil
            }
        }
        .task {
            await trackerViewModel.loadData()
            await viewModel.loadHistory()
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
                        LazyVStack(spacing: 16) {
                            if viewModel.messages.isEmpty {
                                // Intro / Landing UI
                                introView
                                    .padding(.top, 60)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            } else {
                                ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                                    ChatBubble(message: message)
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
                            }
                        }
                        .padding()
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.messages.count)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Suggestions + Input Bar
                chatInputBar
            }
        }
        .onAppear {
            // Trigger landing animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    showEmptyState = true
                }
            }
        }
    }
    
    // MARK: - Intro View
    
    private var introView: some View {
        VStack(spacing: 24) {
            // AI Orb Avatar
            AIOrb(size: 80, showGlow: true)
                .scaleEffect(showEmptyState ? 1 : 0.8)
                .opacity(showEmptyState ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: showEmptyState)
            
            VStack(spacing: 12) {
                Text("Swastri AI")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Your personal health assistant.\nAsk me anything about your vitals, diet, or fitness.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineSpacing(4)
            }
            .offset(y: showEmptyState ? 0 : 20)
            .opacity(showEmptyState ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: showEmptyState)
            
            // Analyze Health Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task {
                    await trackerViewModel.requestAIAnalysis()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Analyse Health")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
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
            .buttonStyle(ScaleButtonStyle())
            .disabled(trackerViewModel.analysisState.isAnalyzing)
            .opacity(showEmptyState ? 1 : 0)
            .offset(y: showEmptyState ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: showEmptyState)
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Suggestions Scroll
    
    private var suggestionsScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(QuickAction.suggestions.enumerated()), id: \.element.id) { index, action in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        Task {
                            await viewModel.sendQuickAction(action)
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(action.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text(action.prompt.prefix(35) + "...")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(width: 220, alignment: .leading)
                        .glass(cornerRadius: 16)
                    }
                    .buttonStyle(QuickActionButtonStyle())
                    .opacity(showEmptyState ? 1 : 0)
                    .offset(y: showEmptyState ? 0 : 20)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.7)
                            .delay(Double(index) * 0.1 + 0.4),
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
    
    private var chatInputBar: some View {
        VStack(spacing: 12) {
            // Medical disclaimer banner when in Medical Expert mode
            if viewModel.selectedAIMode == .medical {
                MedicalDisclaimerBanner()
                    .padding(.horizontal, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Horizontal scrolling suggestions only on landing screen (when no messages)
            if viewModel.messages.isEmpty {
                suggestionsScroll
            }
            
            // Input field with mic and image buttons
            HStack(alignment: .center, spacing: 8) {
                // Image upload button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showImageSourceSheet = true
                }) {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(viewModel.isAnalyzingImage ? Color(hex: "2E3192") : .secondary)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                }
                .disabled(viewModel.isAnalyzingImage)
                
                // Text Field with mic button inside
                HStack(spacing: 8) {
                    TextField("Ask Swastri", text: $viewModel.inputText, axis: .vertical)
                        .font(.system(size: 15))
                        .focused($isInputFocused)
                        .lineLimit(1...5)
                        .onChange(of: speechManager.recognizedText) { _, newValue in
                            if speechManager.isRecording {
                                viewModel.inputText = newValue
                            }
                        }
                    
                    // Mic button inside the field
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
                        Image(systemName: speechManager.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(speechManager.isRecording ? .white : .secondary)
                            .padding(8)
                            .background(speechManager.isRecording ? AnyShapeStyle(Color.red) : AnyShapeStyle(Color.clear))
                            .clipShape(Circle())
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: speechManager.isRecording)
                }
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
                
                // Send button beside the field
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    
                    // Stop mic recording if active
                    if speechManager.isRecording {
                        speechManager.stopRecording()
                    }
                    
                    // Animate button press
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        sendButtonScale = 0.8
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            sendButtonScale = 1.0
                        }
                    }
                    
                    // Send message and clear
                    Task {
                        await viewModel.sendMessage()
                    }
                    isInputFocused = false
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(viewModel.canSend ? Color(hex: "2E3192") : .gray.opacity(0.3))
                        .scaleEffect(sendButtonScale)
                }
                .disabled(!viewModel.canSend)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.selectedAIMode)
        .onChange(of: speechManager.isRecording) { _, isRecording in
            if !isRecording && !speechManager.recognizedText.isEmpty {
                viewModel.inputText = speechManager.recognizedText
            }
        }
    }
    
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let message: ChatMessage
    @State private var appeared = false
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
            if !message.isUser {
                // AI Header (like "Copilot just now")
                HStack(spacing: 6) {
                    MiniAIOrb(size: 14)
                    Text("Swastri")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("just now")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 4)
            }
            
            HStack {
                if message.isUser { Spacer(minLength: 40) }
                
                if message.isLoading {
                    TypingIndicator()
                } else {
                    Text(message.content)
                        .font(.system(size: 15))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            message.isUser
                                ? Color(UIColor.secondarySystemBackground)
                                : Color(UIColor.secondarySystemBackground)
                        )
                        .foregroundColor(.primary)
                        .cornerRadius(16)
                        .scaleEffect(appeared ? 1 : 0.5)
                        .opacity(appeared ? 1 : 0)
                }
                
                if !message.isUser { Spacer(minLength: 40) }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
        }
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.0 : 0.6)
                    .opacity(isAnimating ? 1.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .onAppear {
            isAnimating = true
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()
                
                if viewModel.isLoadingConversations {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if viewModel.conversations.isEmpty {
                    emptyStateView
                } else {
                    conversationListView
                }
            }
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
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
            ForEach(viewModel.conversations) { conversation in
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
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 16) {
                // Icon with gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "2E3192").opacity(0.15), Color(hex: "4A90E2").opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: "2E3192"))
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

#Preview {
    NavigationStack {
        AIView()
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

