//
//  HeartRateView.swift
//  swastricare-mobile-swift
//
//  Main view for camera-based heart rate measurement
//

import SwiftUI

struct HeartRateView: View {
    
    @StateObject private var viewModel = HeartRateViewModel()
    @Environment(\.dismiss) private var dismiss
    
    // Animation states
    @State private var showContent = false
    @State private var heartbeatScale: CGFloat = 1.0
    @State private var borderPulse = false
    @State private var showError = false
    @State private var showAnalytics = false
    
    // Measurement duration constant
    private let measurementDuration: TimeInterval = 30.0
    
    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                Spacer(minLength: 16)
                
                // Main Measurement Area
                measurementArea
                    .padding(.horizontal, 20)
                
                Spacer(minLength: 24)
                
                // BPM & Waveform Section
                bpmSection
                    .padding(.horizontal, 20)
                
                Spacer(minLength: 16)
                
                // Bottom Action
                actionSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 34)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                showContent = true
            }
        }
        // Fixed alert binding
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                viewModel.dismissResult()
                showError = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showError = newValue != nil
        }
        // Heartbeat pulse animation
        .onChange(of: viewModel.bpm) { _, newBPM in
            if newBPM > 0 {
                triggerHeartbeatPulse()
                HapticManager.selection()
            }
        }
        // Border pulse when signal is good
        .onChange(of: viewModel.signalQuality) { _, newQuality in
            if newQuality == .good || newQuality == .excellent {
                withAnimation(.easeInOut(duration: 0.3)) {
                    borderPulse.toggle()
                }
            }
        }
        .sheet(isPresented: $viewModel.showResult) {
            HeartRateResultView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showDisclaimer) {
            HeartRateDisclaimerView(onAccept: viewModel.acceptDisclaimer)
        }
        .sheet(isPresented: $showAnalytics) {
            NavigationStack {
                HeartRateAnalyticsView()
            }
        }
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            // Animated gradient when running
            if viewModel.isRunning {
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.red.opacity(0.15),
                        Color.red.opacity(0.05),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 100,
                    endRadius: 400
                )
                .ignoresSafeArea()
                .transition(.opacity)
                .animation(.easeInOut(duration: 1.0), value: viewModel.isRunning)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        ZStack {
            // Center title
            VStack(spacing: 2) {
                Text("Heart Rate")
                    .font(.headline)
                if viewModel.isRunning {
                    Text(phaseDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: viewModel.isRunning)
            
            // Left and right buttons
            HStack {
                Button(action: {
                    HapticManager.impact(.light)
                    viewModel.stopMeasurement()
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 40)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Go back")
                
                Spacer()
                
                HStack(spacing: 10) {
                    Button(action: {
                        HapticManager.impact(.light)
                        showAnalytics = true
                    }) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(width: 40, height: 40)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Show heart rate analytics and history")
                    
                    // Info button
                    Button(action: {
                        HapticManager.impact(.light)
                        viewModel.showDisclaimer = true
                    }) {
                        Image(systemName: "info.circle")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(width: 40, height: 40)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Show measurement instructions")
                }
            }
        }
        .frame(height: 44)
    }
    
    private var phaseDescription: String {
        if viewModel.progress < 0.1 {
            return "Preparing..."
        } else if viewModel.progress < 0.2 {
            return "Calibrating..."
        } else if viewModel.progress > 0.9 {
            return "Almost done..."
        } else {
            return "Measuring..."
        }
    }
    
    // MARK: - Measurement Area
    
    private var measurementArea: some View {
        ZStack {
            // Pulsing rings animation
            if viewModel.isRunning {
                PulsingRingsView()
            }
            
            // Main camera circle with progress
            CameraPreviewCircle(
                session: viewModel.captureSession,
                isRunning: viewModel.isRunning,
                signalQuality: viewModel.signalQuality,
                progress: viewModel.progress,
                borderPulse: $borderPulse
            )
            
            // Time/Progress overlay - positioned below camera
                if viewModel.isRunning {
                    HeartRateProgressOverlay(
                        progress: viewModel.progress,
                        measurementDuration: measurementDuration,
                        signalQuality: viewModel.signalQuality
                    )
                    .offset(y: 150)
                }
            }
            .frame(height: 300)
        .opacity(showContent ? 1 : 0)
        .scaleEffect(showContent ? 1 : 0.8)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showContent)
    }
    
    // MARK: - BPM Section
    
    private var bpmSection: some View {
        VStack(spacing: 16) {
            // BPM Display with heartbeat animation
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(viewModel.bpm > 0 ? "\(viewModel.bpm)" : "--")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: viewModel.bpm)
                
                Text("BPM")
                    .font(.title3.weight(.medium))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 6)
            }
            .scaleEffect(heartbeatScale)
            .animation(.spring(response: 0.15, dampingFraction: 0.5), value: heartbeatScale)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(viewModel.bpm > 0 ? "\(viewModel.bpm) beats per minute" : "No reading")
            
            // Waveform
            HeartRateWaveformView(isRunning: viewModel.isRunning, bpm: viewModel.bpm)
                .frame(height: 72)
                .accessibilityHidden(true)
            
            // Signal Quality Indicator
            SignalQualityIndicator(
                quality: viewModel.signalQuality,
                isRunning: viewModel.isRunning,
                instructionText: viewModel.instructionText
            )
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: showContent)
    }
    
    // MARK: - Action Section
    
    private var actionSection: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                if viewModel.isRunning {
                    HapticManager.impact(.medium)
                    viewModel.stopMeasurement()
                } else {
                    HapticManager.notification(.success)
                    viewModel.startMeasurement()
                }
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: viewModel.isRunning ? "stop.fill" : "heart.fill")
                    .font(.body.weight(.semibold))
                    .symbolEffect(.pulse, isActive: !viewModel.isRunning)
                
                Text(viewModel.isRunning ? "Stop Measurement" : "Start Measurement")
                    .font(.body.weight(.semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Group {
                    if viewModel.isRunning {
                        Color.gray
                    } else {
                        LinearGradient(
                            colors: [.red, .orange.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .clipShape(Capsule())
            .shadow(color: (viewModel.isRunning ? Color.gray : Color.red).opacity(0.25), radius: 12, x: 0, y: 6)
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: showContent)
        .accessibilityLabel(viewModel.isRunning ? "Stop measurement" : "Start heart rate measurement")
    }
    
    // MARK: - Helpers
    
    private func triggerHeartbeatPulse() {
        withAnimation(.easeOut(duration: 0.1)) {
            heartbeatScale = 1.15
        }
        withAnimation(.easeInOut(duration: 0.2).delay(0.1)) {
            heartbeatScale = 1.0
        }
    }
}

#Preview {
    HeartRateView()
}
