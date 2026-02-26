//
//  ARBodyScanView.swift
//  swastricare-mobile-swift
//
//  AR Body Scan - Point camera at yourself to see organ overlays
//  Uses Vision framework for 2D body pose detection
//

import SwiftUI
import AVFoundation
import Vision
import Combine

// MARK: - AR Body Scan View

struct ARBodyScanView: View {
    @StateObject private var viewModel = ARBodyScanViewModel()
    @ObservedObject private var homeViewModel = DependencyContainer.shared.homeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOrgan: OrganOverlay?
    @State private var showInfoCard = true
    @State private var scanPulse = false

    var body: some View {
        ZStack {
            // Camera feed
            if viewModel.permissionGranted {
                CameraFeedView(session: viewModel.captureSession)
                    .ignoresSafeArea()

                // Scan line animation
                if viewModel.isDetecting && !viewModel.bodyDetected {
                    ScanLineView()
                        .ignoresSafeArea()
                }

                // Body outline + organ overlays
                if viewModel.bodyDetected {
                    OrganOverlayView(
                        bodyPoints: viewModel.bodyPoints,
                        organs: viewModel.visibleOrgans,
                        selectedOrgan: $selectedOrgan,
                        healthData: HealthDataForAR(
                            heartRate: homeViewModel.heartRate,
                            steps: homeViewModel.stepCount,
                            calories: homeViewModel.activeCalories,
                            sleepHours: homeViewModel.sleepHours
                        )
                    )
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
            } else {
                // Permission denied state
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.4))
                        Text("Camera Access Required")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                        Text("Enable camera access in Settings to use AR Body Scan.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "2E3192"))
                    }
                }
            }

            // Top bar
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Status badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.bodyDetected ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                            .scaleEffect(scanPulse ? 1.3 : 1.0)
                        Text(viewModel.bodyDetected ? "Body Detected" : "Scanning...")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())

                    Spacer()

                    // Toggle camera
                    Button(action: { viewModel.toggleCamera() }) {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                // Bottom info / organ detail card
                if let organ = selectedOrgan {
                    OrganDetailCard(organ: organ, healthData: HealthDataForAR(
                        heartRate: homeViewModel.heartRate,
                        steps: homeViewModel.stepCount,
                        calories: homeViewModel.activeCalories,
                        sleepHours: homeViewModel.sleepHours
                    )) {
                        withAnimation(.spring(response: 0.3)) { selectedOrgan = nil }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                } else if showInfoCard && !viewModel.bodyDetected {
                    // Instruction card
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill.viewfinder")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(Color(hex: "2E3192"))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Point camera at a person")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Stand 3-6 feet away for best results")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.4), value: viewModel.bodyDetected)
        .animation(.spring(response: 0.4), value: selectedOrgan?.id)
        .onAppear {
            viewModel.startSession()
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                scanPulse = true
            }
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .statusBarHidden()
    }
}

// MARK: - Health Data Container

struct HealthDataForAR {
    let heartRate: Int
    let steps: Int
    let calories: Int
    let sleepHours: String
}

// MARK: - Organ Overlay Model

