//
//  MovementsComponents.swift
//  swastricare-mobile-swift
//
//  Reusable UI components for the Movements+ screens
//

import SwiftUI
import UIKit

// MARK: - Design Colors for Movements+

struct MovementsColors {
    static let limeGreen = Color(hex: "C6FF00")
    static let darkGreen = Color(hex: "1B4332")
    static let darkGray = Color(hex: "1C1C1E")
    static let cardDark = Color(hex: "2C2C2E")
    /// Light theme card background
    static let cardLight = Color(UIColor.secondarySystemBackground)
    static let textSecondary = Color(hex: "8E8E93")
    static let progressBackground = Color(hex: "3A3A3C")
    
    /// Card background that adapts to color scheme (use with @Environment(\.colorScheme)).
    static func card(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? cardDark : cardLight
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    var trackColor: Color = MovementsColors.progressBackground
    var progressColor: Color = MovementsColors.limeGreen
    var showPercentage: Bool = false
    var percentageTextColor: Color = .primary
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            
            if showPercentage {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                    .foregroundColor(percentageTextColor)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .black : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? MovementsColors.limeGreen : Color.clear)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.primary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Activity Card (New Geometric Design)

struct MovementsActivityCard: View {
    let title: String
    let subtitle: String
    let progress: Double
    let icon: String
    let backgroundColor: Color
    let progressColor: Color
    var contentColor: Color = .white
    var showGeometricPattern: Bool = true
    let action: () -> Void
    var onExpandTapped: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(backgroundColor)
            
            if showGeometricPattern && backgroundColor == MovementsColors.limeGreen {
                GeometricPatternView()
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(contentColor)
                    
                    Spacer()
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onExpandTapped?()
                    }) {
                        ZStack {
                            Circle()
                                .fill(contentColor.opacity(0.15))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(contentColor)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your progress")
                        .font(.system(size: 13))
                        .foregroundColor(contentColor.opacity(0.7))
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(contentColor)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(contentColor.opacity(0.2))
                                .frame(height: 8)
                            
                            Capsule()
                                .fill(contentColor)
                                .frame(width: geometry.size.width * progress, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.horizontal, 16)
                
                HStack {
                    Button(action: action) {
                        Text("Continue")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(contentColor)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(contentColor.opacity(0.2))
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Spacer()
                    
                    // MiniAvatarStackView(contentColor: contentColor)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .padding(.top, 12)
            }
        }
        .frame(width: 180, height: 220)
    }
}

// MARK: - Geometric Pattern View

struct GeometricPatternView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Path { path in
                    let spacing: CGFloat = 12
                    let startX = geometry.size.width * 0.5
                    
                    for i in 0..<8 {
                        let x = startX + CGFloat(i) * spacing
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x - geometry.size.height * 0.5, y: geometry.size.height))
                    }
                }
                .stroke(Color.black.opacity(0.08), lineWidth: 2)
            }
        }
    }
}

// MARK: - Mini Avatar Stack for Activity Card

struct MiniAvatarStackView: View {
    var contentColor: Color = .white
    
    private let avatarColors = ["FF6B6B", "4ECDC4", "45B7D1"]
    
    var body: some View {
        HStack(spacing: -8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: avatarColors[index]),
                                Color(hex: avatarColors[(index + 1) % avatarColors.count])
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(contentColor.opacity(0.3), lineWidth: 1.5)
                    )
                    .zIndex(Double(3 - index))
            }
        }
    }
}


// MARK: - Avatar Stack View

struct AvatarStackView: View {
    let count: Int
    let avatarSize: CGFloat
    
    var body: some View {
        HStack(spacing: -10) {
            ForEach(0..<min(count, 4), id: \.self) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: avatarColors[index % avatarColors.count]),
                                Color(hex: avatarColors[(index + 1) % avatarColors.count])
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .zIndex(Double(4 - index))
            }
            
