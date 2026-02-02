//
//  HeartRateResultView.swift
//  swastricare-mobile-swift
//
//  Result sheet displayed after heart rate measurement completes
//

import SwiftUI

struct HeartRateResultView: View {
    @ObservedObject var viewModel: HeartRateViewModel
    @State private var animateContent = false
    @State private var animateChart = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        heroSection
                            .scaleEffect(animateContent ? 1 : 0.9)
                            .opacity(animateContent ? 1 : 0)
                        
                        healthZoneBar
                            .offset(y: animateContent ? 0 : 20)
                            .opacity(animateContent ? 1 : 0)
                        
                        statsGrid
                            .offset(y: animateContent ? 0 : 30)
                            .opacity(animateContent ? 1 : 0)
                        
                        if !viewModel.bpmReadings.isEmpty {
                            trendChart
                                .offset(y: animateContent ? 0 : 40)
                                .opacity(animateContent ? 1 : 0)
                        }
                        
                        statusMessages
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                
                // Bottom buttons
                VStack {
                    Spacer()
                    actionButtons
                        .padding()
                        .background(
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .mask(
                                    LinearGradient(
                                        colors: [.black, .black, .clear],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
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
                    Button { viewModel.dismissResult() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Close")
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
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: 12) {
            ZStack {
                ForEach(0..<2, id: \.self) { i in
                    Circle()
                        .stroke(Color.red.opacity(0.1), lineWidth: 1)
                        .frame(width: 120 + CGFloat(i * 24), height: 120 + CGFloat(i * 24))
                }
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.15), Color.red.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "heart.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(
                                .linearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: .red.opacity(0.4), radius: 8, x: 0, y: 4)
                    )
            }
            
            VStack(spacing: 2) {
                Text("\(viewModel.finalBPM ?? 0)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .accessibilityLabel("\(viewModel.finalBPM ?? 0) beats per minute")
                
                Text("BPM")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                    .tracking(2)
            }
            
            if let category = viewModel.bpmCategory {
                Text(category.description)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(categoryColor(category))
                            .shadow(color: categoryColor(category).opacity(0.3), radius: 6, y: 3)
                    )
                    .accessibilityLabel("Category: \(category.description)")
            }
        }
        .padding(.top, 12)
    }
    
    // MARK: - Health Zone Bar
    
    private var healthZoneBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Health Zone")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundColor(.secondary)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    HStack(spacing: 2) {
                        Rectangle().fill(Color.blue.opacity(0.3))
                        Rectangle().fill(Color.green.opacity(0.3))
                        Rectangle().fill(Color.orange.opacity(0.3))
                        Rectangle().fill(Color.red.opacity(0.3))
                    }
                    .frame(height: 10)
                    .mask(Capsule())
                    
                    if let bpm = viewModel.finalBPM {
                        let normalized = min(max(Double(bpm - 40) / 140.0, 0), 1)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 18, height: 18)
                            .shadow(color: .black.opacity(0.15), radius: 2)
                            .overlay(Circle().stroke(Color.primary, lineWidth: 2))
                            .offset(x: (geo.size.width - 18) * normalized)
                    }
                }
            }
            .frame(height: 18)
            .accessibilityHidden(true)
            
            HStack {
                Text("Resting").font(.caption2.weight(.medium))
                Spacer()
                Text("Normal").font(.caption2.weight(.medium))
                Spacer()
                Text("High").font(.caption2.weight(.medium))
            }
            .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            statCard(
                title: "Confidence",
                value: "\(Int(viewModel.confidence * 100))%",
                icon: "checkmark.shield.fill",
                color: confidenceColor
            )
            statCard(
                title: "Precision",
                value: viewModel.errorBoundsText,
                icon: "scope",
                color: .blue
            )
            statCard(
                title: "Time",
                value: Date().formatted(date: .omitted, time: .shortened),
                icon: "clock.fill",
                color: .purple
            )
            statCard(
                title: "Source",
                value: "Camera",
                icon: "camera.fill",
                color: .gray
            )
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
            
            Text(value)
                .font(.subheadline.weight(.semibold))
            
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
    
    // MARK: - Trend Chart
    
    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.body)
                    .foregroundColor(.red)
                Text("Measurement Trend")
                    .font(.subheadline.weight(.semibold))
            }
            
            HeartRateChartView(readings: viewModel.bpmReadings, animate: animateChart)
                .frame(height: 72)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .accessibilityLabel("Heart rate trend chart showing \(viewModel.bpmReadings.count) readings")
    }
    
    // MARK: - Status Messages
    
    private var statusMessages: some View {
        VStack(spacing: 10) {
            if viewModel.saveSuccess {
                Label("Reading saved successfully", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.green)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
            }
            
            if let error = viewModel.saveError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.red)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.dismissResult() }) {
                Text("Discard")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(25)
            }
            .disabled(viewModel.isSaving)
            .accessibilityLabel("Discard reading")
            
            Button(action: { Task { await viewModel.saveReading() } }) {
                HStack(spacing: 8) {
                    if viewModel.isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text(viewModel.saveSuccess ? "Done" : "Save")
                    }
                }
                .font(.body.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(viewModel.saveSuccess ? Color.green : Color.red)
                .cornerRadius(25)
                .shadow(color: (viewModel.saveSuccess ? Color.green : Color.red).opacity(0.25), radius: 6, y: 3)
            }
            .disabled(!viewModel.canSave || viewModel.saveSuccess)
            .accessibilityLabel(viewModel.saveSuccess ? "Done" : "Save reading")
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helpers
    
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

// MARK: - Chart View

struct HeartRateChartView: View {
    let readings: [Int]
    let animate: Bool
    
    var body: some View {
        GeometryReader { proxy in
            if readings.count > 1 {
                let minVal = Double(readings.min() ?? 0)
                let maxVal = Double(readings.max() ?? 100)
                let range = max(maxVal - minVal, 1)
                
                Path { path in
                    for (index, bpm) in readings.enumerated() {
                        let x = proxy.size.width * Double(index) / Double(readings.count - 1)
                        let normalizedY = (Double(bpm) - minVal) / range
                        let y = proxy.size.height * (1.0 - normalizedY)
                        
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
