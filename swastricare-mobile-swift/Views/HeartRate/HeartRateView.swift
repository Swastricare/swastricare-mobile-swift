//
//  HeartRateView.swift
//  swastricare-mobile-swift
//
//  SwiftUI view for camera-based heart rate measurement
//

import SwiftUI

struct HeartRateView: View {
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel = HeartRateViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            // Subtle gradient background
            RadialGradient(
                gradient: Gradient(colors: [Color.red.opacity(0.1), Color.clear]),
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                Spacer()
                
                // Main Measurement Area
                ZStack {
                    // Pulsing Rings
                    if viewModel.isRunning {
                        pulsingRings
                    }
                    
                    // Camera Preview with Progress Ring
                    cameraSection
                }
                .frame(height: 320)
                
                // BPM Display & Waveform
                VStack(spacing: 20) {
                    // BPM
                    bpmDisplayView
                    
                    // Waveform
                    HeartRateWaveformView(isRunning: viewModel.isRunning, bpm: viewModel.bpm)
                        .frame(height: 120) // Increased height for better detail
                        .padding(.horizontal)
                    
                    // Status/Instructions
                    statusView
                }
                
                Spacer()
                
                // Action Buttons
                actionButtons
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
            }
        }
        .navigationBarHidden(true)
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.dismissResult()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $viewModel.showResult) {
            ResultSheetView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showDisclaimer) {
            DisclaimerSheetView(onAccept: viewModel.acceptDisclaimer)
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Button(action: {
                viewModel.stopMeasurement()
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("Heart Rate")
                .font(.headline)
            
            Spacer()
            
            // Placeholder for balance
            Image(systemName: "heart.fill")
                .font(.title2)
                .foregroundColor(.red)
                .opacity(0)
        }
    }
    
    private var cameraSection: some View {
        ZStack {
            // Camera Preview Circle
            Group {
                if let session = viewModel.captureSession {
                    CameraPreviewView(session: session)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 180, height: 180)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 180, height: 180)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                        )
                }
            }
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            // Finger Placement Guide Overlay
            if viewModel.isRunning && viewModel.signalQuality == .poor {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 180, height: 180)
                    
                    VStack(spacing: 8) {
                        Image(systemName: "hand.point.up.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                        Text("Cover Camera")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Progress Ring
            if viewModel.isRunning {
                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.progress))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.red.opacity(0.5), .red]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 210, height: 210)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: viewModel.progress)
            }
            
            // Static Ring
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                .frame(width: 210, height: 210)
        }
    }
    
    private var pulsingRings: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Color.red.opacity(0.3 - Double(i) * 0.1), lineWidth: 2)
                    .frame(width: 210 + CGFloat(i * 30), height: 210 + CGFloat(i * 30))
                    .scaleEffect(viewModel.bpm > 0 ? 1.2 : 1.0)
                    .opacity(viewModel.bpm > 0 ? 0 : 1)
                    .animation(
                        Animation.easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.4),
                        value: viewModel.bpm
                    )
            }
        }
    }
    
    private var bpmDisplayView: some View {
        VStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(viewModel.bpm > 0 ? "\(viewModel.bpm)" : "--")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                
                Text("BPM")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 12)
            }
            .scaleEffect(viewModel.bpm > 0 ? 1.05 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: viewModel.bpm)
        }
    }
    
    private var statusView: some View {
        HStack(spacing: 12) {
            if viewModel.isRunning {
                Circle()
                    .fill(signalQualityColor)
                    .frame(width: 8, height: 8)
                
                Text(viewModel.signalQuality.description)
                    .font(.subheadline)
                    .foregroundColor(signalQualityColor)
                    .transition(.opacity)
            } else {
                Text(viewModel.instructionText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.1))
        )
        .animation(.easeInOut, value: viewModel.signalQuality)
    }
    
    private var signalQualityColor: Color {
        switch viewModel.signalQuality {
        case .poor: return .red
        case .fair: return .orange
        case .good, .excellent: return .green
        }
    }
    
    private var actionButtons: some View {
        Button(action: {
            if viewModel.isRunning {
                viewModel.stopMeasurement()
            } else {
                viewModel.startMeasurement()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: viewModel.isRunning ? "stop.fill" : "heart.fill")
                Text(viewModel.isRunning ? "Stop" : "Start Measurement")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: viewModel.isRunning ? [.gray, .gray.opacity(0.8)] : [.red, .orange],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(28)
            .shadow(color: (viewModel.isRunning ? Color.gray : Color.red).opacity(0.4), radius: 10, x: 0, y: 5)
        }
    }
}

