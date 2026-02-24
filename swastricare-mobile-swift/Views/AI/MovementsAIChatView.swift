//
//  MovementsAIChatView.swift
//  swastricare-mobile-swift
//
//  AI Chat screen with Movements+ dark theme design
//

import SwiftUI

struct MovementsAIChatView: View {
    
    // MARK: - Environment & State
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = DependencyContainer.shared.aiViewModel
    @FocusState private var isInputFocused: Bool
    
    @State private var inputText = ""
    @State private var hasAppeared = false
    
    // Namespace for matched geometry effect (passed from parent)
    var animationNamespace: Namespace.ID?
    var textFieldID: String = "aiTextField"
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Chat Messages
                chatMessagesSection
                
                // Input Area
                inputSection
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                hasAppeared = true
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [MovementsColors.limeGreen, Color(hex: "4ECDC4")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                }
                
                Text("Swastri AI")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                // Clear chat or settings
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            MovementsColors.darkGray.opacity(0.8)
                .blur(radius: 0)
        )
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : -20)
    }
    
    // MARK: - Chat Messages Section
    
    private var chatMessagesSection: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    // Welcome message
                    if viewModel.messages.isEmpty {
                        welcomeSection
                            .padding(.top, 40)
                    }
                    
                    // Messages
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                    
                    // Typing indicator
                    if viewModel.chatState.isBusy {
                        TypingIndicatorView()
                            .padding(.leading, 20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Welcome Section
    
    private var welcomeSection: some View {
        VStack(spacing: 24) {
            // AI Avatar
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                MovementsColors.limeGreen.opacity(0.3),
                                MovementsColors.limeGreen.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [MovementsColors.limeGreen, Color(hex: "4ECDC4")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.black)
            }
            .opacity(hasAppeared ? 1 : 0)
            .scaleEffect(hasAppeared ? 1 : 0.5)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: hasAppeared)
            
            VStack(spacing: 8) {
                Text("Hello! I'm Swastri")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Your personal health assistant")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: hasAppeared)
            
            // Quick suggestions
            VStack(spacing: 12) {
                Text("Try asking:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(quickSuggestions.enumerated()), id: \.offset) { index, suggestion in
                        SuggestionChip(text: suggestion) {
                            sendMessage(suggestion)
                        }
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.8)
                                .delay(0.4 + Double(index) * 0.05),
                            value: hasAppeared
                        )
                    }
                }
            }
            .padding(.top, 16)
        }
    }
    
    private let quickSuggestions = [
        "Improve my sleep",
        "Workout tips",
        "Nutrition advice"
    ]
    
    // MARK: - Input Section
    
    private var inputSection: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.1))
            
            HStack(spacing: 12) {
                // Text Input
                HStack(spacing: 12) {
                    TextField("Ask anything...", text: $inputText, axis: .vertical)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .focused($isInputFocused)
                        .lineLimit(1...5)
                        .tint(MovementsColors.limeGreen)
                    
                    if !inputText.isEmpty {
                        Button(action: {
                            inputText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(MovementsColors.cardDark)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    isInputFocused
                                        ? MovementsColors.limeGreen.opacity(0.5)
                                        : Color.white.opacity(0.1),
                                    lineWidth: 1
                                )
                        )
                )
                
                // Send Button
                Button(action: {
                    sendMessage(inputText)
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                inputText.isEmpty
                                    ? Color.white.opacity(0.1)
                                    : MovementsColors.limeGreen
                            )
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(inputText.isEmpty ? .white.opacity(0.4) : .black)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                MovementsColors.darkGray.opacity(0.95)
            )
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 50)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: hasAppeared)
    }
    
    // MARK: - Helper Methods
    
    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        viewModel.inputText = trimmed
        inputText = ""
        isInputFocused = false
        
        Task {
            await viewModel.sendMessage()
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser {
                Spacer(minLength: 60)
            } else {
                // AI Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [MovementsColors.limeGreen, Color(hex: "4ECDC4")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(message.isUser ? .black : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                message.isUser
                                    ? MovementsColors.limeGreen
                                    : MovementsColors.cardDark
                            )
                    )
                
                Text(formatTime(message.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Typing Indicator

private struct TypingIndicatorView: View {
    @State private var dotScale: [CGFloat] = [1, 1, 1]
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [MovementsColors.limeGreen, Color(hex: "4ECDC4")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
            }
            
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(MovementsColors.limeGreen)
                        .frame(width: 8, height: 8)
                        .scaleEffect(dotScale[index])
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(MovementsColors.cardDark)
            )
        }
        .onAppear {
            animateDots()
        }
    }
    
    private func animateDots() {
        for index in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.4)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.15)
            ) {
                dotScale[index] = 0.5
            }
        }
    }
}

// MARK: - Suggestion Chip

private struct SuggestionChip: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(MovementsColors.cardDark)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    MovementsAIChatView()
}