            if count > 4 {
                ZStack {
                    Circle()
                        .fill(MovementsColors.darkGray)
                        .frame(width: avatarSize, height: avatarSize)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                    
                    Text("+\(count - 4)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private let avatarColors = ["FF6B6B", "4ECDC4", "45B7D1", "96CEB4", "FFEAA7", "DDA0DD"]
}

// MARK: - Workout Progress Card (Legacy)

struct WorkoutProgressCard: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let currentHours: Int
    let goalHours: Int
    let action: () -> Void
    
    private var progress: Double {
        guard goalHours > 0 else { return 0 }
        return Double(currentHours) / Double(goalHours)
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                CircularProgressView(
                    progress: progress,
                    lineWidth: 8,
                    size: 80,
                    trackColor: colorScheme == .dark ? MovementsColors.progressBackground : Color.primary.opacity(0.2),
                    progressColor: MovementsColors.limeGreen,
                    showPercentage: false
                )
                .overlay(
                    VStack(spacing: 2) {
                        Text("\(currentHours)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("/\(goalHours)H")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total Time")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Text("Workout Progress")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("\(Int(progress * 100))% completed")
                        .font(.system(size: 13))
                        .foregroundColor(MovementsColors.limeGreen)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(MovementsColors.card(for: colorScheme))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Animated Vitals Card (Same layout as WorkoutProgressCard)

struct AnimatedVitalsCard: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let steps: Int
    let heartRate: Int
    let calories: Int
    let sleepHours: String
    let exerciseMinutes: Int
    let action: () -> Void
    
    @State private var currentIndex: Int = 0
    @State private var animatedProgress: Double = 0
    
    private var vitals: [(icon: String, title: String, subtitle: String, value: String, goal: String, progress: Double)] {
        [
            (
                icon: "figure.walk",
                title: "Steps",
                subtitle: "Daily Goal",
                value: formatSteps(steps),
                goal: "/10,000",
                progress: min(Double(steps) / 10000.0, 1.0)
            ),
            (
                icon: "heart.fill",
                title: "Heart Rate",
                subtitle: "Current",
                value: "\(heartRate > 0 ? heartRate : 72)",
                goal: " bpm",
                progress: min(Double(heartRate > 0 ? heartRate : 72) / 120.0, 1.0)
            ),
            (
                icon: "flame.fill",
                title: "Calories",
                subtitle: "Active",
                value: "\(calories)",
                goal: "/500 kcal",
                progress: min(Double(calories) / 500.0, 1.0)
            ),
            (
                icon: "moon.fill",
                title: "Sleep",
                subtitle: "Last Night",
                value: parseSleepDisplay(sleepHours),
                goal: "/8 hrs",
                progress: min(parseSleepHours(sleepHours) / 8.0, 1.0)
            ),
            (
                icon: "figure.run",
                title: "Exercise",
                subtitle: "Today",
                value: "\(exerciseMinutes)",
                goal: "/30 min",
                progress: min(Double(exerciseMinutes) / 30.0, 1.0)
            )
        ]
    }
    
    private var current: (icon: String, title: String, subtitle: String, value: String, goal: String, progress: Double) {
        vitals[currentIndex]
    }
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            HStack(spacing: 20) {
                CircularProgressView(
                    progress: animatedProgress,
                    lineWidth: 8,
                    size: 80,
                    trackColor: colorScheme == .dark ? MovementsColors.progressBackground : Color.primary.opacity(0.2),
                    progressColor: MovementsColors.limeGreen,
                    showPercentage: false
                )
                .overlay(
                    VStack(spacing: 2) {
                        Text(current.value)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                        Text(current.goal)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .id("progress-\(currentIndex)")
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(current.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: current.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(current.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .id("title-\(currentIndex)")
                    
                    Text("\(Int(current.progress * 100))% completed")
                        .font(.system(size: 13))
                        .foregroundColor(MovementsColors.limeGreen)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(MovementsColors.card(for: colorScheme))
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .onAppear {
            animatedProgress = current.progress
            startCycling()
        }
    }
    
    private func startCycling() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentIndex = (currentIndex + 1) % vitals.count
            }
            withAnimation(.easeOut(duration: 0.6)) {
                animatedProgress = vitals[currentIndex].progress
            }
        }
    }
    
    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000.0)
        }
        return "\(steps)"
    }
    
    private func parseSleepDisplay(_ sleepString: String) -> String {
        let hours = parseSleepHours(sleepString)
        if hours == 0 { return "0" }
        return String(format: "%.1f", hours)
    }
    
    private func parseSleepHours(_ sleepString: String) -> Double {
        let components = sleepString.lowercased().components(separatedBy: CharacterSet.letters.union(.whitespaces))
        let numbers = components.compactMap { Double($0) }
        if numbers.count >= 2 {
            return numbers[0] + numbers[1] / 60.0
        } else if numbers.count == 1 {
            return numbers[0]
        }
        return 0
    }
}

// MARK: - Fluid Progress Indicator (Body Composition)

struct FluidProgressIndicator: View {
    let progress: Double
    @State private var waveOffset: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(MovementsColors.cardDark)
                
                FluidWaveShape(progress: progress, waveOffset: waveOffset)
                    .fill(
                        LinearGradient(
                            colors: [
                                MovementsColors.limeGreen.opacity(0.4),
                                MovementsColors.limeGreen.opacity(0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                FluidWaveShape(progress: progress, waveOffset: waveOffset + 1.5)
                    .fill(
                        LinearGradient(
                            colors: [
                                MovementsColors.limeGreen.opacity(0.3),
                                MovementsColors.limeGreen.opacity(0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                waveOffset = .pi * 2
            }
        }
    }
}

struct FluidWaveShape: Shape {
    var progress: Double
    var waveOffset: Double
    
    var animatableData: Double {
        get { waveOffset }
        set { waveOffset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let height = rect.height * (1 - progress)
        let amplitude: CGFloat = 8
        
        path.move(to: CGPoint(x: 0, y: height))
        
        for x in stride(from: 0, to: rect.width, by: 2) {
            let relativeX = x / rect.width
            let angle = relativeX * .pi * 3 + waveOffset
            let y = height + sin(angle) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Stat Card (for Daily Activities)

struct MovementsStatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let backgroundColor: Color
    let textColor: Color
    var showChart: Bool = false
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { action?() }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.8))
                    
                    Spacer()
                    
                    if showChart {
                        MovementsMiniChartView()
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundColor(textColor.opacity(0.7))
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(textColor)
                        
                        Text(unit)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(textColor.opacity(0.6))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(action == nil)
    }
}

// MARK: - Mini Chart View

struct MovementsMiniChartView: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<7, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 4, height: CGFloat.random(in: 10...30))
            }
        }
    }
}

// MARK: - Heart Rate Bar Chart

struct HeartRateBarChart: View {
    let data: [(String, Int, Bool)]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 8) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 36, height: 150)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                item.2 
                                    ? LinearGradient(
                                        colors: [MovementsColors.limeGreen, MovementsColors.limeGreen.opacity(0.6)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    : LinearGradient(
                                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                            )
                            .frame(width: 36, height: CGFloat(item.1) / 200 * 150)
                    }
                    
                    Text(item.0)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }
}

// MARK: - Benchmark Range Bar

struct BenchmarkRangeBar: View {
    let title: String
    let value: Double
    let maxValue: Double
    let color: Color
    
    private var progress: Double {
        guard maxValue > 0 else { return 0 }
        return min(value / maxValue, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(String(format: "%.0f", value))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: geometry.size.width * progress)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 12)
        }
    }
}

