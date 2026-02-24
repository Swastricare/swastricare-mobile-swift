//
//  HealthStreaksView.swift
//  swastricare-mobile-swift
//
//  Created by Swasthicare AI
//

import SwiftUI

struct HealthStreaksView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedDay: Int = 1
    @State private var hasAppeared = false
    
    let days = Array(1...30)
    
    var body: some View {
        ZStack {
            streaksBackground
            
            VStack(spacing: 20) {
                headerSection
                
                Spacer()
                
                welcomeSection
                
                Spacer()
                
                mainStreakIcon
                
                streakInfoSection
                
                faqButton
                
                Spacer()
                
                dayCarousel
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
        }
    }
    
    // MARK: - Background
    
    private var streaksBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    MovementsColors.darkGreen,
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            StreaksGeometricPattern()
                .ignoresSafeArea()
            
            RadialGradient(
                colors: [
                    MovementsColors.limeGreen.opacity(0.15),
                    Color.clear
                ],
                center: .top,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            Spacer()
            
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : -20)
    }
    
    // MARK: - Welcome Section
    
    private var welcomeSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16))
                    .foregroundColor(MovementsColors.limeGreen)
                
                Text("Health Streaks")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(MovementsColors.limeGreen)
            }
            
            Text("Welcome to Health Streaks!")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: hasAppeared)
    }
    
    // MARK: - Main Streak Icon
    
    private var mainStreakIcon: some View {
        ZStack {
            Circle()
                .fill(MovementsColors.limeGreen)
                .frame(width: 130, height: 130)
                .shadow(color: MovementsColors.limeGreen.opacity(0.5), radius: 30, x: 0, y: 0)
            
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 3)
                .frame(width: 130, height: 130)
            
            Image(systemName: "bolt.fill")
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(.black)
        }
        .padding(.bottom, 10)
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.8)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: hasAppeared)
    }
    
    // MARK: - Streak Info Section
    
    private var streakInfoSection: some View {
        VStack(spacing: 10) {
            Text("Restart your Streak")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text("Start tracking again to earn points")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: hasAppeared)
    }
    
    // MARK: - FAQ Button
    
    private var faqButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 14, weight: .semibold))
                
                Text("FAQ")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(MovementsColors.limeGreen)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.top, 10)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: hasAppeared)
    }
    
    // MARK: - Day Carousel
    
    private var dayCarousel: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                Color.clear.frame(height: 100)
                
                ForEach(days, id: \.self) { day in
                    StreakDayItemView(day: day, isSelected: day == selectedDay, isLocked: day > 1)
                        .frame(height: 180)
                        .scrollTransition { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1.0 : 0.6)
                                .opacity(phase.isIdentity ? 1.0 : 0.5)
                                .blur(radius: phase.isIdentity ? 0 : 2)
                        }
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                selectedDay = day
                            }
                        }
                }
                
                Color.clear.frame(height: 100)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .frame(height: 350)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 20)
        }
        .opacity(hasAppeared ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35), value: hasAppeared)
    }
}

// MARK: - Streaks Geometric Pattern

struct StreaksGeometricPattern: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Path { path in
                    let spacing: CGFloat = 20
                    let startX = geometry.size.width * 0.3
                    
                    for i in 0..<12 {
                        let x = startX + CGFloat(i) * spacing
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x - geometry.size.height * 0.4, y: geometry.size.height))
                    }
                }
                .stroke(Color.white.opacity(0.03), lineWidth: 2)
                
                Circle()
                    .fill(MovementsColors.limeGreen.opacity(0.05))
                    .frame(width: 300, height: 300)
                    .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.2)
                
                Circle()
                    .fill(Color(hex: "4ECDC4").opacity(0.03))
                    .frame(width: 200, height: 200)
                    .offset(x: -geometry.size.width * 0.3, y: geometry.size.height * 0.6)
            }
        }
    }
}

struct StreakDayItemView: View {
    let day: Int
    let isSelected: Bool
    let isLocked: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 140, height: 140)
                        .shadow(color: MovementsColors.limeGreen.opacity(0.3), radius: 20, x: 0, y: 5)
                }
                
                if isLocked {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "FF9F43"), Color(hex: "FFB976")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: "lock.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 24, weight: .semibold))
                    }
                } else {
                    ZStack {
                        Circle()
                            .fill(MovementsColors.limeGreen)
                            .frame(width: 70, height: 70)
                        
                        Circle()
                            .stroke(Color.white.opacity(0.5), lineWidth: 2)
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.black)
                            .font(.system(size: 28, weight: .bold))
                    }
                }
            }
            
            VStack(spacing: 6) {
                Text("Day \(day)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isSelected ? .black : .white)
                
                if isSelected {
                    Text("Keep tracking to unlock your streak")
                        .font(.system(size: 12))
                        .foregroundColor(MovementsColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(width: 200)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let x = rect.midX
        let y = rect.midY
        let side = min(width, height) / 2
        
        // Pointy top hexagon
        let angle = CGFloat.pi / 3
        let startAngle = -CGFloat.pi / 2 // Start at top
        
        path.move(to: CGPoint(x: x + side * cos(startAngle), y: y + side * sin(startAngle)))
        
        for i in 1..<6 {
            let currentAngle = startAngle + angle * CGFloat(i)
            path.addLine(to: CGPoint(x: x + side * cos(currentAngle), y: y + side * sin(currentAngle)))
        }
        
        path.closeSubpath()
        return path
    }
}

#Preview {
    HealthStreaksView()
}
