# iOS Responsive Layout — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make HomeView, VaultView, AIView, RunActivityView, and the tab host scale proportionally from iPhone SE → 16 Pro Max using a hybrid scale-factor (fonts/icons/spacing) + native flexible layout approach.

**Architecture:** Add `ResponsiveScale` enum and helpers to `DesignSystem.swift`, install at `ContentView` root via Environment, refactor 4 main tab screens to consume scaled fonts/padding and to use `maxWidth: .infinity` + `LazyVGrid` instead of fixed widths.

**Tech Stack:** SwiftUI, iOS 17+, no new dependencies.

**Standing rules (from project memory):**
- No `git commit` steps. The user handles commits.
- No edits to `Info.plist` or `.pbxproj`.
- Brand stays "Swastricare"; primary color stays `AITeal #22C5A6`.
- After UI changes finish, auto-install on device `FEC4D85A-...` without asking.

**Verification model:** No test suite exists for iOS. Each task ends with `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build` returning `** BUILD SUCCEEDED **`. Visual verification on simulators iPhone SE (3rd gen), iPhone 15 Pro, iPhone 16 Pro Max after each screen.

**System tab bar limitation:** `ContentView` uses the system `TabView` + `UITabBarAppearance` (ContentView.swift:34–64). The "floating narrow" tab bar on iOS 18+ is OS behavior. Tuning is limited to icon point size and label visibility. A full custom tab bar replacement is **out of scope** for this plan.

---

## Task 1: Add `ResponsiveScale` + Environment in `DesignSystem.swift`

**Files:**
- Modify: `swastricare-mobile-swift/DesignSystem.swift` (append after line 194, before `// MARK: - Liquid Glass View Modifiers`)

**Step 1: Add the enum, EnvironmentKey, and View modifier**

Append this block right after the existing `AppDimensions` struct closes on line 194:

```swift
// MARK: - Responsive Scale

/// Width-bucketed responsive scale factor. Read once at the root and propagated via Environment.
/// Buckets are by physical width, not device model — future-proof.
enum ResponsiveScale: CGFloat {
    case compact = 1.0   // width ≤ 390  (15 Pro, mini, SE)
    case regular = 1.06  // 391–428      (15 Pro Max, 16 Pro)
    case large   = 1.12  // ≥ 429        (16 Pro Max)

    static func from(width: CGFloat) -> ResponsiveScale {
        if width >= 429 { return .large }
        if width >= 391 { return .regular }
        return .compact
    }

    var value: CGFloat { rawValue }
}

private struct ResponsiveScaleKey: EnvironmentKey {
    static let defaultValue: ResponsiveScale = .compact
}

extension EnvironmentValues {
    var responsiveScale: ResponsiveScale {
        get { self[ResponsiveScaleKey.self] }
        set { self[ResponsiveScaleKey.self] = newValue }
    }
}

extension View {
    /// Installs a `ResponsiveScale` derived from the current screen width into the environment.
    /// Apply once at the tab host root.
    func responsive() -> some View {
        GeometryReader { proxy in
            self.environment(\.responsiveScale, ResponsiveScale.from(width: proxy.size.width))
        }
    }
}
```

**Step 2: Build**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 2: Add scaled `AppFont` helpers

**Files:**
- Modify: `swastricare-mobile-swift/DesignSystem.swift` (append after the ResponsiveScale block from Task 1)

**Step 1: Add the AppFont enum**

The codebase uses `Font.poppins(...)` (custom font) and `.system(size:)` interchangeably. We wrap both so callers can stay agnostic.

```swift
// MARK: - Responsive Typography

/// Scaled fonts. Pass the current ResponsiveScale (from @Environment(\.responsiveScale)).
enum AppFont {
    /// Hero numeric metrics (e.g. step count, calorie totals). Base 34pt.
    static func metric(_ scale: ResponsiveScale) -> Font {
        .system(size: 34 * scale.value, weight: .bold, design: .rounded)
    }
    /// Section / screen title. Base 22pt.
    static func title(_ scale: ResponsiveScale) -> Font {
        .system(size: 22 * scale.value, weight: .bold)
    }
    /// Card title / row primary text. Base 17pt.
    static func headline(_ scale: ResponsiveScale) -> Font {
        .system(size: 17 * scale.value, weight: .semibold)
    }
    /// Body copy. Base 15pt.
    static func body(_ scale: ResponsiveScale) -> Font {
        .system(size: 15 * scale.value, weight: .regular)
    }
    /// Secondary / caption text. Base 13pt.
    static func caption(_ scale: ResponsiveScale) -> Font {
        .system(size: 13 * scale.value, weight: .medium)
    }
}
```

