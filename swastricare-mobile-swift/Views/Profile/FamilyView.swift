//
//  FamilyView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI
import UIKit

struct FamilyView: View {
    @EnvironmentObject private var deepLinkHandler: DeepLinkHandler
    
    @State private var inviteCode: String
    @State private var showJoinComingSoon = false
    @State private var showCopied = false
    
    init(initialInviteCode: String? = nil) {
        _inviteCode = State(initialValue: (initialInviteCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    var body: some View {
        ZStack {
            PremiumBackground()
            
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Join a family")
                            .font(.headline)
                        
                        Text("Enter an invite code to join a family group. If you opened an invite link, the code will appear here automatically.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Invite code", text: $inviteCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        
                        HStack(spacing: 12) {
                            Button("Paste") {
                                inviteCode = (UIPasteboard.general.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Clear") {
                                inviteCode = ""
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                            
                            Button("Join") {
                                showJoinComingSoon = true
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Invite")
                }
                
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Share link format")
                                .font(.subheadline)
                            Text("swastricare://family/join?code=…")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Copy") {
                            UIPasteboard.general.string = "swastricare://family/join?code=\(inviteCode.trimmingCharacters(in: .whitespacesAndNewlines))"
                            showCopied = true
                        }
                        .buttonStyle(.bordered)
                        .disabled(inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("Share")
                } footer: {
                    Text("Family management is under development. This screen currently supports deep-link entry and basic invite-code handling.")
                        .font(.caption)
                }
                
                Section {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(.orange)
                        Text("Family members")
                        Spacer()
                        Text("Coming soon")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Manage")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Family")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if inviteCode.isEmpty, let pending = deepLinkHandler.pendingFamilyInviteCode, !pending.isEmpty {
                inviteCode = pending.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            deepLinkHandler.clearFamilyInviteCode()
        }
        .alert("Join family", isPresented: $showJoinComingSoon) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Joining a family will be available in a future update.")
        }
        .overlay(alignment: .top) {
            if showCopied {
                Text("Copied")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCopied = false
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showCopied)
    }
}

#Preview {
    NavigationStack {
        FamilyView(initialInviteCode: "ABC12345")
            .environmentObject(DeepLinkHandler())
    }
}

