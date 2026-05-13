//
//  FamilyMemberAIViewModel.swift
//  swastricare-mobile-swift
//
//  Family Monitoring — AI chat scoped to a specific family member.
//  Each `send()` prepends today's snapshot for the target member as
//  `healthContext` in the ai-router payload (server-side merges it into
//  the system prompt before forwarding to the underlying model).
//
//  Mirrors the Android FamilyMemberAiViewModel.
//

import Foundation
import SwiftUI
import Combine
import Supabase

@MainActor
final class FamilyMemberAIViewModel: ObservableObject {

    // MARK: - Chat message model (screen-local, not the global ChatMessage)

    struct ChatMessage: Identifiable, Equatable {
        let id = UUID()
        let isUser: Bool
        let text: String
        var isLoading: Bool = false
    }

    // MARK: - Published state

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isSending: Bool = false
    @Published var error: String?

    private(set) var targetHealthProfileId: String = ""
    @Published private(set) var memberName: String = ""

    private let client: SupabaseClient = SupabaseManager.shared.client
    private var didInitialize = false

    // MARK: - Lifecycle

    func initialize(targetHealthProfileId: String) async {
        guard !didInitialize else { return }
        didInitialize = true
        self.targetHealthProfileId = targetHealthProfileId

        // Resolve member display name from health_profiles (mirrors what
        // FamilyMemberContextBuilder does for its own header).
        if let name = await fetchFullName(profileId: targetHealthProfileId), !name.isEmpty {
            self.memberName = name
        }

        if messages.isEmpty {
            let firstName = memberName
                .split(separator: " ")
                .first
                .map(String.init) ?? "this member"
            messages.append(
                ChatMessage(
                    isUser: false,
                    text: "Hi! Ask me anything about \(firstName)'s health."
                )
            )
        }
    }

    func setInput(_ text: String) {
        inputText = text
    }

    // MARK: - Send

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        let history = messages.filter { !$0.isLoading }
        messages.append(ChatMessage(isUser: true, text: text))
        messages.append(ChatMessage(isUser: false, text: "", isLoading: true))
        inputText = ""
        isSending = true
        error = nil

        Task {
            do {
                let healthContext = await FamilyMemberContextBuilder.shared
                    .build(targetHealthProfileId: targetHealthProfileId)

                let response = try await invokeRouter(
                    message: text,
                    history: history,
                    healthContext: healthContext.isEmpty ? nil : healthContext
                )

                messages.removeAll { $0.isLoading }
                messages.append(ChatMessage(isUser: false, text: response))
                isSending = false
            } catch {
                messages.removeAll { $0.isLoading }
                messages.append(
                    ChatMessage(
                        isUser: false,
                        text: "I'm having trouble connecting right now. Please try again in a moment."
                    )
                )
                isSending = false
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - ai-router invocation
    //
    // We bypass AIService.sendSmartMessage because that one passes
    // `systemContext`. The recently-patched ai-router edge function reads
    // `healthContext` (camelCase) from the payload and merges it into the
    // system prompt before forwarding to the underlying model. Keeping a
    // separate code path here also avoids polluting the global AI chat
    // with member-scoped state (option B per the implementation plan).

    private struct ChatHistoryItem: Codable {
        let role: String
        let content: String
    }

    private struct RouterRequest: Codable {
        let message: String
        let conversationHistory: [ChatHistoryItem]
        let healthContext: String?
    }

    private struct RouterResponse: Decodable {
        let response: String?
    }

    private func invokeRouter(
        message: String,
        history: [ChatMessage],
        healthContext: String?
    ) async throws -> String {
        // Keep the last 10 turns for context — matches the Android port.
        let trimmedHistory = history.suffix(10).map { msg in
            ChatHistoryItem(
                role: msg.isUser ? "user" : "assistant",
                content: msg.text
            )
        }

        let request = RouterRequest(
            message: message,
            conversationHistory: trimmedHistory,
            healthContext: healthContext
        )

        let response: RouterResponse = try await client.functions.invoke(
            "ai-router",
            options: FunctionInvokeOptions(body: request)
        )

        guard let text = response.response, !text.isEmpty else {
            throw AIError.invalidResponse
        }
        return text
    }

    // MARK: - Health profile name lookup

    private func fetchFullName(profileId: String) async -> String? {
        struct Row: Decodable { let full_name: String? }
        do {
            let rows: [Row] = try await client
                .from("health_profiles")
                .select("full_name")
                .eq("id", value: profileId)
                .limit(1)
                .execute()
                .value
            return rows.first?.full_name
        } catch {
            return nil
        }
    }
}
