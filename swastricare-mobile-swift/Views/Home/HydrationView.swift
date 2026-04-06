//
//  HydrationView.swift
//  swastricare-mobile-swift
//
//  Smart Hydration Tracking — Android-matched redesign
//

import SwiftUI
import Combine
import CoreMotion

// MARK: - Haptic Helper

enum Haptics {
    static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    static let selection = UISelectionFeedbackGenerator()

    static func light() {
        lightImpact.prepare()
        lightImpact.impactOccurred()
    }

    static func medium() {
        mediumImpact.prepare()
        mediumImpact.impactOccurred()
    }

    static func select() {
        selection.prepare()
        selection.selectionChanged()
    }
}

// MARK: - Gravity Motion Manager

final class GravityMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)

    /// Normalized tilt: -1 (full left) to +1 (full right)
    @Published var tiltX: Double = 0
    /// Normalized tilt: -1 (tilted toward user) to +1 (tilted away)
    @Published var tiltY: Double = 0

    private let smoothingFactor: Double = 0.15
    private var lastHapticTiltX: Double = 0
    private var lastHapticTime: TimeInterval = 0
    private let hapticCooldownMs: TimeInterval = 120
    private let hapticThreshold: Double = 0.06

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        hapticGenerator.prepare()
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let gravity = motion?.gravity else { return }
            self.tiltX = self.tiltX + (gravity.x - self.tiltX) * self.smoothingFactor
            self.tiltY = self.tiltY + (gravity.y - self.tiltY) * self.smoothingFactor

            // Haptic tick when tilt changes enough
            let now = Date().timeIntervalSince1970 * 1000
            let delta = abs(self.tiltX - self.lastHapticTiltX)
            if delta > self.hapticThreshold && (now - self.lastHapticTime) > self.hapticCooldownMs {
                self.lastHapticTiltX = self.tiltX
                self.lastHapticTime = now
                // Intensity scales with tilt delta (0.5 to 1.0)
                let intensity = min(0.35 + delta * 2.5, 0.8)
                self.hapticGenerator.impactOccurred(intensity: intensity)
            }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
}

// MARK: - Drink Type Gradients

struct DrinkGradient {
    let topColor: Color
    let bottomColor: Color
    let accentColor: Color

    static func forType(_ type: DrinkType) -> DrinkGradient {
        switch type {
        case .water:
            return DrinkGradient(topColor: Color(hex: "0EA5E9"), bottomColor: Color(hex: "2563EB"), accentColor: Color(hex: "38BDF8"))
        case .coffee:
            return DrinkGradient(topColor: Color(hex: "8B6914"), bottomColor: Color(hex: "5C3D0E"), accentColor: Color(hex: "C48A2A"))
        case .tea:
            return DrinkGradient(topColor: Color(hex: "7CB342"), bottomColor: Color(hex: "558B2F"), accentColor: Color(hex: "8BC34A"))
        case .juice:
            return DrinkGradient(topColor: Color(hex: "F57C00"), bottomColor: Color(hex: "E65100"), accentColor: Color(hex: "FF9800"))
        case .milk:
            return DrinkGradient(topColor: Color(hex: "90A4AE"), bottomColor: Color(hex: "607D8B"), accentColor: Color(hex: "B0BEC5"))
        default:
            return DrinkGradient(topColor: Color(hex: "0EA5E9"), bottomColor: Color(hex: "2563EB"), accentColor: Color(hex: "38BDF8"))
        }
    }
}

// MARK: - Main HydrationView