// MARK: - Preview

// MARK: - Animated AI Text Field

struct AnimatedAITextField: View {
    @Environment(\.colorScheme) private var colorScheme
    let action: () -> Void
    
    @State private var gradientRotation: Double = 0
    @State private var placeholderIndex: Int = 0
    @State private var displayedText: String = ""
    @State private var isTyping = true
    @State private var cursorVisible = true
    
    private let placeholders = [
        "Ask me anything about health...",
        "How can I improve my sleep?",
        "What's a good post-workout meal?",
        "Analyze my heart rate trends",
        "Help me build a workout plan"
    ]
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            HStack(spacing: 14) {
                // AI Icon with animated gradient
                ZStack {
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [
                                    MovementsColors.limeGreen,
                                    Color(hex: "4ECDC4"),
                                    Color(hex: "45B7D1"),
                                    MovementsColors.limeGreen
                                ],
                                center: .center,
                                angle: .degrees(gradientRotation)
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Typewriter text with cursor
                HStack(spacing: 0) {
                    Text(displayedText)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    
                    if isTyping {
                        Text("|")
                            .font(.system(size: 15, weight: .light))
                            .foregroundColor(MovementsColors.limeGreen)
                            .opacity(cursorVisible ? 1 : 0)
                    }
                }
                .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(MovementsColors.limeGreen)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(MovementsColors.card(for: colorScheme))
                    
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    MovementsColors.limeGreen.opacity(0.8),
                                    Color(hex: "4ECDC4").opacity(0.5),
                                    Color(hex: "45B7D1").opacity(0.3),
                                    Color(hex: "5856D6").opacity(0.5),
                                    MovementsColors.limeGreen.opacity(0.8)
                                ],
                                center: .center,
                                angle: .degrees(gradientRotation)
                            ),
                            lineWidth: 1.5
                        )
                }
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Border rotation
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            gradientRotation = 360
        }
        
        // Cursor blink
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            cursorVisible.toggle()
        }
        
        // Start typewriter
        typeNextPlaceholder()
    }
    
    private func typeNextPlaceholder() {
        let target = placeholders[placeholderIndex]
        displayedText = ""
        isTyping = true
        
        for (index, character) in target.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                displayedText += String(character)
                
                if index == target.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        eraseText()
                    }
                }
            }
        }
    }
    
    private func eraseText() {
        isTyping = false
        let length = displayedText.count
        
        for index in 0..<length {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.02) {
                if !displayedText.isEmpty {
                    displayedText.removeLast()
                }
                
                if index == length - 1 {
                    placeholderIndex = (placeholderIndex + 1) % placeholders.count
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        typeNextPlaceholder()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 20) {
            AnimatedAITextField { }
                .padding(.horizontal, 20)
            
            CircularProgressView(
                progress: 0.65,
                lineWidth: 8,
                size: 100,
                showPercentage: true
            )
            
            HStack {
                FilterChip(title: "All", isSelected: true) {}
                FilterChip(title: "Sports", isSelected: false) {}
            }
            
            AvatarStackView(count: 215, avatarSize: 32)
            
            WorkoutProgressCard(currentHours: 10, goalHours: 20) {}
        }
        .padding()
    }
}
