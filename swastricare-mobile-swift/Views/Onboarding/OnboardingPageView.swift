//
//  OnboardingPageView.swift
//  swastricare-mobile-swift
//

import SwiftUI

struct OnboardingPageView<Card: View>: View {
    let pageIndex: Int
    let totalPages: Int
    let title: String
    let highlightedTitle: String
    let subtitle: String
    let accentColor: Color
    let backgroundTint: Color
    let isActive: Bool
    let card: Card

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Animation state — driven by `isActive` changes from parent
    @State private var headlineOffset: CGFloat = 20
    @State private var headlineOpacity: Double = 0
    @State private var subtitleOffset: CGFloat = 15
    @State private var subtitleOpacity: Double = 0
    @State private var cardOffset: CGFloat = 30
    @State private var cardOpacity: Double = 0
    @State private var hasAnimatedIn = false

    init(
        pageIndex: Int,
        totalPages: Int,
        title: String,
        highlightedTitle: String,
        subtitle: String,
        accentColor: Color,
        backgroundTint: Color,
        isActive: Bool,
        @ViewBuilder card: () -> Card
    ) {
        self.pageIndex = pageIndex
        self.totalPages = totalPages
        self.title = title
        self.highlightedTitle = highlightedTitle
        self.subtitle = subtitle
        self.accentColor = accentColor
        self.backgroundTint = backgroundTint
        self.isActive = isActive
        self.card = card()
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 16)

                    // Headline
                    VStack(alignment: .leading, spacing: 0) {
                        Text(title)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.primary)
                        Text(highlightedTitle)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(accentColor)
                    }
                    .offset(y: headlineOffset)
                    .opacity(headlineOpacity)
                    .padding(.bottom, 8)

                    // Subtitle
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                        .offset(y: subtitleOffset)
                        .opacity(subtitleOpacity)
                        .padding(.bottom, 24)

                    // Preview card
                    card
                        .offset(y: cardOffset)
                        .opacity(cardOpacity)
                        .frame(maxWidth: 400)

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 24)
                .frame(minHeight: geo.size.height)
            }
            .scrollIndicators(.hidden)
        }
        .background(pageBackground)
        .onChange(of: isActive) { _, active in
            if active {
                // Small delay ensures view is laid out before animating
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    guard !hasAnimatedIn else { return }
                    animateIn()
                }
            } else {
                hasAnimatedIn = false
                animateOut()
            }
        }
        .onAppear {
            // First page animates immediately
            if isActive && !hasAnimatedIn {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    guard !hasAnimatedIn else { return }
                    if reduceMotion {
                        showInstantly()
                    } else {
                        animateIn()
                    }
                }
            }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var pageBackground: some View {
        if colorScheme == .dark {
            Color.clear // parent provides PremiumBackground
        } else {
            LinearGradient(
                colors: [Color(UIColor.systemBackground), backgroundTint],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Animations

    private func animateIn() {
        hasAnimatedIn = true
        guard !reduceMotion else {
            showInstantly()
            return
        }
        // Staggered spring entrance
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05)) {
            headlineOffset = 0
            headlineOpacity = 1
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15)) {
            subtitleOffset = 0
            subtitleOpacity = 1
        }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.25)) {
            cardOffset = 0
            cardOpacity = 1
        }
    }

    private func animateOut() {
        withAnimation(.easeOut(duration: 0.2)) {
            headlineOpacity = 0
            subtitleOpacity = 0
            cardOpacity = 0
        }
        // Reset offsets synchronously without animation so next animateIn slides fresh
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            headlineOffset = 20
            subtitleOffset = 15
            cardOffset = 30
        }
    }

    private func showInstantly() {
        hasAnimatedIn = true
        headlineOffset = 0
        headlineOpacity = 1
        subtitleOffset = 0
        subtitleOpacity = 1
        cardOffset = 0
        cardOpacity = 1
    }
}
