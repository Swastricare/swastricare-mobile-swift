//
//  HealthStreaksView.swift
//  swastricare-mobile-swift
//
//  Created by Swasthicare AI
//

import SwiftUI

struct HealthStreaksView: View {
    @State private var selectedDay: Int = 1
    
    // Mock data for the days
    let days = Array(1...30)
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [
                    Color(hex: "4A90E2"), // Light Blue
                    Color(hex: "2E3192")  // Dark Blue
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // City Silhouette Background (Placeholder)
            VStack {
                Spacer()
                Image(systemName: "building.2.fill") // Placeholder for city silhouette
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: UIScreen.main.bounds.width)
                    .foregroundColor(.black.opacity(0.1))
                    .offset(y: 50)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button(action: {
                        // Back action if needed
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.white)
                            .opacity(0) // Hidden for main tab
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // Info action
                    }) {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Welcome Text
                Text("Welcome to Health Streaks!")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Main Hexagon Icon (Top Center)
                ZStack {
                    HexagonShape()
                        .fill(Color.white)
                        .frame(width: 120, height: 120)
                        .shadow(color: .white.opacity(0.5), radius: 20, x: 0, y: 0)
                    
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "2E3192"))
                }
                .padding(.bottom, 10)
                
                // Streak Text
                VStack(spacing: 8) {
                    Text("Restart your Streak")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Start tracking again to earn points")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // FAQ Button
                Button(action: {
                    // FAQ Action
                }) {
                    Text("FAQ")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "2E3192"))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 10)
                
                Spacer()
                
                // Vertical Carousel
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        // Add some padding at the top so the first item can be centered
                        Color.clear.frame(height: 100)
                        
                        ForEach(days, id: \.self) { day in
                            DayItemView(day: day, isSelected: day == selectedDay, isLocked: day > 1)
                                .frame(height: 180) // Increased height for better spacing
                                .scrollTransition { content, phase in
                                    content
                                        .scaleEffect(phase.isIdentity ? 1.0 : 0.6)
                                        .opacity(phase.isIdentity ? 1.0 : 0.5)
                                        .blur(radius: phase.isIdentity ? 0 : 2)
                                }
                                .onTapGesture {
                                    withAnimation {
                                        selectedDay = day
                                    }
                                }
                        }
                        
                        // Add padding at bottom
                        Color.clear.frame(height: 100)
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .frame(height: 350) // Adjust height to show ~3 items
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 20)
                }
            }
        }
    }
}

struct DayItemView: View {
    let day: Int
    let isSelected: Bool
    let isLocked: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background Circle for Selected Item
                if isSelected {
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 140, height: 140)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
                
                // Hexagon
                if isLocked {
                    HexagonShape()
                        .fill(Color(hex: "F5A623")) // Orange for locked
                        .frame(width: 70, height: 70)
                        .overlay(
                            Image(systemName: "lock.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                        )
                } else {
                    HexagonShape()
                        .stroke(Color(hex: "2E3192"), lineWidth: 3)
                        .background(HexagonShape().fill(Color.white))
                        .frame(width: 70, height: 70)
                        .overlay(
                            Image(systemName: "bolt.fill")
                                .foregroundColor(Color(hex: "2E3192"))
                                .font(.title2)
                        )
                }
            }
            
            VStack(spacing: 4) {
                Text("Day \(day)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .black : .white)
                
                if isSelected {
                    Text("Keep tracking to unlock your streak")
                        .font(.caption)
                        .foregroundColor(.gray)
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
