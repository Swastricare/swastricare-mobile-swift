# Home Screen Visual Refresh Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Visual refresh of HomeView.swift to match the premium design language from the onboarding/login redesign — semantic color tints, zoned spacing, redesigned header, color-tinted vitals/quick actions with progress bars, and compact activity bar replacing the 3D model section.

**Architecture:** All changes are in one file (`HomeView.swift`, 1,701 lines). Each task modifies a specific MARK section. No ViewModel changes, no new files. The file uses `// MARK: -` sections that serve as natural task boundaries.

**Tech Stack:** SwiftUI, existing `DesignSystem.swift` (`AppColors`, `AppDimensions`, `.glass()`, `ScaleButtonStyle`)

**Spec:** `docs/superpowers/specs/2026-03-14-home-screen-visual-refresh-design.md`

---

## Chunk 1: Header + Spacing + Color Foundation

### Task 1: Redesign the LivingStatusHeader

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/HomeView.swift` — the `LivingStatusHeader` struct (lines 662-735)

**Context:** The `LivingStatusHeader` is a private struct inside `HomeView`. It currently shows a greeting in the health status color, user name with a pulsing heart emoji, bell icon, and a target icon in a circle. The redesign removes the heart emoji, enlarges the name, adds a dot-based status line, and uses rounded square icon buttons.

- [ ] **Step 1: Read the current LivingStatusHeader implementation**

Read `swastricare-mobile-swift/Views/Home/HomeView.swift` from line 662 to 735 to understand the current structure and interface.

- [ ] **Step 2: Rewrite the LivingStatusHeader body**

Replace the body of `LivingStatusHeader` (keeping the same struct signature and properties) with:

```swift
private struct LivingStatusHeader: View {
    let userName: String
    let userPhotoURL: URL?
    let status: HealthStatus
    let greeting: String
    @Binding var showReminders: Bool

