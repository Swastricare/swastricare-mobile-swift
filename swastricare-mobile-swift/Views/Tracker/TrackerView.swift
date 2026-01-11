//
//  TrackerView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI

struct TrackerView: View {
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel = DependencyContainer.shared.trackerViewModel
    @State private var showHeartRateMeasurement = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Date Selector
                    dateSelector
                    
                    // Stats Overview
                    statsOverview
                    
                    // Weekly Chart
                    weeklyChart
                    
                    // Detailed Metrics
                    detailedMetrics
                }
                .padding(.top)
                .padding(.bottom, 80) // Space for FAB
            }
            
            // Floating Action Button for AI Analysis
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        Task { await viewModel.requestAIAnalysis() }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                            Text("Analyze with AI")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "2E3192"), Color(hex: "4A90E2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(color: Color(hex: "2E3192").opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .disabled(viewModel.healthMetrics.isEmpty || viewModel.analysisState.isAnalyzing)
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(isPresented: $viewModel.showAnalysisSheet) {
            AnalysisResultView(
                state: viewModel.analysisState,
                onDismiss: { viewModel.dismissAnalysis() }
            )
        }
        .sheet(isPresented: $showHeartRateMeasurement) {
            NavigationStack {
                HeartRateView()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var dateSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.weekDates, id: \.self) { date in
                    DateButton(
                        date: date,
                        isSelected: viewModel.isSelected(date),
                        dayName: viewModel.dayName(for: date)
                    ) {
                        Task {
                            await viewModel.selectDate(date)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var statsOverview: some View {
        HStack(spacing: 16) {
            StatCard(
                icon: "figure.walk",
                title: "Steps",
                value: "\(viewModel.stepCount)",
                color: .green
            )
            
            // Heart Rate card - tappable to measure
            Button(action: {
                showHeartRateMeasurement = true
            }) {
                HeartRateStatCard(
                    value: "\(viewModel.heartRate)",
                    color: .red
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            StatCard(
                icon: "flame.fill",
                title: "Calories",
                value: "\(viewModel.activeCalories)",
                color: .orange
            )
        }
        .padding(.horizontal)
    }
    
    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Steps")
                .font(.headline)
            
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(viewModel.weeklySteps) { metric in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                Calendar.current.isDate(metric.date, inSameDayAs: viewModel.selectedDate)
                                    ? Color(hex: "2E3192")
                                    : Color.gray.opacity(0.3)
                            )
                            .frame(
                                width: 30,
                                height: CGFloat(metric.steps) / CGFloat(max(viewModel.maxWeeklySteps, 1)) * 120
                            )
                            .animation(.easeInOut, value: metric.steps)
                        
                        Text(metric.dayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150, alignment: .bottom)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    private var detailedMetrics: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Detailed Metrics")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                MetricRow(icon: "figure.walk", title: "Steps", value: "\(viewModel.stepCount)", color: .green)
                
                // Heart Rate row with measure button
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .frame(width: 30)
                    
                    Text("Heart Rate")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(viewModel.heartRate) BPM")
                        .fontWeight(.semibold)
                    
                    Button(action: {
                        showHeartRateMeasurement = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.caption)
                            Text("Measure")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .cornerRadius(8)
                    }
                }
                .padding(.vertical, 4)
                
                MetricRow(icon: "flame.fill", title: "Active Calories", value: "\(viewModel.activeCalories) kcal", color: .orange)
                MetricRow(icon: "clock.fill", title: "Exercise", value: "\(viewModel.exerciseMinutes) mins", color: .blue)
                MetricRow(icon: "figure.stand", title: "Stand Hours", value: "\(viewModel.standHours) hrs", color: .purple)
                MetricRow(icon: "moon.fill", title: "Sleep", value: viewModel.sleepHours, color: .indigo)
                MetricRow(icon: "arrow.left.and.right", title: "Distance", value: String(format: "%.2f km", viewModel.distance), color: .cyan)
            }
            .padding()
            .glass(cornerRadius: 16)
            .padding(.horizontal)
        }
    }
}

// MARK: - Supporting Views

private struct DateButton: View {
    let date: Date
    let isSelected: Bool
    let dayName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(dayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .secondary)
                
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 50, height: 60)
            .background(
                isSelected
                    ? Color(hex: "2E3192")
                    : Color.clear
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

private struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .padding(10)
                .background(color.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct HeartRateStatCard: View {
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
                    .padding(10)
                    .background(color.opacity(0.2))
                    .clipShape(Circle())
                
                Spacer()
                
                // Camera indicator
                Image(systemName: "camera.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(color)
                    .padding(6)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Text("Heart Rate")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct MetricRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Analysis Result View

private struct AnalysisResultView: View {
    let state: AnalysisState
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if state.isAnalyzing {
                            analyzingView
                        } else if let result = state.result {
                            analysisContent(result)
                        } else if case .error(let message) = state {
                            errorView(message)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("AI Health Analysis")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var analyzingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Swastrica is analyzing your health data...")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("This may take a few moments")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func analysisContent(_ result: HealthAnalysisResult) -> some View {
        VStack(spacing: 20) {
            // Sparkle Icon
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "2E3192"), Color(hex: "4A90E2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top)
            
            // Assessment Section
            VStack(alignment: .leading, spacing: 12) {
                Label("Overall Assessment", systemImage: "heart.text.square.fill")
                    .font(.headline)
                    .foregroundColor(Color(hex: "2E3192"))
                
                Text(result.analysis.assessment)
                    .font(.body)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glass(cornerRadius: 16)
            
            // Insights Section
            VStack(alignment: .leading, spacing: 12) {
                Label("Key Insights", systemImage: "lightbulb.fill")
                    .font(.headline)
                    .foregroundColor(Color(hex: "2E3192"))
                
                Text(result.analysis.insights)
                    .font(.body)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glass(cornerRadius: 16)
            
            // Recommendations Section
            VStack(alignment: .leading, spacing: 12) {
                Label("Recommendations", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundColor(Color(hex: "2E3192"))
                
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(result.analysis.recommendations.enumerated()), id: \.offset) { index, rec in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1).")
                                .fontWeight(.semibold)
                                .foregroundColor(Color(hex: "2E3192"))
                            Text(rec)
                                .font(.body)
                                .lineSpacing(4)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glass(cornerRadius: 16)
            
            // Timestamp
            Text("Analysis generated on \(result.timestamp.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Analysis Error")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "2E3192"))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        TrackerView()
    }
}

