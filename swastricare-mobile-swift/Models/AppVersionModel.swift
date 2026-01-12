//
//  AppVersionModel.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Models Layer
//  App version management for force updates and version checks
//

import Foundation

// MARK: - App Version Record (from Supabase)

struct AppVersionRecord: Codable {
    let id: UUID
    let platform: String
    let channel: String
    let minSupportedVersion: String?
    let minSupportedBuild: Int?
    let latestVersion: String?
    let latestBuild: Int?
    let forceUpdate: Bool
    let rolloutPercentage: Int
    let updateTitle: String?
    let updateMessage: String?
    let updateUrl: String?
    let isActive: Bool
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case platform
        case channel
        case minSupportedVersion = "min_supported_version"
        case minSupportedBuild = "min_supported_build"
        case latestVersion = "latest_version"
        case latestBuild = "latest_build"
        case forceUpdate = "force_update"
        case rolloutPercentage = "rollout_percentage"
        case updateTitle = "update_title"
        case updateMessage = "update_message"
        case updateUrl = "update_url"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - App Update Status

enum AppUpdateStatus: Equatable {
    case upToDate
    case updateAvailable(version: String, isForced: Bool)
    case forceUpdateRequired(version: String)
    case error(String)
    
    var requiresAction: Bool {
        switch self {
        case .forceUpdateRequired:
            return true
        default:
            return false
        }
    }
    
    var hasUpdate: Bool {
        switch self {
        case .updateAvailable, .forceUpdateRequired:
            return true
        default:
            return false
        }
    }
}

// MARK: - App Version Info

struct AppVersionInfo {
    let currentVersion: String
    let currentBuild: Int
    let latestVersion: String?
    let latestBuild: Int?
    let minSupportedVersion: String?
    let minSupportedBuild: Int?
    let updateTitle: String?
    let updateMessage: String?
    let updateUrl: String?
    let forceUpdate: Bool
    let rolloutPercentage: Int
    
    /// Check if current version is below minimum supported
    var isBelowMinimum: Bool {
        if let minVersion = minSupportedVersion {
            if compareVersions(currentVersion, minVersion) == .orderedAscending {
                return true
            }
        }
        if let minBuild = minSupportedBuild, currentBuild < minBuild {
            return true
        }
        return false
    }
    
    /// Check if there's a newer version available
    var hasNewerVersion: Bool {
        if let latest = latestVersion {
            if compareVersions(currentVersion, latest) == .orderedAscending {
                return true
            }
        }
        if let latestB = latestBuild, currentBuild < latestB {
            return true
        }
        return false
    }
    
    /// Get the update status
    var updateStatus: AppUpdateStatus {
        // Force update required if below minimum
        if isBelowMinimum || forceUpdate {
            return .forceUpdateRequired(version: latestVersion ?? currentVersion)
        }
        
        // Optional update available
        if hasNewerVersion {
            return .updateAvailable(version: latestVersion ?? currentVersion, isForced: false)
        }
        
        return .upToDate
    }
    
    /// Compare semantic versions (e.g., "1.2.3" vs "1.2.4")
    private func compareVersions(_ version1: String, _ version2: String) -> ComparisonResult {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxLength {
            let v1 = i < v1Components.count ? v1Components[i] : 0
            let v2 = i < v2Components.count ? v2Components[i] : 0
            
            if v1 < v2 {
                return .orderedAscending
            } else if v1 > v2 {
                return .orderedDescending
            }
        }
        
        return .orderedSame
    }
}

// MARK: - App Channel

enum AppChannel: String {
    case production = "production"
    case testflight = "testflight"
    case staging = "staging"
    
    /// Detect current app channel based on receipt
    static var current: AppChannel {
        #if DEBUG
        return .staging
        #else
        // Check for TestFlight receipt
        if let receiptURL = Bundle.main.appStoreReceiptURL {
            if receiptURL.lastPathComponent == "sandboxReceipt" {
                return .testflight
            }
        }
        return .production
        #endif
    }
}
