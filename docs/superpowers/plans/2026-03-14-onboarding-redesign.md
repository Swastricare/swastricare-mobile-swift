# Onboarding Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current 3-screen onboarding (3D models + generic copy) with benefit-first storytelling screens using bold typography and app-preview cards, targeting Indian users.

**Architecture:** Pure SwiftUI rewrite of `OnboardingView` and `OnboardingPageView`. Three new preview card views in a dedicated file. Animation state driven from parent (`OnboardingView`) via `currentPage` changes rather than per-page `onAppear`/`onDisappear`. Reuses existing `DesignSystem.swift` components (`AppColors`, `ScaleButtonStyle`, `.glass()`, `PremiumBackground`).

**Tech Stack:** SwiftUI, existing `DesignSystem.swift`, `AppAnalyticsService`

**Spec:** `docs/superpowers/specs/2026-03-14-onboarding-redesign-design.md`

---

## Chunk 1: Preview Card Views

### Task 1: Create OnboardingPreviewCards.swift with FamilyPreviewCard

**Files:**
- Create: `swastricare-mobile-swift/Views/Onboarding/OnboardingPreviewCards.swift`

**Context:** This file will contain all 3 preview card views. Each card is a self-contained SwiftUI view showing a mini app preview. They use `AppColors` from `DesignSystem.swift` and the `.glass()` modifier for dark mode. Read `swastricare-mobile-swift/DesignSystem.swift` for `AppColors` values, `AppDimensions`, and the `.glass()` modifier signature.

- [ ] **Step 1: Create OnboardingPreviewCards.swift with FamilyPreviewCard**

```swift
//
//  OnboardingPreviewCards.swift
//  swastricare-mobile-swift
//

import SwiftUI

// MARK: - Onboarding Color Constants

extension AppColors {
    /// Purple accent for AI screen
    static let onboardingPurple = Color(hex: "7C3AED")
    /// Sky blue accent for Vault screen
    static let onboardingSkyBlue = Color(hex: "0EA5E9")
}

// MARK: - Shared Card Style

/// Shared card chrome for all onboarding preview cards (background + clip + shadow)
private struct OnboardingCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(AppDimensions.cardPadding)
            .background(colorScheme == .dark ? AnyView(Color.clear.background(.ultraThinMaterial)) : AnyView(AppColors.cardBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppDimensions.largeCardRadius))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 12, y: 4)
    }
}

extension View {
    fileprivate func onboardingCard() -> some View {
        modifier(OnboardingCardModifier())
    }
}

// MARK: - Screen 1: Family Health Hub Preview

struct FamilyPreviewCard: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var alertPulse: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            // Family member header
            HStack(spacing: 10) {
                Circle()
                    .fill(LinearGradient(colors: [AppColors.accentBlue, AppColors.onboardingPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                    .overlay(Text("👩").font(.system(size: 18)))
                    .shadow(color: AppColors.accentBlue.opacity(0.25), radius: 6, y: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Amma")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Last updated 2m ago")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("All Good")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color(hex: "16A34A"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "DCFCE7"))
                    .clipShape(Capsule())
            }

            // Stats row
            HStack(spacing: 6) {
                StatCell(label: "Blood Pressure", value: "120/80", detail: "Normal", detailColor: AppColors.accentGreen)
                StatCell(label: "Medications", value: "2/2 ✓", detail: "On track", detailColor: AppColors.accentGreen)
                StatCell(label: "Hydration", value: "1.5L", detail: "60%", detailColor: .orange)
            }

            // Alert row — Appa missed medication
            HStack(spacing: 10) {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: "F59E0B"), Color(hex: "D97706")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 28, height: 28)
                    .overlay(Text("👴").font(.system(size: 14)))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Appa")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Missed evening medication")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.accentRed)
                }

                Spacer()

                Text("⚠️")
                    .font(.system(size: 14))
                    .scaleEffect(alertPulse ? 1.15 : 1.0)
            }
            .padding(10)
            .background(AppColors.accentRed.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .onboardingCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Family health dashboard showing Amma's blood pressure at 120 over 80, medications on track, and an alert for Appa's missed medication")
        .onChange(of: isActive) { _, active in
            guard !reduceMotion else { return }
            if active {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    alertPulse = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    alertPulse = false
                }
            }
        }
    }
}

// MARK: - Stat Cell (reused within FamilyPreviewCard)

private struct StatCell: View {
    let label: String
    let value: String
    let detail: String
    let detailColor: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
            Text(detail)
                .font(.system(size: 8))
                .foregroundColor(detailColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 2: Build to verify no compile errors**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add swastricare-mobile-swift/Views/Onboarding/OnboardingPreviewCards.swift
git commit -m "feat(onboarding): add FamilyPreviewCard for screen 1"
```

