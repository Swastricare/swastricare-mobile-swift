# Onboarding Redesign — Benefit-First Storytelling

**Date:** 2026-03-14
**Status:** Approved
**Platform:** iOS (Swift/SwiftUI)

## Summary

Replace the current 3-screen onboarding (generic titles + 3D SceneKit models) with a benefit-first storytelling flow using bold typography + app-preview cards. Pure SwiftUI — no 3D models, no GLTFKit2 dependency.

## Problems Solved

1. **Generic content** — "Track Your Health" / "Private & Secure" are undifferentiated
2. **3D model liability** — SceneKit + GLTFKit2 is slow, has ugly placeholder fallbacks, double-rotation bug, and adds binary size for screens seen once
3. **Flat visual hierarchy** — identical layout on all 3 pages, nearly invisible background (4% opacity), all `.linear` animation curves
4. **No Indian context** — no family health angle, no cultural touchpoints, no specific scenarios
5. **Robotic animations** — linear timing, hard reset on swipe-back, no staggered entrance

## Design

### Narrative Arc

| Screen | Theme | Accent Color | Purpose |
|--------|-------|-------------|---------|
| 1 | Family Health Hub | Indigo `#4F46E5` | Emotional hook — caregiving |
| 2 | AI Health Companion | Purple `#7C3AED` | Wow factor — intelligence |
| 3 | Medical Vault | Sky Blue `#0EA5E9` | Trust closer — security |

### Visual Style: Bold Type + App Preview

Each screen has this layout (top to bottom):
1. **Skip** button (top right) — appears after 1s delay, not instantly
2. **Bold headline** — 26pt, `.bold` weight (700), with accent-colored keyword
3. **Subtitle** — 13pt, secondary color, 1-2 lines of specific benefit copy
4. **App preview card** — `AppColors.cardBackground` in light mode, `.glass(cornerRadius: 20)` in dark mode, with real UI elements previewing the feature
5. **Page indicator** — capsule dots, active dot is wider + colored
6. **Action button** — "Next" (screens 1-2), "Get Started" (screen 3)

### Screen 1: Family Health Hub

- **Headline:** "Your family's health, **in your hands**"
- **Subtitle:** "Track your parents' vitals from anywhere. Get alerts when Amma misses her medication."
- **Background gradient:** White → Indigo tint (`#EEF2FF`)
- **Preview card contents:**
  - Family member row: avatar + "Amma" + "Last updated 2m ago" + "All Good" badge
  - Stats row: Blood Pressure (120/80), Medications (2/2 ✓), Hydration (1.5L)
  - Alert row: "Appa" avatar + "Missed evening medication" + ⚠️ icon (red-tinted background)

### Screen 2: AI Health Companion

- **Headline:** "Ask anything. **Get real answers.**"
- **Subtitle:** "AI that understands Indian health — from BP readings to Ayurvedic questions."
- **Background gradient:** White → Purple tint (`#F3E8FF`)
- **Preview card contents:**
  - User chat bubble (indigo): "Is 140/90 BP normal for a 55 year old?"
  - AI response (with ✦ icon): "140/90 is Stage 1 hypertension..." with recommendation
  - Quick suggestion pills: "What foods reduce BP?" / "When to see a doctor?"

### Screen 3: Medical Vault

- **Headline:** "Every report. **Always with you.**"
- **Subtitle:** "No more paper files. Upload, organize, and share with your doctor in one tap."
- **Background gradient:** White → Sky Blue tint (`#E0F2FE`)
- **Preview card contents:**
  - Document row: PDF icon + "Blood Test — Thyrocare" + "Mar 2026 · CBC, Lipid, Thyroid" + 🔒
  - Document row: 🩻 icon + "X-Ray — Apollo Hospital" + "Feb 2026 · Chest X-Ray" + 🔒
  - Document row: 💊 icon + "Prescription — Dr. Sharma" + "Jan 2026 · Diabetes Management" + 🔒
  - Security badge: 🛡️ "End-to-End Encrypted" — "Only you and who you share with can access"

### Dark Mode

- Background gradients shift to deep navy base with subtle colored tints
- Preview cards use `.glass()` modifier (`.ultraThinMaterial`) instead of white
- Accent colors remain vibrant
- PremiumBackground orbs get stronger opacity (current 10% dark mode values)

### Animations

All animations use **spring** or **easeOut** curves — no `.linear`:

