# Workout Lifecycle & Live Activity Error Handling

## Overview

This document describes how the SwasthiCare app handles all scenarios related to workout tracking and Live Activities, including app backgrounding, termination, crashes, and recovery.

## Architecture Components

### 1. WorkoutStateManager
- **Purpose**: Persistent state storage for workout sessions
- **Key Features**:
  - Auto-saves workout state every 10 seconds
  - Crash detection and recovery
  - State validation (workouts older than 24h are discarded)
  - Synchronous writes to ensure data persistence

### 2. WorkoutLifecycleHandler
- **Purpose**: Manages app lifecycle events during workouts
- **Key Features**:
  - Background task management
  - Memory warning handling
  - Automatic state saving on app termination
  - Background time tracking

### 3. WorkoutLiveActivityManager (Enhanced)
- **Purpose**: Manages Live Activities with error handling
- **Key Features**:
  - Update throttling (max 1 update/second)
  - Automatic cleanup of orphaned activities
  - Comprehensive error handling
  - State queries (isActive, canStartActivities)

### 4. WorkoutErrorHandler
- **Purpose**: Centralized error handling and recovery
- **Key Features**:
  - Error categorization
  - User-friendly messages
  - Severity assessment
  - Recovery action suggestions

## Scenario Handling

### Scenario 1: User Closes App During Workout

**What Happens:**
1. App enters background → `didEnterBackgroundNotification` triggered
2. Workout state is immediately saved
3. Background task started (extends app lifetime to ~3 minutes)
4. Auto-save timer starts (saves every 10 seconds)
5. Location tracking continues in background (configured with `allowsBackgroundLocationUpdates = true`)
6. Live Activity remains visible in Dynamic Island

**User Experience:**
- ✅ Workout continues tracking
- ✅ Live Activity shows real-time updates
- ✅ Distance, pace, and calories keep updating
- ✅ Location route continues recording
- ✅ Can return to app anytime to see progress

**Recovery:**
- When user reopens app, workout resumes seamlessly
- All metrics are current and accurate

### Scenario 2: App Force Quit by User

**What Happens:**
1. `willTerminateNotification` triggered (if time permits)
2. Final workout state saved immediately
3. Live Activity persists even after app termination
4. Location tracking stops (iOS limitation)
5. State is marked as "crashed" for recovery on next launch

**User Experience:**
- ⚠️ Workout tracking stops
- ✅ Live Activity shows last known state
- ✅ Data is preserved up to last save point
- ✅ On app reopen, user sees recovery dialog

**Recovery:**
```swift
Recovery Dialog Options:
1. "Recover Workout" - Shows workout details, offers to continue
2. "Discard" - Clears the saved state
```

**Data Preserved:**
- Activity type, start time
- All location points collected
- Last known metrics (distance, calories, pace)
- Elapsed time at point of termination

### Scenario 3: App Crashes

**What Happens:**
1. App terminates unexpectedly
2. Auto-save data preserved (last save within 10 seconds)
3. Live Activity may show stale data or be cleared by system
4. Crash detection flag set

**User Experience:**
- ⚠️ Workout tracking stops
- ⚠️ Live Activity may disappear
- ✅ Data preserved up to last auto-save
- ✅ Recovery dialog shown on relaunch

**Recovery:**
```swift
On App Relaunch:
1. Check for saved workout state
2. Validate state age (< 1 hour)
3. Show WorkoutRecoveryView
4. Offer to restart workout of same type
```

### Scenario 4: System Memory Warning

**What Happens:**
1. `didReceiveMemoryWarningNotification` triggered
2. Immediate state save
3. Non-essential caches cleared
4. Workout continues

**User Experience:**
- ✅ Seamless continuation
- ✅ No visible impact
- ✅ Data safety ensured

### Scenario 5: Location Permission Revoked

**What Happens:**
1. `locationManagerDidChangeAuthorization` called
2. Error posted via `locationService.errorPublisher`
3. WorkoutErrorHandler analyzes error
4. User shown appropriate message

**User Experience:**
```
Error Message: "Location access is required to track your workout. 
Please enable location permissions in Settings."

Actions Available:
- Open Settings
- Try Again
```

**Automatic Handling:**
- Workout pauses automatically
- Last known location preserved
- Can resume when permission granted

### Scenario 6: Poor GPS Signal