---

### Task 2: Add AIPreviewCard to OnboardingPreviewCards.swift

**Files:**
- Modify: `swastricare-mobile-swift/Views/Onboarding/OnboardingPreviewCards.swift`

- [ ] **Step 1: Append AIPreviewCard to the file**

Add after `StatCell` at the bottom of the file:

```swift
// MARK: - Screen 2: AI Health Companion Preview

struct AIPreviewCard: View {
    var body: some View {
        VStack(spacing: 10) {
            // User message
            HStack {
                Spacer()
                Text("Is 140/90 BP normal for a 55 year old?")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(AppColors.accentBlue)
                    .clipShape(
                        .rect(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 16,
                            bottomTrailingRadius: 4,
                            topTrailingRadius: 16
                        )
                    )
            }

            // AI response
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [AppColors.onboardingPurple, AppColors.accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 24, height: 24)
                    .overlay(Text("✦").font(.system(size: 12)).foregroundColor(.white))

                VStack(alignment: .leading, spacing: 6) {
                    Text("**140/90 is Stage 1 hypertension** for any adult. For a 55-year-old, the target is usually below 130/80.")
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .lineSpacing(3)

                    HStack(spacing: 4) {
                        Text("Recommendation:")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.onboardingPurple)
                        Text("Monitor daily for a week.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            // Quick suggestion pills
            HStack(spacing: 6) {
                SuggestionPill(text: "What foods reduce BP?", color: AppColors.onboardingPurple)
                SuggestionPill(text: "When to see a doctor?", color: AppColors.onboardingPurple)
                Spacer()
            }
        }
        .onboardingCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("AI health chat showing a question about blood pressure and a helpful medical response with follow-up suggestions")
    }
}

private struct SuggestionPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.08))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.15), lineWidth: 1))
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add swastricare-mobile-swift/Views/Onboarding/OnboardingPreviewCards.swift
git commit -m "feat(onboarding): add AIPreviewCard for screen 2"
```

---

### Task 3: Add VaultPreviewCard to OnboardingPreviewCards.swift

**Files:**
- Modify: `swastricare-mobile-swift/Views/Onboarding/OnboardingPreviewCards.swift`

- [ ] **Step 1: Append VaultPreviewCard to the file**

Add after `SuggestionPill` at the bottom of the file:

```swift
// MARK: - Screen 3: Medical Vault Preview

struct VaultPreviewCard: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    /// Only shimmer when active and motion is allowed
    private var shouldShimmer: Bool {
        isActive && !reduceMotion
    }

    var body: some View {
        VStack(spacing: 8) {
            DocumentRow(
                icon: "PDF",
                iconGradient: [AppColors.accentRed, Color(hex: "DC2626")],
                iconIsText: true,
                title: "Blood Test — Thyrocare",
                subtitle: "Mar 2026 · CBC, Lipid, Thyroid"
            )
            DocumentRow(
                icon: "🩻",
                iconGradient: [AppColors.onboardingSkyBlue, Color(hex: "0284C7")],
                iconIsText: false,
                title: "X-Ray — Apollo Hospital",
                subtitle: "Feb 2026 · Chest X-Ray"
            )
            DocumentRow(
                icon: "💊",
                iconGradient: [AppColors.accentGreen, Color(hex: "16A34A")],
                iconIsText: false,
                title: "Prescription — Dr. Sharma",
                subtitle: "Jan 2026 · Diabetes Management"
            )

            // Security badge
            HStack(spacing: 8) {
                Text("🛡️").font(.system(size: 16))

                VStack(alignment: .leading, spacing: 1) {
                    Text("End-to-End Encrypted")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Only you and who you share with can access")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [AppColors.onboardingSkyBlue.opacity(0.08), AppColors.accentBlue.opacity(0.08)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.onboardingSkyBlue.opacity(0.12), lineWidth: 1))
            .modifier(ConditionalShimmer(active: shouldShimmer))
        }
        .onboardingCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Medical vault showing blood test from Thyrocare, X-ray from Apollo Hospital, and prescription from Dr. Sharma, all end-to-end encrypted")
    }
}

private struct DocumentRow: View {
    let icon: String
    let iconGradient: [Color]
    let iconIsText: Bool
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: iconGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 36, height: 36)
                .overlay(
                    Group {
                        if iconIsText {
                            Text(icon)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text(icon).font(.system(size: 16))
                        }
                    }
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("🔒").font(.system(size: 14))
        }
        .padding(10)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Applies shimmer only when active (respects Reduce Motion)
private struct ConditionalShimmer: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.shimmer()
        } else {
            content
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add swastricare-mobile-swift/Views/Onboarding/OnboardingPreviewCards.swift
git commit -m "feat(onboarding): add VaultPreviewCard for screen 3"
```

