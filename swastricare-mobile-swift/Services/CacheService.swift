import Foundation

@MainActor
protocol CacheServiceProtocol {
    func save<T: Codable>(_ data: T, forKey key: String, ttl: TimeInterval) throws
    func load<T: Codable>(forKey key: String, as type: T.Type) -> T?
    func remove(forKey key: String)
    func clearAll(forUserId userId: String)
    func setCurrentUser(_ userId: String)
}

@MainActor
final class CacheService: CacheServiceProtocol {
    static let shared = CacheService()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var currentUserId: String?

    private var cacheDirectory: URL {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HealthCache", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func setCurrentUser(_ userId: String) {
        currentUserId = userId
    }

    func save<T: Codable>(_ data: T, forKey key: String, ttl: TimeInterval = 86400) throws {
        let wrapper = CacheWrapper(data: data, expiresAt: Date().addingTimeInterval(ttl))
        let encoded = try encoder.encode(wrapper)
        let fileURL = fileURL(for: prefixedKey(key))
        try encoded.write(to: fileURL, options: .atomic)
    }

    func load<T: Codable>(forKey key: String, as type: T.Type) -> T? {
        let fileURL = fileURL(for: prefixedKey(key))
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let wrapper = try? decoder.decode(CacheWrapper<T>.self, from: data) else { return nil }
        return wrapper.data
    }

    func isExpired(forKey key: String) -> Bool {
        let fileURL = fileURL(for: prefixedKey(key))
        guard let data = try? Data(contentsOf: fileURL) else { return true }
        guard let wrapper = try? decoder.decode(CacheMetadata.self, from: data) else { return true }
        return wrapper.expiresAt < Date()
    }

    func remove(forKey key: String) {
        let fileURL = fileURL(for: prefixedKey(key))
        try? fileManager.removeItem(at: fileURL)
    }

    func clearAll(forUserId userId: String) {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else { return }
        let prefix = "\(userId)_"
        for file in files where file.lastPathComponent.hasPrefix(prefix) {
            try? fileManager.removeItem(at: file)
        }
    }

    // MARK: - Private

    private func prefixedKey(_ key: String) -> String {
        guard let userId = currentUserId else { return key }
        return "\(userId)_\(key)"
    }

    private func fileURL(for key: String) -> URL {
        cacheDirectory.appendingPathComponent("\(key).json")
    }
}

// MARK: - Cache Wrapper

private struct CacheWrapper<T: Codable>: Codable {
    let data: T
    let expiresAt: Date
}

private struct CacheMetadata: Decodable {
    let expiresAt: Date
}
