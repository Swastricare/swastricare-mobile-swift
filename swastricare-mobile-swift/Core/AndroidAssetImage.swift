//
//  AndroidAssetImage.swift
//  swastricare-mobile-swift
//
//  SwiftUI helpers for loading raw image files copied from Android's
//  `app/src/main/assets/{icons,images,illustrations}` folders. These files
//  ship in the bundle (file system synchronized) under their original
//  Android filenames (with spaces preserved), so we look them up by
//  bare basename — bundle resources are flattened to the bundle root.
//

import SwiftUI
import UIKit

extension Image {
    /// Load an icon copied from `android/app/src/main/assets/icons/` by its
    /// raw filename (without extension). Example: `Image.androidIcon("ai illustration")`.
    static func androidIcon(_ name: String, ext: String = "png") -> Image {
        bundleImage(name: name, ext: ext)
    }

    /// Load an illustration copied from `android/app/src/main/assets/illustrations/`.
    static func androidIllustration(_ name: String, ext: String = "png") -> Image {
        bundleImage(name: name, ext: ext)
    }

    /// Load an image copied from `android/app/src/main/assets/images/`.
    static func androidImage(_ name: String, ext: String = "png") -> Image {
        bundleImage(name: name, ext: ext)
    }

    private static func bundleImage(name: String, ext: String) -> Image {
        if let url = Bundle.main.url(forResource: name, withExtension: ext),
           let ui = UIImage(contentsOfFile: url.path) {
            return Image(uiImage: ui).renderingMode(.original)
        }
        // Fallback to system placeholder so missing files are obvious during dev.
        return Image(systemName: "questionmark.square.dashed")
    }
}
