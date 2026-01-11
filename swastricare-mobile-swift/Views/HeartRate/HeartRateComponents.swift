//
//  HeartRateComponents.swift
//  swastricare-mobile-swift
//
//  Shared UI components for heart rate measurement
//

import SwiftUI

// MARK: - Measurement Phase

enum MeasurementPhase: Equatable {
    case idle
    case preparing      // Camera warming up (0-2s)
    case calibrating    // Finding signal (2-5s)
    case measuring      // Active measurement
    case completing     // Final 3 seconds
    
    var description: String {
        switch self {
        case .idle: return "Ready to measure"
        case .preparing: return "Preparing camera..."
        case .calibrating: return "Calibrating signal..."
        case .measuring: return "Measuring heart rate..."
        case .completing: return "Almost done..."
        }
    }
}

// MARK: - Pulsing Rings Animation (TimelineView for smoothness)

struct PulsingRingsView: View {
    var ringSize: CGFloat = 240
    var ringCount: Int = 3
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            ZStack {
                ForEach(0..<ringCount, id: \.self) { index in
                    let phase = (time * 0.5 + Double(index) * 0.33).truncatingRemainder(dividingBy: 1.0)
                    let scale = 1.0 + phase * 0.5
                    let opacity = (1.0 - phase) * 0.5
                    
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.red.opacity(opacity),
                                    Color.orange.opacity(opacity * 0.5)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                        .frame(width: ringSize, height: ringSize)
                        .scaleEffect(scale)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Progress Overlay

struct HeartRateProgressOverlay: View {
    let progress: Float
    let measurementDuration: TimeInterval
    let signalQuality: SignalQuality
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 12) {
                // Warning when signal is poor
                if signalQuality == .poor {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Place finger firmly on camera")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.15))
                    )
                }
                
                HStack(spacing: 20) {
                    // Time remaining
                    VStack(spacing: 4) {
                        Text(timeRemainingFormatted)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                        Text(signalQuality == .poor ? "paused" : "remaining")
                            .font(.caption2)
                            .foregroundColor(signalQuality == .poor ? .orange : .secondary)
                            .textCase(.uppercase)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Time remaining: \(Int(timeRemaining)) seconds")
                    
                    // Progress percentage
                    VStack(spacing: 4) {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                            .contentTransition(.numericText())
                        Text("complete")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(Int(progress * 100)) percent complete")
                }
            }
        }
        .offset(y: 190)
        .animation(.easeInOut(duration: 0.3), value: signalQuality)
    }
    
    private var timeRemaining: Float {
        max(0, Float(measurementDuration) - (progress * Float(measurementDuration)))
    }
    
    private var timeRemainingFormatted: String {
        let seconds = Int(timeRemaining)
        return String(format: "0:%02d", seconds)
    }
}

// MARK: - Signal Quality Indicator

struct SignalQualityIndicator: View {
    let quality: SignalQuality
    let isRunning: Bool
    let instructionText: String
    
    var body: some View {
        HStack(spacing: 10) {
            // Signal bars
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(signalBarColor(for: index))
                        .frame(width: 4, height: CGFloat(8 + index * 4))
                }
            }
            .accessibilityHidden(true)
            
            Text(isRunning ? quality.description : instructionText)
                .font(.subheadline)
                .foregroundColor(signalQualityColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(signalQualityColor.opacity(0.1))
        )
        .animation(.easeInOut(duration: 0.3), value: quality)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isRunning ? "Signal quality: \(quality.description)" : instructionText)
    }
    
    private func signalBarColor(for index: Int) -> Color {
        let activeCount: Int
        switch quality {
        case .poor: activeCount = 1
        case .fair: activeCount = 2
        case .good: activeCount = 3
        case .excellent: activeCount = 4
        }
        
        if !isRunning {
            return Color.gray.opacity(0.3)
        }
        
        return index < activeCount ? signalQualityColor : Color.gray.opacity(0.3)
    }
    
    private var signalQualityColor: Color {
        if !isRunning { return .secondary }
        switch quality {
        case .poor: return .red
        case .fair: return .orange
        case .good, .excellent: return .green
        }
    }
}

// MARK: - Camera Preview Circle

struct CameraPreviewCircle: View {
    let session: AVCaptureSession?
    let isRunning: Bool
    let signalQuality: SignalQuality
    let progress: Float
    @Binding var borderPulse: Bool
    
    private let ringSize: CGFloat = 240
    private let previewSize: CGFloat = 200
    
    var body: some View {
        ZStack {
            // Outer progress track
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                .frame(width: ringSize, height: ringSize)
            
            // Progress arc with glow
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.red.opacity(0.5),
                            Color.red,
                            Color.orange
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
                .shadow(color: .red.opacity(0.3 * Double(progress)), radius: 8)
                .animation(.linear(duration: 0.5), value: progress)
            
            // Progress dot indicator with trailing glow
            if progress > 0 {
                ZStack {
                    // Glow trail
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .blur(radius: 8)
                    
                    // Main dot
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: .red.opacity(0.5), radius: 4)
                }
                .offset(y: -ringSize / 2)
                .rotationEffect(.degrees(Double(progress) * 360 - 90))
                .animation(.linear(duration: 0.5), value: progress)
            }
            
            // Camera preview container
            ZStack {
                if let session = session {
                    CameraPreviewView(session: session)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: previewSize, height: previewSize)
                        .clipShape(Circle())
                } else {
                    // Placeholder
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: previewSize, height: previewSize)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                Text("Tap Start")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        )
                }
                
                // Finger placement overlay
                if isRunning && signalQuality == .poor {
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: previewSize, height: previewSize)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "hand.point.up.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                                    .symbolEffect(.pulse)
                                Text("Place finger on camera")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.white)
                            }
                        )
                        .transition(.opacity)
                }
            }
            .overlay(
                Circle()
                    .stroke(
                        signalQuality == .good || signalQuality == .excellent
                            ? Color.green.opacity(borderPulse ? 0.6 : 0.3)
                            : Color.white.opacity(0.3),
                        lineWidth: 3
                    )
                    .frame(width: previewSize, height: previewSize)
                    .animation(.easeInOut(duration: 0.5), value: borderPulse)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isRunning ? "Camera preview, \(Int(progress * 100)) percent complete" : "Camera preview")
    }
}

// MARK: - Haptic Feedback Helper

struct HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
    
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Import for CameraPreviewView

import AVFoundation
