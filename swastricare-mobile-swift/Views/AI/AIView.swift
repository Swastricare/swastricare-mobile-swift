//
//  AIView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI

struct AIView: View {
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel = DependencyContainer.shared.aiViewModel
    @StateObject private var trackerViewModel = DependencyContainer.shared.trackerViewModel
    
    // MARK: - Local State
    
    @FocusState private var isInputFocused: Bool
    @State private var showEmptyState = false
    @State private var sendButtonScale: CGFloat = 1.0
    @StateObject private var speechManager = SpeechManager.shared
    
    // MARK: - Body
    
    var body: some View {
        chatView
            .navigationTitle("Swastri AI")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.clearChat()
                        }
                    }) {
                        Image(systemName: "trash")
                    }
                    .disabled(viewModel.messages.isEmpty)
                }
            }
            // Temporarily commented out - Analyze with AI button
            /*
            .overlay(alignment: .bottomTrailing) {
                // Floating Action Button for AI Health Analysis
                Button(action: {
                    Task { await trackerViewModel.requestAIAnalysis() }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.title3)
                        Text("Analyze with AI")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "2E3192"), Color(hex: "4A90E2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(25)
                    .shadow(color: Color(hex: "2E3192").opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .disabled(trackerViewModel.healthMetrics.isEmpty || trackerViewModel.analysisState.isAnalyzing)
                .padding(.trailing, 20)
                .padding(.bottom, 90) // Extra padding to avoid input bar
            }
            */
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
            .task {
                await trackerViewModel.loadData()
            }
    }
    
    // MARK: - Chat View
    
    private var chatView: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.messages.isEmpty {
                            emptyChatState
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
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
            
            // Input Bar
            chatInputBar
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                showEmptyState = true
            }
        }
    }
    
    private var emptyChatState: some View {
        VStack(spacing: 24) {
            // Animated sparkle icon
            AnimatedSparkleIcon()
                .scaleEffect(showEmptyState ? 1.0 : 0.8)
                .opacity(showEmptyState ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: showEmptyState)
            
            VStack(spacing: 8) {
                Text("Ask me anything about health")
                    .font(.headline)
                    .opacity(showEmptyState ? 1 : 0)
                    .offset(y: showEmptyState ? 0 : 10)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: showEmptyState)
                
                Text("I can help with fitness tips, nutrition advice, and health questions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(showEmptyState ? 1 : 0)
                    .offset(y: showEmptyState ? 0 : 10)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: showEmptyState)
            }
            
            // Quick Actions as smaller chips with wrap layout
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100))
            ], spacing: 8) {
                ForEach(Array(QuickAction.suggestions.enumerated()), id: \.element.id) { index, action in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            Task { await viewModel.sendQuickAction(action) }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: action.icon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "2E3192"))
                            Text(action.title)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "2E3192").opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(hex: "2E3192").opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(QuickActionButtonStyle())
                    .opacity(showEmptyState ? 1 : 0)
                    .scaleEffect(showEmptyState ? 1.0 : 0.8)
                    .offset(y: showEmptyState ? 0 : 20)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.7)
                            .delay(Double(index) * 0.08 + 0.4),
                        value: showEmptyState
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    private var chatInputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.3)
            
            HStack(alignment: .bottom, spacing: 10) {
                // Text Field Container - Transparent background
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Ask Swastrica...", text: $viewModel.inputText, axis: .vertical)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .focused($isInputFocused)
                        .lineLimit(1...5)
                        .background(Color.clear)
                        .onChange(of: speechManager.recognizedText) { _, newValue in
                            if speechManager.isRecording {
                                viewModel.inputText = newValue
                            }
                        }
                }
                .background(Color.clear)
                .cornerRadius(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            isInputFocused 
                                ? Color(hex: "2E3192").opacity(0.4) 
                                : Color.primary.opacity(0.15), 
                            lineWidth: isInputFocused ? 1.5 : 1
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isInputFocused)
                )
                
                // Action Buttons (WhatsApp style - on the right)
                HStack(alignment: .center, spacing: 8) {
                    // Voice input button
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
                        ZStack {
                            Circle()
                                .fill(speechManager.isRecording ? .red : Color.clear)
                                .frame(width: 44, height: 44)
                                .liquidGlassCircle()
                            
                            Image(systemName: speechManager.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(speechManager.isRecording ? .white : Color(hex: "2E3192"))
                                .symbolEffect(.bounce, value: speechManager.isRecording)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: speechManager.isRecording)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    // Send button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        // Animate button press
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                            sendButtonScale = 0.8
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                sendButtonScale = 1.0
                            }
                        }
                        
                        Task { await viewModel.sendMessage() }
                        isInputFocused = false
                    }) {
                        ZStack {
                            Circle()
                                .fill(viewModel.canSend ? Color(hex: "2E3192") : Color.gray.opacity(0.2))
                                .frame(width: 44, height: 44)
                                .shadow(color: viewModel.canSend ? Color(hex: "2E3192").opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.canSend)
                            
                            Image(systemName: viewModel.chatState.isBusy ? "stop.fill" : "paperplane.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(viewModel.canSend ? .white : .secondary)
                                .scaleEffect(sendButtonScale)
                                .symbolEffect(.bounce, value: viewModel.chatState.isBusy)
                        }
                    }
                    .disabled(!viewModel.canSend && !viewModel.chatState.isBusy)
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
            )
        }
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
        HStack {
            if message.isUser { Spacer(minLength: 60) }
            
            if message.isLoading {
                TypingIndicator()
            } else {
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        message.isUser
                            ? AnyShapeStyle(Color(hex: "2E3192"))
                            : AnyShapeStyle(Material.ultraThinMaterial)
                    )
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(18)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
            }
            
            if !message.isUser { Spacer(minLength: 60) }
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
                    .fill(Color(hex: "2E3192").opacity(0.7))
                    .frame(width: 10, height: 10)
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
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Material.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Animated Sparkle Icon

private struct AnimatedSparkleIcon: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Glow effect - using simple circle with opacity
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
            
            // Main icon
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

#Preview {
    NavigationStack {
        AIView()
    }
}

