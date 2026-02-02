//
//  AppAnalyticsService.swift
//  swastricare-mobile-swift
//
//  Stores all app events to Supabase with queue, retry, and offline support.
//

import Foundation
import Network
import Auth
import Supabase

/// App analytics: logs events to Supabase with network handling and offline queue.
/// Never throws; all errors are handled internally.
final class AppAnalyticsService {

    static let shared = AppAnalyticsService()

    private let queueKey = "app_analytics_queue"
    private let maxQueueSize = 500
    private let flushBatchSize = 50
    private let flushInterval: TimeInterval = 30
    private let requestTimeout: TimeInterval = 10
    private let maxRetries = 3
    private let retryDelays: [UInt64] = [1_000_000_000, 2_000_000_000, 4_000_000_000] // 1s, 2s, 4s in nanoseconds

    private let defaults = UserDefaults.standard
    private let analyticsEnabledKey = "analytics_enabled"
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "app.analytics.reachability")
    private var sessionId: UUID?
    private var flushTask: Task<Void, Never>?
    private var isFlushing = false
    private let lock = NSLock()

    private init() {
        sessionId = UUID()
        startReachability()
        startPeriodicFlush()
    }

    /// Respect user preference; when false, events are not enqueued or sent.
    var isAnalyticsEnabled: Bool {
        get { defaults.object(forKey: analyticsEnabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: analyticsEnabledKey) }
    }

    func setAnalyticsEnabled(_ enabled: Bool) {
        isAnalyticsEnabled = enabled
    }

    // MARK: - Public API (never throws)

    /// Log a generic event.
    func log(eventName: String, eventType: String, properties: [String: Any] = [:]) {
        guard isAnalyticsEnabled else { return }
        enqueue(eventName: eventName, eventType: eventType, properties: properties)
        Task { await flushIfNeeded() }
    }

    /// Log a screen view.
    func logScreen(_ name: String, screenClass: String? = nil) {
        var props: [String: Any] = ["screen": name]
        if let sc = screenClass { props["screen_class"] = sc }
        log(eventName: "screen_view", eventType: "screen", properties: props)
    }

    /// Log an error (sanitized message, no PII).
    func logError(_ error: Error, context: String? = nil, properties: [String: Any] = [:]) {
        var p = properties
        p["message"] = error.localizedDescription
        if let ctx = context { p["context"] = ctx }
        let category = errorCategory(error)
        p["category"] = category
        log(eventName: "error", eventType: "error", properties: p)
    }

    /// Log a count or numeric value.
    func logCount(name: String, value: Int, extra: [String: Any] = [:]) {
        var p = extra
        p["value"] = value
        log(eventName: name, eventType: "count", properties: p)
    }

    // MARK: - Auth events

    func logLoginSuccess(method: String) {
        log(eventName: "login_success", eventType: "auth", properties: ["method": method])
    }

    func logLoginFailed(method: String, errorType: String) {
        log(eventName: "login_failed", eventType: "auth", properties: ["method": method, "error_type": errorType])
    }

    func logLogout() {
        log(eventName: "logout", eventType: "auth", properties: [:])
        Task { await flushNow() }
    }

    // MARK: - Hydration

    func logHydrationLogged(amountMl: Int, source: String = "in_app") {
        log(eventName: "hydration_logged", eventType: "action", properties: ["amount_ml": amountMl, "source": source])
    }

    func logHydrationGoalMet(dailyGoalMl: Int, effectiveMl: Int) {
        log(eventName: "hydration_goal_met", eventType: "action", properties: ["daily_goal_ml": dailyGoalMl, "effective_ml": effectiveMl])
    }

    func logHydrationButtonTap(amountMl: Int, button: String) {
        log(eventName: "hydration_button_tap", eventType: "action", properties: ["amount_ml": amountMl, "button": button])
    }

    // MARK: - Medication

    func logMedicationTaken(medicationId: UUID? = nil, source: String = "in_app") {
        var p: [String: Any] = ["source": source]
        if let id = medicationId { p["medication_id"] = id.uuidString }
        log(eventName: "medication_taken", eventType: "action", properties: p)
    }

    func logMedicationSkipped(medicationId: UUID? = nil) {
        var p: [String: Any] = [:]
        if let id = medicationId { p["medication_id"] = id.uuidString }
        log(eventName: "medication_skipped", eventType: "action", properties: p)
    }

    func logMedicationSnoozed(medicationId: UUID? = nil, minutes: Int) {
        var p: [String: Any] = ["minutes": minutes]
        if let id = medicationId { p["medication_id"] = id.uuidString }
        log(eventName: "medication_snoozed", eventType: "action", properties: p)
    }

    func logMedicationReminderInteraction(action: String, medicationId: String? = nil) {
        var p: [String: Any] = ["action": action]
        if let id = medicationId { p["medication_id"] = id }
        log(eventName: "medication_reminder_interaction", eventType: "action", properties: p)
    }

    // MARK: - Navigation / tabs

    func logTabSelected(tab: String) {
        log(eventName: "tab_selected", eventType: "navigation", properties: ["tab": tab])
    }

    func logButtonTap(buttonId: String, properties: [String: Any] = [:]) {
        var p = properties
        p["button_id"] = buttonId
        log(eventName: "button_tap", eventType: "action", properties: p)
    }

    // MARK: - Workout

    func logWorkoutStart(activityType: String) {
        log(eventName: "workout_start", eventType: "action", properties: ["activity_type": activityType])
    }

    func logWorkoutComplete(activityType: String, durationSeconds: Int? = nil) {
        var p: [String: Any] = ["activity_type": activityType]
        if let d = durationSeconds { p["duration_seconds"] = d }
        log(eventName: "workout_complete", eventType: "action", properties: p)
    }

    func logWorkoutPause(activityType: String) {
        log(eventName: "workout_pause", eventType: "action", properties: ["activity_type": activityType])
    }

    func logWorkoutResume(activityType: String) {
        log(eventName: "workout_resume", eventType: "action", properties: ["activity_type": activityType])
    }

    // MARK: - AI

    func logAIAnalysisRequest(type: String, properties: [String: Any] = [:]) {
        var p = properties
        p["analysis_type"] = type
        log(eventName: "ai_analysis_request", eventType: "action", properties: p)
    }

    // MARK: - Vault

    func logVaultUpload(category: String? = nil) {
        var p: [String: Any] = [:]
        if let c = category { p["category"] = c }
        log(eventName: "vault_upload", eventType: "action", properties: p)
    }

    func logVaultDelete() {
        log(eventName: "vault_delete", eventType: "action", properties: [:])
    }

    // MARK: - Onboarding / Consent

    func logOnboardingComplete() {
        log(eventName: "onboarding_complete", eventType: "action", properties: [:])
    }

    func logConsentAccepted(consentType: String? = nil) {
        var p: [String: Any] = [:]
        if let t = consentType { p["consent_type"] = t }
        log(eventName: "consent_accepted", eventType: "action", properties: p)
    }

    // MARK: - Usage counts (login/logout/days/heartbeat/chats/questions/failures)
    //
    // Backend aggregation examples (Supabase SQL or dashboard):
    // - Login count: COUNT(*) WHERE event_name = 'login_success'; by method: GROUP BY properties->>'method'
    // - Logout count: COUNT(*) WHERE event_name = 'logout'
    // - Days used: COUNT(DISTINCT date(created_at)) WHERE user_id = ?
    // - Heartbeat measurements: COUNT(*) WHERE event_name = 'heartbeat_measurement'
    // - Chats (conversations): COUNT(*) WHERE event_name = 'conversation_started'
    // - Questions/messages: COUNT(*) WHERE event_name = 'chat_message_sent'
    // - Failures: COUNT(*) WHERE event_name = 'failure'; by type: GROUP BY properties->>'failure_type'
    // - Login type per feature: use login_success.properties.method in joins with other events

    /// Heartbeat / vital measurement (e.g. camera heart rate).
    func logHeartbeatMeasurement(bpm: Int, source: String = "camera") {
        log(eventName: "heartbeat_measurement", eventType: "action", properties: ["bpm": bpm, "source": source])
    }

    /// Number of chats: log when user starts a new conversation.
    func logConversationStarted(mode: String? = nil) {
        var p: [String: Any] = [:]
        if let m = mode { p["mode"] = m }
        log(eventName: "conversation_started", eventType: "action", properties: p)
    }

    /// Number of questions/messages sent in chat.
    func logChatMessageSent(mode: String, properties: [String: Any] = [:]) {
        var p = properties
        p["mode"] = mode
        log(eventName: "chat_message_sent", eventType: "action", properties: p)
    }

    /// Explicit failure count (by context and type for aggregation).
    func logFailure(context: String, type: String, message: String? = nil) {
        var p: [String: Any] = ["context": context, "failure_type": type]
        if let m = message { p["message"] = m }
        log(eventName: "failure", eventType: "action", properties: p)
    }

    // MARK: - Queue

    private func enqueue(eventName: String, eventType: String, properties: [String: Any]) {
        let props = AppEvent.propertiesFrom(properties)
        let deviceInfo: [String: String] = [
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "os": "iOS",
            "device_model": DeviceModelHelper.deviceModelName()
        ]
        let event = AppEvent(
            userId: nil,
            eventName: eventName,
            eventType: eventType,
            properties: props,
            deviceInfo: deviceInfo,
            sessionId: sessionId
        )
        lock.lock()
        var queue = loadQueue()
        queue.append(event)
        if queue.count > maxQueueSize {
            queue.removeFirst(queue.count - maxQueueSize)
        }
        saveQueue(queue)
        lock.unlock()
    }

    private func loadQueue() -> [AppEvent] {
        guard let data = defaults.data(forKey: queueKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([AppEvent].self, from: data)) ?? []
    }

    private func saveQueue(_ queue: [AppEvent]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(queue) else { return }
        defaults.set(data, forKey: queueKey)
    }

    // MARK: - Flush

    private func flushIfNeeded() async {
        lock.lock()
        let queue = loadQueue()
        lock.unlock()
        if queue.isEmpty || isFlushing { return }
        await flushNow()
    }

    func flushNow() async {
        lock.lock()
        if isFlushing {
            lock.unlock()
            return
        }
        isFlushing = true
        var queue = loadQueue()
        let toSend = Array(queue.prefix(flushBatchSize))
        lock.unlock()

        guard !toSend.isEmpty else {
            lock.lock()
            isFlushing = false
            lock.unlock()
            return
        }

        var userId: UUID?
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            userId = session.user.id
        } catch {
            userId = nil
        }

        var eventsWithUser = toSend.map { e in
            var ev = e
            ev.userId = userId
            return ev
        }

        var lastError: Error?
        for attempt in 0..<maxRetries {
            do {
                try await SupabaseManager.shared.insertAppEvents(eventsWithUser)
                lock.lock()
                var q = loadQueue()
                q.removeFirst(toSend.count)
                saveQueue(q)
                isFlushing = false
                lock.unlock()
                return
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    try? await Task.sleep(nanoseconds: retryDelays[attempt])
                }
            }
        }

        lock.lock()
        isFlushing = false
        lock.unlock()
        #if DEBUG
        print("AppAnalytics: flush failed after retries: \(lastError?.localizedDescription ?? "unknown")")
        #endif
    }

    // MARK: - Reachability

    private func startReachability() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                Task { await self?.flushNow() }
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    private func startPeriodicFlush() {
        Task {
            while true {
                try? await Task.sleep(nanoseconds: UInt64(flushInterval * 1_000_000_000))
                await flushIfNeeded()
            }
        }
    }

    // MARK: - Helpers

    private func errorCategory(_ error: Error) -> String {
        let desc = String(describing: type(of: error)).lowercased()
        if desc.contains("network") || desc.contains("url") { return "network" }
        if desc.contains("auth") || desc.contains("authenticated") { return "auth" }
        if desc.contains("supabase") || desc.contains("database") { return "server" }
        return "unknown"
    }
}
