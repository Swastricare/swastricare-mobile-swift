//
//  AIView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI
import UIKit

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
        NavigationStack {
            chatView
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Swastri AI")
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
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
                                .padding(10)
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
        .task {
            await trackerViewModel.loadData()
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
            // Logo / Icon
            ZStack {
                Circle()
                    .fill(Color(hex: "2E3192").opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "2E3192"))
            }
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
    
    private var chatInputBar: some View {
        VStack(spacing: 12) {
            // Horizontal scrolling suggestions only on landing screen (when no messages)
            if viewModel.messages.isEmpty {
                suggestionsScroll
            }
            
            // Input field with mic button beside
            HStack(alignment: .center, spacing: 12) {
                // Text Field with send button inside
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
                    
                    // Send button inside the field - always shows arrow icon
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
                            .font(.system(size: 26))
                            .foregroundColor(viewModel.canSend ? Color(hex: "2E3192") : .gray.opacity(0.3))
                            .scaleEffect(sendButtonScale)
                    }
                    .disabled(!viewModel.canSend)
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
                
                // Mic button beside the field
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
                        .padding(12)
                        .background(speechManager.isRecording ? AnyShapeStyle(Color.red) : AnyShapeStyle(.ultraThinMaterial))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(speechManager.isRecording ? 0 : 0.1), lineWidth: 0.5)
                        )
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: speechManager.isRecording)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
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
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
            if !message.isUser {
                // AI Header (like "Copilot just now")
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "2E3192"))
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