**What Happens:**
1. Location accuracy checks (horizontalAccuracy > 50m rejected)
2. Invalid points filtered out
3. Warning shown but workout continues

**User Experience:**
```
Warning: "GPS signal weak. Distance may be inaccurate."
Severity: Warning (yellow)

Actions Available:
- Wait for Better Signal
- Continue Anyway
```

**Data Quality:**
- Only high-accuracy points recorded
- Distance calculations use validated points
- Route smoothing applied

### Scenario 7: User Pauses Workout

**What Happens:**
1. `pauseWorkout()` called
2. Timer stops, location recording pauses
3. Live Activity updated with `isPaused: true`
4. State saved

**User Experience:**
- ✅ Time freezes
- ✅ Live Activity shows "Paused" state (orange color)
- ✅ Can resume anytime
- ✅ App can be closed while paused

**Visual Indicators:**
- Dynamic Island: Orange icon + "Paused" badge
- Lock Screen: Orange glow, "Paused" status

### Scenario 8: HealthKit Save Fails

**What Happens:**
1. Workout completes
2. HealthKit save attempted
3. Error caught and categorized

**User Experience:**
```
Error: "Unable to save workout to Apple Health. 
Please check Health app permissions."
Severity: Warning

Actions Available:
- Open Health Settings
- Continue Without Saving (workout saved locally)
```

**Data Safety:**
- ✅ Workout still saved to Supabase backend
- ✅ Can retry HealthKit sync later
- ✅ No data loss

### Scenario 9: Network Unavailable

**What Happens:**
1. Workout completes
2. Backend sync attempted
3. Network error caught

**User Experience:**
```
Info: "Workout saved locally. Will sync when online."
Severity: Info (blue)

Actions Available:
- Continue Offline
- Try Again
```

**Automatic Handling:**
- ✅ Workout saved to HealthKit
- ✅ Queued for sync when network available
- ✅ No user action required

### Scenario 10: Background Task Expires (After ~3 minutes in background)

**What Happens:**
1. `beginBackgroundTask` expiration handler called
2. Final state save
3. Background task ended
4. Location continues (separate authorization)

**User Experience:**
- ✅ Location tracking continues
- ✅ Data still being recorded
- ⚠️ Live Activity updates may slow down
- ✅ Full recovery when app reopened

**Technical Details:**
```swift
Background Modes Enabled:
- location (continuous tracking)
- fetch (periodic updates)

Location Configuration:
- allowsBackgroundLocationUpdates = true
- pausesLocationUpdatesAutomatically = false
- showsBackgroundLocationIndicator = true
```

## Live Activity States

### Active State
```swift
Visual: Green icon, pulsing animation
Dynamic Island Compact: Icon + Timer
Dynamic Island Expanded: Full metrics display
Lock Screen: Gradient background, all stats
```

### Paused State
```swift
Visual: Orange icon, pause badge
Dynamic Island Compact: Icon + Pause + Timer (dimmed)
Dynamic Island Expanded: "Paused" label, metrics frozen
Lock Screen: Orange glow, "Paused" status
```

### Ended State
```swift
Visual: Final metrics displayed
Dismissal: After 4 hours (default)
Action: Tapping opens app to summary
```

## Error Recovery Flow

```
┌─────────────────────┐
│   Error Occurs      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ WorkoutErrorHandler │
│  - Categorize       │
│  - Assess Severity  │
│  - Get Message      │
└──────────┬──────────┘
           │
           ▼
    ┌──────────────┐
    │  Critical?   │
    └──────┬───────┘
           │
    ┌──────┴──────┐
    │             │
   YES           NO
    │             │
    ▼             ▼
┌─────────┐  ┌─────────┐
│  Stop   │  │Continue │
│ Workout │  │ Workout │
└────┬────┘  └────┬────┘
     │            │
     └────┬───────┘
          │
          ▼
┌──────────────────┐
│ Show Error UI    │
│ + Recovery       │
│   Actions        │
└──────────────────┘
```

## State Persistence

### What Gets Saved
```swift
struct WorkoutState {
    - id: UUID
    - activityType: String
    - startTime: Date
    - isActive: Bool
    - isPaused: Bool
    - pausedDuration: TimeInterval
    - locationPoints: [LocationPoint]
    - heartRateSamples: [HeartRateSample]
    - lastMetrics: WorkoutMetricsSnapshot
    - liveActivityId: String?
    - savedAt: Date
}
```