**Step 2: Build**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 3: Add scaled dimensions and divider helper

**Files:**
- Modify: `swastricare-mobile-swift/DesignSystem.swift` (extend `AppDimensions`, add `.appDivider()`)

**Step 1: Extend `AppDimensions`**

Add this extension below the existing `AppDimensions` struct (after Task 1's responsive block):

```swift
// MARK: - Responsive Dimensions

extension AppDimensions {
    /// Horizontal screen padding. 16 / 18 / 20 by bucket.
    static func screenPadding(_ scale: ResponsiveScale) -> CGFloat {
        switch scale {
        case .compact: return 16
        case .regular: return 18
        case .large:   return 20
        }
    }
    /// Internal card padding. Base 16pt.
    static func cardPadding(_ scale: ResponsiveScale) -> CGFloat {
        16 * scale.value
    }
    /// Vertical spacing between sections. Base 16pt → up to 22pt.
    static func sectionSpacing(_ scale: ResponsiveScale) -> CGFloat {
        switch scale {
        case .compact: return 16
        case .regular: return 18
        case .large:   return 22
        }
    }
    /// Quick action button height. Base 100pt.
    static func quickActionHeight(_ scale: ResponsiveScale) -> CGFloat {
        100 * scale.value
    }
    /// Standard icon point size. Pass base size (e.g. 20, 24).
    static func iconSize(_ base: CGFloat, _ scale: ResponsiveScale) -> CGFloat {
        base * scale.value
    }
}
```

**Step 2: Add `.appDivider()` modifier**

Append after the extension:

```swift
extension View {
    /// Consistent 0.5pt divider in the app's neutral tone.
    func appDivider() -> some View {
        self.overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}
```

**Step 3: Build**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 4: Install `.responsive()` at the tab host root

**Files:**
- Modify: `swastricare-mobile-swift/Views/Main/ContentView.swift` (around line 168)

**Step 1: Apply `.responsive()` to the root `VStack`**

In `body`, the outer `VStack(spacing: 0)` ends at line 168 with `} // VStack`. After all the `.onReceive(...)` modifiers (line 167) and before the closing brace, add `.responsive()`:

```swift
        .onReceive(deepLinkHandler.$pendingWorkout.compactMap { $0 }) { pending in
            // ... existing body ...
        }
        .responsive()   // ← ADD: installs ResponsiveScale into Environment for all tabs
        } // VStack
```

**Step 2: Tune system tab bar icon size in `init`**

Inside `init()` (ContentView.swift:44–64), the system `UITabBarAppearance` lets us bump the title font for the tab labels so they feel right on Pro Max. Add after line 59 (after the for-loop):

```swift
        // Slightly larger tab title font on Plus/Max-class devices.
        let screenWidth = UIScreen.main.bounds.width
        let titleScale: CGFloat = screenWidth >= 429 ? 1.12 : (screenWidth >= 391 ? 1.06 : 1.0)
        let titleFont = UIFont.systemFont(ofSize: 10 * titleScale, weight: .medium)
        for itemAppearance in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            var selectedAttrs = itemAppearance.selected.titleTextAttributes
            selectedAttrs[.font] = titleFont
            itemAppearance.selected.titleTextAttributes = selectedAttrs
            var normalAttrs = itemAppearance.normal.titleTextAttributes
            normalAttrs[.font] = titleFont
            itemAppearance.normal.titleTextAttributes = normalAttrs
        }
```

**Note:** The system tab bar's overall geometry (floating capsule on iOS 18+) cannot be changed without replacing `TabView`. This is the OS-imposed limit referenced in the design doc.

**Step 3: Build**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 5: Refactor `HomeView` — screen padding + section spacing

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/HomeView.swift`

**Step 1: Read `HomeView.swift` in full to understand structure**

```bash
# Use Read tool, not cat
```

**Step 2: Add `@Environment(\.responsiveScale) private var scale` to `HomeView` struct**

Add near the top of the `HomeView` struct (alongside other `@StateObject` / `@Environment` properties).

**Step 3: Replace hardcoded `.padding(.horizontal, 16)` with scaled padding**

Every `.padding(.horizontal, 16)` in HomeView (lines 121, 137, 159, 168, 342, 467, 633 and similar) → `.padding(.horizontal, AppDimensions.screenPadding(scale))`.

Hold the line on these: leave `.padding(.horizontal, 4)` (line 816) and other intentionally narrow inner paddings alone — those are inside cards, not the screen edge.

**Step 4: Replace `Spacer().frame(height: 18)` section gaps with scaled spacing**

The `Spacer().frame(height: 18)` and `Spacer().frame(height: 16)` blocks at lines 126, 142, 164, 173 are between sections. Replace each with:

```swift
Spacer().frame(height: AppDimensions.sectionSpacing(scale))
```

Leave `Spacer().frame(height: 8)` and `height: 12` alone — those are intra-section spacings calibrated for the card design.

**Step 5: Build and visually verify**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 6: Refactor `HomeView` — daily activity card + 2×3 stat grid

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/HomeView.swift`

**Step 1: Identify the daily activity card**

Use `grep -n "Daily Activity\|CompactStatCell\|DailyActivity" swastricare-mobile-swift/Views/Home/HomeView.swift` to find the section. The 2×3 stat grid (Cal, Min, Stand, BPM, Sleep, km) per CLAUDE.md description.

**Step 2: Convert the 2×3 grid to `LazyVGrid`**

Wherever the grid is constructed with manual `HStack` + `VStack` nesting (or with `GridItem(.fixed(...))`), replace with:

```swift
LazyVGrid(
    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
    spacing: 12
) {
    // existing CompactStatCell calls — no other changes
}
```

If the existing code uses three `HStack`s of two cells each, replace the whole three-HStack block with the single `LazyVGrid` above.

**Step 3: Make `CompactStatCell` width-flexible**

Find the `CompactStatCell` definition. Replace any `.frame(width: someFixed)` on the outer view with `.frame(maxWidth: .infinity)`. Keep `.frame(height:)` if it has one (cells should be uniform height).

**Step 4: Scale the icon and numeric font inside `CompactStatCell`**

Inside `CompactStatCell`, add `@Environment(\.responsiveScale) private var scale`. Replace:
- `.font(.system(size: 16))` → `.font(.system(size: AppDimensions.iconSize(16, scale)))`
- The numeric value font → `AppFont.headline(scale)` (or `AppFont.metric(scale)` if it's a large hero number).
- The label/caption font → `AppFont.caption(scale)`.

**Step 5: Build**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 7: Refactor `HomeView` — 4 quick action cards

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/HomeView.swift`

**Step 1: Find the quick actions section**

`grep -n "QuickAction\|Medication\|Hydration.*Diet\|Cycle" swastricare-mobile-swift/Views/Home/HomeView.swift | head -10`. Per CLAUDE.md these are 4 cards (Medication, Hydration, Diet, Cycle) at fixed 100pt height.

**Step 2: Convert to `LazyVGrid` 2×2**

Replace any `HStack { ... HStack { ... } }` layout for the 4 cards with:

```swift
LazyVGrid(
    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
    spacing: 12
) {
    // 4 quick action card calls
}
.padding(.horizontal, AppDimensions.screenPadding(scale))
```

**Step 3: Replace `.frame(height: 100)` with scaled height**

On each quick action card (or in the card view definition):
```swift
.frame(maxWidth: .infinity)
.frame(height: AppDimensions.quickActionHeight(scale))
```

**Step 4: Scale fonts and icons in the quick action card**

Same pattern as CompactStatCell: title → `AppFont.headline(scale)`, icon `.font(.system(size: 20))` → `AppFont` or `AppDimensions.iconSize(20, scale)`.

**Step 5: Build**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 8: Refactor `HomeView` — vitals section dividers

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/HomeView.swift`

**Step 1: Find ad-hoc dividers**

`grep -n "Divider\|Rectangle().fill.*opacity\|\.frame(height: 1)\|\.frame(height: 0.5)" swastricare-mobile-swift/Views/Home/HomeView.swift`.

**Step 2: Replace each with a consistent divider**

Choose the cleanest replacement per case:
- Standalone `Divider()` between rows → leave as-is (system).
- Custom `Rectangle().fill(...).frame(height: 1)` separators → either use system `Divider()` or apply `.appDivider()` to the parent.

The goal is consistency, not eliminating every Divider. Inconsistencies were the complaint, not the existence of dividers.

**Step 3: Build and visually verify on 3 simulators**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

Boot the 3 simulators and visually compare:
- iPhone SE (3rd gen) — should look identical to baseline (compact = 1.0)
- iPhone 15 Pro — should look identical to baseline (regular = 1.06, ~6% larger)
- iPhone 16 Pro Max — cards should fill width, fonts/icons noticeably larger, no center void

---

## Task 9: Refactor `VaultView`

**Files:**
- Modify: `swastricare-mobile-swift/Views/Vault/VaultView.swift` (1681 lines)

**Step 1: Read VaultView in full** to understand its structure (cards, search bar, document list).

**Step 2: Add `@Environment(\.responsiveScale) private var scale`** to the main `VaultView` struct and to any reusable subviews (document card, category card) it defines locally.

**Step 3: Apply the same 4 patterns**

For each section in VaultView:
1. Screen-edge horizontal padding → `AppDimensions.screenPadding(scale)`.
2. Card outer widths → drop any `.frame(width:)`, add `.frame(maxWidth: .infinity)`.
3. Multi-card horizontal rows → `LazyVGrid(columns: [.flexible(), .flexible()])`.
4. Fonts → `AppFont.headline/body/caption(scale)`; icons → `AppDimensions.iconSize(base, scale)`.

Bound the scope: only touch fonts/sizes/widths/paddings. Do **not** change colors, gradients, icons themselves, copy, or behavior.

**Step 4: Build**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 10: Refactor `AIView`

**Files:**
- Modify: `swastricare-mobile-swift/Views/AI/AIView.swift` (3413 lines)

**Step 1: Read AIView** — identify chat list, message bubble, composer, header.

**Step 2: Add `@Environment(\.responsiveScale) private var scale`** to AIView and to any local subviews (message bubble, composer).

**Step 3: Composer**

The composer (text input + send button) should already be full-width. If it has a `.frame(width:)`, replace with `.frame(maxWidth: .infinity)`. Apply `.padding(.horizontal, AppDimensions.screenPadding(scale))`.

**Step 4: Message bubbles**

Message bubble fonts → `AppFont.body(scale)`. Bubble max width is typically `.frame(maxWidth: UIScreen.main.bounds.width * 0.75)` style — convert to `.frame(maxWidth: .infinity, alignment: .leading/.trailing)` then constrain via `.padding(.leading, 60)` on assistant bubbles and `.padding(.trailing, 60)` on user bubbles (let the alignment + padding do the bounding rather than a fixed width).

If that's invasive, fall back to scaling the existing fixed widths: `width * scale.value`.

**Step 5: Header / quick prompts**

If there are quick-prompt chips or a "suggested questions" row, ensure they wrap (`FlowLayout` / `LazyVGrid(.adaptive(minimum: 120))`) instead of being clipped on smaller devices.

**Step 6: Build**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 11: Refactor `RunActivityView`

**Files:**
- Modify: `swastricare-mobile-swift/Views/Run/RunActivityView.swift` (1315 lines)

**Step 1: Read RunActivityView** — identify the big "today's steps" hero metric, weekly chart, stat cards, history list.

**Step 2: Add `@Environment(\.responsiveScale) private var scale`**.

**Step 3: Hero step count → `AppFont.metric(scale)`**

The big numeric step count is the biggest visual offender on Pro Max (looks small in a sea of whitespace). Apply `AppFont.metric(scale)` — this scales 34pt base to ~38pt on Pro Max.

**Step 4: Stat cards row → flexible grid**

If a horizontal `HStack` of 3+ stat cards has fixed widths, convert to `LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3))`.

**Step 5: Screen padding + section spacing** → `AppDimensions.screenPadding(scale)` / `AppDimensions.sectionSpacing(scale)`.

**Step 6: Build**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 12: Final build + install on physical iPhone

**Step 1: Clean build**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug clean build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

**Step 2: Build for the physical device**

```bash
xcodebuild -scheme swastricare-mobile-swift -destination 'platform=iOS,id=FEC4D85A-...' -configuration Debug build 2>&1 | tail -10
```

(Replace `FEC4D85A-...` with the exact device UDID from `xcrun xctrace list devices`.)

**Step 3: Install and launch**

Per standing instruction: auto-install on the iPhone, launch, and report. Use `xcrun devicectl` or `ios-deploy`.

**Step 4: Visual smoke test on three sims sequentially**

```bash
xcrun simctl boot "iPhone SE (3rd generation)"
xcrun simctl boot "iPhone 15 Pro"
xcrun simctl boot "iPhone 16 Pro Max"
# Install + launch the app on each, tap through all 4 tabs.
```

Report any visual regression. **Do not commit** — that's the user's call.

---

## Acceptance criteria

- All 12 tasks land green builds.
- On iPhone 16 Pro Max: cards visibly fill width; fonts/icons read ~12% larger than 15 Pro; no large empty space margins on either side of stat grids and quick actions; section spacing is consistent.
- On iPhone SE: layout is **unchanged** from baseline (scale = 1.0).
- On iPhone 15 Pro: layout is barely changed (scale = 1.06, ~6% tweaks).
- No screen outside the 4 tabs + ContentView is visually affected.
- No `Info.plist` / `.pbxproj` edits.
- No commits made by Claude.
