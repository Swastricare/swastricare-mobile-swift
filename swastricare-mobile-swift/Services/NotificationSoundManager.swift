//
//  NotificationSoundManager.swift
//  swastricare-mobile-swift
//
//  Generates and manages a custom water drop notification sound.
//  The sound is created at runtime as a short sine wave tone and saved
//  to Library/Sounds/ so UNNotificationSound(named:) can reference it.
//

import Foundation
import UserNotifications
import AVFoundation

enum NotificationSoundManager {

    static let fileName = "water_drop.wav"

    /// The custom notification sound, falling back to `.default` if generation failed.
    static var notificationSound: UNNotificationSound {
        if hasSoundFile {
            return UNNotificationSound(named: UNNotificationSoundName(fileName))
        }
        return .default
    }

    /// Whether the custom sound file already exists in Library/Sounds/.
    static var hasSoundFile: Bool {
        FileManager.default.fileExists(atPath: soundFileURL.path)
    }

    /// Call once on first launch (e.g., in AppDelegate) to ensure the sound exists.
    static func ensureSoundFile() {
        guard !hasSoundFile else { return }

        do {
            // Create Library/Sounds/ directory if needed
            let dir = soundFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            // Generate a short "water drop" tone and write it
            let data = generateWaterDropWav()
            try data.write(to: soundFileURL)
            print("🔔 NotificationSoundManager: Created custom sound at \(soundFileURL.path)")
        } catch {
            print("🔔 NotificationSoundManager: Failed to create sound — \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private static var soundFileURL: URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return library.appendingPathComponent("Sounds/\(fileName)")
    }

    /// Generate a ~0.25 s "water drop" tone as a WAV byte buffer.
    /// Uses a descending sine sweep (1200→400 Hz) with exponential decay,
    /// followed by a tiny secondary "splash" ripple.
    private static func generateWaterDropWav() -> Data {
        let sampleRate: Double = 44100
        let duration: Double = 0.25
        let totalSamples = Int(sampleRate * duration)

        var samples = [Int16](repeating: 0, count: totalSamples)

        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate

            // Primary drop: descending frequency sweep with exponential decay
            let freq = 1200.0 - 800.0 * (t / duration)          // 1200→400 Hz
            let envelope = exp(-t * 16.0)                         // fast decay
            let primary = sin(2.0 * .pi * freq * t) * envelope

            // Secondary splash: short burst starting at 0.08 s
            var splash = 0.0
            let splashStart = 0.08
            if t > splashStart {
                let st = t - splashStart
                let splashFreq = 900.0 - 600.0 * (st / (duration - splashStart))
                let splashEnv = exp(-st * 24.0) * 0.4
                splash = sin(2.0 * .pi * splashFreq * st) * splashEnv
            }

            let value = (primary + splash) * 0.85  // headroom
            samples[i] = Int16(clamping: Int(value * Double(Int16.max)))
        }

        return wavData(samples: samples, sampleRate: Int(sampleRate))
    }

    /// Wrap raw 16-bit mono PCM samples in a minimal WAV container.
    private static func wavData(samples: [Int16], sampleRate: Int) -> Data {
        var data = Data()

        let dataSize = samples.count * 2  // 16-bit = 2 bytes
        let fileSize = 36 + dataSize

        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        data.append(uint32LE: UInt32(fileSize))
        data.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        data.append(contentsOf: "fmt ".utf8)
        data.append(uint32LE: 16)                       // chunk size
        data.append(uint16LE: 1)                         // PCM format
        data.append(uint16LE: 1)                         // mono
        data.append(uint32LE: UInt32(sampleRate))        // sample rate
        data.append(uint32LE: UInt32(sampleRate * 2))    // byte rate
        data.append(uint16LE: 2)                         // block align
        data.append(uint16LE: 16)                        // bits per sample

        // data chunk
        data.append(contentsOf: "data".utf8)
        data.append(uint32LE: UInt32(dataSize))
        for sample in samples {
            data.append(uint16LE: UInt16(bitPattern: sample))
        }

        return data
    }
}

// MARK: - Data helpers for little-endian encoding

private extension Data {
    mutating func append(uint16LE value: UInt16) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 2))
    }
    mutating func append(uint32LE value: UInt32) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 4))
    }
}
