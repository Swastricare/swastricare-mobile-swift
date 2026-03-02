# MedicationsView Overhaul Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace MedicationsView's progress ring with an animated pill bottle, restructure cards into a timeline layout, and add an Ask AI button.

**Architecture:** Single-file rewrite of `MedicationsView.swift`. New `PillBottleShape` and `PillBottleView` components follow the same pattern as `GlassShape`/`WaterGlassView` in HydrationView. Timeline groups existing `MedicationWithAdherence` data by `scheduledTime`. Uses shared `WaterWave` from `DesignSystem.swift`.

**Tech Stack:** SwiftUI, existing `MedicationViewModel`, `WaterWave` shape, `MedicationWithAdherence` model

---

### Task 1: Create PillBottleShape and PillBottleView

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/MedicationsView.swift`

**Step 1: Add PillBottleShape before the `#Preview` at end of file**

Add after the closing `}` of `MedicationCard` (after line 404), before `#Preview`:

```swift
// MARK: - Pill Bottle Shape

struct PillBottleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let w = rect.width
        let h = rect.height

        // Bottle proportions
        let capHeight: CGFloat = h * 0.1
        let neckHeight: CGFloat = h * 0.06
        let bodyTop = capHeight + neckHeight
        let bodyRadius: CGFloat = min(w * 0.08, 10)
        let capInset: CGFloat = w * 0.15
        let neckInset: CGFloat = w * 0.1
        let capRadius: CGFloat = min(w * 0.06, 6)

        // Cap (top, narrower)
        path.move(to: CGPoint(x: capInset + capRadius, y: 0))
        path.addLine(to: CGPoint(x: w - capInset - capRadius, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: w - capInset, y: capRadius),
            control: CGPoint(x: w - capInset, y: 0)
        )
        path.addLine(to: CGPoint(x: w - capInset, y: capHeight))
        path.addLine(to: CGPoint(x: capInset, y: capHeight))
        path.addLine(to: CGPoint(x: capInset, y: capRadius))
        path.addQuadCurve(
            to: CGPoint(x: capInset + capRadius, y: 0),
            control: CGPoint(x: capInset, y: 0)
        )
        path.closeSubpath()

        // Neck (short connector, slightly wider than cap)
        path.move(to: CGPoint(x: neckInset, y: capHeight))
        path.addLine(to: CGPoint(x: w - neckInset, y: capHeight))
        path.addLine(to: CGPoint(x: w - neckInset, y: bodyTop))
        path.addLine(to: CGPoint(x: neckInset, y: bodyTop))
        path.closeSubpath()

        // Body (main bottle, full width, rounded bottom)
        path.move(to: CGPoint(x: 0, y: bodyTop))
        path.addLine(to: CGPoint(x: w, y: bodyTop))
        path.addLine(to: CGPoint(x: w, y: h - bodyRadius))
        path.addQuadCurve(
            to: CGPoint(x: w - bodyRadius, y: h),
            control: CGPoint(x: w, y: h)
        )
        path.addLine(to: CGPoint(x: bodyRadius, y: h))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: h - bodyRadius),
            control: CGPoint(x: 0, y: h)
        )
        path.closeSubpath()

        return path
    }
}

/// Shape for just the bottle body (used to clip water fill — excludes cap and neck)
struct PillBottleBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let w = rect.width
        let h = rect.height
        let bodyRadius: CGFloat = min(w * 0.08, 10)

        // Simple rounded rectangle for the body area
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: h - bodyRadius))
        path.addQuadCurve(
            to: CGPoint(x: w - bodyRadius, y: h),
            control: CGPoint(x: w, y: h)
        )
        path.addLine(to: CGPoint(x: bodyRadius, y: h))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: h - bodyRadius),
            control: CGPoint(x: 0, y: h)
        )
        path.closeSubpath()

        return path
    }
}
```

**Step 2: Add PillBottleView after PillBottleBodyShape**

