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
    static let royalBlue = LinearGradient(colors: [Color(hex: "2E3192"), Color(hex: "1BFFFF")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let sunset = LinearGradient(colors: [Color(hex: "FF512F"), Color(hex: "DD2476")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let neonGreen = LinearGradient(colors: [Color(hex: "11998e"), Color(hex: "38ef7d")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let deepPurple = LinearGradient(colors: [Color(hex: "654ea3"), Color(hex: "eaafc8")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let midnight = LinearGradient(colors: [Color(hex: "232526"), Color(hex: "414345")], startPoint: .top, endPoint: .bottom)
    
    // Hex Helper
    static func hex(_ hex: String) -> Color {
        return Color(hex: hex)
    }
}

// MARK: - App Design System Colors (Unified across all screens)
/// Consistent color palette matching RunDetail/ActivityDetail screen styling

struct AppColors {
    // MARK: - Primary Accent Colors
    /// Primary accent blue - used for main actions, distance, pace, selection states
    static let accentBlue = Color(hex: "4F46E5")
    
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
    static let quickActionHeight: CGFloat = 150
    
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
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(1.5)
                        .foregroundStyle(PremiumColor.deepPurple)
                }
                
                Text(title)
                    .font(.system(size: 34, weight: .bold))
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
                                    .font(.title2)
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
                            .font(.title2)
                            .foregroundStyle(PremiumColor.royalBlue)
                    }
                }
            }
            .shadow(color: Color(hex: "2E3192").opacity(0.3), radius: 8, x: 0, y: 4)
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
