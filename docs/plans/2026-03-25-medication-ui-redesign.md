# Medication UI Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign all 3 medication screens to use native iOS system design with proper light/dark theme support.

**Architecture:** Replace PremiumBackground and .glass() with UIKit adaptive system colors (systemGroupedBackground, secondarySystemGroupedBackground, tertiarySystemFill). Unify accent color to AppColors.medication (#5856D6).

**Tech Stack:** SwiftUI, UIKit system colors

---

### Task 1: MedicationsView — Background, Calendar Strip, Progress Section

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/MedicationsView.swift`

**Step 1: Replace background and update calendar strip**

In `body`, replace `PremiumBackground()` with:
```swift
Color(.systemGroupedBackground)
    .ignoresSafeArea()
```

In `calendarStrip`, change the selected circle fill from `AppColors.accentBlue` to `AppColors.medication`. Add a ring for today-but-unselected:
```swift
// Selected state circle
.fill(isSelected ? AppColors.medication : Color.clear)

// Today ring (when not selected)
.overlay(
    Circle()
        .stroke(AppColors.medication, lineWidth: 1.5)
        .opacity(isToday && !isSelected ? 1 : 0)
)
```

Remove the `RoundedRectangle` background on today-unselected (the `AppColors.accentBlue.opacity(0.1)` fill).

**Step 2: Update progress section**

In `progressSection`, replace:
```swift
.background(Color(UIColor.secondarySystemBackground))
```
with:
```swift
.background(Color(UIColor.secondarySystemGroupedBackground))
```

In `medicationStatPill`, keep as-is (already uses semantic color opacity backgrounds).

**Step 3: Update PillBottleView color**

In `PillBottleView`, replace:
```swift
private let teal = Color(hex: "11998e")
```
with:
```swift
private let accentColor = AppColors.medication
```

Update all references from `teal` to `accentColor` within PillBottleView.

**Step 4: Update quick-take checkmark color**

In `TimelineMedicationCard`, replace:
```swift
.foregroundColor(Color(hex: "11998e"))
```
with:
```swift
.foregroundColor(AppColors.accentGreen)
```

**Step 5: Build and verify**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add swastricare-mobile-swift/Views/Home/MedicationsView.swift
git commit -m "refactor(ios): MedicationsView — native system backgrounds, medication accent color"
```

---

### Task 2: MedicationsView — Timeline Cards, Skeleton, Empty State, AI Button

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/MedicationsView.swift`

**Step 1: Update timeline medication cards**

In `TimelineMedicationCard` body, replace:
```swift
.background(Color(UIColor.secondarySystemBackground))
```
with:
```swift
.background(Color(UIColor.secondarySystemGroupedBackground))
```

Replace icon background `AppColors.accentBlue.opacity(0.12)` with `AppColors.medication.opacity(0.12)` and icon foreground `AppColors.accentBlue` with `AppColors.medication`.

**Step 2: Update skeleton loading**

In `medicationsSkeletonView`, replace `.glass(cornerRadius: 16)` with:
```swift
.background(Color(UIColor.secondarySystemGroupedBackground))
.cornerRadius(16)
```

**Step 3: Update empty state**

Change icon color from `AppColors.accentBlue.opacity(0.3)` to `AppColors.medication.opacity(0.15)`.
Change CTA button background from `AppColors.accentBlue` to `AppColors.medication`.

**Step 4: Update Ask AI button**

Replace `AppColors.accentBlue.opacity(0.08)` background with:
```swift
.background(Color(UIColor.secondarySystemGroupedBackground))
```

Keep the `AppColors.accentBlue` foreground color (AI is a different feature, not medication-specific).

Remove the `.overlay(RoundedRectangle(...).stroke(...))` border — the card background provides enough definition.

**Step 5: Update toolbar plus button**

Change `AppColors.accentBlue` to `AppColors.medication` on the plus.circle.fill button.

**Step 6: Build and verify**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 7: Commit**

```bash
git add swastricare-mobile-swift/Views/Home/MedicationsView.swift
git commit -m "refactor(ios): MedicationsView — cards, skeleton, empty state use system backgrounds"
```

---

### Task 3: AddMedicationView — Background, Sections, Color Unification

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/AddMedicationView.swift`

**Step 1: Replace color constants and add background**

Replace the top-level color constants:
```swift
private let medBlue = AppColors.accentBlue
private let medPurple = AppColors.medication
private let tealGreen = Color(hex: "10B981")
```
with:
```swift
private let medAccent = AppColors.medication
private let tealGreen = Color(hex: "10B981")
```

Then find-and-replace all `medBlue` with `medAccent` and remove `medPurple`.

**Step 2: Replace all .glass() section wrappers**

Replace every `.glass(cornerRadius: 16)` with:
```swift
.background(Color(UIColor.secondarySystemGroupedBackground))
.cornerRadius(16)
```

Add background to the outer ZStack/VStack:
```swift
Color(.systemGroupedBackground)
    .ignoresSafeArea()
```

**Step 3: Update chip components**

In `chipButton`, replace unselected background:
```swift
.background(isSelected ? medAccent : Color(UIColor.tertiarySystemFill))
```
Remove the `.overlay(RoundedRectangle...stroke)` for unselected state — tertiarySystemFill provides enough contrast.

Apply same to `frequencyChip`, `durationModeChip`, `presetChip`.

**Step 4: Update text inputs**

In `editableTimeRow`, replace `Color.primary.opacity(0.05)` with `Color(UIColor.tertiarySystemFill)` and remove the `.overlay(RoundedRectangle...stroke)`.

In `dateRow`, same replacement.

In `notesSection` TextEditor, replace `Color.primary.opacity(0.05)` with `Color(UIColor.tertiarySystemFill)` and remove the `.overlay(RoundedRectangle...stroke)`.

**Step 5: Update save button**

Replace the gradient with solid color:
```swift
.background(canSave ? AppColors.medication : Color(UIColor.tertiarySystemFill))
```

Remove the `LinearGradient` usage entirely.

**Step 6: Update drug search field**

Replace `Color(UIColor.tertiarySystemFill)` on the search field with `Color(UIColor.secondarySystemGroupedBackground)`.

Suggestion dropdown: replace `Color(UIColor.systemBackground)` with `Color(UIColor.secondarySystemGroupedBackground)`.

**Step 7: Build and verify**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 8: Commit**

```bash
git add swastricare-mobile-swift/Views/Home/AddMedicationView.swift
git commit -m "refactor(ios): AddMedicationView — native system backgrounds, unified medication accent"
```

---

### Task 4: MedicationDetailView — All Sections

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/MedicationDetailView.swift`

**Step 1: Update medication header**

Replace `.glass(cornerRadius: 18)` with:
```swift
.background(Color(UIColor.secondarySystemGroupedBackground))
.cornerRadius(16)
```

Replace `AppColors.accentBlue.opacity(0.12)` icon background with `AppColors.medication.opacity(0.12)`.
Replace `AppColors.accentBlue` icon foreground with `AppColors.medication`.

**Step 2: Update DoseCard**

Replace `.glass(cornerRadius: 14)` with:
```swift
.background(Color(UIColor.secondarySystemGroupedBackground))
.cornerRadius(14)
```

Same for the empty dose state `.glass(cornerRadius: 16)`.

**Step 3: Update details section**

Outer wrapper: replace `.glass(cornerRadius: 18)` with:
```swift
.background(Color(UIColor.secondarySystemGroupedBackground))
.cornerRadius(16)
```

**Step 4: Update DetailRow**

Replace `.glass(cornerRadius: 14)` with:
```swift
.background(Color(UIColor.tertiarySystemFill))
.cornerRadius(12)
```

Notes sub-card: replace `.glass(cornerRadius: 14)` with same tertiarySystemFill treatment.

**Step 5: Update edit form section**

Replace `.glass(cornerRadius: 18)` with:
```swift
.background(Color(UIColor.secondarySystemGroupedBackground))
.cornerRadius(16)
```

TextEditor: replace `Color.primary.opacity(0.05)` with `Color(UIColor.tertiarySystemFill)`, remove `.overlay(RoundedRectangle...stroke)`.

Change toggle tint from `AppColors.accentBlue` to `AppColors.medication`.

**Step 6: Update adherence section**

Replace `.glass(cornerRadius: 18)` with:
```swift
.background(Color(UIColor.secondarySystemGroupedBackground))
.cornerRadius(16)
```

**Step 7: Update toolbar colors**

Replace `AppColors.accentBlue` on Edit/Save buttons with `AppColors.medication`.

**Step 8: Build and verify**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 9: Commit**

```bash
git add swastricare-mobile-swift/Views/Home/MedicationDetailView.swift
git commit -m "refactor(ios): MedicationDetailView — native system backgrounds, medication accent"
```

---

### Task 5: Final Build Verification

**Step 1: Full clean build**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug clean build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 2: Verify no remaining .glass() or PremiumBackground in medication files**

Run: `grep -n "glass\|PremiumBackground\|medBlue\|medPurple" swastricare-mobile-swift/Views/Home/MedicationsView.swift swastricare-mobile-swift/Views/Home/AddMedicationView.swift swastricare-mobile-swift/Views/Home/MedicationDetailView.swift`
Expected: No matches
