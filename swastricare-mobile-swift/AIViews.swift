//
//  AIViews.swift
//  swastricare-mobile-swift
//
//  Created by AI Assistant on 06/01/26.
//

import SwiftUI

// MARK: - Reusable Premium Components

struct PremiumGlassCard: View {
    var cornerRadius: CGFloat = 20
    var opacity: CGFloat = 0.1
    
    var body: some View {
        ZStack {
            // Blur Background
            VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
            
            // Subtle Gradient Tint
            LinearGradient(
                colors: [
                    Color.primary.opacity(opacity),
                    Color.primary.opacity(opacity * 0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.3),
                            .white.opacity(0.1),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

struct GradientText: View {
    let text: String
    var font: Font = .largeTitle
    var weight: Font.Weight = .bold
    
    var body: some View {
        Text(text)
            .font(font)
            .fontWeight(weight)
            .overlay(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(
                    Text(text)
                        .font(font)
                        .fontWeight(weight)
                )
            )
            .foregroundColor(.clear) // Hide original text
    }
}

// MARK: - Main AI View

struct FunctionalAIView: View {
    @StateObject private var aiManager = AIManager.shared
    @StateObject private var healthManager = HealthManager.shared
    @StateObject private var authManager = AuthManager.shared
    @State private var selectedTab = 0
    @State private var messageText = ""
    
    var body: some View {
        ZStack {
            // Ambient Background
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.1),
                    Color.purple.opacity(0.05),
                    Color(UIColor.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Feature Toggle (Custom Glass Picker)
                if authManager.isAuthenticated {
                    HStack(spacing: 0) {
                        ForEach(["Chat", "Analysis"], id: \.self) { title in
                            let index = title == "Chat" ? 0 : 1
                            let isSelected = selectedTab == index
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTab = index
                                }
                            }) {
                                Text(title)
                                    .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? .white : .primary.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        isSelected ?
                                        LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                                        : nil
                                    )
                                    .background(isSelected ? Color.clear : Color.primary.opacity(0.05))
                            }
                        }
                    }
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                }
                
                // Content
                if selectedTab == 0 {
                    FunctionalChatView(messageText: $messageText)
                        .transition(.opacity)
                } else {
                    FunctionalAnalysisView()
                        .transition(.opacity)
                }
            }
            .safeAreaInset(edge: .top) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Assistant")
                            .font(.system(size: 34, weight: .bold))
                        Text("Your personal health companion")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    if !authManager.isAuthenticated {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.orange)
                    } else {
                        // Profile/Status Icon
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)
                            )
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(Material.ultraThin)
                                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                            )
                    }
                }
                .padding()
                .background(Material.ultraThin)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.primary.opacity(0.05)),
                    alignment: .bottom
                )
            }
        }
    }
}

// MARK: - Chat View

