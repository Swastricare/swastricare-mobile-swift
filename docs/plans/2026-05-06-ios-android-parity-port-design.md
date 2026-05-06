# iOS ↔ Android UI Parity Port — Design

**Date:** 2026-05-06
**Owner:** Syam Sundar
**Goal:** Port all recent Android UI redesigns to iOS so visual design, assets, and user flows are identical across platforms (pixel-match, Approach A).

## Background

Since the last cross-platform sync (`717c6841`, biometric lock rewrite), Android shipped a major redesign cycle while iOS only received analytics work. Android-only changes:

- HomeScreenV3 (rings, quick actions, vitals, AI banner)
- Vault redesign (storage card, category tiles, empty state)
- Settings redesign (profile banner, grouped cards, family hidden)
- Activity tab overhaul (date switcher, animated rings, pace/HR stats, light map, bar chart, goals settings, start-workout setup)
- Sleep screen (new)
- Onboarding + Auth redesign (illustrations, two-step signup, in-field labels, haptics)
- Diet flow redesign (hero, AITeal, merged add-food)
- Hydration past-date read-only logic
- Brand rename → "Swastri AI"
- Poppins typography
- Forced light theme
- Stress mood blob illustrations

iOS Hydration is in sync. iOS AI tab is the source of truth (Android ported FROM iOS).

## Approach

**Foundations-first, then top-down by impact.** Land foundations as one PR, then port screens in priority order. Each screen is its own PR. No commits without explicit user approval.

## Section 1 — Foundations PR

### 1.1 Typography (Poppins)
- Copy `android/app/src/main/res/font/poppins_*.ttf` (Bold, SemiBold, Medium, Regular, Light) to `swastricare-mobile-swift/Resources/Fonts/`.
- Register in `Info.plist` (`UIAppFonts`).
- Add `Font+Poppins.swift` mirroring Android Type.kt tokens (`headlineLarge`, `titleMedium`, `bodyMedium`, `labelSmall`).
- Sweep all iOS views — replace `.system(...)`, `.title`, `.headline`, `.body` with Poppins equivalents.

### 1.2 Color + theme lock
- Add `AppColors.aiTeal = #22C5A6` plus gradient pair to `DesignSystem.swift`.
- Audit Android's color system; add any other missing semantic tokens (drink tints, activity ring colors, sleep stage, stress mood).
- Force light theme via `.preferredColorScheme(.light)` on root in `swastricare_mobile_swiftApp.swift`.

### 1.3 Brand rename → "Swastri AI"
- Sweep iOS strings: greetings, settings, AI tab, splash, onboarding, `CFBundleDisplayName`.
- **Bundle ID stays unchanged** (would break TestFlight).

### 1.4 Asset import
- `signup_brand_header.png` → `Assets.xcassets/SignupBrandHeader.imageset`.
- `map_style_dark.json` bundled (already used).
- Inline Compose illustrations (stress blobs, sleep stages) decided per-screen — SwiftUI `Path`/`Canvas` or rasterize.

### 1.5 Validation
- `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build`
- Spot-check Poppins applied across all screens (no system fallback).
- Verify forced light theme on a device with system dark mode.
- Leave changes unstaged for review (no commit).

## Section 2 — Screen ports (in PR order)

### 2.1 Home V3
Rebuild `Views/Home/HomeView.swift`. Components: greeting+avatar, **Daily Activity card** (4 animated rings — steps, cal, distance, active min), **Quick Actions** row (Medication / Hydration / Cycle / Family with pastel tints), **Vitals row** (HR/BP/Temp), **Swastri AI banner** (gradient teal CTA → AI tab). Animated progress bars. Reuse existing `HealthKitService` + `HomeViewModel`. Retire unused `HomeViewV2`.