struct OrganOverlay: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String
    let color: String
    let relativePosition: CGPoint // 0-1 relative to body bounding box
    let size: CGFloat
    let healthMetric: String?
    let description: String

    static func == (lhs: OrganOverlay, rhs: OrganOverlay) -> Bool {
        lhs.id == rhs.id
    }

    static let allOrgans: [OrganOverlay] = [
        OrganOverlay(
            id: "brain", name: "Brain", icon: "brain.head.profile",
            color: "8B5CF6", relativePosition: CGPoint(x: 0.5, y: 0.08),
            size: 32, healthMetric: "sleep",
            description: "Your brain consolidates memories during deep sleep. Quality rest improves cognitive function and mood."
        ),
        OrganOverlay(
            id: "heart", name: "Heart", icon: "heart.fill",
            color: "EF4444", relativePosition: CGPoint(x: 0.45, y: 0.32),
            size: 34, healthMetric: "heartRate",
            description: "Your heart beats about 100,000 times a day. Regular cardio exercise strengthens it and lowers resting heart rate."
        ),
        OrganOverlay(
            id: "lungs", name: "Lungs", icon: "lungs.fill",
            color: "3B82F6", relativePosition: CGPoint(x: 0.55, y: 0.30),
            size: 30, healthMetric: nil,
            description: "Your lungs process about 11,000 liters of air daily. Deep breathing exercises improve lung capacity and reduce stress."
        ),
        OrganOverlay(
            id: "stomach", name: "Stomach", icon: "fork.knife",
            color: "F59E0B", relativePosition: CGPoint(x: 0.48, y: 0.42),
            size: 28, healthMetric: "calories",
            description: "Your stomach breaks down food using hydrochloric acid. Eating slowly improves digestion and nutrient absorption."
        ),
        OrganOverlay(
            id: "liver", name: "Liver", icon: "cross.vial.fill",
            color: "D97706", relativePosition: CGPoint(x: 0.40, y: 0.40),
            size: 26, healthMetric: nil,
            description: "Your liver performs over 500 functions including filtering blood and producing bile. Stay hydrated to support it."
        ),
        OrganOverlay(
            id: "kidneys", name: "Kidneys", icon: "drop.fill",
            color: "06B6D4", relativePosition: CGPoint(x: 0.50, y: 0.46),
            size: 24, healthMetric: nil,
            description: "Your kidneys filter about 200 liters of blood daily. Drinking enough water keeps them functioning optimally."
        ),
        OrganOverlay(
            id: "legs", name: "Legs", icon: "figure.walk",
            color: "22C55E", relativePosition: CGPoint(x: 0.50, y: 0.75),
            size: 28, healthMetric: "steps",
            description: "Walking is the most underrated exercise. Even 7,000 steps a day significantly reduces mortality risk."
        )
    ]
}

// MARK: - AR Body Scan ViewModel

@MainActor
final class ARBodyScanViewModel: NSObject, ObservableObject {
    @Published var permissionGranted = false
    @Published var bodyDetected = false
    @Published var bodyPoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    @Published var isDetecting = false
    @Published var visibleOrgans: [OrganOverlay] = []
    @Published private(set) var usingFrontCamera = false

    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var outputAdded = false
    private var sessionStarted = false
    private let processingQueue = DispatchQueue(label: "com.swasthicare.bodyscan", qos: .userInteractive)
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    func startSession() {
        guard !sessionStarted else { return }
        sessionStarted = true
        feedbackGenerator.prepare()
        checkPermission()
    }

    func stopSession() {
        sessionStarted = false
        processingQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    func toggleCamera() {
        usingFrontCamera.toggle()
        reconfigureCamera()
    }

    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted { self?.setupCamera() }
                }
            }
        default:
            permissionGranted = false
        }
    }

    private func setupCamera() {
        let isFront = usingFrontCamera // capture on MainActor
        processingQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .high

            // Remove existing inputs to prevent duplicates
            for input in self.captureSession.inputs {
                self.captureSession.removeInput(input)
            }

            // Camera input
            let position: AVCaptureDevice.Position = isFront ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                self.captureSession.commitConfiguration()
                return
            }

            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
            }

            // Video output for Vision processing — only add once
            if !self.outputAdded {
                self.videoOutput.setSampleBufferDelegate(self, queue: self.processingQueue)
                self.videoOutput.alwaysDiscardsLateVideoFrames = true

                if self.captureSession.canAddOutput(self.videoOutput) {
                    self.captureSession.addOutput(self.videoOutput)
                    self.outputAdded = true
                }
            }

            // Set video orientation
            if let connection = self.videoOutput.connection(with: .video) {
                if #available(iOS 17.0, *) {
                    connection.videoRotationAngle = 90 // portrait
                } else {
                    connection.videoOrientation = .portrait
                }
                connection.isVideoMirrored = isFront
            }

            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()

            DispatchQueue.main.async { [weak self] in
                self?.isDetecting = true
            }
        }
    }

    private func reconfigureCamera() {
        let isFront = usingFrontCamera // capture on MainActor
        processingQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.beginConfiguration()

            // Remove existing inputs
            for input in self.captureSession.inputs {
                self.captureSession.removeInput(input)
            }

            let position: AVCaptureDevice.Position = isFront ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                self.captureSession.commitConfiguration()
                return
            }

            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
            }

            if let connection = self.videoOutput.connection(with: .video) {
                if #available(iOS 17.0, *) {
                    connection.videoRotationAngle = 90
                } else {
                    connection.videoOrientation = .portrait
                }
                connection.isVideoMirrored = isFront
            }

            self.captureSession.commitConfiguration()
        }
    }

    private func processBodyPose(_ observation: VNHumanBodyPoseObservation) {
        var points: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .neck,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .root, // hip center
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]

        for joint in jointNames {
            if let point = try? observation.recognizedPoint(joint),
               point.confidence > 0.3 {
                // Vision coordinates: origin bottom-left, flip Y for SwiftUI
                points[joint] = CGPoint(x: point.location.x, y: 1 - point.location.y)
            }
        }

        // Already on MainActor — update state directly
        let wasDetected = bodyDetected
        bodyPoints = points

        // Need at least shoulders + hips to consider body detected
        let hasUpperBody = points[.leftShoulder] != nil && points[.rightShoulder] != nil
        let hasLowerBody = points[.leftHip] != nil || points[.rightHip] != nil
        bodyDetected = hasUpperBody && hasLowerBody

        if bodyDetected && !wasDetected {
            feedbackGenerator.impactOccurred()
            visibleOrgans = OrganOverlay.allOrgans
        } else if !bodyDetected {
            visibleOrgans = []
        }
    }
}

