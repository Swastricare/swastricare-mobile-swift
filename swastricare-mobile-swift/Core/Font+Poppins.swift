//
//  Font+Poppins.swift
//  swastricare-mobile-swift
//
//  Mirrors Android `ui/theme/Type.kt` — Poppins typography tokens for cross-platform parity.
//

import SwiftUI

extension Font {
    enum PoppinsWeight {
        case bold
        case semiBold
        case medium
        case regular
        case light

        var fontName: String {
            switch self {
            case .bold:     return "Poppins-Bold"
            case .semiBold: return "Poppins-SemiBold"
            case .medium:   return "Poppins-Medium"
            case .regular:  return "Poppins-Regular"
            case .light:    return "Poppins-Light"
            }
        }
    }

    static func poppins(_ weight: PoppinsWeight, size: CGFloat) -> Font {
        .custom(weight.fontName, size: size)
    }

    // Token parity with Android Type.kt. Sizes match Material 3 TextStyle definitions there.
    static let pHeadlineLarge  = Font.custom(PoppinsWeight.bold.fontName,     size: 28)
    static let pHeadlineMedium = Font.custom(PoppinsWeight.semiBold.fontName, size: 22)
    static let pHeadlineSmall  = Font.custom(PoppinsWeight.semiBold.fontName, size: 18)
    static let pTitleLarge     = Font.custom(PoppinsWeight.semiBold.fontName, size: 20)
    static let pTitleMedium    = Font.custom(PoppinsWeight.medium.fontName,   size: 16)
    static let pTitleSmall     = Font.custom(PoppinsWeight.medium.fontName,   size: 14)
    static let pBodyLarge      = Font.custom(PoppinsWeight.regular.fontName,  size: 16)
    static let pBodyMedium     = Font.custom(PoppinsWeight.regular.fontName,  size: 14)
    static let pBodySmall      = Font.custom(PoppinsWeight.regular.fontName,  size: 12)
    static let pLabelLarge     = Font.custom(PoppinsWeight.medium.fontName,   size: 14)
    static let pLabelMedium    = Font.custom(PoppinsWeight.medium.fontName,   size: 12)
    static let pLabelSmall     = Font.custom(PoppinsWeight.medium.fontName,   size: 10)
}
