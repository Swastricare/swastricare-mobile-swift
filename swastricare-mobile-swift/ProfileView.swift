//
//  ProfileView.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HeroHeader(
                    title: "My Profile",
                    subtitle: "Settings",
                    icon: "gearshape.fill"
                )
                
                // Tech/Glass Profile Card
                ZStack {
                    // Glass Effect Background
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                        
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(PremiumColor.deepPurple)
                                .frame(width: 100, height: 100)
                                .shadow(color: .purple.opacity(0.4), radius: 15)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 45))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 10)
                        
                        VStack(spacing: 4) {
                            Text(authManager.userEmail ?? "Swastricare Member")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Member since \(formattedDate())")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(Capsule())
                        }
                        
                        // Stats Row
                        HStack(spacing: 20) {
                            ProfileStat(value: "12", label: "Workouts")
                            Divider().frame(height: 30)
                            ProfileStat(value: "85%", label: "Health Score")
                            Divider().frame(height: 30)
                            ProfileStat(value: "68kg", label: "Weight")
                        }
                        .padding(.top, 10)
                    }
                    .padding(24)
                }
                .glass(cornerRadius: 30)
                .padding(.horizontal)
                
                // Account Settings
                VStack(alignment: .leading, spacing: 15) {
                    Text("Account")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.leading, 20)
                    
                    VStack(spacing: 1) {
                        ProfileRow(icon: "person.fill", title: "Edit Profile", color: .blue)
                        Divider().padding(.leading, 50)
                        ProfileRow(icon: "heart.fill", title: "Health Data", color: .red)
                        Divider().padding(.leading, 50)
                        ProfileRow(icon: "bell.fill", title: "Notifications", color: .orange)
                    }
                    .padding(.vertical, 8)
                    .glass(cornerRadius: 20)
                    .padding(.horizontal)
                }
                
                // General Settings
                VStack(alignment: .leading, spacing: 15) {
                    Text("General")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.leading, 20)
                    
                    VStack(spacing: 1) {
                        ProfileRow(icon: "lock.fill", title: "Privacy", color: .purple)
                        Divider().padding(.leading, 50)
                        ProfileRow(icon: "questionmark.circle.fill", title: "Help & Support", color: .green)
                        Divider().padding(.leading, 50)
                        ProfileRow(icon: "info.circle.fill", title: "About", color: .gray)
                    }
                    .padding(.vertical, 8)
                    .glass(cornerRadius: 20)
                    .padding(.horizontal)
                }
                
                // Sign Out Button
                Button(action: {
                    Task {
                        await authManager.signOut()
                    }
                }) {
                    HStack {
                        if authManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.right.square.fill")
                            Text("Sign Out")
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(16)
                    .shadow(color: .red.opacity(0.2), radius: 5, x: 0, y: 2)
                }
                .disabled(authManager.isLoading)
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Bottom Padding for Dock
                Color.clear.frame(height: 100)
            }
            .padding(.top)
        }
    }
    
    private func formattedDate() -> String {
        return "Member since \(Date().formatted(date: .abbreviated, time: .omitted))"
    }
}

// MARK: - Profile Helpers

struct ProfileStat: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct ProfileRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}
