//
//  AppVersionService.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Service Layer
//  Handles app version checks and force update logic
//

import Foundation
import UIKit
import Combine

// MARK: - App Version Service

final class AppVersionService: ObservableObject {
    
    static let shared = AppVersionService()
    
    // MARK: - Published Properties
    
    @Published private(set) var updateStatus: AppUpdateStatus = .upToDate
    @Published private(set) var versionInfo: AppVersionInfo?
    @Published private(set) var isChecking: Bool = false
    @Published private(set) var lastCheckDate: Date?
    
    // MARK: - Private Properties
    
    private let supabaseManager = SupabaseManager.shared
    private let checkIntervalSeconds: TimeInterval = 3600 // Check every hour
    
    // MARK: - Current App Info
    
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var currentBuild: Int {
        if let buildString = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return Int(buildString) ?? 1
        }
        return 1
    }
    
    var currentChannel: AppChannel {
        AppChannel.current
    }
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Check for app updates
    /// - Parameter force: If true, checks even if recently checked
    /// - Returns: The update status
    @discardableResult
    func checkForUpdates(force: Bool = false) async -> AppUpdateStatus {
        // Skip if recently checked (unless forced)
        if !force, let lastCheck = lastCheckDate {
            let elapsed = Date().timeIntervalSince(lastCheck)
            if elapsed < checkIntervalSeconds {
                print("📱 AppVersionService: Skipping check - last checked \(Int(elapsed))s ago")
                return updateStatus
            }
        }
        
        await MainActor.run {
            isChecking = true
        }
        
        defer {
            Task { @MainActor in
                isChecking = false
            }
        }
        
        do {
            print("📱 AppVersionService: Checking for updates...")
            print("📱 Current version: \(currentVersion) (build \(currentBuild))")
            print("📱 Channel: \(currentChannel.rawValue)")
            
            guard let record = try await supabaseManager.fetchAppVersion(
                platform: "ios",
                channel: currentChannel.rawValue
            ) else {
                print("📱 AppVersionService: No version record found")
                await MainActor.run {
                    updateStatus = .upToDate
                    lastCheckDate = Date()
                }
                return .upToDate
            }
            
            let info = AppVersionInfo(
                currentVersion: currentVersion,
                currentBuild: currentBuild,
                latestVersion: record.latestVersion,
                latestBuild: record.latestBuild,
                minSupportedVersion: record.minSupportedVersion,
                minSupportedBuild: record.minSupportedBuild,
                updateTitle: record.updateTitle,
                updateMessage: record.updateMessage,
                updateUrl: record.updateUrl,
                forceUpdate: record.forceUpdate,
                rolloutPercentage: record.rolloutPercentage
            )
            
            // Debug logging
            print("📱 AppVersionService: Server data:")
            print("   - min_supported_version: \(record.minSupportedVersion ?? "nil")")
            print("   - min_supported_build: \(record.minSupportedBuild ?? 0)")
            print("   - latest_version: \(record.latestVersion ?? "nil")")
            print("   - latest_build: \(record.latestBuild ?? 0)")
            print("   - force_update: \(record.forceUpdate)")
            print("📱 AppVersionService: Computed:")
            print("   - isBelowMinimum: \(info.isBelowMinimum)")
            print("   - hasNewerVersion: \(info.hasNewerVersion)")
            
            // Check rollout percentage
            let shouldShowUpdate = shouldParticipateInRollout(percentage: info.rolloutPercentage)
            
            let status: AppUpdateStatus
            
            // ONLY force update if explicitly set by server OR truly below minimum
            if record.forceUpdate {
                // Server explicitly requires force update
                status = .forceUpdateRequired(version: info.latestVersion ?? currentVersion)
                print("📱 AppVersionService: ⚠️ FORCE UPDATE - server flag is true")
            } else if info.isBelowMinimum {
                // App is below minimum supported version
                status = .forceUpdateRequired(version: info.latestVersion ?? currentVersion)
                print("📱 AppVersionService: ⚠️ FORCE UPDATE - below minimum version")
            } else if info.hasNewerVersion && shouldShowUpdate {
                // Optional update available
                status = .updateAvailable(version: info.latestVersion ?? currentVersion, isForced: false)
                print("📱 AppVersionService: ℹ️ Update available - \(info.latestVersion ?? "unknown")")
            } else {
                // No update needed
                status = .upToDate
                print("📱 AppVersionService: ✅ App is up to date")
            }
            
            await MainActor.run {
                versionInfo = info
                updateStatus = status
                lastCheckDate = Date()
            }
            
            return status
            
        } catch {
            print("📱 AppVersionService: ❌ Error checking for updates - \(error.localizedDescription)")
            // On error, default to upToDate to avoid blocking users
            await MainActor.run {
                updateStatus = .upToDate
                lastCheckDate = Date()
            }
            return .upToDate
        }
    }
    
    /// Open App Store for update
    func openAppStore() {
        guard let urlString = versionInfo?.updateUrl,
              let url = URL(string: urlString) else {
            // Fallback to App Store search
            if let appStoreURL = URL(string: "https://apps.apple.com/app/swastricare") {
                UIApplication.shared.open(appStoreURL)
            }
            return
        }
        
        UIApplication.shared.open(url)
    }
    
    /// Reset update status (for testing)
    func reset() {
        Task { @MainActor in
            updateStatus = .upToDate
            versionInfo = nil
            lastCheckDate = nil
        }
    }
    
    // MARK: - Private Methods
    
    /// Determine if this device should participate in the rollout
    /// Uses a deterministic hash based on device ID for consistent behavior
    private func shouldParticipateInRollout(percentage: Int) -> Bool {
        guard percentage < 100 else { return true }
        guard percentage > 0 else { return false }
        
        // Use a deterministic value based on device identifier
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let hash = deviceId.hashValue
        let normalizedValue = abs(hash % 100)
        
        return normalizedValue < percentage
    }
}

// MARK: - Version Comparison Extension

extension String {
    /// Compare semantic versions
    func isOlderThan(_ other: String) -> Bool {
        let v1Components = self.split(separator: ".").compactMap { Int($0) }
        let v2Components = other.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxLength {
            let v1 = i < v1Components.count ? v1Components[i] : 0
            let v2 = i < v2Components.count ? v2Components[i] : 0
            
            if v1 < v2 {
                return true
            } else if v1 > v2 {
                return false
            }
        }
        
        return false
    }
    
    func isNewerThan(_ other: String) -> Bool {
        return other.isOlderThan(self)
    }
}