// MARK: - Video Delegate

extension ARBodyScanViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        let request = VNDetectHumanBodyPoseRequest() // new per frame — VNRequest is not thread-safe

        do {
            try handler.perform([request])
            if let observation = request.results?.first {
                Task { @MainActor [weak self] in
                    self?.processBodyPose(observation)
                }
            } else {
                Task { @MainActor [weak self] in
                    self?.bodyDetected = false
                    self?.visibleOrgans = []
                }
            }
        } catch {
            // Silently handle - frame processing errors are expected occasionally
        }
    }
}

// MARK: - Camera Feed View

private struct CameraFeedView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraFeedUIView {
        let view = CameraFeedUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraFeedUIView, context: Context) {}
}

private class CameraFeedUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

// MARK: - Scan Line Animation

private struct ScanLineView: View {
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color(hex: "2E3192").opacity(0.4), Color(hex: "1BFFFF").opacity(0.6), Color(hex: "2E3192").opacity(0.4), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .shadow(color: Color(hex: "1BFFFF").opacity(0.6), radius: 8, y: 0)
                .offset(y: offset)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        offset = geo.size.height
                    }
                }
        }
    }
}

// MARK: - Organ Overlay View

private struct OrganOverlayView: View {
    let bodyPoints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let organs: [OrganOverlay]
    @Binding var selectedOrgan: OrganOverlay?
    let healthData: HealthDataForAR

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            // Body bounding box from detected joints
            let bodyRect = computeBodyRect(in: size)

            // Skeleton lines (subtle)
            SkeletonView(points: bodyPoints, size: size)
                .opacity(0.3)

            // Organ icons
            ForEach(organs) { organ in
                let pos = CGPoint(
                    x: bodyRect.origin.x + organ.relativePosition.x * bodyRect.width,
                    y: bodyRect.origin.y + organ.relativePosition.y * bodyRect.height
                )

                OrganIconView(
                    organ: organ,
                    healthValue: healthValue(for: organ),
                    isSelected: selectedOrgan?.id == organ.id,
                    onTap: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3)) {
                            selectedOrgan = selectedOrgan?.id == organ.id ? nil : organ
                        }
                    }
                )
                .position(pos)
            }
        }
    }

    private func computeBodyRect(in size: CGSize) -> CGRect {
        let allPoints = bodyPoints.values
        guard !allPoints.isEmpty else {
            return CGRect(x: size.width * 0.25, y: size.height * 0.15, width: size.width * 0.5, height: size.height * 0.7)
        }

        let xs = allPoints.map { $0.x * size.width }
        let ys = allPoints.map { $0.y * size.height }

        let minX = (xs.min() ?? 0) - 30
        let maxX = (xs.max() ?? size.width) + 30
        let minY = (ys.min() ?? 0) - 40
        let maxY = (ys.max() ?? size.height) + 20

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func healthValue(for organ: OrganOverlay) -> String? {
        switch organ.healthMetric {
        case "heartRate": return healthData.heartRate > 0 ? "\(healthData.heartRate) bpm" : nil
        case "steps": return "\(healthData.steps) steps"
        case "calories": return "\(healthData.calories) kcal"
        case "sleep": return healthData.sleepHours != "N/A" ? "\(healthData.sleepHours)h" : nil
        default: return nil
        }
    }
}

