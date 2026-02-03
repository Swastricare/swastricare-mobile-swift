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

struct LocalHeartRateMeasurement: Identifiable, Codable, Equatable {
    let id: UUID
    let bpm: Int
    let measuredAt: Date
    let confidence: Double?
    let deviceUsed: String?
    let source: String
    
    init(
        id: UUID = UUID(),
        bpm: Int,
        measuredAt: Date = Date(),
        confidence: Double? = nil,
        deviceUsed: String? = nil,
        source: String = "camera"
    ) {
        self.id = id
        self.bpm = bpm
        self.measuredAt = measuredAt
        self.confidence = confidence
        self.deviceUsed = deviceUsed
        self.source = source
    }
}

final class HeartRateLocalStorage {
    
    static let shared = HeartRateLocalStorage()
    
    private init() {}
    
    private enum Keys {
        static let lastReading = "last_camera_heart_rate_reading_v1"
        static let history = "camera_heart_rate_history_v1"
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
    
    func appendMeasurement(
        bpm: Int,
        date: Date = Date(),
        confidence: Double? = nil,
        deviceUsed: String? = nil,
        source: String = "camera",
        maxItems: Int = 200
    ) {
        var history = loadHistory(limit: maxItems)
        history.insert(
            LocalHeartRateMeasurement(
                bpm: bpm,
                measuredAt: date,
                confidence: confidence,
                deviceUsed: deviceUsed,
                source: source
            ),
            at: 0
        )
        
        // Keep most recent N items
        if history.count > maxItems {
            history = Array(history.prefix(maxItems))
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(history) else {
            print("❤️ HeartRateLocalStorage: Failed to encode history")
            return
        }
        UserDefaults.standard.set(data, forKey: Keys.history)
    }
    
    func loadLastMeasured() -> LocalHeartRateReading? {
        guard let data = UserDefaults.standard.data(forKey: Keys.lastReading) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(LocalHeartRateReading.self, from: data)
    }
    
    func loadHistory(limit: Int = 200) -> [LocalHeartRateMeasurement] {
        // Migrate the old "last reading" into history if needed.
        if UserDefaults.standard.data(forKey: Keys.history) == nil,
           let last = loadLastMeasured() {
            let migrated = [LocalHeartRateMeasurement(bpm: last.bpm, measuredAt: last.measuredAt)]
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(migrated) {
                UserDefaults.standard.set(data, forKey: Keys.history)
            }
        }
        
        guard let data = UserDefaults.standard.data(forKey: Keys.history) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = (try? decoder.decode([LocalHeartRateMeasurement].self, from: data)) ?? []
        let sorted = decoded.sorted(by: { $0.measuredAt > $1.measuredAt })
        return Array(sorted.prefix(limit))
    }
    
    func deleteMeasurement(id: UUID) {
        let history = loadHistory(limit: 500).filter { $0.id != id }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(history) else { return }
        UserDefaults.standard.set(data, forKey: Keys.history)
    }
    
    func clearHistory() {
        UserDefaults.standard.removeObject(forKey: Keys.history)
    }
    
    /// Returns the last measured BPM if it's "recent enough" to be useful as a fallback.
    /// This avoids showing a stale value forever when Apple Health has no data.
    func loadLastMeasuredBpmIfRecent(maxAgeSeconds: TimeInterval = 24 * 60 * 60) -> Int? {
        guard let reading = loadLastMeasured() else { return nil }
        guard abs(reading.measuredAt.timeIntervalSinceNow) <= maxAgeSeconds else { return nil }
        return reading.bpm
    }
}

