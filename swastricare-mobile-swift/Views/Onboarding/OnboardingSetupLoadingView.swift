//
//  OnboardingSetupLoadingView.swift
//  swastricare-mobile-swift
//
//  Setting-Up loading screen — pixel-matches the reference design
//  (clipboard illustration, progress bar with %, "Your data is safe" badge).
//

import SwiftUI

struct OnboardingSetupLoadingView: View {
    let onComplete: () -> Void
    let saveAction: () async throws -> Void

    @State private var progress: Double = 0
    @State private var currentStep: String = "Setting up your profile"
    @State private var hasError = false
    @State private var errorMessage: String?

    private let steps = [
        "Setting up your profile",
        "Saving your health data",
        "Configuring your dashboard",
        "Almost done"
    ]

    private let darkText = Color(hex: "0F172A")
    private let mutedText = Color(hex: "6B7280")

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // Hero illustration
                Image.androidImage("setting up screen illustration")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 32)

                // Title
                Text(currentStep)
                    .font(.poppins(.bold, size: 22))
                    .foregroundColor(darkText)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.25), value: currentStep)

                Spacer().frame(height: 8)

                Text("Please wait...")
                    .font(.poppins(.regular, size: 14))
                    .foregroundColor(mutedText)

                Spacer().frame(height: 28)

                // Progress bar with trailing percentage
                ProgressBarRow(progress: progress, accent: AppColors.aiTeal)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 28)

                // "Your data is safe" badge
                DataSafeBadge()
                    .padding(.horizontal, 28)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 24)
        }
        .task { await simulateProgress() }
    }

    private func simulateProgress() async {
        let saveTask = Task {
            do {
                try await saveAction()
            } catch {
                await MainActor.run {
                    hasError = true
                    errorMessage = UserFriendlyError.message(from: error)
                }
            }
        }

        for (index, step) in steps.enumerated() {
            await MainActor.run {
                currentStep = step
                withAnimation(.easeInOut(duration: 0.4)) {
                    progress = Double(index + 1) / Double(steps.count)
                }
            }

            try? await Task.sleep(nanoseconds: 700_000_000)

            if index == 1 {
                _ = try? await saveTask.value
            }
        }

        do { try await saveTask.value } catch {}

        try? await Task.sleep(nanoseconds: 400_000_000)

        await MainActor.run {
            if !hasError { onComplete() }
        }
    }
}

// MARK: - Progress Bar with Percentage

private struct ProgressBarRow: View {
    let progress: Double
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "E5E7EB"))
                        .frame(height: 6)
                    Capsule()
                        .fill(accent)
                        .frame(width: max(0, geo.size.width * progress), height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)

            Text("\(Int(progress * 100))%")
                .font(.poppins(.semiBold, size: 13))
                .foregroundColor(accent)
                .frame(width: 44, alignment: .trailing)
        }
    }
}

// MARK: - Data Safe Badge

private struct DataSafeBadge: View {
    private let cardBg = Color(hex: "F0FBF8")
    private let darkText = Color(hex: "0F172A")
    private let mutedText = Color(hex: "6B7280")

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.aiTeal)
                    .frame(width: 36, height: 36)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Your data is safe")
                    .font(.poppins(.semiBold, size: 14))
                    .foregroundColor(darkText)
                Text("We're securely personalising your experience for better health insights.")
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(mutedText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    OnboardingSetupLoadingView(
        onComplete: {},
        saveAction: {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    )
}
