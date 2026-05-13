//
//  PushNotificationManager.swift
//  swastricare-mobile-swift
//
//  Family Monitoring (Batch 8) — bridges iOS APNs + Firebase Cloud Messaging
//  to the `device_tokens` table and the family nudge deep-link route.
//
//  Build resilience: this file compiles whether or not the `FirebaseMessaging`
//  SPM product has been added to the app target. When it's absent, the methods
//  no-op so the rest of the app keeps working. Once a maintainer adds the
//  `FirebaseMessaging` product to the target (Project → Package Dependencies
//  → firebase-ios-sdk → check FirebaseMessaging), the guarded paths activate.
//

import Foundation
import UIKit
import UserNotifications

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

/// Bridges iOS APNs + Firebase Cloud Messaging to the `device_tokens` table and
/// the family nudge deep-link route. See file header for build-resilience notes.
final class PushNotificationManager: NSObject {
    static let shared = PushNotificationManager()

    private override init() { super.init() }

    /// Request push permission and register the FCM token (if FirebaseMessaging
    /// is linked) for the given user. Safe to call on every authenticated app
    /// launch — duplicates are deduped by the `(user_id, fcm_token)` UNIQUE
    /// constraint on device_tokens.
    func requestAuthorizationAndRegister(forUserId userId: String?) {
        guard let userId = userId, !userId.isEmpty else { return }

        pendingUserId = userId

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted { UIApplication.shared.registerForRemoteNotifications() }
            }
        }

        #if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
        Messaging.messaging().token { [weak self] token, _ in
            guard let self = self, let token = token else { return }
            self.uploadToken(token, forUserId: userId)
        }
        #endif
    }

    /// Extract a nudge id from a `swastricareapp://nudge/{id}` URL. Returns nil
    /// for non-nudge URLs. The caller (deep-link handler) presents
    /// NudgeDetailView with the returned id.
    static func nudgeId(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "swastricareapp" else { return nil }
        guard url.host?.lowercased() == "nudge" else { return nil }
        let id = url.lastPathComponent
        guard !id.isEmpty, id != "nudge", id != "/" else { return nil }
        return id
    }

    // MARK: - Private

    private var pendingUserId: String?

    private func uploadToken(_ token: String, forUserId userId: String) {
        pendingUserId = userId
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let deviceModel = UIDevice.current.model
        Task {
            try? await DeviceTokenRepository.shared.upsertToken(
                userId: userId,
                token: token,
                appVersion: appVersion,
                deviceModel: deviceModel
            )
        }
    }
}

#if canImport(FirebaseMessaging)
extension PushNotificationManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken, let userId = pendingUserId else { return }
        uploadToken(token, forUserId: userId)
    }
}
#endif