struct FunctionalChatView: View {
    @StateObject private var aiManager = AIManager.shared
    @StateObject private var speechManager = SpeechManager.shared
    @Binding var messageText: String
    @State private var showError = false
    @State private var errorText = ""
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Chat Messages
            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if aiManager.chatHistory.isEmpty {
                            EmptyChatState(action: sendQuickQuestion)
                        } else {
                            // Spacer for header
                            Color.clear.frame(height: 10)
                            
                            ForEach(aiManager.chatHistory) { message in
                                FunctionalChatBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        
                        if aiManager.isLoading {
                            HStack {
                                ProgressView()
                                    .padding(8)
                                    .background(Material.ultraThin)
                                    .clipShape(Circle())
                                Text("Thinking...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading)
                        }
                        
                        // Bottom padding for input bar + dock
                        Color.clear.frame(height: 160)
                    }
                    .padding(.horizontal)
                    .onChange(of: aiManager.chatHistory.count) {
                        if let lastMessage = aiManager.chatHistory.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            
            // Floating Input Bar
            HStack(spacing: 12) {
                // Microphone button for speech-to-text
                Button(action: toggleRecording) {
                    Image(systemName: speechManager.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 22))
                        .foregroundColor(speechManager.isRecording ? .red : .blue)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(speechManager.isRecording ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                        )
                }
                .disabled(aiManager.isLoading)
                
                TextField("Ask about your health...", text: $messageText)
                    .padding(12)
                    .padding(.horizontal, 4)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.05))
                    )
                    .disabled(aiManager.isLoading)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(
                            messageText.isEmpty ?
                            LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.3)], startPoint: .top, endPoint: .bottom) :
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: messageText.isEmpty ? .clear : .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .disabled(messageText.isEmpty || aiManager.isLoading)
            }
            .padding(12)
            .background(
                PremiumGlassCard(cornerRadius: 35)
            )
            .padding(.horizontal)
            .padding(.bottom, 90) // Raised to clear the fixed bottom navigation bar
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorText)
        }
    }
    
    private func sendMessage() {
        let message = messageText
        messageText = ""
        
        Task {
            do {
                _ = try await aiManager.sendMessage(message)
            } catch {
                errorText = "Failed to send message: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func sendQuickQuestion(_ question: String) {
        messageText = question
        sendMessage()
    }
    
    private func toggleRecording() {
        if speechManager.isRecording {
            speechManager.stopRecording()
            // Use recognized text
            if !speechManager.recognizedText.isEmpty {
                messageText = speechManager.recognizedText
            }
        } else {
            Task {
                do {
                    try await speechManager.startRecording()
                } catch {
                    errorText = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Empty Chat State

struct EmptyChatState: View {
    let action: (String) -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 40)
            
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.blue.opacity(0.1), .purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            
            // Text
            VStack(spacing: 8) {
                Text("How can I help you?")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("I can analyze your health data, give fitness tips, or just chat about wellness.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Quick Questions
            VStack(spacing: 12) {
                QuickActionRow(icon: "moon.fill", text: "How can I improve my sleep?", color: .indigo) {
                    action("How can I improve my sleep?")
                }
                QuickActionRow(icon: "figure.run", text: "Tips for staying active?", color: .green) {
                    action("Tips for staying active?")
                }
                QuickActionRow(icon: "leaf.fill", text: "Best foods for energy?", color: .orange) {
                    action("Best foods for energy?")
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
        }
    }
}

struct QuickActionRow: View {
    let icon: String
    let text: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 32)
                
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(PremiumGlassCard(cornerRadius: 16, opacity: 0.05))
        }
    }
}

// MARK: - Chat Bubble

struct FunctionalChatBubble: View {
    let message: ChatMessage
    @StateObject private var speechManager = SpeechManager.shared
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if message.role == "user" {
                Spacer()
            } else {
                // AI Avatar
                Image(systemName: "sparkles")
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Circle())
                    .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            
            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 8) {
                Text(message.content)
                    .font(.body)
                    .padding(16)
                    .background(
                        message.role == "user" 
                            ? AnyView(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyView(Color.secondary.opacity(0.1))
                    )
                    .foregroundColor(message.role == "user" ? .white : .primary)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    .frame(maxWidth: 280, alignment: message.role == "user" ? .trailing : .leading)
                
                // Text-to-Speech button for assistant messages
                if message.role == "assistant" {
                    Button(action: { speakMessage() }) {
                        HStack(spacing: 4) {
                            Image(systemName: speechManager.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                                .font(.caption)
                            Text(speechManager.isSpeaking ? "Speaking..." : "Listen")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
            
            if message.role == "assistant" {
                Spacer()
            }
        }
    }
    
    private func speakMessage() {
        if speechManager.isSpeaking {
            speechManager.stopSpeaking()
        } else {
            speechManager.speak(message.content)
        }
    }
}

// MARK: - Analysis View

struct FunctionalAnalysisView: View {
    @StateObject private var aiManager = AIManager.shared
    @StateObject private var healthManager = HealthManager.shared
    @StateObject private var speechManager = SpeechManager.shared
    @State private var isAnalyzing = false
    @State private var showError = false
    @State private var errorText = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Info Card
                ZStack {
                    PremiumGlassCard(cornerRadius: 24)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "waveform.path.ecg")
                                .font(.title)
                                .foregroundColor(.blue)
                            Text("AI Analysis")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Text("Get personalized insights based on your health metrics. Our AI analyzes your steps, heart rate, and sleep.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(24)
                }
                .padding(.horizontal)
                
                // Metrics Grid
                if healthManager.isAuthorized {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricGlassCard(value: "\(healthManager.stepCount)", unit: "Steps", icon: "figure.walk", color: .green)
                        MetricGlassCard(value: "\(healthManager.heartRate)", unit: "BPM", icon: "heart.fill", color: .red)
                        MetricGlassCard(value: healthManager.sleepHours, unit: "Sleep", icon: "bed.double.fill", color: .indigo)
                    }
                    .padding(.horizontal)
                }
                
                // Analyze Button
                Button(action: analyzeHealth) {
                    HStack {
                        if isAnalyzing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "sparkles")
                            Text("Generate Insights")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .disabled(isAnalyzing || !healthManager.isAuthorized)
                .padding(.horizontal)
                
                if !healthManager.isAuthorized {
                    Text("⚠️ Enable Health access for analysis")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                // Analysis Results
                if let analysis = aiManager.lastAnalysis {
                    VStack(spacing: 20) {
                        // Listen button for full analysis
                        Button(action: { speakFullAnalysis(analysis) }) {
                            HStack {
                                Image(systemName: speechManager.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                                Text(speechManager.isSpeaking ? "Stop Reading" : "Read Analysis Aloud")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(colors: [.green, .teal], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(16)
                            .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal)
                        
                        ResultGlassCard(title: "Assessment", icon: "doc.text.fill", color: .blue) {
                            Text(analysis.assessment)
                        }
                        
                        ResultGlassCard(title: "Key Insights", icon: "lightbulb.fill", color: .orange) {
                            Text(analysis.insights)
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "list.star")
                                    .foregroundColor(.purple)
                                Text("Recommendations")
                                    .font(.headline)
                            }
                            .padding(.horizontal)
                            
                            ForEach(Array(analysis.recommendations.enumerated()), id: \.offset) { index, recommendation in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Color.purple)
                                        .clipShape(Circle())
                                    
                                    Text(recommendation)
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(PremiumGlassCard(cornerRadius: 16, opacity: 0.05))
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                }
                
                // Padding for Dock
                Color.clear.frame(height: 100)
            }
            .padding(.top)
        }
        .alert("Analysis Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorText)
        }
    }
    
    private func analyzeHealth() {
        isAnalyzing = true
        Task {
            do {
                _ = try await aiManager.analyzeHealth(
                    steps: healthManager.stepCount,
                    heartRate: healthManager.heartRate,
                    sleepHours: healthManager.sleepHours
                )
            } catch {
                errorText = "Analysis failed: \(error.localizedDescription)"
                showError = true
            }
            isAnalyzing = false
        }
    }
    
    private func speakFullAnalysis(_ analysis: HealthAnalysis) {
        if speechManager.isSpeaking {
            speechManager.stopSpeaking()
        } else {
            let fullText = """
            Health Assessment. \(analysis.assessment). 
            Key Insights. \(analysis.insights). 
            Recommendations. \(analysis.recommendations.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: ". "))
            """
            speechManager.speak(fullText, rate: 0.5)
        }
    }
}

// MARK: - Helper Views

struct MetricGlassCard: View {
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(PremiumGlassCard(cornerRadius: 16, opacity: 0.05))
    }
}

struct ResultGlassCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .padding(8)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            content()
                .font(.body)
                .foregroundColor(.primary.opacity(0.9))
                .lineSpacing(4)
        }
        .padding(20)
        .background(PremiumGlassCard(cornerRadius: 20))
        .padding(.horizontal)
    }
}

// Helper for masking specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