    var body: some View {
        HStack(alignment: .top) {
            // Left: Greeting + Name + Status
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                Text(userName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                // Status dot + label
                HStack(spacing: 6) {
                    Circle()
                        .fill(status.color)
                        .frame(width: 8, height: 8)
                    Text(status.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(status.color)
                }
                .padding(.top, 2)
            }

            Spacer()

            // Right: Bell + Avatar
            HStack(spacing: 10) {
                // Bell icon — rounded square
                Button(action: { showReminders = true }) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .frame(width: 34, height: 34)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                }

                // Analytics — rounded square
                NavigationLink(destination: HealthAnalyticsView()) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .frame(width: 34, height: 34)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}
```

- [ ] **Step 3: Update HealthStatus titles to match spec**

In the `HealthStatus` enum (lines 52-88), update the `title` property:

```swift
var title: String {
    switch self {
    case .optimal: return "All vitals normal"
    case .attention: return "Needs attention"
    case .normal: return "Status normal"
    }
}
```

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add swastricare-mobile-swift/Views/Home/HomeView.swift
git commit -m "feat(home): redesign greeting header with bold name, status dot, and square icon buttons"
```

---

### Task 2: Update section spacing and add zone labels

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/HomeView.swift` — the `body` computed property (lines 108-266)

**Context:** Currently all sections use uniform 8pt padding-top with no zone labels. The spec requires 28pt between major zones, 12pt within zones, and optional section labels.

- [ ] **Step 1: Read the body layout**

Read lines 108-266 to understand the current spacing.

- [ ] **Step 2: Update spacing between sections in body**

In the `body` computed property, update the paddings between sections. Change the `VStack(spacing: 0)` contents to use these gaps:

After LivingStatusHeader — add `.padding(.bottom, 8)` (same zone as nudges)

Before `humanBodyImageWithDetails` (which will become the activity bar) — change `.padding(.top, 0)` to `.padding(.top, 28)` and add a section label:
```swift
// Section label
Text("TODAY'S ACTIVITY")
    .font(.system(size: 11, weight: .semibold))
    .foregroundColor(.secondary)
    .tracking(0.8)
    .padding(.horizontal, 20)
    .padding(.top, 28)
```

Before `healthVitalsSection` — change `.padding(.top, 8)` to add a section label:
```swift
Text("YOUR VITALS")
    .font(.system(size: 11, weight: .semibold))
    .foregroundColor(.secondary)
    .tracking(0.8)
    .padding(.horizontal, 20)
    .padding(.top, 28)
```

Before `quickActionsSection` — change `.padding(.top, 8)` to add a section label:
```swift
Text("QUICK ACTIONS")
    .font(.system(size: 11, weight: .semibold))
    .foregroundColor(.secondary)
    .tracking(0.8)
    .padding(.horizontal, 20)
    .padding(.top, 28)
```

Remove the existing "Quick Actions" text header inside `quickActionsSection` (lines 565-571) since the zone label now handles it.

- [ ] **Step 3: Update staggered animation delays**

Update the animation delays to match the new zone structure:
- Header: 0.05s (unchanged)
- Activity bar: 0.10s
- Vitals: 0.20s
- AR scan: 0.30s
- Quick actions: 0.35s

- [ ] **Step 4: Build and commit**

```bash
git add swastricare-mobile-swift/Views/Home/HomeView.swift
git commit -m "feat(home): add zoned spacing with section labels and updated animation delays"
```

---

### Task 3: Replace 3D model section with compact activity bar

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/HomeView.swift` — the `humanBodyImageWithDetails` computed property (lines 332-407)

**Context:** The current section is a 320pt-tall GeometryReader with a 3D ModelViewer on the right and 3 DailyActivityStatItems on the left. Replace with a compact ~80pt horizontal bar with 3 color-tinted activity pills. Keep the ModelViewer import and the AR Body Scan button — only remove it from this section.

- [ ] **Step 1: Rewrite humanBodyImageWithDetails**

Replace the entire `humanBodyImageWithDetails` computed property with:

```swift
private var humanBodyImageWithDetails: some View {
    HStack(spacing: 10) {
        // Active Calories
        ActivityPill(
            icon: "flame.fill",
            color: .orange,
            value: viewModel.activeCalories > 0 ? "\(viewModel.activeCalories)" : "—",
            unit: "kcal"
        )

        // Exercise Minutes
        ActivityPill(
            icon: "clock.fill",
            color: AppColors.accentBlue,
            value: viewModel.exerciseMinutes > 0 ? "\(viewModel.exerciseMinutes)" : "—",
            unit: "min"
        )

        // Stand Hours
        ActivityPill(
            icon: "figure.stand",
            color: .purple,
            value: viewModel.standHours > 0 ? "\(viewModel.standHours)" : "—",
            unit: "hrs"
        )
    }
    .padding(.horizontal, 20)
}
```

- [ ] **Step 2: Remove modelOpacity and modelScale state variables**

Remove `@State private var modelOpacity: Double = 0` (line 26) and `@State private var modelScale: CGFloat = 0.8` (line 27) since the 3D model is no longer displayed here.

Also remove the model animation in `onAppear` (lines 297-299):
```swift
withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
    modelOpacity = 0.8
    modelScale = 1.20
}
```

- [ ] **Step 3: Add ActivityPill component**

Add after the `ScrollAnimationModifier` (around line 780), before `// MARK: - Supporting Views`:

```swift
// MARK: - Activity Pill

private struct ActivityPill: View {
    let icon: String
    let color: Color
    let value: String
    let unit: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.10), lineWidth: 1)
        )
    }
}
```

- [ ] **Step 4: Build and commit**

```bash
git add swastricare-mobile-swift/Views/Home/HomeView.swift
git commit -m "feat(home): replace 320pt 3D model with compact activity bar pills"
```

---

## Chunk 2: Vitals Cards + Quick Actions Redesign

### Task 4: Redesign healthVitalsSection with semantic color tints

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/HomeView.swift` — `healthVitalsSection` (lines 510-556)

**Context:** Currently uses `VitalCard` components in a 3-column grid. The VitalCard component is defined later in the file (around line 783 in "Supporting Views"). We need to either modify VitalCard or replace the section inline. Since VitalCard is used only here, we'll replace the section with inline color-tinted cards.

- [ ] **Step 1: Rewrite healthVitalsSection**

Replace the entire `healthVitalsSection` with:

```swift
private var healthVitalsSection: some View {
    LazyVGrid(columns: [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ], spacing: 10) {
        // Heart Rate — tappable
        Button(action: { showHeartRateMeasurement = true }) {
            VitalTintedCard(
                icon: "heart.fill",
                title: "Heart Rate",
                value: viewModel.heartRate > 0 ? "\(viewModel.heartRate)" : "—",
                unit: "bpm",
                status: viewModel.heartRate > 0 ? "Normal" : "",
                color: AppColors.accentRed
            )
        }
        .buttonStyle(ScaleButtonStyle())

        // Sleep
        VitalTintedCard(
            icon: "bed.double.fill",
            title: "Sleep",
            value: viewModel.sleepHours == "0h 0m" ? "—" : viewModel.sleepHours,
            unit: "",
            status: viewModel.sleepHours != "0h 0m" ? "Good" : "",
            color: AppColors.sleep
        )

        // Distance
        VitalTintedCard(
            icon: "figure.walk",
            title: "Distance",
            value: viewModel.distance > 0 ? String(format: "%.1f", viewModel.distance) : "—",
            unit: viewModel.distance > 0 ? "km" : "",
            status: viewModel.distance > 0 ? "Active" : "",
            color: AppColors.accentGreen
        )
    }
    .padding(.horizontal, 20)
}
```

- [ ] **Step 2: Add VitalTintedCard component**

Add after the `ActivityPill` struct:

```swift
// MARK: - Vital Tinted Card

private struct VitalTintedCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let status: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon badge + label
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                    .frame(width: 22, height: 22)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(color)
                    .lineLimit(1)
            }

            // Value
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
                .tracking(-1)

            // Unit + status
            if !unit.isEmpty || !status.isEmpty {
                Text([unit, status].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 9))
                    .foregroundColor(color.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.10), lineWidth: 1)
        )
    }
}
```

- [ ] **Step 3: Build and commit**

```bash
git add swastricare-mobile-swift/Views/Home/HomeView.swift
git commit -m "feat(home): redesign vitals cards with semantic color tints and larger values"
```

---

### Task 5: Redesign quickActionsSection with color tints and progress bars

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/HomeView.swift` — `quickActionsSection` (lines 563-630)

