//
//  DietSyncManager.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Service Layer
//  Manages diet data synchronization with retry, batching, and conflict resolution
//

import Foundation
import Combine

// MARK: - Sync Status

enum DietSyncStatus: Equatable {
    case synced
    case syncing
    case pending(count: Int)
    case error(message: String)

    var displayText: String {
        switch self {
        case .synced:
            return "All data synced"
        case .syncing:
            return "Syncing..."
        case .pending(let count):
            return "\(count) item\(count == 1 ? "" : "s") pending sync"
        case .error(let message):
            return "Sync error: \(message)"
        }
    }

    var isSynced: Bool {
        if case .synced = self { return true }
        return false
    }
}

// MARK: - Sync Conflict Record

struct DietSyncConflict: Codable {
    let entryId: UUID
    let localTimestamp: Date
    let remoteTimestamp: Date
    let resolution: String // "local_wins" or "remote_wins"
    let resolvedAt: Date
}

// MARK: - Protocol

protocol DietSyncManagerProtocol {
    var syncStatus: DietSyncStatus { get }
    var syncStatusPublisher: Published<DietSyncStatus>.Publisher { get }
    var lastSyncTime: Date? { get }
    var pendingCount: Int { get }
    func syncAllPending() async
    func syncEntry(_ entry: DietLogEntry) async
    func retryFailedSync() async
    func resetSyncState()
}

// MARK: - Implementation

@MainActor
final class DietSyncManager: ObservableObject, DietSyncManagerProtocol {

    // MARK: - Singleton

    static let shared = DietSyncManager()

    // MARK: - Published State

    @Published private(set) var syncStatus: DietSyncStatus = .synced
    var syncStatusPublisher: Published<DietSyncStatus>.Publisher { $syncStatus }

    @Published private(set) var lastSyncTime: Date?

    // MARK: - Retry Configuration

    private let maxRetries = 3
    private let retryDelays: [UInt64] = [
        5_000_000_000,   // 5 seconds
        15_000_000_000,  // 15 seconds
        45_000_000_000   // 45 seconds
    ]

    // MARK: - Internal State

    private var retryCountByEntryId: [UUID: Int] = [:]
    private var failedEntryIds: Set<UUID> = []
    private var syncConflicts: [DietSyncConflict] = []
    private let maxConflictHistory = 50
    private var isSyncing = false
    private var retryTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - Dependencies

    private let localStorage: DietLocalStorage

    // MARK: - Computed

    /// Cached pending count — updated after sync operations instead of re-scanning all logs.
    private(set) var pendingCount: Int = 0

    func refreshPendingCount() {
        pendingCount = localStorage.getUnsyncedLogs().count
    }

    // MARK: - Init

    private init(localStorage: DietLocalStorage = DietLocalStorage.shared) {
        self.localStorage = localStorage
    }

    // MARK: - Sync All Pending

    func syncAllPending() async {
        let unsyncedLogs = localStorage.getUnsyncedLogs()
        guard !unsyncedLogs.isEmpty else {
            syncStatus = .synced
            return
        }

        guard !isSyncing else {
            print("🍎 DietSyncManager: Sync already in progress, skipping")
            return
        }

        isSyncing = true
        syncStatus = .syncing

        // Batch sync: group entries and send together
        do {
            try await SupabaseManager.shared.syncDietLogs(unsyncedLogs)

            let syncedIds = unsyncedLogs.map { $0.id }
            localStorage.markLogsAsSynced(ids: syncedIds)

            // Clear retry state for successfully synced entries
            for id in syncedIds {
                retryCountByEntryId.removeValue(forKey: id)
                failedEntryIds.remove(id)
            }

            lastSyncTime = Date()
            syncStatus = .synced
            print("🍎 DietSyncManager: Batch synced \(unsyncedLogs.count) entries")
        } catch {
            print("🍎 DietSyncManager: Batch sync failed - \(error.localizedDescription)")

            // Fall back to individual sync for each entry
            await syncEntriesIndividually(unsyncedLogs)
        }

        isSyncing = false
        updateSyncStatus()
    }

    // MARK: - Sync Single Entry

    func syncEntry(_ entry: DietLogEntry) async {
        syncStatus = .syncing

        do {
            try await SupabaseManager.shared.syncDietLog(entry)
            localStorage.markLogsAsSynced(ids: [entry.id])

            retryCountByEntryId.removeValue(forKey: entry.id)
            failedEntryIds.remove(entry.id)
            lastSyncTime = Date()

            print("🍎 DietSyncManager: Synced entry \(entry.id)")
        } catch {
            print("🍎 DietSyncManager: Failed to sync entry \(entry.id) - \(error.localizedDescription)")
            failedEntryIds.insert(entry.id)
            scheduleRetry(for: entry)
        }

        updateSyncStatus()
    }

