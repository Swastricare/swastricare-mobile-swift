# Live Activity & Workout Lifecycle Implementation Guide

## Overview

This guide provides step-by-step instructions for integrating the comprehensive workout lifecycle and Live Activity error handling system into your SwasthiCare app.

## What Has Been Implemented

### New Services
1. **WorkoutStateManager** - Persistent state storage
2. **WorkoutLifecycleHandler** - App lifecycle event handling
3. **WorkoutErrorHandler** - Centralized error handling
4. **Enhanced WorkoutLiveActivityManager** - Improved Live Activity management

### New UI Components
1. **WorkoutRecoveryView** - Crash recovery dialog
2. Error handling integration in LiveActivityViewModel

### Documentation
1. **WORKOUT_LIFECYCLE_HANDLING.md** - Complete scenario documentation
2. **IMPLEMENTATION_GUIDE.md** - This guide

## Integration Steps

### Step 1: Update Run View to Show Recovery Dialog

Update your main Run tracking view to show the recovery dialog:

```swift
// In your main Run tracking view (e.g., LiveActivityTrackingView.swift)
import SwiftUI

struct LiveActivityTrackingView: View {
    @StateObject private var viewModel = DependencyContainer.shared.liveActivityViewModel
    
    var body: some View {
        ZStack {
            // Your existing workout tracking UI
            WorkoutTrackingContent(viewModel: viewModel)
            
            // Recovery dialog
            .sheet(isPresented: $viewModel.showRecoveryAlert) {
                if let recoveredState = viewModel.recoveredWorkoutState {
                    WorkoutRecoveryView(
                        state: recoveredState,
                        onRecover: {
                            viewModel.recoverWorkout()
                        },
                        onDiscard: {
                            viewModel.discardRecoveredWorkout()
                        }
                    )
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                }
            }
            
            // Background indicator (optional)
            if viewModel.isInBackground {
                VStack {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.green)
                        Text("Tracking in background")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(20)
                    Spacer()
                }
                .padding()
            }
        }
    }
}
```

### Step 2: Update DependencyContainer

Ensure the lifecycle handler is accessible:

```swift
// In DependencyContainer.swift
@MainActor
final class DependencyContainer: ObservableObject {
    // ... existing code ...
    
    let workoutLifecycleHandler: WorkoutLifecycleHandler
    let workoutStateManager: WorkoutStateManager
    let workoutErrorHandler: WorkoutErrorHandler
    
    private init() {
        // ... existing initializations ...
        
        self.workoutLifecycleHandler = WorkoutLifecycleHandler.shared
        self.workoutStateManager = WorkoutStateManager.shared
        self.workoutErrorHandler = WorkoutErrorHandler.shared
    }
}
```

### Step 3: Integrate Error Handling in Your Workout Views

Add comprehensive error handling to your workout UI:

```swift
// Example error alert in your view
.alert("Workout Error", isPresented: $viewModel.showError) {
    if let errorMessage = viewModel.errorMessage,
       let error = someError { // You'll need to store the actual error
        let handler = WorkoutErrorHandler.shared
        let actions = handler.recoveryActions(for: error)
        
        ForEach(actions) { action in
            Button(action.title) {
                handleRecoveryAction(action)
            }
        }
    }
} message: {
    if let errorMessage = viewModel.errorMessage {
        Text(errorMessage)
    }
}

func handleRecoveryAction(_ action: WorkoutErrorRecoveryAction) {
    switch action {
    case .retry:
        Task { await viewModel.startWorkout() }
    case .openSettings:
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    case .discardWorkout:
        viewModel.discardWorkout()
    // Handle other actions...
    default:
        break
    }
}
```

### Step 4: Add Background Mode Capabilities

Ensure your app has the required background modes:

1. Open Xcode project
2. Select target → Signing & Capabilities
3. Add "Background Modes" capability
4. Enable:
   - ✅ Location updates
   - ✅ Background fetch

### Step 5: Update Info.plist

Add/verify the required privacy descriptions:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to track your workout route and distance.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need location access to track your workouts in the background, even when the app is closed. This ensures accurate distance and route tracking throughout your entire workout.</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>We need always-on location access to track your workouts in the background.</string>

