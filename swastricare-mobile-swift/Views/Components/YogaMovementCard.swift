//
//  YogaMovementCard.swift
//  swastricare-mobile-swift
//
//  Yoga movement card with inline poses carousel.
//

import SwiftUI

struct YogaMovementCard: View {
    @State private var showAllPoses = false

    var body: some View {
        MovementsActivityCard(
            title: "Yoga",
            subtitle: "Morning flow",
            progress: 0.65,
            icon: "figure.yoga",
            backgroundColor: Color(hex: "AF52DE"),
            progressColor: .white,
            contentColor: .white,
            showGeometricPattern: false
        ) {
            showAllPoses = true
        } onExpandTapped: {
            showAllPoses = true
        }
        .fullScreenCover(isPresented: $showAllPoses) {
            NavigationStack {
                YogaLibraryView()
            }
        }
    }
}

#Preview {
    ScrollView(.horizontal) {
        HStack(spacing: 16) {
            YogaMovementCard()
        }
        .padding()
    }
}

