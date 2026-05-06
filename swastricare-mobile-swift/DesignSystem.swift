//
//  DesignSystem.swift
//  swastricare-mobile-swift
//
//  Created by SwastriCare Premium on 06/01/26.
//  Updated for Liquid Glass effect using standard SwiftUI materials
//

import SwiftUI
import UIKit

// MARK: - Premium Colors

struct PremiumColor {
    // Primary Gradients
    static let royalBlue = LinearGradient(colors: [AppColors.aiTeal, Color(hex: "1BFFFF")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let sunset = LinearGradient(colors: [Color(hex: "FF512F"), Color(hex: "DD2476")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let neonGreen = LinearGradient(colors: [Color(hex: "11998e"), Color(hex: "38ef7d")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let deepPurple = LinearGradient(colors: [Color(hex: "654ea3"), Color(hex: "eaafc8")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let midnight = LinearGradient(colors: [Color(hex: "232526"), Color(hex: "414345")], startPoint: .top, endPoint: .bottom)
    static let aiTeal = LinearGradient(colors: [Color(hex: "22C5A6"), Color(hex: "0E8C75")], startPoint: .topLeading, endPoint: .bottomTrailing)

    // Hex Helper
    static func hex(_ hex: String) -> Color {
        return Color(hex: hex)
    }
}

// MARK: - App Design System Colors (Unified across all screens)
/// Consistent color palette matching RunDetail/ActivityDetail screen styling

struct AppColors {
    // MARK: - Primary Accent Colors
    /// Primary accent — re-pointed to AITeal brand color so legacy `accentBlue` references pick up the new color.
    static let accentBlue = Color(hex: "22C5A6")
    
    /// Success/positive green - used for steps, walking, start buttons, achievements
    static let accentGreen = Color(hex: "22C55E")
    
    /// Danger/negative red - used for delete, errors, heart rate
    static let accentRed = Color(hex: "EF4444")
    
    /// Warning orange - used for calories, attention needed
    static let accentOrange = Color.orange
    
    /// Records/achievements yellow - used for personal records, trophies
    static let accentYellow = Color.yellow
    
    /// Cadence/activity purple - used for cadence, cycle tracker
    static let accentPurple = Color.purple

    // MARK: - Swastri AI brand
    /// Swastri AI accent — matches Android `AITeal` (#22C5A6)
    static let aiTeal = Color(hex: "22C5A6")
    static let aiTealDark = Color(hex: "0E8C75")

    // MARK: - Semantic Colors (by feature)
    static let steps = Color.green
    static let distance = accentBlue
    static let pace = accentBlue
    static let calories = Color.orange
    static let heartRate = Color.red
    static let sleep = Color.indigo
    static let exercise = Color.blue
    static let cadence = Color.purple
    static let hydration = Color.cyan
    static let medication = Color(hex: "5856D6") // iOS purple
    static let diet = accentGreen
    static let records = accentYellow
    
    // MARK: - Background Colors
    static let cardBackground = Color(UIColor.secondarySystemBackground)
    static let darkModeCard = Color.gray.opacity(0.05)
    
    // MARK: - Diet / Macro Colors
    static let dietOrange = Color(hex: "F97316")
    static let dietOrangeLight = Color(hex: "FB923C")
    static let macroBlue = Color(hex: "3B82F6")
    static let macroViolet = Color(hex: "8B5CF6")
    static let family = Color(hex: "10B981")

    // MARK: - Gradients
    static let blueGradient = LinearGradient(
        colors: [accentBlue, accentBlue.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let greenGradient = LinearGradient(
        colors: [accentGreen, accentGreen.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let dietOrangeGradient = LinearGradient(
        colors: [dietOrange, dietOrangeLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Home Screen Pastel Theme Colors

struct HomeThemeColors {
    // Per-card pastel backgrounds (light mode / dark mode)
    static func cardCalories(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "3D2C2C") : Color(hex: "FFF0E6")
    }
    static func cardExercise(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "2C2C3D") : Color(hex: "E8E6FF")
    }
    static func cardStand(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "2C3D2C") : Color(hex: "E6FFE6")
    }
    static func cardHeartRate(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "3D2C2F") : Color(hex: "FFE6EA")
    }
    static func cardSleep(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "2E2C3D") : Color(hex: "EDE6FF")
    }
    static func cardDistance(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "2C3D38") : Color(hex: "E6FFF5")
    }

    // Hero card gradient
    static func heroGradientStart(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? AppColors.aiTeal : Color(hex: "E0F2FE")
    }
    static func heroGradientEnd(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "1A3A2F") : Color(hex: "DCFCE7")
    }

    // Week strip
    static func weekDaySelected(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? AppColors.aiTeal : AppColors.aiTeal
    }
    static func weekDayDefault(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "2A2A2E") : Color(hex: "F3F4F6")
    }

    // Card surface
    static func cardSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "1C1C1E") : Color.white
    }

    // Quick action pastels — match Android brand colors
    // Android: MedicationColor #5856D6 / HydrationColor #00C7BE
    static func medicationBg(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "5856D6").opacity(0.18) : Color(hex: "5856D6").opacity(0.20)
    }
    static func hydrationBg(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "00C7BE").opacity(0.18) : Color(hex: "00C7BE").opacity(0.20)
    }
    static func cycleBg(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "3D1F3D") : Color(hex: "FCE4EC")
    }
    static func familyBg(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "1A3D2E") : Color(hex: "E8F5E9")
    }
}

// MARK: - App Design System Dimensions

struct AppDimensions {
    // MARK: - Corner Radius
    /// Standard card corner radius
    static let cardRadius: CGFloat = 16
    
