//
//  MedicationsView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI

struct MedicationsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: MedicationViewModel
    
    @State private var selectedDate = Date()
    @State private var showAddMedication = false
    @State private var selectedMedication: MedicationWithAdherence?
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {   // Black Background
          
                // Theme-aware Background
                // PremiumBackground()
                if viewModel.isLoading {
                    medicationsSkeletonView
                } else if viewModel.todaysMedications.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        // Custom Calendar Strip
                        calendarStrip
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                        
                        // Progress Header
                        progressSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        
                        // Medication List
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.todaysMedications) { medWithAdherence in
                                    MedicationCard(
                                        medicationWithAdherence: medWithAdherence,
                                        onTaken: {
                                            Task {
                                                try? await viewModel.quickMarkAsTaken(medicationWithAdherence: medWithAdherence)
                                            }
                                        },
                                        onTap: {
                                            selectedMedication = medWithAdherence
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .onAppear {
                AppAnalyticsService.shared.logScreen("medications")
            }
            .navigationTitle("Medications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showAddMedication = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "2E3192"))
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                    .font(.body)
                }
            }
            .sheet(isPresented: $showAddMedication) {
                AddMedicationView(viewModel: viewModel)
            }
            .sheet(item: $selectedMedication) { medWithAdherence in
                MedicationDetailView(
                    medication: medWithAdherence.medication,
                    viewModel: viewModel
                )
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            await viewModel.loadMedications()
        }
    }
    
    // MARK: - Skeleton Loading

    private var medicationsSkeletonView: some View {
        VStack(spacing: 0) {
            // Calendar strip skeleton (7 date circles)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<7, id: \.self) { _ in
                        VStack(spacing: 6) {
                            SkeletonShape(width: 28, height: 10, cornerRadius: 4)
                            SkeletonCircle(size: 40)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 8)
            .padding(.bottom, 16)

            // Progress section skeleton
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonShape(width: 120, height: 14)
                    SkeletonShape(width: 80, height: 12)
                }
                Spacer()
                SkeletonCircle(size: 72)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // Medication cards skeleton
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        HStack(spacing: 14) {
                            SkeletonCircle(size: 44)
                            VStack(alignment: .leading, spacing: 6) {
                                SkeletonShape(width: 140, height: 14)
                                SkeletonShape(width: 90, height: 12)
                            }
                            Spacer()
                            SkeletonShape(width: 60, height: 28, cornerRadius: 14)
                        }
                        .padding(16)
                        .glass(cornerRadius: 16)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "pills.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(Color(hex: "2E3192").opacity(0.3))
            
            VStack(spacing: 12) {
                Text("No Medications Yet")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Add your first medication to get started with reminders")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: {
                showAddMedication = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add Medication")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color(hex: "2E3192"))
                .cornerRadius(14)
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Subviews
    
    private var calendarStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<7) { index in
                    let date = Calendar.current.date(byAdding: .day, value: index, to: Date()) ?? Date()
                    let isToday = Calendar.current.isDateInToday(date)
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDate = date
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isSelected ? .white : .secondary)
                            
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(isSelected ? .white : .primary)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(isSelected ? Color(hex: "2E3192") : Color.clear)
                                )
                        }
                        .frame(width: 56)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isToday && !isSelected ? Color(hex: "2E3192").opacity(0.1) : Color.clear)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 16) {
            Text("Today's Progress")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            // Pill bottle animation
            PillBottleView(progress: viewModel.todayAdherencePercentage / 100)
                .padding(.vertical, 4)

            // Stat pills row
            HStack(spacing: 10) {
                medicationStatPill(
                    icon: "checkmark.circle.fill",
                    color: Color(hex: "11998e"),
                    value: "\(viewModel.takenCount)",
                    label: "taken"
                )

                medicationStatPill(
                    icon: "clock.fill",
                    color: .orange,
                    value: "\(viewModel.totalCount - viewModel.takenCount)",
                    label: "remaining"
                )

                medicationStatPill(
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green,
                    value: viewModel.adherenceStatistics?.adherenceRate ?? "0%",
                    label: "adherence"
                )
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    private func medicationStatPill(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }
}

// MARK: - Medication Card

struct MedicationCard: View {
    let medicationWithAdherence: MedicationWithAdherence
    let onTaken: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon Container
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "2E3192").opacity(0.12))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: medicationWithAdherence.medication.type.icon)
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "2E3192"))
                }
                
                // Medication Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(medicationWithAdherence.medication.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(medicationWithAdherence.medication.dosage)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    // Status indicator
                    if let overdue = medicationWithAdherence.overdueDose {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 11))
                            Text("Overdue • \(formatTime(overdue.scheduledTime))")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.red)
                    } else if let next = medicationWithAdherence.nextDose {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 11))
                            Text("Next • \(formatTime(next.scheduledTime))")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Progress indicator
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(Color.primary.opacity(0.1), lineWidth: 3.5)
                            .frame(width: 44, height: 44)
                        
                        Circle()
                            .trim(from: 0, to: medicationWithAdherence.adherencePercentage)
                            .stroke(Color(hex: "11998e"), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(medicationWithAdherence.takenCount)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    
                    Text("\(medicationWithAdherence.takenCount)/\(medicationWithAdherence.totalDoses)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                // Quick action button
                if medicationWithAdherence.overdueDose != nil || medicationWithAdherence.nextDose != nil {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            onTaken()
                        }
                    }) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Color(hex: "11998e"))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .glass(cornerRadius: 18)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Pill Bottle Shape

