//
//  ActivityDetailView.swift
//  swastricare-mobile-swift
//
//  Detailed view for a single walking/running activity with analytics
//  Redesigned with Movements+ UI - Lime Green, Dark Theme
//

import SwiftUI
import MapKit

// MARK: - Detail Tab Enum

enum ActivityDetailTab: String, CaseIterable {
    case overview = "Overview"
    case splits = "Splits"
    case pace = "Pace"
    case heartRate = "Heart Rate"
    
    var icon: String {
        switch self {
        case .overview: return "chart.bar.fill"
        case .splits: return "ruler"
        case .pace: return "speedometer"
        case .heartRate: return "heart.fill"
        }
    }
}

struct ActivityDetailView: View {
    
    // MARK: - Properties
    
    let activity: RouteActivity
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = DependencyContainer.shared.runActivityViewModel
    @State private var isAnimating = false
    @State private var mapRegion: MKCoordinateRegion
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var shareImage: UIImage?
    @State private var isGeneratingShare = false
    
    // Analytics state
    @State private var selectedTab: ActivityDetailTab = .overview
    @State private var analytics: ActivityAnalytics?
    @State private var isLoadingAnalytics = false
    
    private let limeGreen = MovementsColors.limeGreen
    private let darkGreen = MovementsColors.darkGreen
    private let analyticsService = RunAnalyticsService.shared
    
    // MARK: - Init
    
