//
//  YogaPoseDetailView.swift
//  swastricare-mobile-swift
//
//  Detailed view for a single yoga pose
//

import SwiftUI

struct YogaPoseDetailView: View {
    
    // MARK: - Properties
    
    let pose: YogaPose
    @Environment(\.dismiss) private var dismiss
    @State private var showFullDescription = false
    @State private var hasAppeared = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerImageSection
                    contentSection
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
        }
    }
    
    // MARK: - Header Image Section
    
    private var headerImageSection: some View {
        ZStack(alignment: .top) {
            AsyncImage(url: pose.imageURL) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(MovementsColors.cardDark)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: MovementsColors.limeGreen))
                                .scaleEffect(1.5)
                        )
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .background(Color.white.opacity(0.05))
                case .failure:
                    Rectangle()
                        .fill(MovementsColors.cardDark)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "figure.yoga")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("Image unavailable")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .frame(height: 280)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        pose.difficulty?.color.opacity(0.3) ?? Color.purple.opacity(0.3),
                        Color.black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            HStack {
                Button(action: { dismiss() }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                if let difficulty = pose.difficulty {
                    HStack(spacing: 6) {
                        Image(systemName: difficulty.icon)
                            .font(.system(size: 12))
                        Text(difficulty.displayName)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(difficulty.color)
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
        }
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            titleSection
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
            
            if let category = pose.categoryName {
                categoryBadge(category)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: hasAppeared)
            }
            
            if let description = pose.poseDescription, !description.isEmpty {
                descriptionSection(description)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: hasAppeared)
            }
            
            benefitsSection
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: hasAppeared)
            
            translationSection
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: hasAppeared)
            
            Spacer(minLength: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pose.englishName)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            HStack(spacing: 8) {
                Text(pose.sanskritName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(MovementsColors.limeGreen)
                
                Text("•")
                    .foregroundColor(.white.opacity(0.3))
                
                Text(pose.sanskritNameAdapted)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    // MARK: - Category Badge
    
    private func categoryBadge(_ category: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "tag.fill")
                .font(.system(size: 12))
            Text(category)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.1))
        )
    }
    
    // MARK: - Description Section
    
    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 14))
                    .foregroundColor(MovementsColors.limeGreen)
                
                Text("How to Practice")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(description)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(6)
                .lineLimit(showFullDescription ? nil : 4)
            
            if description.count > 200 {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showFullDescription.toggle()
                    }
                }) {
                    Text(showFullDescription ? "Show Less" : "Read More")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(MovementsColors.limeGreen)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(MovementsColors.cardDark)
        )
    }
    
    // MARK: - Benefits Section
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "FF6B6B"))
                
                Text("Benefits")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(pose.benefitsList.enumerated()), id: \.offset) { index, benefit in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(MovementsColors.limeGreen.opacity(0.2))
                                .frame(width: 24, height: 24)
                            
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(MovementsColors.limeGreen)
                        }
                        
                        Text(benefit)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .lineSpacing(4)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(MovementsColors.cardDark)
        )
    }
    
    // MARK: - Translation Section
    
    private var translationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "FFB347"))
                
                Text("Sanskrit Translation")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(pose.translationName)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(MovementsColors.cardDark)
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        YogaPoseDetailView(pose: YogaPose.sample)
    }
}
