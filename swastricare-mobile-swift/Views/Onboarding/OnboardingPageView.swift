//
//  OnboardingPageView.swift
//  swastricare-mobile-swift
//
//  Redesigned to pixel-match Android OnboardingPageContent.
//  • Hero illustration fills the top weight(1) area
//  • Text block: italic+bold prefix, teal highlighted suffix
//  • Optional card content below (feature cards on page 0)
//

import SwiftUI

private let darkText  = Color(hex: "0F172A")
private let mutedText = Color(hex: "6B7280")

struct OnboardingPageView<Card: View>: View {
    let pageIndex: Int
    let illustrationName: String
    let isFamilyHero: Bool      // true → horizontal-edge fade; false → simple fill
    let titlePrefix: String
    let titleItalic: String
    let titleSeparator: String
    let titleHighlight: String
    let subtitle: String
    let isActive: Bool
    let card: Card

    init(
        pageIndex: Int,
        illustrationName: String,
        isFamilyHero: Bool,
        titlePrefix: String,
        titleItalic: String,
        titleSeparator: String,
        titleHighlight: String,
        subtitle: String,
        isActive: Bool,
        @ViewBuilder card: () -> Card
    ) {
        self.pageIndex = pageIndex
        self.illustrationName = illustrationName
        self.isFamilyHero = isFamilyHero
        self.titlePrefix = titlePrefix
        self.titleItalic = titleItalic
        self.titleSeparator = titleSeparator
        self.titleHighlight = titleHighlight
        self.subtitle = subtitle
        self.isActive = isActive
        self.card = card()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Hero illustration — takes flexible top space
            GeometryReader { geo in
                if isFamilyHero {
                    // Page 0: horizontal-edge fade on the image + 56pt top/bottom fades
                    // (mirrors Android drawWithContent + verticalGradient overlays)
                    ZStack {
                        Image.androidImage(illustrationName)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 320)
                            .mask(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .black, location: 0.28),
                                        .init(color: .black, location: 0.72),
                                        .init(color: .clear, location: 1)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Top-edge fade (white → transparent), 56pt tall
                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 56)
                            Spacer(minLength: 0)
                        }

                        // Bottom-edge fade (transparent → white), 56pt tall
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            LinearGradient(
                                colors: [Color.white.opacity(0), Color.white],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 56)
                        }
                    }
                    .allowsHitTesting(false)
                } else {
                    // Pages 1 & 2: simple centered illustration
                    Image.androidImage(illustrationName)
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            // Give the illustration the same flex weight as Android's weight(1f)
            .frame(minHeight: 200)
            .layoutPriority(1)

            // Text + cards block
            VStack(alignment: .center, spacing: 0) {
                // Composed title: prefix (bold) + italic (bold+italic) + highlight (teal bold)
                titleText
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)

                Spacer().frame(height: 10)

                Text(subtitle)
                    .font(.poppins(.regular, size: 13))
                    .lineSpacing(6)
                    .foregroundColor(mutedText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 28)

                // Optional card content (page 0 gets feature cards)
                if Card.self != EmptyView.self {
                    Spacer().frame(height: 18)
                    card
                        .padding(.horizontal, 20)
                }

                Spacer().frame(height: 12)
            }
        }
        .background(Color.white)
    }

    // MARK: - Title Text

    private var titleText: some View {
        // Build attributed string: prefix(bold) + italic(bold+italic) + separator(bold) + highlight(teal bold)
        (
            Text(titlePrefix)
                .foregroundColor(darkText)
            +
            Text(titleItalic)
                .foregroundColor(darkText)
                .italic()
            +
            Text(titleSeparator)
                .foregroundColor(darkText)
            +
            Text(titleHighlight)
                .foregroundColor(AppColors.aiTeal)
        )
        .font(.poppins(.bold, size: 24))
    }
}