    // MARK: - Retry Failed

    func retryFailedSync() async {
        retryTasks.values.forEach { $0.cancel() }
        retryTasks.removeAll()

        // Reset retry counts so we get fresh attempts
        retryCountByEntryId.removeAll()

        await syncAllPending()
    }

    // MARK: - Reset

    func resetSyncState() {
        retryTasks.values.forEach { $0.cancel() }
        retryTasks.removeAll()
        retryCountByEntryId.removeAll()
        failedEntryIds.removeAll()
        syncConflicts.removeAll()
        isSyncing = false
        syncStatus = .synced
    }

    // MARK: - Conflict Resolution

    /// Resolves a conflict between local and remote data using timestamp-based last-write-wins.
    /// Logs the conflict for debugging/auditing purposes.
    func resolveConflict(localEntry: DietLogEntry, remoteTimestamp: Date) -> DietLogEntry {
        let localTimestamp = localEntry.loggedAt
        let resolution: String

        if localTimestamp >= remoteTimestamp {
            resolution = "local_wins"
        } else {
            resolution = "remote_wins"
        }

        let conflict = DietSyncConflict(
            entryId: localEntry.id,
            localTimestamp: localTimestamp,
            remoteTimestamp: remoteTimestamp,
            resolution: resolution,
            resolvedAt: Date()
        )
        syncConflicts.append(conflict)
        if syncConflicts.count > maxConflictHistory {
            syncConflicts.removeFirst(syncConflicts.count - maxConflictHistory)
        }

        print("🍎 DietSyncManager: Conflict resolved for entry \(localEntry.id) — \(resolution)")

        // With last-write-wins, local always persists; remote is handled by upsert on server
        return localEntry
    }

    /// Returns recorded conflicts for debugging.
    var recentConflicts: [DietSyncConflict] {
        syncConflicts
    }

    // MARK: - Private Helpers

    private func syncEntriesIndividually(_ entries: [DietLogEntry]) async {
        for entry in entries {
            let retryCount = retryCountByEntryId[entry.id] ?? 0
            guard retryCount < maxRetries else {
                failedEntryIds.insert(entry.id)
                print("🍎 DietSyncManager: Entry \(entry.id) exceeded max retries (\(maxRetries))")
                continue
            }

            do {
                try await SupabaseManager.shared.syncDietLog(entry)
                localStorage.markLogsAsSynced(ids: [entry.id])
                retryCountByEntryId.removeValue(forKey: entry.id)
                failedEntryIds.remove(entry.id)
                print("🍎 DietSyncManager: Individually synced entry \(entry.id)")
            } catch {
                retryCountByEntryId[entry.id] = retryCount + 1
                failedEntryIds.insert(entry.id)
                print("🍎 DietSyncManager: Individual sync failed for \(entry.id), attempt \(retryCount + 1)/\(maxRetries)")
            }
        }
    }

    private func scheduleRetry(for entry: DietLogEntry) {
        let retryCount = retryCountByEntryId[entry.id] ?? 0
        guard retryCount < maxRetries else {
            print("🍎 DietSyncManager: Entry \(entry.id) exceeded max retries, not scheduling")
            updateSyncStatus()
            return
        }

        let delayIndex = min(retryCount, retryDelays.count - 1)
        let delay = retryDelays[delayIndex]
        let attemptNumber = retryCount + 1

        retryCountByEntryId[entry.id] = attemptNumber

        print("🍎 DietSyncManager: Scheduling retry \(attemptNumber)/\(maxRetries) for entry \(entry.id) in \(delay / 1_000_000_000)s")

        retryTasks[entry.id]?.cancel()
        retryTasks[entry.id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }

            await self?.syncEntry(entry)
        }
    }

    private func updateSyncStatus() {
        let unsyncedCount = localStorage.getUnsyncedLogs().count

        if unsyncedCount == 0 {
            syncStatus = .synced
        } else if !failedEntryIds.isEmpty {
            let permanentlyFailed = failedEntryIds.filter { id in
                (retryCountByEntryId[id] ?? 0) >= maxRetries
            }
            if !permanentlyFailed.isEmpty {
                syncStatus = .error(message: "\(permanentlyFailed.count) item\(permanentlyFailed.count == 1 ? "" : "s") failed to sync")
            } else {
                syncStatus = .pending(count: unsyncedCount)
            }
        } else {
            syncStatus = .pending(count: unsyncedCount)
        }
    }
}