```swift
// MARK: - Pill Bottle View

struct PillBottleView: View {
    let progress: CGFloat // 0...1
    let bottleWidth: CGFloat
    let bottleHeight: CGFloat

    @State private var wavePhase: Double = 0
    @State private var visualProgress: CGFloat = 0

    private let teal = Color(hex: "11998e")

    // Bottle layout ratios (must match PillBottleShape)
    private var capHeight: CGFloat { bottleHeight * 0.1 }
    private var neckHeight: CGFloat { bottleHeight * 0.06 }
    private var bodyTop: CGFloat { capHeight + neckHeight }
    private var bodyHeight: CGFloat { bottleHeight - bodyTop }

    init(progress: CGFloat, width: CGFloat = 80, height: CGFloat = 130) {
        self.progress = min(max(progress, 0), 1)
        self.bottleWidth = width
        self.bottleHeight = height
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Bottle outline
            PillBottleShape()
                .stroke(teal.opacity(0.3), lineWidth: 2)
                .frame(width: bottleWidth, height: bottleHeight)

            // Water fill inside body only
            VStack(spacing: 0) {
                // Cap + neck spacer (no fill here)
                Color.clear
                    .frame(height: bodyTop)

                // Body with wave fill
                ZStack(alignment: .bottom) {
                    PillBottleBodyShape()
                        .fill(Color.clear)
                        .frame(width: bottleWidth, height: bodyHeight)

                    let fillHeight = bodyHeight * visualProgress
                    ZStack {
                        WaterWave(amplitude: 3, offset: wavePhase)
                            .fill(teal.opacity(0.25))
                            .frame(height: fillHeight)

                        WaterWave(amplitude: 2.5, offset: wavePhase + 1.5)
                            .fill(
                                LinearGradient(
                                    colors: [teal.opacity(0.5), teal.opacity(0.35)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: fillHeight)
                    }
                    .frame(height: fillHeight, alignment: .bottom)
                    .clipShape(PillBottleBodyShape())
                }
                .frame(width: bottleWidth, height: bodyHeight)
            }
            .frame(width: bottleWidth, height: bottleHeight)

            // Percentage label (centered in body)
            VStack(spacing: 2) {
                Spacer()
                    .frame(height: bodyTop)

                Spacer()

                Text("\(Int(visualProgress * 100))%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                if visualProgress >= 1.0 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                }

                Spacer()
            }
            .frame(width: bottleWidth, height: bottleHeight)
        }
        .frame(width: bottleWidth, height: bottleHeight)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                visualProgress = progress
            }
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                visualProgress = min(max(newValue, 0), 1)
            }
        }
    }
}
```

**Step 3: Build to verify shapes compile**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add swastricare-mobile-swift/Views/Home/MedicationsView.swift
git commit -m "feat(medications): add PillBottleShape and PillBottleView components"
```

---

### Task 2: Rewrite progressSection with pill bottle

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/MedicationsView.swift` — replace `progressSection` (lines 249-298)

**Step 1: Replace progressSection**

Replace the current `progressSection` computed property with:

```swift
    private var progressSection: some View {
        VStack(spacing: 16) {
            Text("Today's Progress")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            // Pill bottle animation
            PillBottleView(progress: viewModel.todayAdherencePercentage / 100)
                .padding(.vertical, 4)

            // Stat pills row
            HStack(spacing: 10) {
                medicationStatPill(
                    icon: "checkmark.circle.fill",
                    color: Color(hex: "11998e"),
                    value: "\(viewModel.takenCount)",
                    label: "taken"
                )

                medicationStatPill(
                    icon: "clock.fill",
                    color: .orange,
                    value: "\(viewModel.totalCount - viewModel.takenCount)",
                    label: "remaining"
                )

                medicationStatPill(
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green,
                    value: viewModel.adherenceStatistics?.adherenceRate ?? "0%",
                    label: "adherence"
                )
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
```

**Step 2: Add medicationStatPill helper**

Add after `progressSection`, before `// MARK: - Medication Card`:

```swift
    private func medicationStatPill(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }
```

**Step 3: Build to verify**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add swastricare-mobile-swift/Views/Home/MedicationsView.swift
git commit -m "feat(medications): replace progress ring with animated pill bottle"
```

---

### Task 3: Add timeline layout for medication cards

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/MedicationsView.swift` — replace the medication list ScrollView in body

**Step 1: Add a TimelineSlot model and grouping helper**

Add before `// MARK: - Pill Bottle Shape`:

```swift
// MARK: - Timeline Slot

struct TimelineSlot: Identifiable {
    let id: String  // "HH:mm" key
    let time: Date
    let items: [(medication: MedicationWithAdherence, dose: MedicationAdherence)]

    var allTaken: Bool {
        items.allSatisfy { dose in
            dose.dose.status == .taken || dose.dose.status == .late || dose.dose.status == .early
        }
    }

    var hasOverdue: Bool {
        items.contains { $0.dose.isOverdue() }
    }

    var dotColor: Color {
        if allTaken { return .green }
        if hasOverdue { return .red }
        return Color.primary.opacity(0.3)
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
}
```

**Step 2: Add a computed property to group medications into timeline slots**

Add inside `MedicationsView` struct, after `selectedMedication` state:

```swift
    private var timelineSlots: [TimelineSlot] {
        let calendar = Calendar.current
        var slotDict: [String: (time: Date, items: [(MedicationWithAdherence, MedicationAdherence)])] = [:]

        for medWithAdherence in viewModel.todaysMedications {
            for dose in medWithAdherence.todayDoses {
                let comps = calendar.dateComponents([.hour, .minute], from: dose.scheduledTime)
                let key = String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)

                if slotDict[key] == nil {
                    slotDict[key] = (time: dose.scheduledTime, items: [])
                }
                slotDict[key]?.items.append((medWithAdherence, dose))
            }
        }

        return slotDict.map { key, value in
            TimelineSlot(
                id: key,
                time: value.time,
                items: value.items.map { (medication: $0.0, dose: $0.1) }
            )
        }
        .sorted { $0.time < $1.time }
    }
```