---

## Chunk 2: Rewrite OnboardingPageView and OnboardingView

### Task 4: Rewrite OnboardingPageView

**Files:**
- Modify: `swastricare-mobile-swift/Views/Onboarding/OnboardingPageView.swift` (complete rewrite)

**Context:** The current file uses `ModelViewer` (SceneKit 3D) and per-page `@State` animation with `onAppear`/`onDisappear` hard resets. The new version uses bold typography + a preview card slot, and receives its animation trigger from the parent via a binding. Read the existing file at `swastricare-mobile-swift/Views/Onboarding/OnboardingPageView.swift` to understand the current interface, then replace the entire body.

- [ ] **Step 1: Rewrite OnboardingPageView.swift**

Replace the entire file contents with:

```swift
//
//  OnboardingPageView.swift
//  swastricare-mobile-swift
//

import SwiftUI

struct OnboardingPageView<Card: View>: View {
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

    init(
        title: String,
        highlightedTitle: String,
        subtitle: String,
        accentColor: Color,
        backgroundTint: Color,
        isActive: Bool,
        @ViewBuilder card: () -> Card
    ) {
        self.title = title
        self.highlightedTitle = highlightedTitle
        self.subtitle = subtitle
        self.accentColor = accentColor
        self.backgroundTint = backgroundTint
        self.isActive = isActive
        self.card = card()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
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
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
        .background(pageBackground)
        .onChange(of: isActive) { _, active in
            if active {
                animateIn()
            } else {
                animateOut()
            }
        }
        .onAppear {
            if isActive {
                if reduceMotion {
                    showInstantly()
                } else {
                    animateIn()
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
        headlineOffset = 0
        headlineOpacity = 1
        subtitleOffset = 0
        subtitleOpacity = 1
        cardOffset = 0
        cardOpacity = 1
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: Build may fail because `OnboardingView` still references old `OnboardingPageView` init signature. That's OK — we fix it in the next task.

- [ ] **Step 3: Commit**

```bash
git add swastricare-mobile-swift/Views/Onboarding/OnboardingPageView.swift
git commit -m "refactor(onboarding): rewrite OnboardingPageView with bold type + card slot"
```

---

### Task 5: Rewrite OnboardingView

**Files:**
- Modify: `swastricare-mobile-swift/Views/Onboarding/OnboardingView.swift` (complete rewrite)

**Context:** This is the parent container. It owns `currentPage`, passes `isActive` to each page, handles the skip/next/get-started buttons, page dots, and completion. The new version drives per-screen accent colors, uses spring animations for page transitions, and removes the dead `hasSeenOnboardingKey` write. Read the existing file and the spec's "State Management" and "Navigation Controls" sections.

- [ ] **Step 1: Rewrite OnboardingView.swift**

Replace the entire file contents with:

```swift
//
//  OnboardingView.swift
//  swastricare-mobile-swift
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentPage = 0
    @State private var skipOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var isAnimating: Bool = false

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private let totalPages = 3
    private let buttonWidth: CGFloat = 180
    private let buttonHeight: CGFloat = 52

    /// Per-screen accent colors for the narrative color progression
    private static let accentColors: [Color] = [
        AppColors.accentBlue,          // Screen 1: Indigo
        AppColors.onboardingPurple,    // Screen 2: Purple
        AppColors.onboardingSkyBlue,   // Screen 3: Sky Blue
    ]

    private var currentAccent: Color {
        Self.accentColors[currentPage]
    }

    var body: some View {
        ZStack {
            // Background
            PremiumBackground()

            VStack(spacing: 0) {
                // Skip button — top right, delayed appearance
                HStack {
                    Spacer()
                    Button {
                        guard !isAnimating else { return }
                        completeOnboarding()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .disabled(isAnimating)
                    .opacity(skipOpacity)
                    .padding(.trailing, 24)
                    .padding(.top, 12)
                }

                // Pages
                TabView(selection: $currentPage) {
                    OnboardingPageView(
                        title: "Your family's health,",
                        highlightedTitle: "in your hands",
                        subtitle: "Track your parents' vitals from anywhere. Get alerts when Amma misses her medication.",
                        accentColor: Self.accentColors[0],
                        backgroundTint: Color(hex: "EEF2FF"),
                        isActive: currentPage == 0
                    ) {
                        FamilyPreviewCard(isActive: currentPage == 0)
                    }
                    .tag(0)

                    OnboardingPageView(
                        title: "Ask anything.",
                        highlightedTitle: "Get real answers.",
                        subtitle: "AI that understands Indian health — from BP readings to Ayurvedic questions.",
                        accentColor: Self.accentColors[1],
                        backgroundTint: Color(hex: "F3E8FF"),
                        isActive: currentPage == 1
                    ) {
                        AIPreviewCard()
                    }
                    .tag(1)

                    OnboardingPageView(
                        title: "Every report.",
                        highlightedTitle: "Always with you.",
                        subtitle: "No more paper files. Upload, organize, and share with your doctor in one tap.",
                        accentColor: Self.accentColors[2],
                        backgroundTint: Color(hex: "E0F2FE"),
                        isActive: currentPage == 2
                    ) {
                        VaultPreviewCard(isActive: currentPage == 2)
                    }
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentPage)
                .disabled(isAnimating)
                .allowsHitTesting(!isAnimating)

                // Bottom controls
                VStack(spacing: 20) {
                    // Page indicator dots
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Capsule()
                                .fill(currentPage == index ? currentAccent : Color.primary.opacity(0.2))
                                .frame(
                                    width: currentPage == index ? 20 : 6,
                                    height: 6
                                )
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }

                    // Action button
                    if currentPage < totalPages - 1 {
                        Button {
                            guard !isAnimating else { return }
                            isAnimating = true
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                currentPage += 1
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                guard !isOnboardingComplete else { return }
                                isAnimating = false
                            }
                        } label: {
                            Text("Next")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: buttonWidth, height: buttonHeight)
                                .background(currentAccent)
                                .clipShape(Capsule())
                                .shadow(color: currentAccent.opacity(0.3), radius: 12, y: 6)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(isAnimating)
                        .opacity(buttonOpacity)
                    } else {
                        Button {
                            guard !isAnimating else { return }
                            isAnimating = true
                            completeOnboarding()
                        } label: {
                            Text("Get Started")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: buttonWidth, height: buttonHeight)
                                .background(
                                    LinearGradient(
                                        colors: [AppColors.accentBlue, AppColors.onboardingSkyBlue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                                .shadow(color: AppColors.accentBlue.opacity(0.3), radius: 14, y: 7)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(isAnimating)
                        .opacity(buttonOpacity)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            let delay: Double = reduceMotion ? 0 : 1.0
            withAnimation(.easeOut(duration: 0.4).delay(delay)) {
                skipOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(reduceMotion ? 0 : 0.4)) {
                buttonOpacity = 1.0
            }
        }
    }

    // MARK: - Completion

    private func completeOnboarding() {
        AppAnalyticsService.shared.logOnboardingComplete()
        withAnimation(.easeOut(duration: 0.2)) {
            isOnboardingComplete = true
        }
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
```

- [ ] **Step 2: Build the full project**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add swastricare-mobile-swift/Views/Onboarding/OnboardingView.swift
git commit -m "feat(onboarding): rewrite OnboardingView with benefit-first storytelling flow"
```

---

## Chunk 3: Cleanup

### Task 6: Remove unused onboarding 3D assets

**Files:**
- Remove: `swastricare-mobile-swift/Resources/3DModels/doc.glb`
- Remove: `swastricare-mobile-swift/Resources/3DModels/love.glb`
- Remove: `swastricare-mobile-swift/Resources/3DModels/vault.glb`
- Retain: `swastricare-mobile-swift/Resources/3DModels/anatomy.glb` (used by HomeView)
- Retain: `swastricare-mobile-swift/Resources/3DModels/heart animation.glb` (may be used elsewhere)
- Retain: `swastricare-mobile-swift/Views/Onboarding/ModelViewer.swift` (used by HomeView)

**Context:** Before removing, verify no other file references these 3 `.glb` names. `ModelViewer` is used in `HomeView.swift:340` for the `anatomy` model — do NOT delete it. Only delete the 3 onboarding-specific `.glb` files. Also remove them from the Xcode project if they are listed in the `.pbxproj`.

- [ ] **Step 1: Verify no other references to doc.glb, love.glb, vault.glb**

Run: `grep -r '"doc"' swastricare-mobile-swift/Views/ swastricare-mobile-swift/Services/ --include="*.swift" | grep -v OnboardingPreviewCards`
Run: `grep -r '"love"' swastricare-mobile-swift/Views/ swastricare-mobile-swift/Services/ --include="*.swift" | grep -v OnboardingPreviewCards`
Run: `grep -r '"vault"' swastricare-mobile-swift/Views/ swastricare-mobile-swift/Services/ --include="*.swift" | grep -v OnboardingPreviewCards`

Expected: No results (the old `OnboardingPageView` no longer references these). If results appear, investigate before deleting.

- [ ] **Step 2: Delete the 3 files**

```bash
rm "swastricare-mobile-swift/Resources/3DModels/doc.glb"
rm "swastricare-mobile-swift/Resources/3DModels/love.glb"
rm "swastricare-mobile-swift/Resources/3DModels/vault.glb"
```

- [ ] **Step 3: Build to verify nothing breaks**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add -u swastricare-mobile-swift/Resources/3DModels/
git commit -m "chore: remove unused onboarding 3D model assets (doc, love, vault)"
```

---

### Task 7: Clean up dead UserDefaults write

**Files:**
- Modify: `swastricare-mobile-swift/Views/Onboarding/OnboardingView.swift` (already rewritten — verify the dead write is gone)

**Context:** The spec says to remove the dead `UserDefaults.standard.set(true, forKey: AppConfig.hasSeenOnboardingKey)` write. If the rewrite in Task 5 was applied correctly, this is already gone. Verify.

- [ ] **Step 1: Verify no hasSeenOnboardingKey write exists**

Run: `grep -n "hasSeenOnboardingKey" swastricare-mobile-swift/Views/Onboarding/OnboardingView.swift`
Expected: No results. If found, remove the line.

- [ ] **Step 2: Verify analytics call is preserved**

Run: `grep -n "logOnboardingComplete" swastricare-mobile-swift/Views/Onboarding/OnboardingView.swift`
Expected: One result in `completeOnboarding()`.

- [ ] **Step 3: Remove the dead `hasSeenOnboardingKey` constant from Config.swift**

In `swastricare-mobile-swift/Config.swift`, remove line 20:
```swift
    static let hasSeenOnboardingKey = "hasSeenOnboarding"
```

This key is written but never read (the app entry point reads `hasLoggedInBeforeKey` instead).

- [ ] **Step 4: Build to verify nothing references `hasSeenOnboardingKey`**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`. If it fails, search for remaining references and remove them.

- [ ] **Step 5: Commit**

```bash
git add swastricare-mobile-swift/Config.swift
git commit -m "chore: remove dead hasSeenOnboardingKey constant"
```

---

### Task 8: Final build and visual verification

**Files:** None (verification only)

- [ ] **Step 1: Full clean build**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug clean build 2>&1 | tail -10`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Run on simulator and verify**

Launch in Xcode simulator. With `AppConfig.isTestingMode = true`, verify:
1. Screen 1 appears with "Your family's health, in your hands" headline, family preview card with Amma/Appa
2. Swipe or tap Next → Screen 2 with AI chat preview, purple accent
3. Swipe or tap Next → Screen 3 with vault documents, sky blue accent, "Get Started" button
4. Skip button appears after ~1s delay on first screen
5. Page dots animate with correct accent colors
6. Staggered entrance animations play (headline → subtitle → card)
7. Swiping back does not cause content to "pop" or hard-reset
8. Toggle dark mode in simulator — cards should use glass material
9. Toggle Reduce Motion in simulator — animations should be instant

- [ ] **Step 3: Commit any final fixes if needed**
