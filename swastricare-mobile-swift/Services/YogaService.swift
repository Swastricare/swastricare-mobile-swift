//
//  YogaService.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Service Layer
//  Fetches yoga poses and categories from yoga-api
//

import Foundation
import OSLog

// MARK: - Protocol

protocol YogaServiceProtocol {
    func fetchAllCategories() async throws -> [YogaCategory]
    func fetchCategory(byId id: Int) async throws -> YogaCategory
    func fetchCategory(byName name: String) async throws -> YogaCategory
    func fetchCategoryPoses(categoryId: Int, level: YogaDifficultyLevel?) async throws -> YogaCategory
    func fetchAllPoses() async throws -> [YogaPose]
    func fetchPose(byId id: Int) async throws -> YogaPose
    func fetchPose(byName name: String) async throws -> YogaPose
    func fetchPoses(byLevel level: YogaDifficultyLevel) async throws -> [YogaPose]
}

// MARK: - Error Types

enum YogaServiceError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case notFound(String)
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .notFound(let message):
            return message
        case .serverError(let code):
            return "Server error with code: \(code)"
        }
    }
}

// MARK: - Implementation

final class YogaService: YogaServiceProtocol {
    
    // MARK: - Singleton
    
    static let shared = YogaService()
    
    // MARK: - Properties
    