<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>fetch</string>
</array>
```

### Step 6: Test the Implementation

#### Test Checklist

- [ ] **Basic Tracking**
  - Start a workout
  - Verify Live Activity appears
  - Check metrics update in real-time
  - Complete workout successfully

- [ ] **Background Mode**
  - Start workout
  - Press home button
  - Wait 2 minutes
  - Check Live Activity updates
  - Reopen app
  - Verify metrics are current

- [ ] **Force Quit Recovery**
  - Start workout
  - Run for 2+ minutes
  - Force quit app (swipe up in app switcher)
  - Reopen app
  - Verify recovery dialog appears
  - Test both "Recover" and "Discard" options

- [ ] **Poor GPS Signal**
  - Start workout
  - Go indoors or to area with poor signal
  - Verify warning message appears
  - Go back outdoors
  - Verify tracking resumes

- [ ] **Permission Revocation**
  - Start workout
  - Go to Settings → Privacy → Location
  - Change permission to "Never"
  - Return to app
  - Verify error message and recovery actions

- [ ] **Network Offline**
  - Enable airplane mode
  - Complete a workout
  - Verify local save works
  - Disable airplane mode
  - Verify sync occurs

## Advanced Configuration

### Customize Auto-Save Interval

```swift
// In WorkoutStateManager.swift
private let autoSaveInterval: TimeInterval = 10 // Change to desired seconds
```

### Customize State Validation

```swift
// In WorkoutStateManager.swift
func hasActiveWorkout() -> Bool {
    guard let state = loadWorkoutState() else { return false }
    
    // Customize the time window (default 24 hours)
    let hoursSinceStart = Date().timeIntervalSince(state.startTime) / 3600
    return state.isActive && hoursSinceStart < 24 // Change hours as needed
}
```

### Customize Live Activity Update Throttling

```swift
// In WorkoutLiveActivityManager.swift
private let minimumUpdateInterval: TimeInterval = 1.0 // Change to desired seconds
```

## Monitoring & Analytics

### Add Analytics Tracking

```swift
// Example: Track recovery events
func recoverWorkout() {
    guard let state = recoveredWorkoutState else { return }
    
    // Track recovery event
    Analytics.logEvent("workout_recovered", parameters: [
        "activity_type": state.activityType,
        "duration_minutes": Int(state.lastMetrics.elapsedTime / 60),
        "distance_km": state.lastMetrics.totalDistance / 1000,
        "time_since_crash_minutes": Int(Date().timeIntervalSince(state.savedAt) / 60)
    ])
    
    Task {
        // ... recovery logic
    }
}
```

### Add Error Logging

```swift
// In your error handling code
private func handleError(_ error: Error) {
    // Log to error handler
    WorkoutErrorHandler.shared.logError(error, context: "startWorkout")
    
    // Send to analytics
    Analytics.logError(error)
    
    // Show to user
    errorMessage = WorkoutErrorHandler.shared.userFriendlyMessage(for: error)
    showError = true
}
```

## Troubleshooting

### Issue: Recovery Dialog Not Showing

**Solution:**
1. Check that `checkForCrashedWorkout()` is called in ViewModel init
2. Verify auto-save is running during workout
3. Check UserDefaults for saved state:
   ```swift
   print(UserDefaults.standard.data(forKey: "com.swasthicare.workoutState"))
   ```

### Issue: Live Activity Not Updating in Background

**Solution:**
1. Verify background modes are enabled
2. Check location permission is "Always"
3. Ensure `allowsBackgroundLocationUpdates = true` in LocationTrackingService
4. Check background task is running:
   ```swift
   print("Background time: \(UIApplication.shared.backgroundTimeRemaining)s")
   ```

### Issue: Location Tracking Stops in Background

**Solution:**
1. Request "Always" permission (not just "When In Use")
2. Verify `showsBackgroundLocationIndicator = true`
3. Check Info.plist has all required keys
4. Ensure `pausesLocationUpdatesAutomatically = false`

### Issue: State Not Persisting

**Solution:**
1. Ensure `UserDefaults.synchronize()` is called after save
2. Check app has storage permissions
3. Verify state encoding/decoding works:
   ```swift
   // Test in console
   let state = WorkoutStateManager.shared.loadWorkoutState()
   print(state)
   ```

## Performance Considerations

### Memory Usage
- Auto-save keeps full route in memory
- For very long workouts (>3 hours), consider:
  - Reducing save frequency
  - Saving only last N location points
  - Compressing route data

### Battery Impact
- Background location uses significant battery
- Live Activity updates use minimal power
- Consider showing battery warning for workouts >1 hour

### Storage
- Each saved state is ~10-50KB depending on route length
- Clean up old states periodically
- Current retention: 24 hours (configurable)

## Best Practices

### For Development

1. **Always Test on Real Device**
   - Simulator doesn't support:
     - True background location
     - Live Activities
     - Background task timing

2. **Log Everything**
   - Use descriptive logs
   - Include timestamps
   - Log state transitions

3. **Handle All Errors**
   - Never assume success
   - Always provide fallbacks
   - Test error scenarios

4. **Validate State**
   - Check nil values
   - Validate time ranges
   - Verify data integrity

### For Users

1. **Clear Onboarding**
   - Explain "Always" permission need
   - Show Live Activity features
   - Demo recovery process

2. **Visual Feedback**
   - Show background tracking indicator
   - Display battery usage estimate
   - Indicate save status

3. **Easy Recovery**
   - Make recovery dialog prominent
   - Show workout details
   - Clear action buttons

## Future Enhancements

### Recommended Improvements

1. **Smart Pause**
   ```swift
   // Auto-pause when user stops moving for >30 seconds
   if currentSpeed < 0.5 && timeSinceLastMovement > 30 {
       pauseWorkout()
   }
   ```

2. **Route Simplification**
   ```swift
   // Reduce point count for very long routes
   func simplifyRoute(_ points: [LocationPoint]) -> [LocationPoint] {
       // Douglas-Peucker algorithm
   }
   ```

3. **Offline Maps**
   ```swift
   // Cache map tiles for offline route display
   func preloadMapArea(region: MKCoordinateRegion) {
       // Implementation
   }
   ```

4. **Voice Feedback**
   ```swift
   // Audio cues every km
   func announceProgress(distance: Double) {
       let utterance = AVSpeechUtterance(text: "You've run \(distance) kilometers")
       synthesizer.speak(utterance)
   }
   ```

## Support

For issues or questions:
1. Check WORKOUT_LIFECYCLE_HANDLING.md for scenario details
2. Review error logs in Xcode console
3. Test on real device with proper permissions
4. Verify all Info.plist keys are present

## Version History

- **v1.0** (2026-01-27): Initial implementation
  - WorkoutStateManager
  - WorkoutLifecycleHandler
  - Enhanced Live Activity manager
  - Recovery UI
  - Comprehensive error handling

---

**Ready to Test!** Follow the test checklist above to verify all scenarios work correctly.
