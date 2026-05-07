//
//  SplashView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI
import Lottie

struct SplashView: View {
    @Binding var fadeOut: Bool

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            LottieView(animation: .named("swasrticare-logo"))
                .playing(loopMode: .playOnce)
                .animationSpeed(1.0)
                .frame(width: 180, height: 180)

            Color.white
                .ignoresSafeArea()
                .opacity(fadeOut ? 1 : 0)
                .animation(.easeInOut(duration: 0.4), value: fadeOut)
        }
        .trackScreen("Splash")
    }
}

#Preview {
    SplashView(fadeOut: .constant(false))
}