// MARK: - Result Sheet View

private struct ResultSheetView: View {
    @ObservedObject var viewModel: HeartRateViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // Animation states
    @State private var animateContent = false
    @State private var animateChart = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Tech-rich dark background or system background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 1. Hero Result Section
                        heroResultSection
                            .scaleEffect(animateContent ? 1 : 0.9)
                            .opacity(animateContent ? 1 : 0)
                        
                        // 2. Health Context Bar
                        healthZoneBar
                            .offset(y: animateContent ? 0 : 20)
                            .opacity(animateContent ? 1 : 0)
                        
                        // 3. Detailed Stats Grid
                        statsGrid
                            .offset(y: animateContent ? 0 : 30)
                            .opacity(animateContent ? 1 : 0)
                        
                        // 4. Trend Chart (Tech Feature)
                        if !viewModel.bpmReadings.isEmpty {
                            trendChartSection
                                .offset(y: animateContent ? 0 : 40)
                                .opacity(animateContent ? 1 : 0)
                        }
                        
                        // 5. Save Status / Error
                        statusMessages
                            .offset(y: animateContent ? 0 : 50)
                            .opacity(animateContent ? 1 : 0)
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
                
                // Floating Action Bar at bottom
                VStack {
                    Spacer()
                    actionButtons
                        .padding()
                        .background(
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .bottom, endPoint: .top))
                                .ignoresSafeArea()
                        )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text(Date(), format: .dateTime.day().month().year())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.dismissResult()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animateContent = true
            }
            withAnimation(.easeInOut(duration: 1.0).delay(0.3)) {
                animateChart = true
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving)
    }
    
    // MARK: - Components
    
    private var heroResultSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // Decorative pulsing rings behind
                ForEach(0..<2) { i in
                    Circle()
                        .stroke(Color.red.opacity(0.1), lineWidth: 1)
                        .frame(width: 140 + CGFloat(i * 30), height: 140 + CGFloat(i * 30))
                }
                
                // Main Heart Icon with shadow
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.15), Color.red.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "heart.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(
                                .linearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: .red.opacity(0.4), radius: 10, x: 0, y: 5)
                    )
            }
            
            VStack(spacing: 4) {
                Text("\(viewModel.finalBPM ?? 0)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("BPM")
                    .font(.title3.weight(.medium))
                    .foregroundColor(.secondary)
                    .tracking(2)
            }
            
            if let category = viewModel.bpmCategory {
                Text(category.description)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(categoryColor(category))
                            .shadow(color: categoryColor(category).opacity(0.4), radius: 8, y: 4)
                    )
            }
        }
        .padding(.top, 20)
    }
    
    private var healthZoneBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Health Zone")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background Track
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 12)
                    
                    // Zones (Simplified visual representation)
                    HStack(spacing: 2) {
                        Rectangle().fill(Color.blue.opacity(0.3)).frame(width: geo.size.width * 0.3)
                        Rectangle().fill(Color.green.opacity(0.3)).frame(width: geo.size.width * 0.4)
                        Rectangle().fill(Color.orange.opacity(0.3)).frame(width: geo.size.width * 0.15)
                        Rectangle().fill(Color.red.opacity(0.3)).frame(width: geo.size.width * 0.15)
                    }
                    .mask(Capsule())
                    
                    // Indicator
                    if let bpm = viewModel.finalBPM {
                        let normalized = min(max(Double(bpm - 40) / 140.0, 0), 1) // Map 40-180 to 0-1
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                            .shadow(color: .black.opacity(0.2), radius: 2)
                            .overlay(Circle().stroke(Color.primary, lineWidth: 2))
                            .offset(x: (geo.size.width - 20) * normalized)
                    }
                }
            }
            .frame(height: 12)
            
            HStack {
                Text("Resting")
                Spacer()
                Text("Normal")
                Spacer()
                Text("High")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
    }
    
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            // Confidence Card
            techStatCard(
                title: "Confidence",
                value: "\(Int(viewModel.confidence * 100))%",
                icon: "checkmark.shield.fill",
                color: confidenceColor
            )
            
            // Error Margin Card
            techStatCard(
                title: "Precision",
                value: viewModel.errorBoundsText,
                icon: "scope",
                color: .blue
            )
            
            // Time Card
            techStatCard(
                title: "Time",
                value: Date().formatted(date: .omitted, time: .shortened),
                icon: "clock.fill",
                color: .purple
            )
            
            // Device Card
            techStatCard(
                title: "Source",
                value: "Camera PPG",
                icon: "camera.macro",
                color: .gray
            )
        }
    }
    
    private func techStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.headline)
                        .minimumScaleFactor(0.8)
                    Text(title)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.red)
                Text("Measurement Trend")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
            }
            .padding(.leading, 4)
            
            ChartPathView(readings: viewModel.bpmReadings, animate: animateChart)
                .frame(height: 80)
                .background(Color.clear)
                .padding(.vertical, 8)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
    }
    
    private var statusMessages: some View {
        VStack(spacing: 12) {
            if viewModel.saveSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Reading saved successfully")
                }
                .font(.subheadline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(16)
            }
            
            if let error = viewModel.saveError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                }
                .font(.subheadline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.1))
                .cornerRadius(16)
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: {
                viewModel.dismissResult()
            }) {
                Text("Discard")
                    .font(.headline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(28)
            }
            .disabled(viewModel.isSaving)
            
            Button(action: {
                Task {
                    await viewModel.saveReading()
                }
            }) {
                HStack {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(viewModel.saveSuccess ? "Done" : "Save")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(viewModel.saveSuccess ? Color.green : Color.red)
                .cornerRadius(28)
                .shadow(color: (viewModel.saveSuccess ? Color.green : Color.red).opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(!viewModel.canSave || viewModel.saveSuccess)
        }
        .padding(.bottom, 10)
    }
    
    // Helpers
    
    private var confidenceColor: Color {
        switch viewModel.confidenceLevel {
        case .veryHigh, .high: return .green
        case .moderate: return .orange
        case .low, .veryLow: return .red
        }
    }
    
    private func categoryColor(_ category: BPMCategory) -> Color {
        switch category {
        case .low, .athlete: return .blue
        case .normal: return .green
        case .elevated: return .orange
        case .high: return .red
        }
    }
}

// Simple chart path view
private struct ChartPathView: View {
    let readings: [Int]
    let animate: Bool
    
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            
            if readings.count > 1 {
                let minVal = Double(readings.min() ?? 0)
                let maxVal = Double(readings.max() ?? 100)
                let range = max(maxVal - minVal, 1)
                
                Path { path in
                    for (index, bpm) in readings.enumerated() {
                        let x = width * Double(index) / Double(readings.count - 1)
                        let normalizedY = (Double(bpm) - minVal) / range
                        let y = height * (1.0 - normalizedY)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .trim(from: 0, to: animate ? 1 : 0)
                .stroke(
                    LinearGradient(
                        colors: [.red.opacity(0.5), .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}

// MARK: - Disclaimer Sheet View

private struct DisclaimerSheetView: View {
    let onAccept: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Image
                    HStack {
                        Spacer()
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.top, 20)
                    
                    VStack(spacing: 8) {
                        Text("Important Notice")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        
                        Text("Please read carefully before proceeding")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Disclaimer Cards
                    VStack(spacing: 16) {
                        disclaimerCard(
                            icon: "info.circle.fill",
                            title: "Wellness Only",
                            text: "This feature is for informational purposes only and is not a medical device.",
                            color: .blue
                        )
                        
                        disclaimerCard(
                            icon: "exclamationmark.triangle.fill",
                            title: "Not Medical Advice",
                            text: "Do not use this for diagnosis or treatment. Always consult a healthcare professional.",
                            color: .orange
                        )
                    }
                    
                    // Best Practices
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How to Measure")
                            .font(.headline)
                            .padding(.leading, 4)
                        
                        VStack(spacing: 0) {
                            instructionRow(step: "1", text: "Place finger gently on the back camera.")
                            Divider()
                            instructionRow(step: "2", text: "Ensure the camera and flash are covered.")
                            Divider()
                            instructionRow(step: "3", text: "Stay still and silent during measurement.")
                        }
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                    }
                    
                    Spacer(minLength: 20)
                    
                    Button(action: onAccept) {
                        Text("I Understand & Agree")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.red)
                            .cornerRadius(28)
                    }
                    .padding(.bottom, 20)
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .interactiveDismissDisabled()
    }
    
    private func disclaimerCard(icon: String, title: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private func instructionRow(step: String, text: String) -> some View {
        HStack(spacing: 16) {
            Text(step)
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.secondary))
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    HeartRateView()
}
