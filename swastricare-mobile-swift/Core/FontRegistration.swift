//
//  FontRegistration.swift
//  swastricare-mobile-swift
//
//  Registers bundled Poppins TTFs with CoreText at runtime so we can use
//  them without listing them in Info.plist (UIAppFonts).
//

import CoreText
import Foundation

enum FontRegistration {
    private static let fontFiles = [
        "Poppins-Bold",
        "Poppins-SemiBold",
        "Poppins-Medium",
        "Poppins-Regular",
        "Poppins-Light",
    ]

    static func registerBundledFonts() {
        let urls: [URL] = fontFiles.compactMap { name in
            Bundle.main.url(forResource: name, withExtension: "ttf")
        }

        guard urls.isEmpty == false else { return }

        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
    }
}