### Save Frequency
- **Active Tracking**: Every 10 seconds (auto-save)
- **App Background**: Immediately
- **App Terminate**: Immediately
- **Memory Warning**: Immediately
- **User Action**: After pause/resume

### Storage Location
```swift
UserDefaults.standard
Key: "com.swasthicare.workoutState"
Encoding: JSON with ISO8601 dates
Sync: Immediate (synchronize() called)
```

## Testing Scenarios

### Manual Testing

1. **Background Test**
   ```
   1. Start workout
   2. Close app (home button/swipe up)
   3. Wait 5 minutes
   4. Check Live Activity updates
   5. Reopen app
   6. Verify all metrics current
   ```

2. **Force Quit Test**
   ```
   1. Start workout
   2. Run for 2 minutes
   3. Force quit app
   4. Reopen app
   5. Verify recovery dialog
   6. Check data preserved
   ```

3. **Airplane Mode Test**
   ```
   1. Start workout
   2. Enable airplane mode
   3. Complete workout
   4. Verify local save
   5. Disable airplane mode
   6. Verify sync occurs
   ```

4. **GPS Signal Test**
   ```
   1. Start workout outdoors
   2. Go indoors (poor signal)
   3. Verify warning shown
   4. Go back outdoors
   5. Verify tracking resumes
   ```

5. **Permission Revoke Test**
   ```
   1. Start workout
   2. Open Settings
   3. Disable location access
   4. Return to app
   5. Verify error message
   6. Re-enable location
   7. Verify resume option
   ```

## Best Practices

### For Users
1. **Always Allow Location**: Enable "Always" permission for background tracking
2. **Check Live Activity**: Monitor Dynamic Island for real-time updates
3. **Battery Awareness**: Long workouts drain battery faster
4. **Recovery**: Don't ignore recovery dialogs - data can be saved

### For Developers
1. **Save Frequently**: Use auto-save for crash protection
2. **Validate State**: Always check state age and validity
3. **Handle Errors**: Never assume success - always have fallbacks
4. **Test Edge Cases**: Force quit, airplane mode, memory warnings
5. **Monitor Background Time**: Track remaining background time
6. **Throttle Updates**: Don't overload ActivityKit with updates

## Metrics & Monitoring

### Key Metrics to Track
- Crash rate during workouts
- Recovery success rate
- Average background duration
- Location accuracy distribution
- HealthKit save success rate
- Network sync success rate

### Logging

```swift
// Error logging
WorkoutErrorHandler.shared.logError(error, context: "startWorkout")

// State changes
print("📍 Location tracking started")
print("⏸️ Workout paused")
print("✅ Workout completed")

// Background events
print("📱 App entering background")
print("⏰ Background task expiring")
```

## Future Enhancements

1. **Push Notifications**: Update Live Activity from server
2. **Apple Watch**: Sync with Watch app
3. **Smart Pause**: Auto-pause when user stops moving
4. **Route Playback**: Animated route replay
5. **Social Sharing**: Share workout directly from Live Activity
6. **Voice Feedback**: Audio cues during workout

## Support & Troubleshooting

### Common Issues

**"GPS signal weak"**
- Move to open area
- Check device GPS functionality
- Restart device if persistent

**"Location permission denied"**
- Settings → Privacy → Location Services → SwasthiCare
- Enable "Always" for background tracking

**"Workout not recovering"**
- Check if more than 1 hour passed
- Verify app not deleted and reinstalled
- Check available storage

**"Live Activity not updating"**
- Verify Live Activities enabled in Settings
- Check if Do Not Disturb mode is on
- Force quit and restart app

## Technical Requirements

### iOS Version
- iOS 16.0+ (base features)
- iOS 16.1+ (Live Activities)
- iOS 17.0+ (numeric transitions)

### Permissions Required
- Location: "Always" (background tracking)
- HealthKit: Write workouts, routes
- Motion: Activity type detection (optional)

### Info.plist Keys
```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>fetch</string>
</array>

<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to track your workout route.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need location access to track your workouts in the background.</string>
```

## Conclusion

This comprehensive error handling system ensures:
- ✅ No workout data loss
- ✅ Smooth user experience
- ✅ Clear error communication
- ✅ Automatic recovery when possible
- ✅ Background tracking reliability
- ✅ Live Activity persistence

All scenarios are covered with appropriate fallbacks and recovery mechanisms.
