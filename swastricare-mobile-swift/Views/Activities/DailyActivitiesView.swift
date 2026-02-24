//
//  DailyActivitiesView.swift
//  swastricare-mobile-swift
//
//  Daily Activities screen with steps, weight, heart rate, and body composition
//

import SwiftUI

struct DailyActivitiesView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var homeViewModel = DependencyContainer.shared.homeViewModel
    
    // MARK: - State
    
    @State private var showHeartRateDetail = false
    @State private var hasAppeared = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, 8)
                    
                    agendaSection
                        .padding(.top, 32)
                    
                    stepsSection
                        .padding(.top, 8)
                    
                    statsGridSection
                        .padding(.top, 24)
                    
                    bodyCompositionSection
                        .padding(.top, 16)
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showHeartRateDetail) {
            NavigationStack {
                TargetHeartRateView()
            }
        }
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
            
            Text("Daily Activities")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {}) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "info.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : -20)
    }
    
    // MARK: - Agenda Section
    
    private var agendaSection: some View {
        HStack {
            Text("1 Agenda:")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            
            Text("Walking")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(MovementsColors.limeGreen)
            
            Spacer()
        }
        .opacity(hasAppeared ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: hasAppeared)
    }
    
    // MARK: - Steps Section
    
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Steps")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(formatSteps(homeViewModel.stepCount))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: hasAppeared)
    }
    
    // MARK: - Stats Grid Section
    
    private var statsGridSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            MovementsStatCard(
                title: "Weight",
                value: "72.2",
                unit: "kg",
                icon: "scalemass.fill",
                backgroundColor: .white,
                textColor: .black
            )
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: hasAppeared)
            
            MovementsStatCard(
                title: "Heart Rate",
                value: "\(homeViewModel.heartRate > 0 ? homeViewModel.heartRate : 101)",
                unit: "bpm",
                icon: "heart.fill",
                backgroundColor: MovementsColors.darkGreen,
                textColor: .white,
                showChart: true
            ) {
                showHeartRateDetail = true
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: hasAppeared)
        }
    }
    
    // MARK: - Body Composition Section
    
    private var bodyCompositionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                FluidProgressIndicator(progress: 0.879)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Body Composition")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Spacer()
                        
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    
                    Spacer()
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("87.9")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("%")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Text("Muscle Mass")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(20)
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35), value: hasAppeared)
    }
    
    // MARK: - Helper Methods
    
    private func formatSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DailyActivitiesView()
    }
}