    private let baseURL = "https://yoga-api-nzy4.onrender.com/v1"
    private let session: URLSession
    private let decoder: JSONDecoder
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "swastricare-mobile-swift",
        category: "YogaService"
    )
    
    // Cache
    private var cachedCategories: [YogaCategory]?
    private var cachedPoses: [YogaPose]?
    private var cacheTimestamp: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    
    private init() {
        let config = URLSessionConfiguration.default
        // Render-hosted APIs often cold start; allow enough time for first response.
        config.timeoutIntervalForRequest = 90
        config.timeoutIntervalForResource = 180
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }
    
    // MARK: - Cache Management
    
    private var isCacheValid: Bool {
        guard let timestamp = cacheTimestamp else { return false }
        return Date().timeIntervalSince(timestamp) < cacheValidityDuration
    }
    
    private func clearCacheIfNeeded() {
        if !isCacheValid {
            cachedCategories = nil
            cachedPoses = nil
            cacheTimestamp = nil
        }
    }
    
    // MARK: - Categories
    
    func fetchAllCategories() async throws -> [YogaCategory] {
        clearCacheIfNeeded()
        
        if let cached = cachedCategories, isCacheValid {
            return cached
        }
        
        let url = try buildURL(path: "/categories")
        let categories: [YogaCategory] = try await performRequest(url: url)
        
        cachedCategories = categories
        cacheTimestamp = Date()
        
        return categories
    }
    
    func fetchCategory(byId id: Int) async throws -> YogaCategory {
        let url = try buildURL(path: "/categories", queryItems: [
            URLQueryItem(name: "id", value: String(id))
        ])
        return try await performRequest(url: url)
    }
    
    func fetchCategory(byName name: String) async throws -> YogaCategory {
        let url = try buildURL(path: "/categories", queryItems: [
            URLQueryItem(name: "name", value: name)
        ])
        return try await performRequest(url: url)
    }
    
    func fetchCategoryPoses(categoryId: Int, level: YogaDifficultyLevel?) async throws -> YogaCategory {
        var queryItems = [URLQueryItem(name: "id", value: String(categoryId))]
        
        if let level = level {
            queryItems.append(URLQueryItem(name: "level", value: level.rawValue.lowercased()))
        }
        
        let url = try buildURL(path: "/categories", queryItems: queryItems)
        return try await performRequest(url: url)
    }
    
    // MARK: - Poses
    
    func fetchAllPoses() async throws -> [YogaPose] {
        clearCacheIfNeeded()
        
        if let cached = cachedPoses, isCacheValid {
            return cached
        }
        
        let url = try buildURL(path: "/poses")
        let poses: [YogaPose] = try await performRequest(url: url)
        
        cachedPoses = poses
        cacheTimestamp = Date()
        
        return poses
    }
    
    func fetchPose(byId id: Int) async throws -> YogaPose {
        let url = try buildURL(path: "/poses", queryItems: [
            URLQueryItem(name: "id", value: String(id))
        ])
        return try await performRequest(url: url)
    }
    
    func fetchPose(byName name: String) async throws -> YogaPose {
        let url = try buildURL(path: "/poses", queryItems: [
            URLQueryItem(name: "name", value: name)
        ])
        return try await performRequest(url: url)
    }
    
    func fetchPoses(byLevel level: YogaDifficultyLevel) async throws -> [YogaPose] {
        let url = try buildURL(path: "/poses", queryItems: [
            URLQueryItem(name: "level", value: level.rawValue.lowercased())
        ])
        let response: PosesByLevelResponse = try await performRequest(url: url)
        return response.poses
    }
    
    // MARK: - Network Helpers
    
    private func buildURL(path: String, queryItems: [URLQueryItem]? = nil) throws -> URL {
        guard var components = URLComponents(string: baseURL + path) else {
            throw YogaServiceError.invalidURL
        }
        
        if let queryItems = queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        guard let url = components.url else {
            throw YogaServiceError.invalidURL
        }
        
        return url
    }
    
    private func performRequest<T: Decodable>(url: URL) async throws -> T {
        let maxAttempts = 3
        var attempt = 0
        var lastError: Error?
        
        while attempt < maxAttempts {
            attempt += 1
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 90
                
                let start = Date()
                let (data, response) = try await session.data(for: request)
                let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw YogaServiceError.networkError(NSError(domain: "YogaService", code: -1))
                }
                
                logger.info("Request \(url.absoluteString, privacy: .public) -> \(httpResponse.statusCode) (\(elapsedMs)ms, \(data.count) bytes) [attempt \(attempt)/\(maxAttempts)]")
                
                switch httpResponse.statusCode {
                case 200...299:
                    do {
                        return try decoder.decode(T.self, from: data)
                    } catch {
                        logger.error("Decoding failed for \(url.absoluteString, privacy: .public): \(String(describing: error), privacy: .public)")
                        if let snippet = String(data: data.prefix(600), encoding: .utf8) {
                            logger.debug("Response snippet: \(snippet, privacy: .public)")
                        }
                        throw YogaServiceError.decodingError(error)
                    }
                    
                case 400:
                    if let errorResponse = try? decoder.decode(YogaAPIError.self, from: data) {
                        throw YogaServiceError.notFound(errorResponse.message)
                    }
                    throw YogaServiceError.notFound("Resource not found")
                    
                case 500, 502, 503, 504:
                    throw YogaServiceError.serverError(httpResponse.statusCode)
                    
                default:
                    throw YogaServiceError.serverError(httpResponse.statusCode)
                }
            } catch let error as YogaServiceError {
                lastError = error
                if shouldRetry(error: error), attempt < maxAttempts {
                    let delayNs = retryDelayNanoseconds(forAttempt: attempt)
                    logger.warning("Retrying after YogaServiceError: \(String(describing: error), privacy: .public) [attempt \(attempt)/\(maxAttempts)]")
                    try? await Task.sleep(nanoseconds: delayNs)
                    continue
                }
                throw error
            } catch {
                let wrapped = YogaServiceError.networkError(error)
                lastError = wrapped
                
                if shouldRetry(error: wrapped), attempt < maxAttempts {
                    let delayNs = retryDelayNanoseconds(forAttempt: attempt)
                    logger.warning("Retrying after network error: \(String(describing: error), privacy: .public) [attempt \(attempt)/\(maxAttempts)]")
                    try? await Task.sleep(nanoseconds: delayNs)
                    continue
                }
                
                throw wrapped
            }
        }
        
        throw lastError ?? YogaServiceError.networkError(NSError(domain: "YogaService", code: -1))
    }
    
    private func shouldRetry(error: YogaServiceError) -> Bool {
        switch error {
        case .serverError(let code):
            return [500, 502, 503, 504].contains(code)
        case .networkError(let underlying):
            if let urlError = underlying as? URLError {
                switch urlError.code {
                case .timedOut, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet, .dnsLookupFailed:
                    return true
                default:
                    return false
                }
            }
            return false
        default:
            return false
        }
    }
    
    private func retryDelayNanoseconds(forAttempt attempt: Int) -> UInt64 {
        // Small exponential backoff: ~0.6s, 1.2s, 2.4s
        let base: Double = 0.6
        let seconds = base * pow(2.0, Double(max(0, attempt - 1)))
        return UInt64(seconds * 1_000_000_000)
    }
}

// MARK: - Convenience Extensions

extension YogaService {
    
    func fetchRandomPoses(count: Int = 5) async throws -> [YogaPose] {
        let allPoses = try await fetchAllPoses()
        return Array(allPoses.shuffled().prefix(count))
    }
    
    func fetchBeginnerPoses(limit: Int = 10) async throws -> [YogaPose] {
        let poses = try await fetchPoses(byLevel: .beginner)
        return Array(poses.prefix(limit))
    }
    
    func searchPoses(query: String) async throws -> [YogaPose] {
        let allPoses = try await fetchAllPoses()
        let lowercasedQuery = query.lowercased()
        
        return allPoses.filter { pose in
            pose.englishName.lowercased().contains(lowercasedQuery) ||
            pose.sanskritNameAdapted.lowercased().contains(lowercasedQuery) ||
            pose.sanskritName.lowercased().contains(lowercasedQuery) ||
            (pose.categoryName?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }
    
    func fetchPosesByCategory(_ categoryName: String) async throws -> [YogaPose] {
        let allPoses = try await fetchAllPoses()
        return allPoses.filter { $0.categoryName?.lowercased() == categoryName.lowercased() }
    }
}
