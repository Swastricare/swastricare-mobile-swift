//
//  FoodSnapView.swift
//  swastricare-mobile-swift
//
//  AI-powered food photo analysis and logging
//  Premium UI matching Android FoodSnapScreen
//

import SwiftUI
import PhotosUI

// MARK: - Brand Colors (snap-specific)

private let snapGreen = Color(hex: "34C759")
private let snapGreenDark = Color(hex: "28A745")
private let macroProteinColor = Color(hex: "4CAF50")
private let macroCarbsColor   = Color(hex: "FF9800")
private let macroFatColor     = Color(hex: "FFD600")

// MARK: - FoodSnapView

struct FoodSnapView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: DietViewModel

    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedMealType: MealType = .lunch
    @State private var servingQuantity: Double = 1.0

    // Editable snap fields (after result)
    @State private var editedFoodName: String = ""
    @State private var editedCalories: String = ""
    @State private var editedProtein: String = ""
    @State private var editedCarbs: String = ""
    @State private var editedFat: String = ""

    @Environment(\.colorScheme) private var colorScheme

    init(viewModel: DietViewModel, suggestedMealType: MealType? = nil) {
        self.viewModel = viewModel
        let initial = suggestedMealType ?? MealType.autoDetect()
        _selectedMealType = State(initialValue: initial)
    }

    private var isAnalyzing: Bool {
        if case .analyzing = viewModel.snapAnalysisState { return true }
        return false
    }

    private var isResult: Bool {
        if case .result = viewModel.snapAnalysisState { return true }
        return false
    }

    @ViewBuilder
    private var stateContent: some View {
        switch viewModel.snapAnalysisState {
        case .idle:
            idleView
        case .analyzing:
            analyzingView
        case .result(let result):
            reviewView(result)
        case .error(let msg):
            errorView(msg)
        }
    }

    var body: some View {
        NavigationView {
            mainContent
                .navigationBarHidden(isAnalyzing)
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { snapToolbar }
        }
        .trackScreen("FoodSnap")
    }
    
    private var mainContent: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                stateContent
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            cameraView
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            handlePhotoItemChange(newItem)
        }
        .onChange(of: viewModel.snapAnalysisState) { _, newState in
            handleStateChange(newState)
        }
    }
    
    private var cameraView: some View {
        CameraView { image in
            showCamera = false
            guard let data = image.jpegData(compressionQuality: 0.85) else { return }
            Task { await viewModel.analyzeFoodImage(data) }
        }
    }
    
    private func handlePhotoItemChange(_ newItem: PhotosPickerItem?) {
        Task {
            guard let item = newItem else { return }
            if let data = try? await item.loadTransferable(type: Data.self) {
                await viewModel.analyzeFoodImage(data)
            }
        }
    }
    
    private func handleStateChange(_ state: DietViewModel.SnapAnalysisState) {
        if case .result(let r) = state {
            editedFoodName  = r.name
            editedCalories  = "\(Int(r.calories))"
            editedProtein   = "\(Int(r.proteinG))"
            editedCarbs     = "\(Int(r.carbsG))"
            editedFat       = "\(Int(r.fatG))"
        }
    }

    @ToolbarContentBuilder
    private var snapToolbar: some ToolbarContent {
        if !isAnalyzing {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    viewModel.resetSnapState()
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                }
            }
        }
        if isResult {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    viewModel.resetSnapState()
                }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(snapGreen)
                }
            }
        }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        switch viewModel.snapAnalysisState {
        case .idle: return "Food Snap"
        case .analyzing: return ""
        case .result: return "Review & Log"
        case .error: return "Oops!"
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(snapGreen.opacity(0.12))
                    .frame(width: 120, height: 120)

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [snapGreen, snapGreenDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 10) {
                Text("Snap & Track")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.primary)
                Text("Take a photo of your food and we'll\nestimate the nutrition automatically")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Tips card
            VStack(alignment: .leading, spacing: 12) {
                Label("Tips for best results", systemImage: "lightbulb.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(snapGreen)

                tipRow("camera.circle", "Shoot from directly above")
                tipRow("light.max", "Use good natural lighting")
                tipRow("square.split.2x2", "Include the whole dish")
                tipRow("globe.asia.australia.fill", "Optimized for Indian cuisine")
            }
            .padding(16)
            .glass(cornerRadius: 16)
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 14) {
                Button(action: { showCamera = true }) {
                    Label("Take Photo", systemImage: "camera.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [snapGreen, snapGreenDark],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: snapGreen.opacity(0.35), radius: 8, x: 0, y: 4)
                }

                Button(action: { showPhotoPicker = true }) {
                    Label("Choose from Gallery", systemImage: "photo.on.rectangle.angled")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(snapGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(snapGreen, lineWidth: 1.5)
                                .background(snapGreen.opacity(0.06).clipShape(RoundedRectangle(cornerRadius: 14)))
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func tipRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(snapGreen)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Analyzing View

    private var analyzingView: some View {
        ZStack {
            // Full-screen blurred bg
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Pulsing orb
                PulsingSnapOrb()

                VStack(spacing: 10) {
                    Text("Analyzing your food...")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Our AI is identifying the dish\nand calculating nutrition info")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Animated dots indicator
                SnapDotsIndicator()

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Review / Result View

    @ViewBuilder
    private func reviewView(_ result: SnapFoodResult) -> some View {
        ScrollView {
            VStack(spacing: 20) {

                // Hero card: food emoji + name
                VStack(spacing: 12) {
                    Text(result.category.icon)
                        .font(.system(size: 64))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                    // Editable food name
                    TextField("Food name", text: $editedFoodName)
                        .font(.system(size: 24, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)

                    // AI badge
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                        Text("AI Detected")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(snapGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(snapGreen.opacity(0.12))
                    .clipShape(Capsule())
                }
                .padding(.top, 8)

                // Calorie summary
                calorieSummary(result)

                // Macro pills
                macroPills(result)

                // Serving row
                servingRow(result)

                // Meal type chips
                mealTypeSection

                // Log & retry buttons
                actionButtons(result)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    private func calorieSummary(_ result: SnapFoodResult) -> some View {
        let cal = Double(editedCalories) ?? result.calories
        let totalCalories = cal * servingQuantity
        let dailyCals = Double(max(1, viewModel.dietGoals.dailyCalories))
        let progress = min(1.0, totalCalories / dailyCals)
        let progressPercent = Int(progress * 100)
        let displayCalories = Int(totalCalories)

        return VStack(spacing: 12) {
            calorieHeader(displayCalories: displayCalories)
            progressSection(progress: progress, progressPercent: progressPercent, dailyCals: Int(dailyCals))
        }
        .padding(20)
        .glass(cornerRadius: 18)
    }
    
    private func calorieHeader(displayCalories: Int) -> some View {
        HStack(alignment: .bottom, spacing: 4) {
            Text("\(displayCalories)")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text("kcal")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
        }
    }
    
    private func progressSection(progress: Double, progressPercent: Int, dailyCals: Int) -> some View {
        VStack(spacing: 4) {
            progressBar(progress: progress)
                .frame(height: 6)

            HStack {
                Spacer()
                Text("\(progressPercent)% of daily goal (\(dailyCals) kcal)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func progressBar(progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 6)
                
                let progressGradient = LinearGradient(
                    colors: [snapGreen, snapGreenDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                
                Capsule()
                    .fill(progressGradient)
                    .frame(width: geo.size.width * progress, height: 6)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
            }
        }
    }

    private func macroPills(_ result: SnapFoodResult) -> some View {
        HStack(spacing: 10) {
            macroPill(label: "Protein", value: $editedProtein, accent: macroProteinColor)
            macroPill(label: "Carbs",   value: $editedCarbs,   accent: macroCarbsColor)
            macroPill(label: "Fat",     value: $editedFat,     accent: macroFatColor)
        }
    }

    private func macroPill(label: String, value: Binding<String>, accent: Color) -> some View {
        VStack(spacing: 0) {
            // Colored top bar
            Rectangle()
                .fill(accent)
                .frame(height: 3)
                .clipShape(RoundedCornerTop(radius: 14))

            VStack(spacing: 4) {
                HStack(alignment: .bottom, spacing: 2) {
                    TextField("0", text: value)
                        .font(.system(size: 20, weight: .bold))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .frame(maxWidth: 52)

                    Text("g")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 2)
                }
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
        .glass(cornerRadius: 14)
    }

    private func servingRow(_ result: SnapFoodResult) -> some View {
        HStack {
            Text("Serving")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            // Stepper
            HStack(spacing: 6) {
                Button(action: {
                    servingQuantity = max(0.5, servingQuantity - 0.5)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Circle())
                }

                Text(servingQuantity == servingQuantity.rounded() ?
                     "\(Int(servingQuantity))" :
                     String(format: "%.1f", servingQuantity))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .frame(minWidth: 36)
                    .multilineTextAlignment(.center)

                Button(action: {
                    servingQuantity = min(10, servingQuantity + 0.5)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(snapGreen.opacity(0.12))
                        .clipShape(Circle())
                        .foregroundColor(snapGreen)
                }
            }

            // Unit label
            Text("×  \(Int(result.servingSize)) \(result.servingUnit.displayName)")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(.leading, 4)
        }
        .padding(16)
        .glass(cornerRadius: 14)
    }

    private var mealTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Meal")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MealType.allCases) { meal in
                        mealChip(meal)
                    }
                }
            }
        }
    }

    private func mealChip(_ meal: MealType) -> some View {
        let isSelected = meal == selectedMealType
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedMealType = meal
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            HStack(spacing: 6) {
                Image(systemName: meal.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(meal.displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? AnyView(LinearGradient(colors: [snapGreen, snapGreenDark],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyView(Color.primary.opacity(0.07))
            )
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.clear : Color.primary.opacity(0.1), lineWidth: 0.5))
            .shadow(color: isSelected ? snapGreen.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func actionButtons(_ result: SnapFoodResult) -> some View {
        VStack(spacing: 12) {
            // Log Food
            Button(action: {
                let cal  = Double(editedCalories) ?? result.calories
                let prot = Double(editedProtein)  ?? result.proteinG
                let carb = Double(editedCarbs)    ?? result.carbsG
                let fat  = Double(editedFat)      ?? result.fatG
                let name = editedFoodName.isEmpty ? result.name : editedFoodName

                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task {
                    await viewModel.logCustomFood(
                        name: name,
                        mealType: selectedMealType,
                        quantity: servingQuantity,
                        servingUnit: result.servingUnit,
                        calories: cal * servingQuantity,
                        proteinG: prot * servingQuantity,
                        carbsG: carb * servingQuantity,
                        fatG: fat * servingQuantity
                    )
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    viewModel.resetSnapState()
                    dismiss()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Log to \(selectedMealType.displayName)")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [snapGreen, snapGreenDark],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: snapGreen.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
            }

            VStack(spacing: 10) {
                Text("Analysis Failed")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 14) {
                Button(action: {
                    viewModel.resetSnapState()
                    // No sheet - will show idle view with buttons
                }) {
                    Label("Try Again", systemImage: "camera.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [snapGreen, snapGreenDark],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: snapGreen.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(ScaleButtonStyle())

                Button(action: {
                    viewModel.resetSnapState()
                    dismiss()
                }) {
                    Text("Enter Manually")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

// MARK: - Pulsing Orb for Analyzing State

private struct PulsingSnapOrb: View {
    @State private var pulse = false
    @State private var rotate = false

    var body: some View {
        ZStack {
            // Outermost ring
            Circle()
                .stroke(snapGreen.opacity(0.15), lineWidth: 1)
                .frame(width: 180, height: 180)
                .scaleEffect(pulse ? 1.15 : 1)

            // Middle ring
            Circle()
                .stroke(snapGreen.opacity(0.25), lineWidth: 1.5)
                .frame(width: 140, height: 140)
                .scaleEffect(pulse ? 1.1 : 1)

            // Inner glow fill
            Circle()
                .fill(
                    RadialGradient(
                        colors: [snapGreen.opacity(0.3), snapGreen.opacity(0.05)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 55
                    )
                )
                .frame(width: 110, height: 110)

            // Rotating arc
            Circle()
                .trim(from: 0, to: 0.6)
                .stroke(
                    LinearGradient(colors: [snapGreen, snapGreenDark, .clear],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 110, height: 110)
                .rotationEffect(.degrees(rotate ? 360 : 0))

            // Center icon
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(snapGreen)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                rotate = true
            }
        }
    }
}

// MARK: - Animated Dots Indicator

private struct SnapDotsIndicator: View {
    @State private var dotScale: [CGFloat] = [1, 1, 1]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(snapGreen)
                    .frame(width: 8, height: 8)
                    .scaleEffect(dotScale[i])
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.18)
                        ) {
                            dotScale[i] = 0.4
                        }
                    }
            }
        }
    }
}

// MARK: - RoundedCornerTop Shape

private struct RoundedCornerTop: Shape {
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: radius))
        path.addQuadCurve(to: CGPoint(x: radius, y: 0),
                          control: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width - radius, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: radius),
                          control: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - MealType Auto-detect Extension

extension MealType {
    static func autoDetect() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<10:  return .breakfast
        case 10..<12: return .morningSnack
        case 12..<16: return .lunch
        case 16..<18: return .eveningSnack
        case 18..<22: return .dinner
        default:       return .lateNight
        }
    }
}

// MARK: - CameraView (UIKit wrapper)

struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onCapture(image) }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
