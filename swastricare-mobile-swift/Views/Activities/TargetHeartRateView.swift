//
//  TargetHeartRateView.swift
//  swastricare-mobile-swift
//
//  Target Heart Rate Zone screen with bar chart and benchmark ranges
//

import SwiftUI

struct TargetHeartRateView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var hasAppeared = false
    @State private var selectedTimeRange = "Today"
    
    private let timeRanges = ["Today", "Week", "Month"]
    
    private let heartRateData: [(String, Int, Bool)] = [
        ("6AM", 85, false),
        ("9AM", 120, true),
        ("12PM", 95, false),
        ("3PM", 140, true),
        ("6PM", 110, true),
        ("9PM", 75, false)
    ]
    
    private let benchmarkData: [(String, Double, Color)] = [
        ("Light", 45, Color(hex: "4ECDC4")),
        ("REM", 72, Color(hex: "45B7D1")),
        ("Deep", 38, Color(hex: "5856D6")),
        ("Awake", 15, Color(hex: "FF6B6B"))
    ]
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, 8)
                    
                    titleSection
                        .padding(.top, 32)
                    
                    timeRangeSelector
                        .padding(.top, 24)
                    
                    chartSection
                        .padding(.top, 24)
                    
                    fatBurnIndicator
                        .padding(.top, 16)
                    
                    benchmarkSection
                        .padding(.top, 32)
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            Button(action: {}) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : -20)
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target Heart")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
            
            Text("Rate Zone")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: hasAppeared)
    }
    
    // MARK: - Time Range Selector
    
    private var timeRangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(timeRanges, id: \.self) { range in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTimeRange = range
                    }
                }) {
                    Text(range)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selectedTimeRange == range ? .black : .white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedTimeRange == range
                                ? MovementsColors.limeGreen
                                : Color.clear
                        )
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: hasAppeared)
    }
    
    // MARK: - Chart Section
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Heart Rate Tracking")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(MovementsColors.limeGreen)
                        .frame(width: 8, height: 8)
                    
                    Text("Fat Burn Zone")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            HeartRateBarChart(data: heartRateData)
                .frame(height: 180)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(MovementsColors.cardDark)
        )
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: hasAppeared)
    }
    
    // MARK: - Fat Burn Indicator
    
    private var fatBurnIndicator: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(MovementsColors.limeGreen.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 22))
                    .foregroundColor(MovementsColors.limeGreen)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Fat Burn Zone Active")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("120-150 BPM optimal range")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Text("3h 24m")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(MovementsColors.limeGreen)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(MovementsColors.cardDark)
        )
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: hasAppeared)
    }
    
    // MARK: - Benchmark Section
    
    private var benchmarkSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Benchmark Ranges")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {}) {
                    Text("See All")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(MovementsColors.limeGreen)
                }
            }
            
            VStack(spacing: 16) {
                ForEach(Array(benchmarkData.enumerated()), id: \.offset) { index, item in
                    BenchmarkRangeBar(
                        title: item.0,
                        value: item.1,
                        maxValue: 100,
                        color: item.2
                    )
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(x: hasAppeared ? 0 : -20)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.8)
                            .delay(0.35 + Double(index) * 0.05),
                        value: hasAppeared
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(MovementsColors.cardDark)
        )
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35), value: hasAppeared)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TargetHeartRateView()
    }
}