**Context:** Currently uses `MedicationQuickActionButton`, `HydrationQuickActionButton`, `DietQuickActionButton`, and `CycleTrackerQuickActionButton` in a 2×2 grid. The cycle tracker spans 2 columns. We'll replace the button calls with inline color-tinted cards with progress bars. The existing button components (defined later in the file) can remain for backward compatibility — we just stop using them here.

- [ ] **Step 1: Rewrite quickActionsSection**

Replace the `quickActionsSection` body (keeping the sheet modifiers at the bottom):

```swift
private var quickActionsSection: some View {
    VStack(spacing: 12) {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            // Medication
            Button(action: { showMedications = true }) {
                QuickActionTintedCard(
                    icon: "💊",
                    title: "Medication",
                    value: "\(medicationViewModel.takenCount)",
                    total: "/\(medicationViewModel.totalCount)",
                    progress: medicationViewModel.totalCount > 0
                        ? Double(medicationViewModel.takenCount) / Double(medicationViewModel.totalCount)
                        : 0,
                    color: AppColors.medication
                )
            }
            .buttonStyle(ScaleButtonStyle())

            // Hydration
            Button(action: { showHydration = true }) {
                QuickActionTintedCard(
                    icon: "💧",
                    title: "Hydration",
                    value: String(format: "%.1f", Double(hydrationViewModel.effectiveIntake) / 1000.0),
                    total: "L",
                    progress: hydrationViewModel.dailyGoal > 0
                        ? Double(hydrationViewModel.effectiveIntake) / Double(hydrationViewModel.dailyGoal)
                        : 0,
                    color: AppColors.hydration
                )
            }
            .buttonStyle(ScaleButtonStyle())

            // Diet
            Button(action: { showDiet = true }) {
                QuickActionTintedCard(
                    icon: "🍽️",
                    title: "Diet",
                    value: "\(dietViewModel.totalCalories)",
                    total: " kcal",
                    progress: dietViewModel.dietGoals.dailyCalories > 0
                        ? Double(dietViewModel.totalCalories) / Double(dietViewModel.dietGoals.dailyCalories)
                        : 0,
                    color: .orange
                )
            }
            .buttonStyle(ScaleButtonStyle())

            // Menstrual Cycle
            Button(action: { showMenstrualCycle = true }) {
                CycleTintedCard()
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
    .padding(.horizontal, 20)
    .sheet(isPresented: $showMedications) {
        MedicationsView(viewModel: medicationViewModel)
    }
    .sheet(isPresented: $showHydration) {
        HydrationView(viewModel: hydrationViewModel)
    }
    .sheet(isPresented: $showDiet) {
        DietView(viewModel: dietViewModel)
    }
    .sheet(isPresented: $showMenstrualCycle) {
        MenstrualCycleView()
    }
}
```