    init(activity: RouteActivity) {
        self.activity = activity
        
        if let firstCoord = activity.routeCoordinates.first {
            _mapRegion = State(initialValue: MKCoordinateRegion(
                center: firstCoord.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
            ))
        } else {
            _mapRegion = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946),
                span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
            ))
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Map View
                    mapSection
                        .frame(height: selectedTab == .overview ? 260 : 140)
                    
                    // Activity Info Header
                    activityHeader
                    
                    // Tab Selector
                    tabSelector
                    
                    // Tab Content
                    tabContent
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(activity.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: shareActivity) {
                    if isGeneratingShare {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(limeGreen)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(limeGreen)
                    }
                }
                .disabled(isGeneratingShare)
            }
        }
        .alert("Delete Activity", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteActivity()
            }
        } message: {
            Text("Are you sure you want to delete this activity? This action cannot be undone.")
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ActivityShareSheet(image: image, activity: activity)
            }
        }
        .overlay {
            if isDeleting {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                        
                        Text("Deleting...")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAnimating = true
            }
            loadAnalytics()
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ActivityDetailTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = tab
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12, weight: .bold))
                            
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(selectedTab == tab ? .black : .primary.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? limeGreen : MovementsColors.card(for: colorScheme))
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 10)
        .animation(.spring(response: 0.5).delay(0.15), value: isAnimating)
    }
    
    // MARK: - Tab Content
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            overviewContent
        case .splits:
            splitsContent
        case .pace:
            paceContent
        case .heartRate:
            heartRateContent
        }
    }
    
    // MARK: - Overview Content
    
    private var overviewContent: some View {
        VStack(spacing: 24) {
            mainStatsGrid
            detailedMetricsSection
            timeAnalysisSection
            actionButtonsSection
        }
    }
    
    // MARK: - Splits Content
    
    private var splitsContent: some View {
        VStack(spacing: 16) {
            if isLoadingAnalytics {
                loadingView
            } else if let analytics = analytics, !analytics.splits.isEmpty {
                SplitsListView(
                    splits: analytics.splits,
                    bestSplitIndex: analytics.bestSplitIndex,
                    worstSplitIndex: analytics.worstSplitIndex
                )
            } else {
                emptyAnalyticsView(
                    icon: "ruler",
                    title: "No Splits Data",
                    message: "Splits are calculated for activities with GPS tracking over 1 km"
                )
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .animation(.spring(response: 0.5).delay(0.2), value: isAnimating)
    }
    
    // MARK: - Pace Content
    
    private var paceContent: some View {
        VStack(spacing: 16) {
            if isLoadingAnalytics {
                loadingView
            } else if let analytics = analytics, !analytics.paceSamples.isEmpty {
                PaceChartView(
                    paceSamples: analytics.paceSamples,
                    avgPaceSecondsPerKm: analytics.avgPaceSecondsPerKm,
                    bestPaceSecondsPerKm: analytics.bestPaceSecondsPerKm,
                    worstPaceSecondsPerKm: analytics.worstPaceSecondsPerKm
                )
            } else {
                emptyAnalyticsView(
                    icon: "speedometer",
                    title: "No Pace Data",
                    message: "Pace analysis requires GPS tracking during the activity"
                )
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .animation(.spring(response: 0.5).delay(0.2), value: isAnimating)
    }
    
    // MARK: - Heart Rate Content
    
    private var heartRateContent: some View {
        VStack(spacing: 16) {
            if isLoadingAnalytics {
                loadingView
            } else if let analytics = analytics, !analytics.heartRateSamples.isEmpty {
                RunHeartRateChartView(
                    heartRateSamples: analytics.heartRateSamples,
                    zoneDistribution: analytics.zoneDistribution,
                    avgHeartRate: analytics.avgHeartRate,
                    maxHeartRate: analytics.maxHeartRate,
                    minHeartRate: analytics.minHeartRate,
                    userMaxHR: 190 // Could be fetched from user profile
                )
            } else {
                emptyAnalyticsView(
                    icon: "heart.text.square",
                    title: "No Heart Rate Data",
                    message: "Heart rate data requires an Apple Watch or compatible monitor"
                )
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .animation(.spring(response: 0.5).delay(0.2), value: isAnimating)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(limeGreen)
            
            Text("Loading analytics...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Empty Analytics View
    
    private func emptyAnalyticsView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(limeGreen.opacity(0.15))
                    .frame(width: 72, height: 72)
                
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(limeGreen)
            }
            
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.primary)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .padding(.horizontal, 20)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 20)
    }
    
    // MARK: - Load Analytics
    
    private func loadAnalytics() {
        isLoadingAnalytics = true
        
        Task {
            // Convert route coordinates to RouteCoordinate format
            let isoFormatter = ISO8601DateFormatter()
            let routeCoords = activity.routeCoordinates.enumerated().map { index, coord -> RouteCoordinate in
                // Use actual timestamp if available, otherwise estimate based on activity duration
                let timestamp: Date
                if let coordTimestamp = coord.timestamp {
                    timestamp = coordTimestamp
                } else {
                    let progress = Double(index) / Double(max(activity.routeCoordinates.count - 1, 1))
                    timestamp = activity.startTime.addingTimeInterval(activity.duration * progress)
                }
                
                return RouteCoordinate(
                    lat: coord.latitude,
                    lng: coord.longitude,
                    alt: coord.altitude,
                    ts: isoFormatter.string(from: timestamp)
                )
            }
            
            // Generate mock heart rate samples for demo (in production, fetch from HealthKit)
            let heartRateSamples = RunAnalyticsService.generateMockRunHeartRateSamples(
                durationMinutes: Int(activity.duration / 60)
            )
            
            // Calculate analytics
            let calculatedAnalytics = analyticsService.calculateActivityAnalytics(
                coordinates: routeCoords,
                heartRateSamples: heartRateSamples,
                maxHeartRate: 190
            )
            
            await MainActor.run {
                withAnimation {
                    self.analytics = calculatedAnalytics
                    self.isLoadingAnalytics = false
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func shareActivity() {
        guard !isGeneratingShare else { return }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        isGeneratingShare = true
        
        // Generate map snapshot first, then create share image
        Task {
            let mapSnapshot = await generateRouteMapSnapshot()
            
            await MainActor.run {
                // Generate share card image with map
                let shareView = ActivityShareCardView(activity: activity, mapSnapshot: mapSnapshot)
                let renderer = ImageRenderer(content: shareView.frame(width: 400))
                renderer.scale = 3.0
                
                if let image = renderer.uiImage {
                    shareImage = image
                    showShareSheet = true
                }
                
                isGeneratingShare = false
            }
        }
    }
    
    // MARK: - Generate Route Map Snapshot
    
    private func generateRouteMapSnapshot() async -> UIImage? {
        let routeCoordinates = activity.routeCoordinates.map { $0.coordinate }
        
        guard routeCoordinates.count >= 2 else {
            // No route data, return nil
            return nil
        }
        
        let options = MKMapSnapshotter.Options()
        
        // Calculate bounding region for the route using coordinate-based approach
        var minLat = routeCoordinates[0].latitude
        var maxLat = routeCoordinates[0].latitude
        var minLon = routeCoordinates[0].longitude
        var maxLon = routeCoordinates[0].longitude
        
        for coordinate in routeCoordinates {
            minLat = Swift.min(minLat, coordinate.latitude)
            maxLat = Swift.max(maxLat, coordinate.latitude)
            minLon = Swift.min(minLon, coordinate.longitude)
            maxLon = Swift.max(maxLon, coordinate.longitude)
        }
        
        // Calculate center
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        
        // Calculate span with padding (40% extra on each side)
        let latDelta = (maxLat - minLat) * 1.4
        let lonDelta = (maxLon - minLon) * 1.4
        
        // Ensure minimum span for very short routes (~300 meters)
        let minSpan = 0.003
        let span = MKCoordinateSpan(
            latitudeDelta: Swift.max(latDelta, minSpan),
            longitudeDelta: Swift.max(lonDelta, minSpan)
        )
        
        options.region = MKCoordinateRegion(center: center, span: span)
        options.size = CGSize(width: 360, height: 180)
        options.scale = UIScreen.main.scale
        options.mapType = .standard
        options.showsBuildings = true
        options.pointOfInterestFilter = .excludingAll
        
        let snapshotter = MKMapSnapshotter(options: options)
        
        return await withCheckedContinuation { continuation in
            snapshotter.start { snapshot, error in
                guard let snapshot = snapshot, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Draw route on snapshot
                UIGraphicsBeginImageContextWithOptions(snapshot.image.size, true, snapshot.image.scale)
                snapshot.image.draw(at: .zero)
                
                guard let context = UIGraphicsGetCurrentContext() else {
                    let finalImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    continuation.resume(returning: finalImage)
                    return
                }
                
                // Draw route polyline
                let routeColor = UIColor(activity.type.color)
                context.setStrokeColor(routeColor.cgColor)
                context.setLineWidth(4)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                
                var isFirst = true
                for coordinate in routeCoordinates {
                    let point = snapshot.point(for: coordinate)
                    if isFirst {
                        context.move(to: point)
                        isFirst = false
                    } else {
                        context.addLine(to: point)
                    }
                }
                context.strokePath()
                
                // Draw start marker (green)
                if let startCoord = routeCoordinates.first {
                    let startPoint = snapshot.point(for: startCoord)
                    drawRouteMarker(at: startPoint, color: .systemGreen, in: context)
                }
                
                // Draw end marker (red)
                if let endCoord = routeCoordinates.last {
                    let endPoint = snapshot.point(for: endCoord)
                    drawRouteMarker(at: endPoint, color: .systemRed, in: context)
                }
                
                let finalImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                continuation.resume(returning: finalImage)
            }
        }
    }
    
    private func drawRouteMarker(at point: CGPoint, color: UIColor, in context: CGContext) {
        let markerSize: CGFloat = 14
        let rect = CGRect(
            x: point.x - markerSize/2,
            y: point.y - markerSize/2,
            width: markerSize,
            height: markerSize
        )
        
        // Draw filled circle
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: rect)
        
        // Draw white border
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.5)
        context.strokeEllipse(in: rect.insetBy(dx: 1.25, dy: 1.25))
    }
    
    private func deleteActivity() {
        isDeleting = true
        
        Task {
            let success = await viewModel.deleteActivity(activity)
            
            await MainActor.run {
                isDeleting = false
                
                if success {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    // Small delay to show success feedback before dismissing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dismiss()
                    }
                } else {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    
                    // Show error alert if there's an error message
                    if let errorMessage = viewModel.errorMessage {
                        // Error will be shown via the viewModel's errorMessage
                        print("Delete error: \(errorMessage)")
                    }
                }
            }
        }
    }
    
    // MARK: - Map Section
    
    private var mapSection: some View {
        ZStack(alignment: .bottomTrailing) {
            ActivityRouteMapView(routeCoordinates: activity.routeCoordinates)
                .clipShape(RoundedRectangle(cornerRadius: 22))
            
            if selectedTab == .overview {
                Button(action: {}) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(14)
            }
        }
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.spring(response: 0.3), value: selectedTab)
    }
    
    // MARK: - Activity Header
    
    private var activityHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(activity.type.color.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: activity.type.icon)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(activity.type.color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(activity.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(activity.formattedTimeRange)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(activity.formattedDuration)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(limeGreen)
                
                Text("Duration")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 15)
        .animation(.spring(response: 0.5).delay(0.1), value: isAnimating)
    }
    
    // MARK: - Main Stats Grid
    
    private var mainStatsGrid: some View {
        HStack(spacing: 12) {
            ActivityDetailStatCard(
                icon: "figure.walk",
                iconColor: limeGreen,
                value: "\(activity.steps)",
                label: "Steps",
                colorScheme: colorScheme
            )
            
            ActivityDetailStatCard(
                icon: "map.fill",
                iconColor: Color(hex: "5AC8FA"),
                value: activity.formattedDistance,
                label: "Distance",
                colorScheme: colorScheme
            )
            
            ActivityDetailStatCard(
                icon: "flame.fill",
                iconColor: .orange,
                value: "\(activity.calories)",
                label: "Calories",
                colorScheme: colorScheme
            )
        }
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.spring(response: 0.5).delay(0.15), value: isAnimating)
    }
    
    // MARK: - Detailed Metrics Section
    
    private var detailedMetricsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(limeGreen)
                
                Text("Activity Metrics")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 0) {
                DetailedMetricRow(
                    icon: "heart.fill",
                    iconColor: .red,
                    title: "Average Heart Rate",
                    value: "\(activity.averageBPM) BPM"
                )
                
                Divider().padding(.leading, 52)
                
                DetailedMetricRow(
                    icon: "speedometer",
                    iconColor: limeGreen,
                    title: "Average Pace",
                    value: calculatePace()
                )
                
                Divider().padding(.leading, 52)
                
                DetailedMetricRow(
                    icon: "arrow.up.right",
                    iconColor: Color(hex: "5AC8FA"),
                    title: "Elevation Gain",
                    value: "12 m"
                )
                
                Divider().padding(.leading, 52)
                
                DetailedMetricRow(
                    icon: "figure.run",
                    iconColor: .purple,
                    title: "Cadence",
                    value: "\(Int.random(in: 150...180)) spm"
                )
            }
            .padding(16)
            .background(MovementsColors.card(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 25)
        .animation(.spring(response: 0.5).delay(0.2), value: isAnimating)
    }
    
    // MARK: - Time Analysis Section
    
    private var timeAnalysisSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.orange)
                
                Text("Time Analysis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 0) {
                TimeAnalysisRow(title: "Start Time", value: formatTime(activity.startTime))
                Divider().padding(.leading, 16)
                TimeAnalysisRow(title: "End Time", value: formatTime(activity.endTime))
                Divider().padding(.leading, 16)
                TimeAnalysisRow(title: "Active Time", value: activity.formattedDuration)
                Divider().padding(.leading, 16)
                TimeAnalysisRow(title: "Rest Time", value: "0 min")
            }
            .padding(16)
            .background(MovementsColors.card(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 30)
        .animation(.spring(response: 0.5).delay(0.25), value: isAnimating)
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 14) {
            // Share Button
            Button(action: shareActivity) {
                HStack(spacing: 10) {
                    if isGeneratingShare {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.black)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .bold))
                    }
                    
                    Text(isGeneratingShare ? "Generating..." : "Share Activity")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(limeGreen)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isGeneratingShare)
            
            // Delete Button
            Button(action: {
                showDeleteAlert = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .bold))
                    
                    Text("Delete Activity")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 35)
        .animation(.spring(response: 0.5).delay(0.3), value: isAnimating)
    }
    
    // MARK: - Helper Methods
    
    private func calculatePace() -> String {
        guard activity.distance > 0 else { return "--:--" }
        let minutesPerKm = activity.duration / 60.0 / activity.distance
        let mins = Int(minutesPerKm)
        let secs = Int((minutesPerKm - Double(mins)) * 60)
        return String(format: "%d:%02d /km", mins, secs)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Activity Detail Stat Card

struct ActivityDetailStatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(iconColor)
            }
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Detailed Metric Row