// MARK: - Organ Icon

private struct OrganIconView: View {
    let organ: OrganOverlay
    let healthValue: String?
    let isSelected: Bool
    let onTap: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    // Pulse ring
                    if organ.id == "heart" {
                        Circle()
                            .stroke(Color(hex: organ.color).opacity(0.3), lineWidth: 2)
                            .frame(width: organ.size + 16, height: organ.size + 16)
                            .scaleEffect(pulse ? 1.4 : 1.0)
                            .opacity(pulse ? 0 : 0.6)
                    }

                    // Glow
                    Circle()
                        .fill(Color(hex: organ.color).opacity(0.25))
                        .frame(width: organ.size + 8, height: organ.size + 8)
                        .blur(radius: 4)

                    // Icon circle
                    Circle()
                        .fill(Color(hex: organ.color).opacity(0.85))
                        .frame(width: organ.size, height: organ.size)
                        .overlay(
                            Image(systemName: organ.icon)
                                .font(.system(size: organ.size * 0.45, weight: .semibold))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                        .shadow(color: Color(hex: organ.color).opacity(0.5), radius: 8)
                }

                // Health value label
                if let value = healthValue {
                    Text(value)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: organ.color).opacity(0.8))
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                }
            }
            .scaleEffect(isSelected ? 1.25 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
        .onAppear {
            if organ.id == "heart" {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }
}

// MARK: - Skeleton View

private struct SkeletonView: View {
    let points: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let size: CGSize

    private let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.nose, .neck),
        (.neck, .leftShoulder), (.neck, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.neck, .root),
        (.root, .leftHip), (.root, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
    ]

    var body: some View {
        Canvas { context, canvasSize in
            for (from, to) in connections {
                guard let p1 = points[from], let p2 = points[to] else { continue }
                let start = CGPoint(x: p1.x * size.width, y: p1.y * size.height)
                let end = CGPoint(x: p2.x * size.width, y: p2.y * size.height)

                var path = Path()
                path.move(to: start)
                path.addLine(to: end)

                context.stroke(path, with: .linearGradient(
                    Gradient(colors: [
                        Color(hex: "2E3192").opacity(0.5),
                        Color(hex: "1BFFFF").opacity(0.5)
                    ]),
                    startPoint: start,
                    endPoint: end
                ), lineWidth: 2)
            }

            // Joint dots
            for (_, point) in points {
                let pos = CGPoint(x: point.x * size.width, y: point.y * size.height)
                let dot = Path(ellipseIn: CGRect(x: pos.x - 3, y: pos.y - 3, width: 6, height: 6))
                context.fill(dot, with: .color(Color(hex: "1BFFFF").opacity(0.8)))
            }
        }
    }
}

// MARK: - Organ Detail Card

private struct OrganDetailCard: View {
    let organ: OrganOverlay
    let healthData: HealthDataForAR
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: organ.color).opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: organ.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: organ.color))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(organ.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    if let metric = healthMetricText {
                        Text(metric)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: organ.color))
                    }
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }

            Text(organ.description)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(4)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: organ.color).opacity(0.3), lineWidth: 1)
        )
    }

    private var healthMetricText: String? {
        switch organ.healthMetric {
        case "heartRate": return healthData.heartRate > 0 ? "\(healthData.heartRate) bpm" : nil
        case "steps": return "\(healthData.steps) steps today"
        case "calories": return "\(healthData.calories) kcal burned"
        case "sleep": return healthData.sleepHours != "N/A" ? "\(healthData.sleepHours) hours of sleep" : nil
        default: return nil
        }
    }
}