- [ ] **Step 2: Add QuickActionTintedCard and CycleTintedCard components**

Add after `VitalTintedCard`:

```swift
// MARK: - Quick Action Tinted Card

private struct QuickActionTintedCard: View {
    let icon: String
    let title: String
    let value: String
    let total: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Icon + label
            HStack(spacing: 6) {
                Text(icon)
                    .font(.system(size: 16))
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
            }

            // Value
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(color)
                Text(total)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color.opacity(0.6))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.10))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * min(progress, 1.0), height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.10), lineWidth: 1)
        )
    }
}

// MARK: - Cycle Tinted Card

private struct CycleTintedCard: View {
    private let color = Color(hex: "EC4899")

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("🩸")
                    .font(.system(size: 16))
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                Text("Cycle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
            }

            Text("Track")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)

            Text("Tap to view cycle")
                .font(.system(size: 9))
                .foregroundColor(color.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.10), lineWidth: 1)
        )
    }
}
```

- [ ] **Step 3: Remove quickActionsVisible state and ScrollAnimationModifier usage**

Since quick actions now use the global `hasAppeared` staggered animation (from Task 2), remove:
- `@State private var quickActionsVisible = false` (line 28)
- The `.modifier(ScrollAnimationModifier(isVisible: $quickActionsVisible))` from the quick actions section
- The individual `.opacity(quickActionsVisible ? ...)` and `.scaleEffect(quickActionsVisible ? ...)` modifiers that were on each button

The quick actions section now uses the standard `hasAppeared` animation like other zones.

- [ ] **Step 4: Build and commit**

```bash
git add swastricare-mobile-swift/Views/Home/HomeView.swift
git commit -m "feat(home): redesign quick actions with color tints and progress bars"
```

---

### Task 6: Final build and visual verification

**Files:** None (verification only)

- [ ] **Step 1: Full clean build**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug clean build 2>&1 | tail -10`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Run on simulator and verify**

Launch in Xcode simulator. Verify:
1. Header shows bold name (24pt), no heart emoji, dot + status text, rounded square icons
2. Section labels appear ("TODAY'S ACTIVITY", "YOUR VITALS", "QUICK ACTIONS")
3. 28pt gaps between zones, 12pt within zones
4. Activity bar shows 3 color-tinted pills (orange/blue/purple)
5. No 3D anatomy model on home screen
6. Vitals cards have distinct color tints (red/indigo/green)
7. Quick action cards have color tints + progress bars
8. Staggered entrance animation cascades zone by zone
9. All taps work: heart rate opens sheet, quick actions open sheets, bell opens reminders
10. Dark mode: colors are subtler, cards still readable
11. Pull-to-refresh still works

- [ ] **Step 3: Commit any final fixes**