struct DetailedMetricRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Time Analysis Row

struct TimeAnalysisRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let tab: ActivityDetailTab
    let isSelected: Bool
    let action: () -> Void
    let colorScheme: ColorScheme
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .bold))
                
                Text(tab.rawValue)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(isSelected ? .black : .primary.opacity(0.6))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(isSelected ? limeGreen : MovementsColors.card(for: colorScheme))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ActivityDetailView(activity: MockRunActivityData.generateMockActivities()[0])
    }
}

// MARK: - Activity Share Card View

struct ActivityShareCardView: View {
    let activity: RouteActivity
    var mapSnapshot: UIImage? = nil
    
    private let limeGreen = MovementsColors.limeGreen
    private let darkGreen = MovementsColors.darkGreen
    
    var body: some View {
        VStack(spacing: 0) {
            if let mapImage = mapSnapshot {
                ZStack(alignment: .topLeading) {
                    Image(uiImage: mapImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                    
                    VStack {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: activity.type.icon)
                                    .font(.system(size: 14, weight: .bold))
                                Text(activity.type.rawValue)
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(limeGreen)
                            .clipShape(Capsule())
                            
                            Spacer()
                            
                            HStack(spacing: 5) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 11))
                                Text("SwasthiCare")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                        }
                        .padding(18)
                        
                        Spacer()
                    }
                }
                .frame(height: 200)
            } else {
                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        gradient: Gradient(colors: [darkGreen, limeGreen]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 160)
                    
                    GeometryReader { geo in
                        Path { path in
                            let width = geo.size.width
                            let height = geo.size.height
                            path.move(to: CGPoint(x: width * 0.65, y: 0))
                            path.addLine(to: CGPoint(x: width, y: 0))
                            path.addLine(to: CGPoint(x: width, y: height * 0.7))
                            path.closeSubpath()
                        }
                        .fill(Color.white.opacity(0.15))
                    }
                    .frame(height: 160)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: activity.type.icon)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            HStack(spacing: 5) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 12))
                                Text("SwasthiCare")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.black.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Text(activity.name)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text(formattedDate)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black.opacity(0.7))
                    }
                    .padding(22)
                }
                .frame(height: 160)
            }
            
            VStack(spacing: 18) {
                if mapSnapshot != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(activity.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(formattedDate)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                }
                
                VStack(spacing: 6) {
                    Text(activity.formattedDistance)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(limeGreen)
                    
                    Text("DISTANCE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(2)
                }
                .padding(.top, mapSnapshot != nil ? 10 : 22)
                
                HStack(spacing: 0) {
                    ShareStatItem(
                        icon: "clock.fill",
                        value: activity.formattedDuration,
                        label: "Duration"
                    )
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1, height: 55)
                    
                    ShareStatItem(
                        icon: "figure.walk",
                        value: "\(activity.steps)",
                        label: "Steps"
                    )
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1, height: 55)
                    
                    ShareStatItem(
                        icon: "flame.fill",
                        value: "\(activity.calories)",
                        label: "Calories"
                    )
                }
                .padding(.horizontal, 18)
                
                HStack(spacing: 28) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.red)
                        
                        Text("\(activity.averageBPM) BPM")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 15))
                            .foregroundColor(limeGreen)
                        
                        Text(calculatePace())
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            .background(Color(UIColor.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 12)
        .padding(22)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy • h:mm a"
        return formatter.string(from: activity.startTime)
    }
    
    private func calculatePace() -> String {
        guard activity.distance > 0 else { return "--:--" }
        let minutesPerKm = activity.duration / 60.0 / activity.distance
        let mins = Int(minutesPerKm)
        let secs = Int((minutesPerKm - Double(mins)) * 60)
        return String(format: "%d:%02d /km", mins, secs)
    }
}

