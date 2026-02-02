//
//  HeartRateLocalStorage.swift
//  swastricare-mobile-swift
//
//  Stores the most recent camera-measured heart rate locally
//  so Home/Vitals can show a fallback when Apple Health has no data.
//

import Foundation

struct LocalHeartRateReading: Codable, Equatable {
    let bpm: Int
    let measuredAt: Date
}

final class HeartRateLocalStorage {
    
    static let shared = HeartRateLocalStorage()
    
    private init() {}
    
    private enum Keys {
        static let lastReading = "last_camera_heart_rate_reading_v1"
    }
    
    func saveLastMeasured(bpm: Int, date: Date = Date()) {
        let reading = LocalHeartRateReading(bpm: bpm, measuredAt: date)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(reading) else {
            print("❤️ HeartRateLocalStorage: Failed to encode reading")
            return
        }
        UserDefaults.standard.set(data, forKey: Keys.lastReading)
    }
    
    func loadLastMeasured() -> LocalHeartRateReading? {
        guard let data = UserDefaults.standard.data(forKey: Keys.lastReading) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(LocalHeartRateReading.self, from: data)
    }
    
    /// Returns the last measured BPM if it's "recent enough" to be useful as a fallback.
    /// This avoids showing a stale value forever when Apple Health has no data.
    func loadLastMeasuredBpmIfRecent(maxAgeSeconds: TimeInterval = 24 * 60 * 60) -> Int? {
        guard let reading = loadLastMeasured() else { return nil }
        guard abs(reading.measuredAt.timeIntervalSinceNow) <= maxAgeSeconds else { return nil }
        return reading.bpm
    }
}

