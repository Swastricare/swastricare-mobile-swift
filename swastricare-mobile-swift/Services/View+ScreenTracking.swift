//
//  View+ScreenTracking.swift
//  swastricare-mobile-swift
//
//  Attaches a screen_view analytics event (with dwell time) to any SwiftUI View.
//  Usage: add .trackScreen("ScreenName") to the outermost view of each full screen.
//

import SwiftUI

private struct ScreenTrackingModifier: ViewModifier {
    let screenName: String
    @State private var enteredAt: Date?

    func body(content: Content) -> some View {
        content
            .onAppear { enteredAt = Date() }
            .onDisappear {
                let duration = enteredAt.map { Int(Date().timeIntervalSince($0)) } ?? 0
                AppAnalyticsService.shared.logScreen(screenName, durationSeconds: duration)
                enteredAt = nil
            }
    }
}

extension View {
    func trackScreen(_ name: String) -> some View {
        modifier(ScreenTrackingModifier(screenName: name))
    }
}
