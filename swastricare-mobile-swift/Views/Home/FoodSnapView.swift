//
//  FoodSnapView.swift
//  swastricare-mobile-swift
//
//  AI-powered food photo analysis and logging
//  Takes a photo and extracts nutrition data automatically
//

import SwiftUI
import PhotosUI

struct FoodSnapView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DietViewModel

    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var selectedMealType: MealType = .lunch
    @State private var servingQuantity: Double = 1.0
    @State private var showingQuantitySheet = false
    @State private var currentResult: SnapFoodResult?

    init(viewModel: DietViewModel, suggestedMealType: MealType? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        if let suggested = suggestedMealType {
            _selectedMealType = State(initialValue: suggested)
        } else {
            _selectedMealType = State(initialValue: MealType.autoDetect())
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection

                        // State-based content
                        switch viewModel.snapAnalysisState {
                        case .idle:
                            idleStateView

                        case .analyzing:
                            analyzingStateView

                        case .result(let foodResult):
                            resultStateView(foodResult)

                        case .error(let message):
                            errorStateView(message)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Snap Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.resetSnapState()
                        dismiss()
                    }
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { image in
                    capturedImage = image
                    showCamera = false
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        await analyzeImage(data)
                    }
                }
            }
            .onChange(of: capturedImage) { _, newImage in
                if let image = newImage, let imageData = image.jpegData(compressionQuality: 0.8) {
                    Task {
                        await analyzeImage(imageData)
                    }
                }
            }
            .sheet(isPresented: $showingQuantitySheet) {
                if let result = currentResult {
                    quantityAdjustmentSheet(for: result)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(AppColors.accentBlue)

            Text("Snap & Track")
                .font(.title2.bold())
                .foregroundColor(Color.primary)

            Text("Take a photo of your food and we'll estimate the nutrition info")
                .font(.subheadline)
                .foregroundColor(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Idle State

    private var idleStateView: some View {
        VStack(spacing: 20) {
            // Action buttons
            VStack(spacing: 16) {
                Button(action: { showCamera = true }) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.title3)
                        Text("Take Photo")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.accentBlue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                Button(action: { showPhotoPicker = true }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title3)
                        Text("Choose from Gallery")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.cardBackground)
                    .foregroundColor(AppColors.accentBlue)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)

            // Tips
            tipsSection
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tips for best results:")
                .font(.headline)
                .foregroundColor(Color.primary)

            tipRow(icon: "camera.circle", text: "Take photo from directly above")
            tipRow(icon: "light.max", text: "Use good lighting")
            tipRow(icon: "square.split.2x2", text: "Capture the whole dish")
            tipRow(icon: "sparkles", text: "Works best with Indian cuisine")
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppColors.accentBlue)
            Text(text)
                .font(.subheadline)
                .foregroundColor(Color.secondary)
            Spacer()
        }
    }

    // MARK: - Analyzing State

    private var analyzingStateView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.accentBlue)

            Text("Analyzing food...")
                .font(.headline)
                .foregroundColor(Color.primary)

            Text("Our AI is identifying the dish and calculating nutrition")
                .font(.subheadline)
                .foregroundColor(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Result State

    private func resultStateView(_ result: SnapFoodResult) -> some View {
        VStack(spacing: 20) {
            // Food name and category
            VStack(spacing: 8) {
                Text(result.category.icon)
                    .font(.system(size: 60))

                Text(result.name)
                    .font(.title2.bold())
                    .foregroundColor(Color.primary)

                Text(result.category.displayName)
                    .font(.subheadline)
                    .foregroundColor(Color.secondary)
            }

            // Nutrition info
            nutritionCard(result: result)

            // Meal type selector
            mealTypeSelector

            // Action buttons
            VStack(spacing: 12) {
                Button(action: {
                    currentResult = result
                    showingQuantitySheet = true
                }) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Adjust Quantity")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.cardBackground)
                    .foregroundColor(AppColors.accentBlue)
                    .cornerRadius(12)
                }

                Button(action: {
                    Task {
                        await viewModel.logFoodFromSnap(
                            result: result,
                            mealType: selectedMealType,
                            quantity: servingQuantity
                        )
                        dismiss()
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Log Food")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.accentBlue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }

            // Retry button
            Button(action: {
                viewModel.resetSnapState()
            }) {
                Text("Try Another Photo")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentBlue)
            }
            .padding(.top, 8)
        }
    }

    private func nutritionCard(result: SnapFoodResult) -> some View {
        VStack(spacing: 16) {
            // Calories
            HStack {
                Label("Calories", systemImage: "flame.fill")
                    .foregroundColor(.orange)
                Spacer()
                Text("\(Int(result.calories * servingQuantity)) cal")
                    .font(.headline)
                    .foregroundColor(Color.primary)
            }

            Divider()

            // Macros
            VStack(spacing: 12) {
                macroRow(
                    label: "Protein",
                    value: result.proteinG * servingQuantity,
                    color: .blue
                )
                macroRow(
                    label: "Carbs",
                    value: result.carbsG * servingQuantity,
                    color: .green
                )
                macroRow(
                    label: "Fat",
                    value: result.fatG * servingQuantity,
                    color: .purple
                )
                if result.fiberG > 0 {
                    macroRow(
                        label: "Fiber",
                        value: result.fiberG * servingQuantity,
                        color: .brown
                    )
                }
            }

            // Serving info
            Divider()

            HStack {
                Label("Serving", systemImage: "circle.grid.cross")
                    .foregroundColor(Color.secondary)
                Spacer()
                Text("\(servingQuantity.formatted(.number.precision(.fractionLength(1)))) × \(result.servingSize.formatted(.number.precision(.fractionLength(0)))) \(result.servingUnit.displayName)")
                    .font(.subheadline)
                    .foregroundColor(Color.secondary)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }

    private func macroRow(label: String, value: Double, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(Color.secondary)
            Spacer()
            Text("\(Int(value))g")
                .font(.subheadline.bold())
                .foregroundColor(Color.primary)
        }
    }

    private var mealTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meal Type")
                .font(.subheadline.bold())
                .foregroundColor(Color.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MealType.allCases) { mealType in
                        mealTypeChip(mealType)
                    }
                }
            }
        }
    }

    private func mealTypeChip(_ mealType: MealType) -> some View {
        Button(action: {
            selectedMealType = mealType
        }) {
            HStack(spacing: 6) {
                Image(systemName: mealType.icon)
                    .font(.caption)
                Text(mealType.displayName)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(selectedMealType == mealType ? AppColors.accentBlue : AppColors.cardBackground)
            .foregroundColor(selectedMealType == mealType ? .white : Color.primary)
            .cornerRadius(20)
        }
    }

    // MARK: - Error State

    private func errorStateView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Analysis Failed")
                .font(.headline)
                .foregroundColor(Color.primary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(Color.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                viewModel.resetSnapState()
            }) {
                Text("Try Again")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.accentBlue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Quantity Adjustment Sheet

    private func quantityAdjustmentSheet(for result: SnapFoodResult) -> some View {
        NavigationView {
            VStack(spacing: 20) {
                // Food info
                VStack(spacing: 8) {
                    Text(result.category.icon)
                        .font(.system(size: 50))
                    Text(result.name)
                        .font(.title3.bold())
                        .foregroundColor(Color.primary)
                }
                .padding(.top)

                // Quantity stepper
                VStack(spacing: 16) {
                    Text("Serving Quantity")
                        .font(.headline)
                        .foregroundColor(Color.primary)

                    HStack(spacing: 20) {
                        Button(action: {
                            servingQuantity = max(0.5, servingQuantity - 0.5)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title)
                                .foregroundColor(AppColors.accentBlue)
                        }

                        Text(servingQuantity.formatted(.number.precision(.fractionLength(1))))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Color.primary)
                            .frame(minWidth: 80)

                        Button(action: {
                            servingQuantity = min(10, servingQuantity + 0.5)
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundColor(AppColors.accentBlue)
                        }
                    }

                    Text("\(servingQuantity.formatted(.number.precision(.fractionLength(1)))) × \(result.servingSize.formatted(.number.precision(.fractionLength(0)))) \(result.servingUnit.displayName)")
                        .font(.subheadline)
                        .foregroundColor(Color.secondary)
                }
                .padding()
                .background(AppColors.cardBackground)
                .cornerRadius(12)

                // Updated nutrition
                nutritionCard(result: result)

                Spacer()
            }
            .padding()
            .background(Color(UIColor.systemBackground).ignoresSafeArea())
            .navigationTitle("Adjust Quantity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingQuantitySheet = false
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func analyzeImage(_ imageData: Data) async {
        await viewModel.analyzeFoodImage(imageData)
    }
}

// MARK: - MealType Auto-detect Extension

extension MealType {
    static func autoDetect() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 6..<10:
            return .breakfast
        case 10..<12:
            return .morningSnack
        case 12..<16:
            return .lunch
        case 16..<18:
            return .eveningSnack
        case 18..<22:
            return .dinner
        default:
            return .lateNight
        }
    }
}

// MARK: - Camera View

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

        init(onCapture: @escaping (UIImage) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
