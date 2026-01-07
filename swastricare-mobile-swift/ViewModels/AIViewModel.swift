//
//  AIViewModel.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - ViewModel Layer
//

import Foundation
import Combine

@MainActor
final class AIViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var chatState: AIChatState = .idle
    @Published private(set) var errorMessage: String?
    @Published var inputText = ""
    
    // MARK: - Computed Properties
    
    var isBusy: Bool { chatState.isBusy }
    var hasMessages: Bool { !messages.isEmpty }
    var canSend: Bool { !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chatState.isBusy }
    
    // MARK: - Dependencies
    
    private let aiService: AIServiceProtocol
    
    // MARK: - Init
    
    init(aiService: AIServiceProtocol = AIService.shared) {
        self.aiService = aiService
    }
    
    // MARK: - Chat Actions
    
    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Add user message
        let userMessage = ChatMessage.userMessage(text)
        messages.append(userMessage)
        inputText = ""
        
        // Add loading message
        let loadingMessage = ChatMessage.loadingMessage()
        messages.append(loadingMessage)
        
        chatState = .sending
        
        do {
            let response = try await aiService.sendChatMessage(text, context: messages.dropLast())
            
            // Remove loading message and add response
            messages.removeLast()
            messages.append(ChatMessage.assistantMessage(response))
            chatState = .idle
        } catch {
            messages.removeLast()
            chatState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }
    
    func sendQuickAction(_ action: QuickAction) async {
        inputText = action.prompt
        await sendMessage()
    }
    
    func clearChat() {
        messages = []
        chatState = .idle
        errorMessage = nil
    }
    
    // MARK: - Helpers
    
    func clearError() {
        errorMessage = nil
        if case .error = chatState {
            chatState = .idle
        }
    }
}

