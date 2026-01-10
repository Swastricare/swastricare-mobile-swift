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
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Camera preview with overlay
                cameraPreviewSection
                
                // BPM display
                bpmDisplayView
                
                // Signal quality indicator
                signalQualityView
                
                // Progress bar (when measuring)
                if viewModel.isRunning {
                    progressView
                }
                
                Spacer()
                
                // Action buttons
                actionButtons
                    .padding(.bottom, 40)
            }
            .padding()
        }
        .navigationTitle("Measure Heart Rate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") {
                    viewModel.stopMeasurement()
                    dismiss()
                }
            }
        }
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
    
    private var cameraPreviewSection: some View {
        ZStack {
            // Camera preview
            if let session = viewModel.captureSession {
                CameraPreviewView(session: session)
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.red.opacity(0.5), lineWidth: 3)
                    )
                    .shadow(color: .red.opacity(0.3), radius: 10)
            } else {
                // Placeholder when camera not active
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text(viewModel.instructionText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    )
            }
            
            // Overlay: Finger placement guide
            if viewModel.isRunning {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "hand.point.up.fill")
                            .foregroundColor(.white)
                        Text("Keep finger on lens")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .padding(.bottom, 8)
                }
                .frame(width: 200, height: 200)
            }
        }
    }
    
    private var heartPulseView: some View {
        ZStack {
            // Outer pulse circle
            Circle()
                .fill(Color.red.opacity(0.2))
                .frame(width: 160, height: 160)
                .scaleEffect(pulseScale)
                .animation(pulseAnimation, value: viewModel.bpm)
            
            // Inner circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.red.opacity(0.3), Color.red.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 140)
            
            // Heart icon
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
                .scaleEffect(heartScale)
                .animation(heartAnimation, value: viewModel.bpm)
        }
    }
    
    private var pulseScale: CGFloat {
        viewModel.isRunning && viewModel.bpm > 0 ? 1.15 : 1.0
    }
    
    private var heartScale: CGFloat {
        viewModel.isRunning && viewModel.bpm > 0 ? 1.1 : 1.0
    }
    
    private var pulseAnimation: Animation? {
        guard viewModel.isRunning && viewModel.bpm > 0 else { return .default }
        let duration = 60.0 / Double(viewModel.bpm)
        return .easeInOut(duration: duration * 0.5).repeatForever(autoreverses: true)
    }
    
    private var heartAnimation: Animation? {
        guard viewModel.isRunning && viewModel.bpm > 0 else { return .default }
        let duration = 60.0 / Double(viewModel.bpm)
        return .easeInOut(duration: duration * 0.3).repeatForever(autoreverses: true)
    }
    
    private var bpmDisplayView: some View {
        VStack(spacing: 4) {
            Text(viewModel.bpm > 0 ? "\(viewModel.bpm)" : "--")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundColor(.red)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: viewModel.bpm)
            
            Text("BPM")
                .font(.title2.weight(.medium))
                .foregroundColor(.secondary)
        }
    }
    
    private var signalQualityView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(signalQualityColor)
                .frame(width: 10, height: 10)
            
            Text(viewModel.signalQuality.description)
                .font(.subheadline)
                .foregroundColor(signalQualityColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(signalQualityColor.opacity(0.1))
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
    
    private var progressView: some View {
        VStack(spacing: 8) {
            ProgressView(value: viewModel.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .red))
                .scaleEffect(y: 1.5)
            
            Text("\(Int(viewModel.progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 40)
    }
    
    private var actionButtons: some View {
        Button(action: {
            if viewModel.isRunning {
                viewModel.stopMeasurement()
            } else {
                viewModel.startMeasurement()
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: viewModel.isRunning ? "stop.fill" : "play.fill")
                Text(viewModel.isRunning ? "Stop" : "Start Measurement")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(width: 220, height: 50)
            .background(viewModel.isRunning ? Color.gray : Color.red)
            .cornerRadius(25)
            .shadow(color: (viewModel.isRunning ? Color.gray : Color.red).opacity(0.3), radius: 10, x: 0, y: 5)
        }
    }
}

// MARK: - Result Sheet View

private struct ResultSheetView: View {
    @ObservedObject var viewModel: HeartRateViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Success icon
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                            .padding(.top, 20)
                        
                        Text("Measurement Complete")
                            .font(.title2.bold())
                        
                        // Result card
                        resultCard
                        
                        // Confidence info
                        confidenceCard
                        
                        // Category info
                        if let category = viewModel.bpmCategory {
                            categoryCard(category)
                        }
                        
                        // Save status
                        if viewModel.saveSuccess {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Saved successfully!")
                            }
                            .font(.subheadline)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(10)
                        }
                        
                        if let error = viewModel.saveError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(error)
                            }
                            .font(.subheadline)
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(10)
                        }
                        
                        Spacer(minLength: 20)
                        
                        // Action buttons
                        actionButtons
                    }
                    .padding()
                }
            }
            .navigationTitle("Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.dismissResult()
                    }
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving)
    }
    
    private var resultCard: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("Heart Rate")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
            
            Text("\(viewModel.finalBPM ?? 0)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(.red)
            
            Text("BPM")
                .font(.title3.weight(.medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private var confidenceCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Measurement Confidence")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(viewModel.confidenceDescription)
                    .font(.headline)
            }
            
            Spacer()
            
            Text("\(Int(viewModel.confidence * 100))%")
                .font(.title2.bold())
                .foregroundColor(confidenceColor)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var confidenceColor: Color {
        switch viewModel.confidenceLevel {
        case .veryHigh, .high: return .green
        case .moderate: return .orange
        case .low, .veryLow: return .red
        }
    }
    
    private func categoryCard(_ category: BPMCategory) -> some View {
        HStack {
            Text(category.emoji)
                .font(.title)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Category")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(category.description)
                    .font(.headline)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Save button
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
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text(viewModel.isSaving ? "Saving..." : "Save Reading")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(viewModel.canSave ? Color.red : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!viewModel.canSave || viewModel.saveSuccess)
            
            // Discard button
            Button(action: {
                viewModel.dismissResult()
            }) {
                Text("Discard")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
            }
            .disabled(viewModel.isSaving)
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
                VStack(alignment: .leading, spacing: 20) {
                    // Warning icon
                    HStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding(.top, 20)
                    
                    Text("Medical Disclaimer")
                        .font(.title.bold())
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        disclaimerItem(
                            icon: "info.circle",
                            title: "For Wellness Only",
                            text: "This heart rate measurement feature is for informational and wellness purposes only."
                        )
                        
                        disclaimerItem(
                            icon: "cross.case",
                            title: "Not Medical Advice",
                            text: "It is not intended to diagnose, treat, cure, or prevent any disease or health condition."
                        )
                        
                        disclaimerItem(
                            icon: "iphone",
                            title: "Results May Vary",
                            text: "Results may vary based on device, lighting, skin tone, and measurement technique."
                        )
                        
                        disclaimerItem(
                            icon: "stethoscope",
                            title: "Consult Professionals",
                            text: "For accurate medical readings, please use a certified medical device and consult with a healthcare professional."
                        )
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(16)
                    
                    // Tips for accurate measurement
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tips for Best Results")
                            .font(.headline)
                        
                        tipItem("Place fingertip firmly on the camera lens")
                        tipItem("Stay still during measurement")
                        tipItem("Ensure good lighting")
                        tipItem("Wait for signal quality to improve")
                        tipItem("Measure at rest for accurate results")
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    
                    Spacer(minLength: 20)
                    
                    // Accept button
                    Button(action: onAccept) {
                        Text("I Understand")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                    .padding(.bottom, 20)
                }
                .padding()
            }
            .navigationTitle("Important Information")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }
    
    private func disclaimerItem(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func tipItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.subheadline)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HeartRateView()
    }
}