    /// Large card/section corner radius
    static let largeCardRadius: CGFloat = 20
    
    /// Tab/pill button corner radius
    static let pillRadius: CGFloat = 20
    
    /// Quick action button corner radius
    static let quickActionRadius: CGFloat = 24
    
    // MARK: - Spacing
    /// Standard section spacing
    static let sectionSpacing: CGFloat = 24
    
    /// Standard card internal padding
    static let cardPadding: CGFloat = 16
    
    /// Large card internal padding
    static let largeCardPadding: CGFloat = 20
    
    // MARK: - Heights
    /// Quick action button height
    static let quickActionHeight: CGFloat = 100
    
    /// Stat card minimum height
    static let statCardHeight: CGFloat = 100
}

// MARK: - Liquid Glass View Modifiers

struct GlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var opacity: CGFloat = 0.1
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        colorScheme == .dark 
                            ? Color.white.opacity(0.2) 
                            : Color.black.opacity(0.1),
                        lineWidth: 0.5
                    )
            )
    }
}

extension View {
    /// Liquid Glass effect
    func glass(cornerRadius: CGFloat = 20) -> some View {
        self.modifier(GlassModifier(cornerRadius: cornerRadius))
    }
    
    /// Liquid Glass with custom shape - Capsule
    func liquidGlassCapsule() -> some View {
        self.background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(
                    Color.primary.opacity(0.1),
                    lineWidth: 0.5
                )
            )
    }
    
    /// Liquid Glass with custom shape - Circle
    func liquidGlassCircle() -> some View {
        self.background(.ultraThinMaterial)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(
                    Color.primary.opacity(0.1),
                    lineWidth: 0.5
                )
            )
    }
}

