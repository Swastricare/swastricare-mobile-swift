//
//  SplashView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI
import AVFoundation

struct SplashView: View {
    @Binding var fadeOut: Bool

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            SplashVideoPlayer()
                .ignoresSafeArea()

            // Fade-to-black overlay for cinematic exit transition
            Color.black
                .ignoresSafeArea()
                .opacity(fadeOut ? 1 : 0)
                .animation(.easeInOut(duration: 0.4), value: fadeOut)
        }
        .trackScreen("Splash")
    }
}

// MARK: - Video Player (UIViewRepresentable)

/// A zero-chrome AVPlayerLayer wrapper that plays the splash video once
/// and holds on the final frame (logo + "Swastricare" text).
private struct SplashVideoPlayer: UIViewRepresentable {

    func makeUIView(context: Context) -> UIView {
        let view = PlayerContainerView()
        view.backgroundColor = .black

        guard let url = Bundle.main.url(forResource: "Sw Logo V1", withExtension: "mp4") else {
            print("⚠️ SplashView: Sw Logo V1.mp4 not found in bundle")
            return view
        }

        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .none  // Hold on the last frame
        player.isMuted = true

        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill

        player.play()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Player Container View

/// UIView subclass that hosts an AVPlayerLayer and keeps it sized to bounds.
private class PlayerContainerView: UIView {

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

#Preview {
    SplashView(fadeOut: .constant(false))
}
