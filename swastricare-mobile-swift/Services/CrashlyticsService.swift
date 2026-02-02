//
//  CrashlyticsService.swift
//  swastricare-mobile-swift
//
//  Firebase Crashlytics wrapper for crash reporting and non-fatal errors.
//

import Foundation
import FirebaseCrashlytics

/// Wraps Firebase Crashlytics for crash reporting, user identification, and custom keys.
enum CrashlyticsService {
    
    /// Set the user identifier (e.g. after login). Pass nil to clear.
    static func setUserId(_ userId: String?) {
        Crashlytics.crashlytics().setUserID(userId ?? "")
    }
    
    /// Set a custom key-value pair for crash reports (helps debug context).
    static func setCustomValue(_ value: String, forKey key: String) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }
    
    /// Set a custom key with Int value.
    static func setCustomValue(_ value: Int, forKey key: String) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }
    
    /// Set a custom key with Bool value.
    static func setCustomValue(_ value: Bool, forKey key: String) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }
    
    /// Log a non-fatal error so it appears in Crashlytics (without crashing).
    static func record(_ error: Error) {
        Crashlytics.crashlytics().record(error: error)
    }
    
    /// Log a non-fatal error with a custom message.
    static func record(error: Error, userInfo: [String: Any]? = nil) {
        let nsError = error as NSError
        if let userInfo = userInfo {
            let enriched = NSError(domain: nsError.domain, code: nsError.code, userInfo: nsError.userInfo.merging(userInfo) { _, new in new })
            Crashlytics.crashlytics().record(error: enriched)
        } else {
            Crashlytics.crashlytics().record(error: error)
        }
    }
    
    /// Log a custom message to the next crash report (for context).
    static func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }
}