// MARK: - Premium Background
struct PremiumBackground: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Base Color
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            if colorScheme == .dark {
                // Dark theme orbs (softer glow) - static positions
                orb(color: .blue, opacity: 0.1, size: 350, blur: 100, x: -100, y: -150)
                orb(color: .purple, opacity: 0.1, size: 300, blur: 100, x: 150, y: 200)
                orb(color: .cyan, opacity: 0.08, size: 200, blur: 80, x: -100, y: 100)

            } else {
                // Light theme orbs (very subtle) - static positions
                orb(color: .blue, opacity: 0.04, size: 350, blur: 100, x: -100, y: -150)
                orb(color: .purple, opacity: 0.04, size: 300, blur: 100, x: 150, y: 200)
                orb(color: .cyan, opacity: 0.03, size: 200, blur: 80, x: -100, y: 100)
            }
        }
    }

    // MARK: - Orb Builder
    private func orb(
        color: Color,
        opacity: Double,
        size: CGFloat,
        blur: CGFloat,
        x: CGFloat,
        y: CGFloat
    ) -> some View {
        Circle()
            .fill(color.opacity(opacity))
            .frame(width: size, height: size)
            .blur(radius: blur)
            .offset(x: x, y: y)
    }
}


// MARK: - Hero Header

struct HeroHeader: View {
    let title: String
    let subtitle: String?
    let icon: String?
    var imageURL: URL? = nil
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let subtitle = subtitle {
                    Text(subtitle.uppercased())
                        .font(.poppins(.bold, size: 12))
                        .tracking(1.5)
                        .foregroundStyle(PremiumColor.deepPurple)
                }
                
                Text(title)
                    .font(.poppins(.bold, size: 34))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Spacer()
            
            // Profile Image
            Group {
                if let imageURL = imageURL {
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(PremiumColor.royalBlue, lineWidth: 2))
                    } placeholder: {
                        ZStack {
                            Circle()
                                .fill(.clear)
                                .frame(width: 60, height: 60)
                                .liquidGlassCircle()
                            
                            if let icon = icon {
                                Image(systemName: icon)
                                    .font(.poppins(.bold, size: 22))
                                    .foregroundStyle(PremiumColor.royalBlue)
                            } else {
                                ProgressView()
                            }
                        }
                    }
                } else if let icon = icon {
                    ZStack {
                        Circle()
                            .fill(.clear)
                            .frame(width: 60, height: 60)
                            .liquidGlassCircle()
                        
                        Image(systemName: icon)
                            .font(.poppins(.bold, size: 22))
                            .foregroundStyle(PremiumColor.royalBlue)
                    }
                }
            }
            .shadow(color: AppColors.aiTeal.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension Color {
    static var theme: PremiumColor.Type { PremiumColor.self }
}

// MARK: - Button Styles

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct LiquidGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 0.5))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Shimmer Loading Effect

/// Adds an animated diagonal light-sweep shimmer over the content.
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.5

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let width = geo.size.width
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.4),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: width * 0.6)
                    .offset(x: phase * width)
                    .clipped()
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

extension View {
    /// Applies a diagonal shimmer sweep animation.
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    /// Alias for `.shimmer()` — backwards compatibility.
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

/// A rounded placeholder shape with shimmer for skeleton loading states.
struct SkeletonShape: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.primary.opacity(0.08))
            .frame(width: width, height: height)
            .shimmer()
    }
}

/// A circular placeholder shape with shimmer for skeleton loading states.
struct SkeletonCircle: View {
    var size: CGFloat = 44

    var body: some View {
        Circle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: size, height: size)
            .shimmer()
    }
}

// MARK: - Water Wave Shape

struct WaterWave: Shape {
    var amplitude: CGFloat
    var offset: Double

    var animatableData: Double {
        get { offset }
        set { offset = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height

        // Wave oscillates around y = amplitude so it stays in [0, 2*amplitude], avoiding top cut-off.
        let cap = min(amplitude, height / 2)

        path.move(to: CGPoint(x: 0, y: cap * (1 + sin(offset))))

        for x in stride(from: 0, to: width, by: 2) {
            let relativeX = x / width
            let angle = relativeX * .pi * 2 + offset
            let y = cap * (1 + sin(angle))
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: height + cap))
        path.addLine(to: CGPoint(x: 0, y: height + cap))
        path.closeSubpath()

        return path
    }
}

// MARK: - Visual Effect Blur

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}
