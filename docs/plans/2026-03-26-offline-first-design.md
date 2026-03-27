# Offline-First Architecture Design

**Date**: 2026-03-26
**Status**: Approved
**Approach**: B — Session Fix + Network Monitor + Read Cache

## Problem

When the app loses network connectivity, `checkSession()` times out after 5 seconds and returns `nil`, causing the app to navigate to the login screen. Users are falsely logged out even though their session is still valid locally.

## Solution Overview

Five layers, built bottom-up:

1. **NetworkMonitor** — reactive connectivity state
2. **Session persistence fix** — trust local session when offline
3. **Read cache** — cache-first data loading with background refresh
4. **Network-gated UX** — banner, disabled features, toasts
5. **Cache cleanup** — per-user, TTL-based, secure

## Layer 1: Network Monitor

### iOS — `NetworkMonitorService`
- `NWPathMonitor` on background `DispatchQueue`
- Conforms to `NetworkMonitorServiceProtocol`
- Exposes `@Published var isConnected: Bool` (starts `true` optimistically)
- Registered as singleton in `DependencyContainer`
- Available via SwiftUI environment for views

### Android — `NetworkMonitorService`
- `ConnectivityManager.registerDefaultNetworkCallback`
- Exposes `StateFlow<Boolean>` for `isConnected`
- `@Singleton` via Hilt in `ServiceModule`
- Observed via `collectAsStateWithLifecycle()` in Compose

## Layer 2: Session Persistence Fix

### Auth State Machine (both platforms)

```
App Launch
  ├─ Online → check session with server → authenticated / unauthenticated
  └─ Offline → check local cached session
        ├─ Local session exists → authenticated (offline mode)
        └─ No local session → unauthenticated (show login)
```

### iOS — Fix `AuthService.checkSession()`
- When offline: skip network check, return Supabase SDK's locally cached session
- Don't check `isExpired` when offline (token auto-refreshes when network returns)
- Only set `.unauthenticated` when: no local session exists OR explicit logout
- Remove 5-second timeout as sole auth determinator

### Android — Fix `checkSession()` + `SessionManager`
- `SessionManager` already handles `NetworkError` correctly (doesn't mark expired) — keep as-is
- Fix `checkSession()` timeout path: on timeout due to no network, check SDK's local session
- `AuthViewModel` distinguishes "no session" from "can't reach server"

### Network Restoration
- Supabase SDK auto-refreshes token in background
- If refresh fails (session revoked server-side), `SessionManager` / auth listener navigates to login
- No manual intervention needed

## Layer 3: Read Cache

### Strategy: Cache-First, Network-Refresh

1. Return cached data immediately (instant UI)
2. If online, fetch fresh data in background
3. On success, update cache + UI
4. On failure, keep showing cached data silently

### CacheService

Generic service on both platforms:
- iOS: `save<T: Codable>(key, data, ttl)` / `load<T: Codable>(key) -> T?` — JSON files in Documents dir
- Android: `save(key, data, ttl)` / `load(key, type)` — EncryptedSharedPreferences with Kotlin serialization

Properties:
- Per-user cache keys (prefixed with `userId`)
- TTL-based expiry (stale data still returned offline)

### Cached Data

| Data | TTL |
|------|-----|
| Health vitals (BP, heart rate, SpO2) | 24h |
| Medications list + schedule | 24h |
| Hydration logs (today) | 4h |
| Step/activity data | 24h |
| User profile + health profile | 7d |
| Diet data | Already has `DietLocalStorage` |

### NOT Cached
- AI chat conversations (network-only feature)
- Family group data (needs fresh server state)
- Images/media (too large)

### Integration Point
- Cache read/write in existing ViewModels/repositories directly
- Each `loadData()` becomes: show cache → if online, fetch & update cache → update UI
- No new abstraction layers

## Layer 4: Network-Gated Features

### Offline Behavior by Feature

| Feature | Offline behavior |
|---------|-----------------|
| AI Chat | Disable send, show "AI chat requires internet" |
| Login / Signup | Show "Internet connection required" |
| Profile sync | Silent skip, sync on reconnect |
| Family features | Show "Family features require internet" |
| Image analysis | Disable camera, show message |
| Write operations | Toast: "Will save when you're back online" |

### UX Patterns
- **Global offline banner**: Amber banner at top — "You're offline. Some features may be limited." Auto-dismisses on reconnect.
- **Inline feature blocking**: Dimmed buttons, tap shows toast "This feature needs internet"
- **No aggressive popups** — banner + toast only

## Layer 5: Cache Cleanup & Security

### On Logout
- Clear all cached health data for current user
- Clear cached profile
- Keep non-sensitive settings (theme, notifications, onboarding)

### Per-User Isolation
- Cache keys prefixed with `userId`
- Logout clears only current user's entries

### Security
- iOS: Relies on iOS Data Protection (file-level encryption at rest)
- Android: EncryptedSharedPreferences (AES-256-GCM) already in use

### TTL Policy
- Default 24h for health data
- Profile: 7d
- Today's logs: 4h
- Stale data still shown offline (no staleness indicator)