// MARK: - Share Stat Item

struct ShareStatItem: View {
    let icon: String
    let value: String
    let label: String
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(limeGreen)
            
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Activity Share Sheet

struct ActivityShareSheet: View {
    let image: UIImage
    let activity: RouteActivity
    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedToast = false
    @State private var showSavedToast = false
    
    private let limeGreen = MovementsColors.limeGreen
    private let darkGreen = MovementsColors.darkGreen
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 26) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.15), radius: 14, x: 0, y: 8)
                        .padding(.top, 22)
                    
                    Text("Share your achievement!")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 14) {
                        Button(action: shareToSocial) {
                            HStack(spacing: 14) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18, weight: .bold))
                                
                                Text("Share to...")
                                    .font(.system(size: 16, weight: .bold))
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black.opacity(0.5))
                            }
                            .foregroundColor(.black)
                            .padding(18)
                            .background(limeGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                        
                        Button(action: saveToPhotos) {
                            HStack(spacing: 14) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(limeGreen)
                                
                                Text("Save to Photos")
                                    .font(.system(size: 16, weight: .bold))
                                
                                Spacer()
                                
                                if showSavedToast {
                                    HStack(spacing: 5) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 15))
                                        Text("Saved!")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    .foregroundColor(limeGreen)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(limeGreen)
                                }
                            }
                            .foregroundColor(.primary)
                            .padding(18)
                            .background(limeGreen.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                        
                        Button(action: copyStats) {
                            HStack(spacing: 14) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 18, weight: .bold))
                                
                                Text("Copy Stats")
                                    .font(.system(size: 16, weight: .bold))
                                
                                Spacer()
                                
                                if showCopiedToast {
                                    HStack(spacing: 5) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 15))
                                        Text("Copied!")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    .foregroundColor(limeGreen)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .foregroundColor(.primary)
                            .padding(18)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                    }
                    .padding(.horizontal, 22)
                    
                    Spacer()
                }
                
                if showSavedToast {
                    VStack {
                        Spacer()
                        
                        HStack(spacing: 14) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.black)
                            
                            Text("Saved to Photos")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 26)
                        .padding(.vertical, 18)
                        .background(limeGreen)
                        .clipShape(Capsule())
                        .shadow(color: limeGreen.opacity(0.5), radius: 14, x: 0, y: 6)
                        .padding(.bottom, 44)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Share Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(limeGreen)
                }
            }
        }
    }
    
    private func shareToSocial() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        let text = generateShareText()
        let activityVC = UIActivityViewController(
            activityItems: [image, text],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presentedVC = topVC.presentedViewController {
                topVC = presentedVC
            }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            topVC.present(activityVC, animated: true)
        }
    }
    
    private func saveToPhotos() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        let notificationGenerator = UINotificationFeedbackGenerator()
        notificationGenerator.notificationOccurred(.success)
        
        withAnimation(.spring(response: 0.4)) {
            showSavedToast = true
        }
        
        // Auto dismiss after showing toast
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
    
    private func copyStats() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        let text = generateShareText()
        UIPasteboard.general.string = text
        
        withAnimation(.spring(response: 0.3)) {
            showCopiedToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedToast = false
            }
        }
    }
    
    private func generateShareText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        let dateStr = formatter.string(from: activity.startTime)
        
        return """
        🏃 \(activity.name)
        📅 \(dateStr)
        📏 Distance: \(activity.formattedDistance)
        ⏱️ Duration: \(activity.formattedDuration)
        👣 Steps: \(activity.steps)
        🔥 Calories: \(activity.calories)
        ❤️ Avg Heart Rate: \(activity.averageBPM) BPM
        
        Tracked with SwastricCare 💚
        """
    }
}