struct HydrationView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var viewModel: HydrationViewModel

    @State private var heroPage = 0
    @State private var showAddDrink = false

    private var gradient: DrinkGradient {
        DrinkGradient.forType(viewModel.dominantDrinkType)
    }

    @State private var sheetOffset: CGFloat = 0
    @State private var sheetExpanded = false
    private let sheetPeekHeight: CGFloat = 260
    private let sheetTopPadding: CGFloat = 120

    var body: some View {
        GeometryReader { geo in
            let screenHeight = geo.size.height
            let maxSheetHeight = screenHeight - sheetTopPadding
            let collapsedOffset = screenHeight - sheetPeekHeight
            let expandedOffset = sheetTopPadding

            ZStack(alignment: .top) {
                // Gradient background
                LinearGradient(
                    colors: [gradient.topColor, gradient.bottomColor],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: viewModel.dominantDrinkType)

                // Fixed hero content at top
                VStack(spacing: 12) {
                    // Top bar
                    topBar

                    // Hero Pager
                    heroPager
                        .frame(height: 240)

                    // Pagination dots
                    paginationDots

                    // Calendar strip
                    HydrationCalendarStrip(
                        selectedDate: $viewModel.selectedDate,
                        accentColor: gradient.accentColor
                    )

                    // Quick-add drink chips
                    quickAddChips

                    // Weather banner
                    if viewModel.weatherAdjustmentMl > 0, let temp = viewModel.currentTemperature {
                        weatherBanner(temp: temp)
                    }
                }

                // Draggable bottom sheet
                entriesSheet
                    .frame(maxHeight: maxSheetHeight)
                    .offset(y: sheetExpanded ? expandedOffset + sheetOffset : collapsedOffset + sheetOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                sheetOffset = value.translation.height
                            }
                            .onEnded { value in
                                let velocity = value.predictedEndTranslation.height
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    if sheetExpanded {
                                        // Currently expanded: pull down to collapse
                                        if value.translation.height > 80 || velocity > 300 {
                                            sheetExpanded = false
                                            Haptics.light()
                                        }
                                    } else {
                                        // Currently collapsed: pull up to expand
                                        if value.translation.height < -80 || velocity < -300 {
                                            sheetExpanded = true
                                            Haptics.light()
                                        }
                                    }
                                    sheetOffset = 0
                                }
                            }
                    )
            }
        }
        .task {
            await viewModel.onAppear()
        }
        .sheet(isPresented: $showAddDrink) {
            AddDrinkSheet(viewModel: viewModel, accentColor: gradient.accentColor)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $viewModel.showUrineColorGuide) {
            UrineColorGuideView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showSettings) {
            HydrationSettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showOverview) {
            HydrationOverviewSheet(viewModel: viewModel, accentColor: gradient.accentColor)
                .presentationDetents([.large])
        }
        .trackScreen("Hydration")
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }

            Spacer()

            Text("Hydration")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Menu {
                Button(action: { viewModel.showSettings = true }) {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                Button(action: { viewModel.showUrineColorGuide = true }) {
                    Label("Hydration Check", systemImage: "drop.fill")
                }
                Button(action: { viewModel.showOverview = true }) {
                    Label("Analytics", systemImage: "chart.bar.fill")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Hero Pager

    private var heroPager: some View {
        TabView(selection: $heroPage) {
            // Page 0: Hero Ring
            HydrationHeroRing(
                intakeMl: viewModel.effectiveIntake,
                goalMl: viewModel.dailyGoal,
                progress: viewModel.progress,
                isGoalMet: viewModel.isGoalMet,
                streak: viewModel.insights?.currentStreak ?? 0,
                accentColor: gradient.accentColor,
                onAdd: { amount in
                    Task {
                        await viewModel.addWaterIntake(amount: amount, drinkType: viewModel.dominantDrinkType)
                    }
                }
            )
            .tag(0)

            // Page 1: Insight tiles
            insightTilesPage
                .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private var paginationDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<2) { index in
                Circle()
                    .fill(heroPage == index ? Color.white : Color.white.opacity(0.4))
                    .frame(width: heroPage == index ? 8 : 6, height: heroPage == index ? 8 : 6)
                    .animation(.easeInOut(duration: 0.2), value: heroPage)
            }
        }
    }

    // MARK: - Insight Tiles Page

    private var insightTilesPage: some View {
        let insights = viewModel.insights
        let caffeine = viewModel.caffeineInfo

        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                insightTile(
                    icon: "flame.fill",
                    value: "\(insights?.currentStreak ?? 0)",
                    label: "Day Streak",
                    color: .orange
                )
                insightTile(
                    icon: "chart.line.uptrend.xyaxis",
                    value: "\(insights?.averageDailyIntake ?? 0)ml",
                    label: "Daily Average",
                    color: .green
                )
            }
            HStack(spacing: 12) {
                insightTile(
                    icon: "cup.and.saucer.fill",
                    value: "\(caffeine.count)",
                    label: "Caffeine Drinks",
                    color: .brown
                )
                insightTile(
                    icon: "drop.fill",
                    value: "\(viewModel.remainingMl)ml",
                    label: "Remaining",
                    color: gradient.accentColor
                )
            }
        }
        .padding(.horizontal, 24)
    }

    private func insightTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Quick Add Chips

    private var quickAddChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(DrinkType.allCases) { type in
                    QuickAddDrinkChip(
                        drinkType: type,
                        onTap: {
                            Haptics.light()
                            Task {
                                await viewModel.addWaterIntake(amount: 100, drinkType: type)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Weather Banner

    private func weatherBanner(temp: Double) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "FF9500").opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "FF9500"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Goal adjusted for hot weather")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text("\(Int(temp))°C — +\(viewModel.weatherAdjustmentMl)ml added")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Text("+20%")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "FF9500"))
        }
        .padding(16)
        .background(Color(hex: "FF9500").opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "FF9500").opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    // MARK: - Entries Sheet

    private var entriesSheet: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.primary.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Date header row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedSelectedDate)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    Text("\(viewModel.todaysEntries.count) drinks • \(viewModel.totalIntake)ml total")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { showAddDrink = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(gradient.accentColor)
                        .frame(width: 40, height: 40)
                        .background(gradient.accentColor.opacity(0.12))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 20)

            // Scrollable entries content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if viewModel.todaysEntries.isEmpty {
                        emptyStateView
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.todaysEntries) { entry in
                                HydrationEntryCard(entry: entry) {
                                    Task {
                                        await viewModel.deleteEntry(entry)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }

                    // Ask AI button
                    Button(action: {
                        Haptics.medium()
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NotificationCenter.default.post(name: NSNotification.Name("SwitchToAITab"), object: nil)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Ask AI about my hydration")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(gradient.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(gradient.accentColor.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(gradient.accentColor.opacity(0.15), lineWidth: 0.5)
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(colorScheme == .dark ? Color(hex: "0A0A0A") : Color.white)
                .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy"
        return formatter.string(from: viewModel.selectedDate)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "drop")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No drinks yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)

            Text("Tap + or use the chips above to log a drink")
                .font(.system(size: 13))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Hydration Hero Ring

struct HydrationHeroRing: View {
    let intakeMl: Int
    let goalMl: Int
    let progress: Double
    let isGoalMet: Bool
    let streak: Int
    let accentColor: Color
    let onAdd: (Int) -> Void

    @StateObject private var gravity = GravityMotionManager()
    @State private var displayProgress: Double = 0
    @State private var targetProgress: Double = 0
    @State private var isDragging = false
    @State private var dragMl: Int = 0
    @State private var lastTickMl: Int = 0
    @State private var startDate = Date()
    @State private var lastFrameTime: Date = Date()

    private let ringSize: CGFloat = 220
    private let strokeWidth: CGFloat = 14
    /// How fast the water lerps toward target (higher = faster). ~4.0 gives a smooth 0.9s rise.
    private let lerpSpeed: Double = 4.0

    var body: some View {
        let innerRadius = (ringSize - strokeWidth * 2) / 2

        ZStack {
            // Track ring
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: strokeWidth)
                .frame(width: ringSize, height: ringSize)

            // TimelineView drives continuous wave + fluid level animation
            TimelineView(.animation) { timeline in
                let now = timeline.date
                let elapsed = now.timeIntervalSince(startDate)
                let dt = min(now.timeIntervalSince(lastFrameTime), 0.05) // cap at 50ms

                // Smooth lerp: displayProgress chases targetProgress each frame
                let _ = updateDisplayProgress(dt: dt, now: now)

                // Wave phases: continuous rotation matching Android periods
                let phase1 = (elapsed / 2.2).truncatingRemainder(dividingBy: 1.0) * .pi * 2
                let phase2 = .pi + (elapsed / 2.8).truncatingRemainder(dividingBy: 1.0) * .pi * 2

                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let circleHeight = innerRadius * 2
                    let circleBottom = center.y + innerRadius

                    let waterTop = circleBottom - (circleHeight * CGFloat(min(displayProgress, 1.0)))
                    let amplitude = circleHeight * 0.04

                    // Gravity tilt: tiltX shifts water diagonally, max 30% of circle height
                    let tiltOffset = CGFloat(gravity.tiltX) * circleHeight * 0.3

                    let waveWidth = innerRadius * 2 + 20
                    let waveStartX = center.x - innerRadius - 10

                    // Clip to inner circle
                    let clipRect = CGRect(
                        x: center.x - innerRadius,
                        y: center.y - innerRadius,
                        width: innerRadius * 2,
                        height: innerRadius * 2
                    )
                    let clipPath = Path(ellipseIn: clipRect)
                    context.clipToLayer { ctx in
                        ctx.fill(clipPath, with: .color(.white))
                    }

                    // Wave 1 — back layer (1 wavelength, 2200ms period)
                    var path1 = Path()
                    path1.move(to: CGPoint(x: waveStartX, y: circleBottom + 10))
                    var x: CGFloat = 0
                    while x <= waveWidth {
                        let xf = waveStartX + x
                        let normalizedX = x / waveWidth
                        let gravityShift = tiltOffset * (1 - 2 * normalizedX)
                        let angle = Double(normalizedX) * 2 * .pi + phase1
                        let y = waterTop + gravityShift + sin(angle) * amplitude
                        path1.addLine(to: CGPoint(x: xf, y: y))
                        x += 3
                    }
                    path1.addLine(to: CGPoint(x: waveStartX + waveWidth, y: circleBottom + 10))
                    path1.closeSubpath()
                    context.fill(path1, with: .color(fillColor.opacity(0.35)))

                    // Wave 2 — front layer (1.25 wavelengths, 2800ms period, 30% taller)
                    var path2 = Path()
                    path2.move(to: CGPoint(x: waveStartX, y: circleBottom + 10))
                    x = 0
                    while x <= waveWidth {
                        let xf = waveStartX + x
                        let normalizedX = x / waveWidth
                        let gravityShift = tiltOffset * (1 - 2 * normalizedX)
                        let angle = Double(normalizedX) * 2.5 * .pi + phase2
                        let y = waterTop + gravityShift + sin(angle) * amplitude * 1.3
                        path2.addLine(to: CGPoint(x: xf, y: y))
                        x += 3
                    }
                    path2.addLine(to: CGPoint(x: waveStartX + waveWidth, y: circleBottom + 10))
                    path2.closeSubpath()
                    context.fill(path2, with: .color(fillColor.opacity(0.6)))
                }
            }
            .frame(width: ringSize, height: ringSize)

            // Progress arc
            Circle()
                .trim(from: 0, to: CGFloat(min(displayProgress, 1.0)))
                .stroke(
                    isGoalMet ? Color(hex: "34C759") : Color.white,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))

            // Text overlay with rolling number animation
            VStack(spacing: 4) {
                if isDragging {
                    Text("+\(dragMl)ml")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText(value: Double(dragMl)))
                        .animation(.snappy(duration: 0.15), value: dragMl)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))

                    Text("Release to add")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Text("\(intakeMl)ml")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText(value: Double(intakeMl)))
                        .animation(.easeOut(duration: 0.6), value: intakeMl)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))

                    Text("of \(goalMl)ml")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .contentTransition(.numericText(value: Double(goalMl)))

                    // Percentage pill
                    Text("\(Int(min(progress, 1.0) * 100))%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                        .contentTransition(.numericText(value: progress))
                        .animation(.easeOut(duration: 0.6), value: progress)

                    if streak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                            Text("\(streak) day streak")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                                .contentTransition(.numericText(value: Double(streak)))
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isDragging)
        }
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    let upwardDrag = -value.translation.height
                    if upwardDrag > 0 {
                        isDragging = true
                        let mlPerPx = CGFloat(goalMl) / ringSize
                        let rawMl = Int(upwardDrag * mlPerPx)
                        let snapped = max(50, (rawMl / 50) * 50)
                        if snapped != lastTickMl {
                            Haptics.light()
                            lastTickMl = snapped
                        }
                        dragMl = snapped
                    }
                }
                .onEnded { _ in
                    if isDragging && dragMl > 0 {
                        Haptics.medium()
                        onAdd(dragMl)
                    }
                    isDragging = false
                    dragMl = 0
                    lastTickMl = 0
                }
        )
        .onAppear {
            gravity.start()
            startDate = Date()
            lastFrameTime = Date()
            targetProgress = progress
            // Start at 0 so the water rises on first load
            displayProgress = 0
        }
        .onDisappear {
            gravity.stop()
        }
        .onChange(of: progress) { _, newValue in
            targetProgress = newValue
        }
    }

    /// Lerp displayProgress toward targetProgress each frame for smooth fluid rise
    private func updateDisplayProgress(dt: Double, now: Date) {
        DispatchQueue.main.async {
            lastFrameTime = now
            let diff = targetProgress - displayProgress
            if abs(diff) < 0.001 {
                displayProgress = targetProgress
            } else {
                // Exponential ease-out lerp
                displayProgress += diff * min(lerpSpeed * dt, 1.0)
            }
        }
    }

    private var fillColor: Color {
        isGoalMet ? Color(hex: "34C759") : accentColor
    }
}