### 2.2 Auth + Onboarding
Two-step signup (name+email → password+confirm). Build `FloatingLabelField.swift` for in-field floating labels. Add `signup_brand_header.png` header. Haptics: `.light` on focus, `.medium` on submit, `.error` on validation. Refresh onboarding illustrations to Android's set.

### 2.3 Activity / Run
Rebuild `Views/Run/RunActivityView.swift`: date switcher with chevrons, 4 animated activity rings, time-range selector, **PaceStatsCard**, **HRStatsCard** (StatGrid pattern), **CadenceCard**, split bar chart, light-mode map, activity goals settings sheet (propagated to Home rings), start-workout setup with activity-type picker.

### 2.4 Diet
Rebuild `Views/Home/DietView.swift` with hero-overlay pattern: full-bleed illustration, **Today's Progress** card overlapping. AITeal accents, macro pills (P/C/F). Merge `AddFoodView` into a tabbed sheet (search / snap / quick-add). Keep `DietLocalStorage` + Supabase sync untouched.

### 2.5 Settings
Profile banner (avatar, name, days-active counter) + grouped cards. Hide Family section. Theme settings entry point (even though theme is locked).

### 2.6 Vault
Add: **Storage card** (used / total), **Category tiles** (Reports / Prescriptions / Bills / etc.), **Empty state** with illustration, **Search + category filter**, redesigned **Add-document sheet**.

### 2.7 Sleep (new screen)
Create `Views/Sleep/SleepView.swift` matching Android's `SleepScreen.kt`: stage Canvas (deep/light/REM/awake), cycle graph, stage timing, manual log button, hours+quality stats. Wire to HealthKit (`HKCategoryTypeIdentifier.sleepAnalysis`). Add route from Home Vitals row.

### 2.8 Stress (new screen)
Create `Views/Stress/StressView.swift`: 1–10 slider, mood blob illustrations (SwiftUI `Path`/`Canvas` ported from Compose), category chips, notes, log button, history. Reuse Android's Supabase schema via `SupabaseManager`.

### 2.9 Hydration polish
Past-date read-only: disable add/quick-add/drag-add when date < today (show disabled, not hidden). Empty-state copy alignment. Keep iOS gravity motion (iOS-only enhancement).

### 2.10 Mascot + misc copy
"Swastri AI" mascot bleed-to-edge on relevant cards. Stress mood blobs replace mood emoji wherever it appears.

## Section 3 — Validation, sequencing, risks

### 3.1 Per-PR validation
- `xcodebuild -sdk iphonesimulator` after each change.
- Side-by-side: OnePlus 8T (`acac8d4b`) + iOS sim, screen-by-screen.
- Golden paths smoke test: signup → onboarding → home → log → activity → settings.
- New screens: manual test plan (data flow + edge states).

### 3.2 PR sequence
1. Foundations
2. Home V3
3. Auth + Onboarding
4. Activity / Run
5. Diet
6. Settings
7. Vault
8. Sleep (new)
9. Stress (new)
10. Hydration polish + mascot/copy sweep

### 3.3 Risks
- **Poppins load failure** — verify `UIAppFonts` and runtime-log fallback.
- **Light theme lock** — accepted per user memory (white-only).
- **Brand rename misses** — grep `SwasthiCare`, `SwastriCare`, `Swasthi` across `.swift` + `Localizable.strings`.
- **Stress/Sleep schemas** — reuse Android's Supabase tables (no new migrations).
- **Custom Compose shapes** — port to SwiftUI `Path`/`Shape`; rasterize if lossy.
- **Widget extension** — verify `SwasthiCareWidgetsExtension` still builds after home + color changes.
- **HealthKit Sleep permission** — confirm requested or add to `Info.plist`.

### 3.4 Constraints
- No commits without explicit user approval.
- No bundle-ID change.
- No automated tests (matches project convention).
- No new abstractions beyond per-screen need.

### 3.5 Effort
~6–8 weeks across 10 PRs. Foundations + Home V3 ≈ 1 week.
