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
    
    // MARK: - Local State
    
    @FocusState private var isInputFocused: Bool
    @State private var showEmptyState = false
    @State private var sendButtonScale: CGFloat = 1.0
    
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
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.errorMessage ?? "")
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
                                            removal: .opacity
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
        VStack(spacing: 20) {
            // Animated sparkle icon
            AnimatedSparkleIcon()
            
            Text("Ask me anything about health")
                .font(.headline)
                .opacity(showEmptyState ? 1 : 0)
                .offset(y: showEmptyState ? 0 : 10)
            
            Text("I can help with fitness tips, nutrition advice, and health questions")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .opacity(showEmptyState ? 1 : 0)
                .offset(y: showEmptyState ? 0 : 10)
            
            // Quick Actions with staggered animation
            VStack(spacing: 8) {
                ForEach(Array(QuickAction.suggestions.enumerated()), id: \.element.id) { index, action in
                    Button(action: {
                        Task { await viewModel.sendQuickAction(action) }
                    }) {
                        HStack {
                            Image(systemName: action.icon)
                                .foregroundStyle(PremiumColor.royalBlue)
                            Text(action.title)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .glass(cornerRadius: 12)
                    }
                    .buttonStyle(QuickActionButtonStyle())
                    .opacity(showEmptyState ? 1 : 0)
                    .offset(x: showEmptyState ? 0 : -30)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.7)
                            .delay(Double(index) * 0.1 + 0.3),
                        value: showEmptyState
                    )
                }
            }
        }
        .padding()
    }
    
    private var chatInputBar: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Material.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    isInputFocused ? Color(hex: "2E3192").opacity(0.5) : Color.clear,
                                    lineWidth: 2
                                )
                        )
                )
                .focused($isInputFocused)
                .lineLimit(1...5)
                .animation(.easeInOut(duration: 0.2), value: isInputFocused)
            
            Button(action: {
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
                Image(systemName: viewModel.chatState.isBusy ? "stop.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        viewModel.canSend
                            ? PremiumColor.royalBlue
                            : LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
                    )
                    .scaleEffect(sendButtonScale)
                    .symbolEffect(.bounce, value: viewModel.chatState.isBusy)
            }
            .disabled(!viewModel.canSend)
        }
        .padding()
        .background(Material.bar)
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
                            ? AnyShapeStyle(PremiumColor.royalBlue)
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
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
            // Glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "2E3192").opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 60
                    )
                )
                .frame(width: 100, height: 100)
                .scaleEffect(isAnimating ? 1.2 : 0.9)
                .animation(
                    .easeInOut(duration: 2).repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // Main icon
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundStyle(PremiumColor.royalBlue)
                .scaleEffect(isAnimating ? 1.05 : 1.0)
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
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        AIView()
    }
}