struct PillBottleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let w = rect.width
        let h = rect.height

        // Bottle proportions
        let capHeight: CGFloat = h * 0.1
        let neckHeight: CGFloat = h * 0.06
        let bodyTop = capHeight + neckHeight
        let bodyRadius: CGFloat = min(w * 0.08, 10)
        let capInset: CGFloat = w * 0.15
        let neckInset: CGFloat = w * 0.1
        let capRadius: CGFloat = min(w * 0.06, 6)

        // Cap (top, narrower)
        path.move(to: CGPoint(x: capInset + capRadius, y: 0))
        path.addLine(to: CGPoint(x: w - capInset - capRadius, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: w - capInset, y: capRadius),
            control: CGPoint(x: w - capInset, y: 0)
        )
        path.addLine(to: CGPoint(x: w - capInset, y: capHeight))
        path.addLine(to: CGPoint(x: capInset, y: capHeight))
        path.addLine(to: CGPoint(x: capInset, y: capRadius))
        path.addQuadCurve(
            to: CGPoint(x: capInset + capRadius, y: 0),
            control: CGPoint(x: capInset, y: 0)
        )
        path.closeSubpath()

        // Neck (short connector, slightly wider than cap)
        path.move(to: CGPoint(x: neckInset, y: capHeight))
        path.addLine(to: CGPoint(x: w - neckInset, y: capHeight))
        path.addLine(to: CGPoint(x: w - neckInset, y: bodyTop))
        path.addLine(to: CGPoint(x: neckInset, y: bodyTop))
        path.closeSubpath()

        // Body (main bottle, full width, rounded bottom)
        path.move(to: CGPoint(x: 0, y: bodyTop))
        path.addLine(to: CGPoint(x: w, y: bodyTop))
        path.addLine(to: CGPoint(x: w, y: h - bodyRadius))
        path.addQuadCurve(
            to: CGPoint(x: w - bodyRadius, y: h),
            control: CGPoint(x: w, y: h)
        )
        path.addLine(to: CGPoint(x: bodyRadius, y: h))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: h - bodyRadius),
            control: CGPoint(x: 0, y: h)
        )
        path.closeSubpath()

        return path
    }
}

/// Shape for just the bottle body (used to clip water fill — excludes cap and neck)
struct PillBottleBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let w = rect.width
        let h = rect.height
        let bodyRadius: CGFloat = min(w * 0.08, 10)

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: h - bodyRadius))
        path.addQuadCurve(
            to: CGPoint(x: w - bodyRadius, y: h),
            control: CGPoint(x: w, y: h)
        )
        path.addLine(to: CGPoint(x: bodyRadius, y: h))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: h - bodyRadius),
            control: CGPoint(x: 0, y: h)
        )
        path.closeSubpath()

        return path
    }
}

// MARK: - Pill Bottle View

struct PillBottleView: View {
    let progress: CGFloat // 0...1
    let bottleWidth: CGFloat
    let bottleHeight: CGFloat

    @State private var wavePhase: Double = 0
    @State private var visualProgress: CGFloat = 0

    private let teal = Color(hex: "11998e")

    private var capHeight: CGFloat { bottleHeight * 0.1 }
    private var neckHeight: CGFloat { bottleHeight * 0.06 }
    private var bodyTop: CGFloat { capHeight + neckHeight }
    private var bodyHeight: CGFloat { bottleHeight - bodyTop }

    init(progress: CGFloat, width: CGFloat = 80, height: CGFloat = 130) {
        self.progress = min(max(progress, 0), 1)
        self.bottleWidth = width
        self.bottleHeight = height
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Bottle outline
            PillBottleShape()
                .stroke(teal.opacity(0.3), lineWidth: 2)
                .frame(width: bottleWidth, height: bottleHeight)

            // Water fill inside body only
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: bodyTop)

                ZStack(alignment: .bottom) {
                    PillBottleBodyShape()
                        .fill(Color.clear)
                        .frame(width: bottleWidth, height: bodyHeight)

                    let fillHeight = bodyHeight * visualProgress
                    ZStack {
                        WaterWave(amplitude: 3, offset: wavePhase)
                            .fill(teal.opacity(0.25))
                            .frame(height: fillHeight)

                        WaterWave(amplitude: 2.5, offset: wavePhase + 1.5)
                            .fill(
                                LinearGradient(
                                    colors: [teal.opacity(0.5), teal.opacity(0.35)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: fillHeight)
                    }
                    .frame(height: fillHeight, alignment: .bottom)
                    .clipShape(PillBottleBodyShape())
                }
                .frame(width: bottleWidth, height: bodyHeight)
            }
            .frame(width: bottleWidth, height: bottleHeight)

            // Percentage label (centered in body)
            VStack(spacing: 2) {
                Spacer()
                    .frame(height: bodyTop)

                Spacer()

                Text("\(Int(visualProgress * 100))%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                if visualProgress >= 1.0 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                }

                Spacer()
            }
            .frame(width: bottleWidth, height: bottleHeight)
        }
        .frame(width: bottleWidth, height: bottleHeight)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                visualProgress = progress
            }
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                visualProgress = min(max(newValue, 0), 1)
            }
        }
    }
}

#Preview {
    MedicationsView(viewModel: MedicationViewModel())
}