**Step 3: Replace the medication list ScrollView in body**

In the body, replace the existing `// Medication List` ScrollView (lines 42-61) with a new `timelineSection`:

```swift
                        // Timeline Medication List
                        ScrollView {
                            timelineSection
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                                .padding(.bottom, 24)
                        }
```

**Step 4: Add timelineSection computed property**

Add after `medicationStatPill`:

```swift
    private var timelineSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(timelineSlots.enumerated()), id: \.element.id) { index, slot in
                HStack(alignment: .top, spacing: 14) {
                    // Time + dot column
                    VStack(spacing: 0) {
                        Text(slot.formattedTime)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(slot.hasOverdue ? .red : .secondary)
                            .frame(width: 65, alignment: .trailing)

                        Circle()
                            .fill(slot.dotColor)
                            .frame(width: 10, height: 10)
                            .padding(.top, 6)

                        // Connecting line (except last slot)
                        if index < timelineSlots.count - 1 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.1))
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 65)

                    // Cards for this time slot
                    VStack(spacing: 8) {
                        ForEach(slot.items, id: \.dose.id) { item in
                            TimelineMedicationCard(
                                medication: item.medication,
                                dose: item.dose,
                                onTaken: {
                                    Task {
                                        try? await viewModel.quickMarkAsTaken(medicationWithAdherence: item.medication)
                                    }
                                },
                                onTap: {
                                    selectedMedication = item.medication
                                }
                            )
                        }
                    }
                }
                .padding(.bottom, index < timelineSlots.count - 1 ? 16 : 0)
            }
        }
    }
```

**Step 5: Add TimelineMedicationCard**

Add before `// MARK: - Timeline Slot`:

```swift
// MARK: - Timeline Medication Card

struct TimelineMedicationCard: View {
    let medication: MedicationWithAdherence
    let dose: MedicationAdherence
    let onTaken: () -> Void
    let onTap: () -> Void

    private var statusColor: Color {
        switch dose.status {
        case .taken, .early: return .green
        case .late: return .orange
        case .missed: return .red
        case .skipped: return Color.primary.opacity(0.4)
        case .pending:
            return dose.isOverdue() ? .red : Color.primary.opacity(0.4)
        }
    }

    private var statusText: String {
        if dose.status == .pending && dose.isOverdue() {
            return "Overdue"
        }
        return dose.status.displayName
    }

    private var showTakeButton: Bool {
        dose.status == .pending
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Medication type icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "2E3192").opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: medication.medication.type.icon)
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "2E3192"))
                }

                // Name + dosage
                VStack(alignment: .leading, spacing: 3) {
                    Text(medication.medication.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(medication.medication.dosage)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Text("·")
                            .foregroundColor(.secondary)

                        HStack(spacing: 3) {
                            Image(systemName: dose.status.icon)
                                .font(.system(size: 10))
                            Text(statusText)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(statusColor)
                    }
                }

                Spacer()

                // Quick take button
                if showTakeButton {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            onTaken()
                        }
                    }) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: "11998e"))
                    }
                    .buttonStyle(PlainButtonStyle())
                } else if dose.status == .taken || dose.status == .late || dose.status == .early {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green.opacity(0.6))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(14)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
```

**Step 6: Build to verify**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 7: Commit**

```bash
git add swastricare-mobile-swift/Views/Home/MedicationsView.swift
git commit -m "feat(medications): add timeline layout for medication cards"
```

---

### Task 4: Enable PremiumBackground and add Ask AI button

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/MedicationsView.swift`

**Step 1: Enable PremiumBackground**

In the body, line 24, change:
```swift
                // PremiumBackground()
```
to:
```swift
                PremiumBackground()
```

**Step 2: Add Ask AI button at bottom of ScrollView content**

Inside the ScrollView in body, after the `LazyVStack` closing, add the AI button (same pattern as HydrationView):

```swift
                            // Ask AI about medications
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToAITab"), object: nil)
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Ask AI about my medications")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(Color(hex: "2E3192"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(hex: "2E3192").opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "2E3192").opacity(0.15), lineWidth: 0.5)
                                )
                            }
                            .padding(.horizontal, 20)
```

**Step 3: Build to verify**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add swastricare-mobile-swift/Views/Home/MedicationsView.swift
git commit -m "feat(medications): enable PremiumBackground and add Ask AI button"
```

---

### Task 5: Final verification and cleanup

**Step 1: Full build**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 2: Verify old MedicationCard is still used by MedicationDetailView or other files**

Search: `grep -r "MedicationCard(" --include="*.swift" | grep -v MedicationsView`

If MedicationCard is only used in MedicationsView, it can be removed since TimelineMedicationCard replaces it. If used elsewhere, keep it.

**Step 3: Remove old MedicationCard if unused elsewhere**

If unused, delete the `MedicationCard` struct from `MedicationsView.swift`.

**Step 4: Final commit**

```bash
git add swastricare-mobile-swift/Views/Home/MedicationsView.swift
git commit -m "refactor(medications): remove unused MedicationCard component"
```
