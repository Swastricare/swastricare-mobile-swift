//
//  NotificationImageGenerator.swift
//  swastricare-mobile-swift
//
//  Generates progress ring images for rich notification attachments.
//  The image is saved to a temp file and attached via UNNotificationAttachment.
//

import UIKit
import SwiftUI
import UserNotifications

enum NotificationImageGenerator {

    /// Generate a progress ring image and return the file URL for attachment,
    /// or `nil` if generation fails.
    static func generateProgressRing(progress: Double, remainingMl: Int) -> URL? {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 80
            let lineWidth: CGFloat = 14

            // Background ring
            let bgPath = UIBezierPath(
                arcCenter: center,
                radius: radius,
                startAngle: -.pi / 2,
                endAngle: 2 * .pi - .pi / 2,
                clockwise: true
            )
            UIColor(white: 1.0, alpha: 0.15).setStroke()
            bgPath.lineWidth = lineWidth
            bgPath.lineCapStyle = .round
            bgPath.stroke()

            // Progress ring
            let clampedProgress = min(max(progress, 0), 1.0)
            let endAngle = -.pi / 2 + 2 * .pi * CGFloat(clampedProgress)
            let progressPath = UIBezierPath(
                arcCenter: center,
                radius: radius,
                startAngle: -.pi / 2,
                endAngle: endAngle,
                clockwise: true
            )
            // Use design system colors for consistency
            let ringColor: UIColor = clampedProgress >= 1.0
                ? UIColor(AppColors.accentGreen)
                : UIColor(AppColors.hydration)
            ringColor.setStroke()
            progressPath.lineWidth = lineWidth
            progressPath.lineCapStyle = .round
            progressPath.stroke()

            // Percentage text
            let percentText = "\(Int(clampedProgress * 100))%"
            let percentAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 44, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let percentSize = (percentText as NSString).size(withAttributes: percentAttrs)
            let percentOrigin = CGPoint(
                x: center.x - percentSize.width / 2,
                y: center.y - percentSize.height / 2 - 8
            )
            (percentText as NSString).draw(at: percentOrigin, withAttributes: percentAttrs)

            // Remaining ml text
            let mlText = "\(remainingMl)ml left"
            let mlAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: UIColor(white: 1.0, alpha: 0.7)
            ]
            let mlSize = (mlText as NSString).size(withAttributes: mlAttrs)
            let mlOrigin = CGPoint(
                x: center.x - mlSize.width / 2,
                y: center.y + percentSize.height / 2 - 8
            )
            (mlText as NSString).draw(at: mlOrigin, withAttributes: mlAttrs)
        }

        // Write to temp file
        guard let pngData = image.pngData() else { return nil }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("hydration_progress_\(UUID().uuidString).png")
        do {
            try pngData.write(to: fileURL)
            return fileURL
        } catch {
            print("🔔 NotificationImageGenerator: Failed to write image — \(error.localizedDescription)")
            return nil
        }
    }

    /// Cached image URL for the current scheduling batch.
    /// Call `clearCache()` before each scheduling cycle to avoid stale reuse.
    private static var cachedImageURL: URL?
    private static var cachedProgress: Double = -1
    private static var cachedRemainingMl: Int = -1

    /// Create a UNNotificationAttachment from a progress ring image.
    /// Caches the generated image so identical notifications in a batch share one file.
    static func progressAttachment(progress: Double, remainingMl: Int) -> UNNotificationAttachment? {
        // Reuse cached image if progress values match (same scheduling batch)
        if let cached = cachedImageURL,
           cachedProgress == progress, cachedRemainingMl == remainingMl,
           FileManager.default.fileExists(atPath: cached.path) {
            // UNNotificationAttachment moves the file, so copy for reuse
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("hydration_progress_\(UUID().uuidString).png")
            try? FileManager.default.copyItem(at: cached, to: copy)
            return try? UNNotificationAttachment(
                identifier: "hydration-progress",
                url: copy,
                options: [UNNotificationAttachmentOptionsThumbnailHiddenKey: false]
            )
        }

        guard let url = generateProgressRing(progress: progress, remainingMl: remainingMl) else {
            return nil
        }

        // Cache for subsequent calls in the same batch
        cachedImageURL = url
        cachedProgress = progress
        cachedRemainingMl = remainingMl

        // Keep a copy since UNNotificationAttachment moves the original
        let masterCopy = FileManager.default.temporaryDirectory
            .appendingPathComponent("hydration_progress_master.png")
        try? FileManager.default.removeItem(at: masterCopy)
        try? FileManager.default.copyItem(at: url, to: masterCopy)
        cachedImageURL = masterCopy

        return try? UNNotificationAttachment(
            identifier: "hydration-progress",
            url: url,
            options: [UNNotificationAttachmentOptionsThumbnailHiddenKey: false]
        )
    }

    /// Clean up old progress images from the temp directory.
    /// Call at the start of each scheduling cycle.
    static func clearCache() {
        cachedImageURL = nil
        cachedProgress = -1
        cachedRemainingMl = -1

        let tempDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(
            at: tempDir, includingPropertiesForKeys: nil
        ) {
            for file in files where file.lastPathComponent.hasPrefix("hydration_progress_") {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
