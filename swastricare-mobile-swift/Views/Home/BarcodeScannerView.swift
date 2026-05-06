//
//  BarcodeScannerView.swift
//  swastricare-mobile-swift
//
//  Camera-based barcode scanning for food product lookup
//  Uses AVFoundation for barcode detection and Open Food Facts API
//

import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: DietViewModel
    let mealType: MealType

    @State private var scannedBarcode: String?
    @State private var lookupState: BarcodeLookupState = .scanning
    @State private var manualBarcode = ""
    @State private var showManualEntry = false
    @State private var foundFoodItem: FoodItem?
    @State private var showQuantitySheet = false
    @State private var showCustomEntry = false
    @State private var cameraPermissionDenied = false

    private let barcodeService: BarcodeScannerServiceProtocol = BarcodeScannerService.shared

    enum BarcodeLookupState: Equatable {
        case scanning
        case lookingUp
        case found(FoodItem)
        case notFound(String)
        case error(String)

        static func == (lhs: BarcodeLookupState, rhs: BarcodeLookupState) -> Bool {
            switch (lhs, rhs) {
            case (.scanning, .scanning): return true
            case (.lookingUp, .lookingUp): return true
            case (.found(let a), .found(let b)): return a.id == b.id
            case (.notFound(let a), .notFound(let b)): return a == b
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if cameraPermissionDenied {
                    permissionDeniedView
                } else {
                    VStack(spacing: 0) {
                        // Camera preview with scanner overlay
                        ZStack {
                            BarcodeCameraPreview(onBarcodeScanned: handleBarcodeScan)
                                .ignoresSafeArea(edges: .top)

                            scannerOverlay
                        }
                        .frame(maxHeight: .infinity)

                        // Bottom panel
                        bottomPanel
                    }
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showQuantitySheet) {
                if let food = foundFoodItem {
                    FoodQuantitySheet(
                        viewModel: viewModel,
                        food: food,
                        mealType: mealType,
                        onLog: { dismiss() }
                    )
                }
            }
            .sheet(isPresented: $showCustomEntry) {
                CustomFoodEntryView(
                    viewModel: viewModel,
                    selectedMealType: mealType,
                    onSave: { dismiss() }
                )
            }
            .onAppear {
                checkCameraPermission()
            }
        }
        .trackScreen("BarcodeScanner")
    }

    // MARK: - Scanner Overlay

    private var scannerOverlay: some View {
        ZStack {
            // Dimmed area around scan zone
            Color.black.opacity(0.4)
                .mask {
                    ZStack {
                        Rectangle()
                        RoundedRectangle(cornerRadius: 16)
                            .frame(width: 280, height: 160)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                }
                .ignoresSafeArea()

            // Scan frame
            VStack(spacing: 16) {
                Spacer()

                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        lookupState == .lookingUp ? Color.yellow : AppColors.accentGreen,
                        lineWidth: 3
                    )
                    .frame(width: 280, height: 160)
                    .overlay(
                        // Corner accents
                        ZStack {
                            cornerAccent(rotation: 0)
                                .position(x: 20, y: 20)
                            cornerAccent(rotation: 90)
                                .position(x: 260, y: 20)
                            cornerAccent(rotation: 180)
                                .position(x: 260, y: 140)
                            cornerAccent(rotation: 270)
                                .position(x: 20, y: 140)
                        }
                    )

                // Status text
                statusLabel

                Spacer()
                Spacer()
            }
        }
    }

    private func cornerAccent(rotation: Double) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 20))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 20, y: 0))
        }
        .stroke(AppColors.accentGreen, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        .rotationEffect(.degrees(rotation))
        .frame(width: 20, height: 20)
    }

    private var statusLabel: some View {
        Group {
            switch lookupState {
            case .scanning:
                HStack(spacing: 8) {
                    Image(systemName: "barcode.viewfinder")
                    Text("Align barcode within frame")
                }
            case .lookingUp:
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text("Looking up product...")
                }
            case .found(let food):
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.accentGreen)
                    Text("Found: \(food.name)")
                }
            case .notFound:
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.yellow)
                    Text("Product not found")
                }
            case .error(let message):
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(message)
                }
            }
        }
        .font(.poppins(.medium, size: 15))
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: 16) {
            // Result card (when found)
            if case .found(let food) = lookupState {
                foundFoodCard(food)
            }

            // Not found actions
            if case .notFound = lookupState {
                notFoundActions
            }

            // Manual entry toggle
            HStack(spacing: 16) {
                Button {
                    showManualEntry.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "keyboard")
                            .font(.poppins(.regular, size: 14))
                        Text("Enter Manually")
                            .font(.poppins(.medium, size: 14))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                if lookupState != .scanning {
                    Button {
                        resetScanner()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.poppins(.regular, size: 14))
                            Text("Scan Again")
                                .font(.poppins(.medium, size: 14))
                        }
                        .foregroundColor(AppColors.accentGreen)
                    }
                }
            }

            // Manual barcode input
            if showManualEntry {
                HStack(spacing: 12) {
                    TextField("Enter barcode number", text: $manualBarcode)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.poppins(.regular, size: 16))

                    Button {
                        Task {
                            await lookupBarcode(manualBarcode)
                        }
                    } label: {
                        Text("Look Up")
                            .font(.poppins(.semiBold, size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AppColors.accentGreen)
                            .cornerRadius(8)
                    }
                    .disabled(manualBarcode.count < 8)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color(UIColor.systemBackground)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 24,
                        topTrailingRadius: 24
                    )
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Found Food Card

    private func foundFoodCard(_ food: FoodItem) -> some View {
        Button {
            foundFoodItem = food
            showQuantitySheet = true
        } label: {
            HStack(spacing: 12) {
                // Category icon
                Text(food.category.icon)
                    .font(.poppins(.regular, size: 32))
                    .frame(width: 50, height: 50)
                    .background(AppColors.accentGreen.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Food details
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        VegIndicator(isVegetarian: food.isVegetarian)
                        Text(food.name)
                            .font(.poppins(.semiBold, size: 16))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }

                    if let brand = food.brand {
                        Text(brand)
                            .font(.poppins(.regular, size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 6) {
                        Text(food.displayServingSize)
                            .font(.poppins(.regular, size: 12))
                            .foregroundColor(.secondary)
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(food.caloriesPerServing)
                            .font(.poppins(.bold, size: 12))
                            .foregroundColor(AppColors.accentGreen)
                    }
                }

                Spacer()

                // Add button
                ZStack {
                    Circle()
                        .fill(AppColors.accentGreen)
                        .frame(width: 36, height: 36)
                    Image(systemName: "plus")
                        .font(.poppins(.bold, size: 16))
                        .foregroundColor(.white)
                }
            }
            .padding(14)
            .glass(cornerRadius: 14)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Not Found Actions

    private var notFoundActions: some View {
        VStack(spacing: 10) {
            Text("This product isn't in our database yet")
                .font(.poppins(.regular, size: 14))
                .foregroundColor(.secondary)

            Button {
                showCustomEntry = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.poppins(.regular, size: 16))
                    Text("Add Custom Food")
                        .font(.poppins(.semiBold, size: 15))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppColors.accentGreen)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    // MARK: - Permission Denied

    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.poppins(.regular, size: 60))
                .foregroundColor(.secondary)

            Text("Camera Access Required")
                .font(.poppins(.bold, size: 22))
                .foregroundColor(.primary)

            Text("Allow camera access in Settings to scan barcodes")
                .font(.poppins(.regular, size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.poppins(.semiBold, size: 17))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(AppColors.accentBlue)
            .cornerRadius(12)

            // Manual entry fallback
            Button {
                showManualEntry = true
                cameraPermissionDenied = false
            } label: {
                Text("Enter Barcode Manually")
                    .font(.poppins(.regular, size: 15))
                    .foregroundColor(AppColors.accentBlue)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionDenied = false
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermissionDenied = !granted
                }
            }
        case .denied, .restricted:
            cameraPermissionDenied = true
        @unknown default:
            cameraPermissionDenied = true
        }
    }

    private func handleBarcodeScan(_ barcode: String) {
        guard lookupState == .scanning else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        scannedBarcode = barcode
        Task {
            await lookupBarcode(barcode)
        }
    }

    private func lookupBarcode(_ barcode: String) async {
        lookupState = .lookingUp

        do {
            if let food = try await barcodeService.lookupBarcode(barcode) {
                lookupState = .found(food)
                foundFoodItem = food
            } else {
                lookupState = .notFound(barcode)
            }
        } catch let error as BarcodeLookupError {
            switch error {
            case .productNotFound:
                lookupState = .notFound(barcode)
            default:
                lookupState = .error(error.localizedDescription ?? "Lookup failed")
            }
        } catch {
            lookupState = .error("Lookup failed. Try again.")
        }
    }

    private func resetScanner() {
        lookupState = .scanning
        scannedBarcode = nil
        foundFoodItem = nil
        manualBarcode = ""
    }
}

// MARK: - Camera Preview (AVFoundation)

struct BarcodeCameraPreview: UIViewRepresentable {
    let onBarcodeScanned: (String) -> Void

    func makeUIView(context: Context) -> BarcodeCameraUIView {
        let view = BarcodeCameraUIView(onBarcodeScanned: onBarcodeScanned)
        return view
    }

    func updateUIView(_ uiView: BarcodeCameraUIView, context: Context) {}
}

class BarcodeCameraUIView: UIView {
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let onBarcodeScanned: (String) -> Void
    private var hasScanned = false

    init(onBarcodeScanned: @escaping (String) -> Void) {
        self.onBarcodeScanned = onBarcodeScanned
        super.init(frame: .zero)
        setupCamera()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .medium // Barcode metadata detection needs no high-res video

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            print("🍎 BarcodeScannerView: Failed to access camera")
            return
        }

        guard session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [
            .ean8,
            .ean13,
            .upce,
            .code128,
            .code39,
            .code93,
            .interleaved2of5
        ]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        layer.addSublayer(preview)
        previewLayer = preview

        captureSession = session

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    func resetScanning() {
        hasScanned = false
    }

    deinit {
        captureSession?.stopRunning()
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension BarcodeCameraUIView: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasScanned,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let barcode = object.stringValue else {
            return
        }

        hasScanned = true
        print("🍎 BarcodeScannerView: Scanned barcode: \(barcode)")
        onBarcodeScanned(barcode)
    }
}
