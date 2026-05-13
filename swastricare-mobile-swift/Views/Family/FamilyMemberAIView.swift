//
//  FamilyMemberAIView.swift
//  swastricare-mobile-swift
//
//  Family Monitoring — dedicated AI chat scoped to a specific family member.
//  The screen prepends today's snapshot for the target member as `healthContext`
//  in the ai-router payload, so answers are grounded in their data rather than
//  the caller's.
//
//  Mirrors the Android FamilyMemberAiScreen.
//

import SwiftUI

struct FamilyMemberAIView: View {

    let targetHealthProfileId: String

    @StateObject private var vm = FamilyMemberAIViewModel()
    @Environment(\.dismiss) private var dismiss

    private let suggestions = [
        "How is their sleep?",
        "Are they hydrated enough?",
        "How's their medication adherence today?"
    ]

    private var firstName: String {
        vm.memberName
            .split(separator: " ")
            .first
            .map(String.init) ?? "member"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    messagesScroll
                    if vm.messages.count <= 1 {
                        suggestionChips
                    }
                    inputBar
                }
            }
            .navigationTitle("Ask about \(firstName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .font(.poppins(.medium, size: 15))
                        .foregroundStyle(AppColors.accentBlue)
                }
            }
        }
        .task { await vm.initialize(targetHealthProfileId: targetHealthProfileId) }
    }

    // MARK: - Messages list

    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(vm.messages) { msg in
                        messageRow(msg)
                            .id(msg.id)
                    }
                }
                .padding(16)
            }
            .onChange(of: vm.messages.count) { _ in
                if let last = vm.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func messageRow(_ msg: FamilyMemberAIViewModel.ChatMessage) -> some View {
        HStack {
            if msg.isUser { Spacer(minLength: 40) }

            Group {
                if msg.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(msg.isUser ? .white : AppColors.accentBlue)
                } else {
                    Text(msg.text)
                        .font(.poppins(.regular, size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(msg.isUser ? AppColors.accentBlue : Color(white: 0.95))
            .foregroundColor(msg.isUser ? .white : .black)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .frame(maxWidth: 280, alignment: msg.isUser ? .trailing : .leading)

            if !msg.isUser { Spacer(minLength: 40) }
        }
    }

    // MARK: - Suggestion chips

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { s in
                    Button {
                        vm.setInput(s)
                    } label: {
                        Text(s)
                            .font(.poppins(.medium, size: 12))
                            .foregroundStyle(AppColors.accentBlue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.accentBlue, lineWidth: 1)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField(
                "Ask about \(firstName)",
                text: Binding(
                    get: { vm.inputText },
                    set: { vm.setInput($0) }
                ),
                axis: .vertical
            )
            .font(.poppins(.regular, size: 14))
            .lineLimit(1...4)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(white: 0.96))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .submitLabel(.send)
            .onSubmit { vm.send() }

            Button {
                vm.send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .resizable()
                    .frame(width: 36, height: 36)
                    .foregroundColor(
                        sendDisabled
                            ? AppColors.accentBlue.opacity(0.4)
                            : AppColors.accentBlue
                    )
            }
            .disabled(sendDisabled)
        }
        .padding(12)
        .background(Color.white)
    }

    private var sendDisabled: Bool {
        vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isSending
    }
}

// MARK: - Preview

#Preview {
    FamilyMemberAIView(targetHealthProfileId: "00000000-0000-0000-0000-000000000000")
}