// MARK: - Calendar Strip

struct HydrationCalendarStrip: View {
    @Binding var selectedDate: Date
    let accentColor: Color

    private let calendar = Calendar.current
    private let dayCount = 7

    private var dates: [Date] {
        (-3...3).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: Date())
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(dates, id: \.timeIntervalSince1970) { date in
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                let isToday = calendar.isDateInToday(date)
                let isFuture = date > Date() && !isToday

                VStack(spacing: 6) {
                    Text(date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(isFuture ? 0.35 : 0.7))

                    Text(date.formatted(.dateTime.day()))
                        .font(.system(size: isSelected ? 17 : 16, weight: isSelected ? .bold : .medium))
                        .foregroundColor(.white.opacity(isFuture ? 0.35 : 1.0))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(isSelected ? Color.white.opacity(0.25) : Color.clear)
                        )
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.white.opacity(0.6) : Color.clear, lineWidth: 1)
                        )
                }
                .frame(maxWidth: .infinity)
                .scaleEffect(isSelected ? 1.0 : 0.9)
                .onTapGesture {
                    guard !isFuture else { return }
                    Haptics.select()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDate = date
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Quick Add Drink Chip

struct QuickAddDrinkChip: View {
    let drinkType: DrinkType
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(drinkType.assetIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(drinkType.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text("+100ml")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(0.22), Color.white.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Drink Sheet

struct AddDrinkSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var viewModel: HydrationViewModel
    let accentColor: Color

    @State private var selectedType: DrinkType = .water
    @State private var customAmount: String = ""
    @FocusState private var amountFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Drag handle
            Capsule()
                .fill(Color.primary.opacity(0.3))
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            // Title
            Text("Add a drink")
                .font(.system(size: 24, weight: .bold))
                .padding(.horizontal, 24)

            // Drink type selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DrinkType.allCases) { type in
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(
                                        selectedType == type
                                            ? accentColor.opacity(0.2)
                                            : Color(UIColor.secondarySystemBackground)
                                    )
                                    .frame(width: 64, height: 64)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                selectedType == type ? accentColor : Color.clear,
                                                lineWidth: 2
                                            )
                                    )

                                Image(type.assetIcon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                            }

                            Text(type.displayName)
                                .font(.system(size: 11, weight: selectedType == type ? .semibold : .regular))
                                .foregroundColor(selectedType == type ? accentColor : .secondary)
                        }
                        .onTapGesture {
                            Haptics.select()
                            selectedType = type
                        }
                    }
                }
                .padding(.horizontal, 24)
            }

            // Custom amount input
            VStack(alignment: .leading, spacing: 8) {
                Text("CUSTOM AMOUNT")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.7))
                    .tracking(0.5)
                    .padding(.horizontal, 24)

                HStack(spacing: 12) {
                    HStack {
                        TextField("Enter amount (ml)", text: $customAmount)
                            .keyboardType(.numberPad)
                            .font(.system(size: 15, weight: .medium))
                            .focused($amountFocused)

                        Text("ml")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "F8F9FA"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    Button(action: addDrink) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                validAmount ? accentColor : Color(UIColor.secondarySystemBackground)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(!validAmount)
                }
                .padding(.horizontal, 24)
            }

            // Quick preset amounts
            HStack(spacing: 10) {
                ForEach([100, 250, 500, 750], id: \.self) { amount in
                    Button(action: {
                        customAmount = "\(amount)"
                    }) {
                        Text("\(amount)ml")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(customAmount == "\(amount)" ? .white : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                customAmount == "\(amount)"
                                    ? accentColor
                                    : Color(UIColor.secondarySystemBackground)
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 24)

            // Urine guide footer
            Button(action: {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    viewModel.showUrineColorGuide = true
                }
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 18))
                            .foregroundColor(accentColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Check Hydration Level")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Use urine color guide")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [accentColor.opacity(0.08), accentColor.opacity(0.12)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .padding(.horizontal, 16)
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private var validAmount: Bool {
        guard let val = Int(customAmount) else { return false }
        return val > 0
    }

    private func addDrink() {
        guard let amount = Int(customAmount), amount > 0 else { return }
        Haptics.medium()
        Task {
            await viewModel.addWaterIntake(amount: amount, drinkType: selectedType)
        }
        customAmount = ""
        dismiss()
    }
}

// MARK: - Hydration Overview Sheet

struct HydrationOverviewSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var viewModel: HydrationViewModel
    let accentColor: Color

    @State private var selectedPeriod = 0 // 0=Today, 1=7 Days, 2=30 Days

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hydration Analytics")
                            .font(.system(size: 28, weight: .bold))
                        Text("Your complete overview")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                    // Period selector
                    HStack(spacing: 8) {
                        ForEach(["Today", "7 Days", "30 Days"], id: \.self) { period in
                            let index = ["Today", "7 Days", "30 Days"].firstIndex(of: period) ?? 0
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedPeriod = index
                                }
                            }) {
                                Text(period)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(selectedPeriod == index ? .white : .primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        selectedPeriod == index
                                            ? accentColor
                                            : Color(colorScheme == .dark ? UIColor(hex: "1C1C1E") : UIColor(hex: "F2F2F7"))
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Today's progress card
                    if selectedPeriod == 0 {
                        todayCard
                    }

                    // Insights stats
                    if let insights = viewModel.insights {
                        statsGrid(insights)
                    }

                    // Drink breakdown
                    drinkBreakdown

                    // Goal description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goal Calculation")
                            .font(.system(size: 16, weight: .semibold))
                        Text(viewModel.goalDescription)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(accentColor)
                }
            }
        }
    }

    private var todayCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.effectiveIntake)ml")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("of \(viewModel.dailyGoal)ml goal")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(viewModel.progress * 100))%")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text(viewModel.isGoalMet ? "Goal met!" : "In progress")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [accentColor, accentColor.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 20)
    }

    private func statsGrid(_ insights: HydrationInsights) -> some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return LazyVGrid(columns: columns, spacing: 12) {
            analyticsMiniCard(label: "Streak", value: "\(insights.currentStreak) days", icon: "flame.fill", color: .orange)
            analyticsMiniCard(label: "Daily Average", value: "\(insights.averageDailyIntake)ml", icon: "chart.line.uptrend.xyaxis", color: .green)
            analyticsMiniCard(label: "Caffeine", value: "\(viewModel.caffeineInfo.count) drinks", icon: "cup.and.saucer.fill", color: .brown)
            if let best = insights.bestDayThisWeek {
                analyticsMiniCard(label: "Best Day", value: "\(best.amount)ml", icon: "trophy.fill", color: .yellow)
            } else {
                analyticsMiniCard(label: "Remaining", value: "\(viewModel.remainingMl)ml", icon: "drop.fill", color: accentColor)
            }
        }
        .padding(.horizontal, 20)
    }

    private func analyticsMiniCard(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var drinkBreakdown: some View {
        let grouped = Dictionary(grouping: viewModel.todaysEntries, by: { $0.drinkType })
        let totalMl = viewModel.totalIntake

        return VStack(alignment: .leading, spacing: 12) {
            Text("Drink Breakdown")
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 20)

            if grouped.isEmpty {
                Text("No drinks logged yet")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
            } else {
                ForEach(grouped.sorted(by: { $0.value.reduce(0) { $0 + $1.amountMl } > $1.value.reduce(0) { $0 + $1.amountMl } }), id: \.key) { type, entries in
                    let typeMl = entries.reduce(0) { $0 + $1.amountMl }
                    let proportion = totalMl > 0 ? CGFloat(typeMl) / CGFloat(totalMl) : 0

                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(type.color.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Image(type.assetIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(type.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                Text("(\(entries.count))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(typeMl)ml")
                                    .font(.system(size: 14, weight: .semibold))
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.primary.opacity(0.1))
                                        .frame(height: 4)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(type.color)
                                        .frame(width: geo.size.width * proportion, height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

// MARK: - Hydration Entry Card (swipe-to-delete)

struct HydrationEntryCard: View {
    let entry: HydrationEntry
    let onDelete: () -> Void

    @State private var offsetX: CGFloat = 0
    @State private var showDelete = false
    @State private var isRemoving = false

    private let deleteThreshold: CGFloat = -80
    private let fullSwipeThreshold: CGFloat = -160

    var body: some View {
        if !isRemoving {
            ZStack(alignment: .trailing) {
                // Delete background
                HStack {
                    Spacer()
                    Button(action: performDelete) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 60, height: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hex: "FF3B30"))
                )
                .opacity(offsetX < 0 ? 1 : 0)

                // Card content
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(entry.drinkType.color.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(entry.drinkType.assetIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(entry.amountMl)ml")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)

                            if entry.drinkType != .water {
                                Text("(\(entry.effectiveHydration)ml eff.)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Text("\(entry.drinkType.displayName) • \(entry.formattedTime)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(14)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .offset(x: offsetX)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            let drag = value.translation.width
                            // Only allow left swipe
                            if drag < 0 {
                                offsetX = drag
                            } else if showDelete {
                                // Allow swiping back to close
                                offsetX = deleteThreshold + drag
                                if offsetX > 0 { offsetX = 0 }
                            }
                        }
                        .onEnded { value in
                            let drag = value.translation.width
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if drag < fullSwipeThreshold {
                                    // Full swipe — delete immediately
                                    performDelete()
                                } else if drag < deleteThreshold {
                                    // Partial swipe — reveal delete button
                                    offsetX = deleteThreshold
                                    showDelete = true
                                    Haptics.light()
                                } else {
                                    // Snap back
                                    offsetX = 0
                                    showDelete = false
                                }
                            }
                        }
                )
            }
            .transition(.asymmetric(
                insertion: .opacity,
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
    }

    private func performDelete() {
        Haptics.medium()
        withAnimation(.easeOut(duration: 0.25)) {
            offsetX = -UIScreen.main.bounds.width
            isRemoving = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDelete()
        }
    }
}

// MARK: - Missing Data Item Model

struct MissingDataItem {
    let icon: String
    let title: String
    let description: String
    let action: String
}

// MARK: - UIColor hex extension (for UIColor usage in Color init)

private extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, alpha: Double(a) / 255)
    }
}

#Preview {
    HydrationView(viewModel: HydrationViewModel())
}