**Page entrance (staggered):**
1. Headline slides up + fades in (spring, 0.6s)
2. Subtitle slides up + fades in (spring, 0.6s, 0.1s delay)
3. Preview card slides up from bottom + fades in (spring, 0.7s, 0.2s delay)
4. Button fades in (easeOut, 0.3s, 0.4s delay)

**Page exit / swipe-back fix:**
- Drive animation state from `currentPage` changes in `OnboardingView` (via `.onChange(of: currentPage)`) rather than `onAppear`/`onDisappear` on individual pages. This avoids the hard-reset problem when swiping back.
- Remove all `@State` animation resets from `onDisappear`

**Continuous (within preview cards):**
- Screen 1: Subtle pulse on the ⚠️ alert indicator
- Screen 2: Typewriter effect on AI response text (optional, can be static)
- Screen 3: Subtle shimmer on 🛡️ security badge

**Button:** `ScaleButtonStyle` (already exists in DesignSystem)

### Navigation Controls

- **Skip button:** Appears after 1s delay (not instant). Visible on all pages.
- **Next button:** Screens 1-2. Color matches screen accent.
- **Get Started button:** Screen 3. Gradient background (indigo → sky blue).
- **Page dots:** Active = 20pt wide capsule in accent color. Inactive = 6pt circle in gray.
- **Swipe:** TabView with `.page` style (keep existing swipe behavior).

## Technical Changes

### Files to Modify
- `OnboardingView.swift` — new layout structure, animation system, screen-specific accent colors
- `OnboardingPageView.swift` — complete rewrite: remove ModelViewer, add preview card system

### Files to Remove (or stop using in onboarding)
- `ModelViewer.swift` — no longer used in onboarding (may still be used elsewhere — check before deleting)
- 3D model assets (`doc.glb`, `love.glb`, `vault.glb`) — check if used elsewhere before removing

### Files to Add
- `OnboardingPreviewCards.swift` — the 3 preview card views (FamilyPreviewCard, AIPreviewCard, VaultPreviewCard)

### No Changes Needed
- `Config.swift` — `isTestingMode` flag stays as-is
- `DesignSystem.swift` — reuse existing `AppColors`, `ScaleButtonStyle`, `PremiumBackground`, `.glass()` modifier
- `SharedGraphics.swift` — `ParticleField` not needed for this design
- `OnboardingComponents.swift` — used by health profile questionnaire, not by onboarding screens

### State Management

The current codebase has a mismatch: `OnboardingView` writes `hasSeenOnboardingKey` on completion, but the app entry point reads `hasLoggedInBeforeKey` to decide whether to show onboarding. This means onboarding visibility is actually tied to login state, not to the onboarding completion itself. This is acceptable (onboarding only matters for pre-login users), but the dead `hasSeenOnboardingKey` write should be cleaned up. In the new implementation:
- Keep `completeOnboarding()` setting `isOnboardingComplete = true` (the in-memory binding)
- Remove the dead `UserDefaults.standard.set(true, forKey: AppConfig.hasSeenOnboardingKey)` write
- Preserve the `AppAnalyticsService.shared.logOnboardingComplete()` call
- Consider adding per-page analytics: `logOnboardingPageViewed(page:)` for funnel analysis

### Accessibility

- **VoiceOver:** Preview card content is informational (not decorative). Add `accessibilityLabel` to each preview card summarizing its contents (e.g., "Family health dashboard showing Amma's blood pressure at 120/80, medications on track, and an alert for Appa's missed medication").
- **Dynamic Type:** Wrap each page's content in a `ScrollView` so it remains usable with large accessibility text sizes. Use `@ScaledMetric` for preview card internal spacing.
- **Reduce Motion:** Check `@Environment(\.accessibilityReduceMotion)`. If enabled: no staggered delays, no continuous animations (pulse/typewriter/shimmer), instant content display.

### Device Compatibility

- **iPhone SE (4.7"):** Content is wrapped in `ScrollView` — preview card will scroll if needed.
- **iPad:** Onboarding uses the same layout. `TabView` `.page` style works on iPad. Preview card maxes out at 400pt width via `.frame(maxWidth: 400)`.
- **Landscape:** Not explicitly locked. The `ScrollView` wrapping handles landscape gracefully.

### Dependencies
- **Retain:** `ModelViewer.swift` and GLTFKit2 — used by `HomeView` for the `anatomy` 3D model
- **Remove:** 3 onboarding `.glb` assets only (`doc.glb`, `love.glb`, `vault.glb`)
- **Add:** None — pure SwiftUI implementation for onboarding
