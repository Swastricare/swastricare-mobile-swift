# Widget Testing Guide

## Build Status: ✅ SUCCESS

The widgets have been successfully built! Follow these steps to test them.

## Adding Widgets to Home Screen

### 1. Run the App
1. Select your device/simulator
2. Run the app (Cmd+R)
3. Wait for app to fully launch
4. Go to iOS home screen

### 2. Add Widgets
1. **Long press** on empty space on home screen
2. Tap the **+** button (top left)
3. Search for "SwasthiCare"
4. You should see **2 widgets**:
   - Hydration Tracker
   - Medication Reminder

### 3. Test Hydration Widget

**Small Widget:**
- Shows circular progress ring
- Displays current intake / goal
- Shows percentage

**Medium Widget:**
- Progress ring on left
- Stats (intake, goal, remaining)
- **Quick action buttons**: +250ml, +500ml (iOS 17+)

**Test Flow:**
1. Add small hydration widget to home screen
2. Open app → Navigate to Hydration
3. Log some water (e.g., 500ml)
4. Return to home screen
5. Widget should update within 15 minutes (or immediately if refreshed)

### 4. Test Medication Widget

**Small Widget:**
- Shows next/overdue medication
- Medication name and time
- Status indicator

**Medium Widget:**
- List of today's medications (up to 3)
- Progress counter (e.g., "2/5 taken")
- **Quick action**: Mark as taken button (iOS 17+)

**Test Flow:**
1. Add medication widget to home screen
2. Open app → Navigate to Medications
3. Add a medication (e.g., "Vitamin D", 8:00 AM)
4. Return to home screen
5. Widget should show the medication
6. On iOS 17+, tap "Mark as taken" directly from widget

## Widget Features

### Hydration Widget
- **Refresh interval**: Every 15 minutes (day), hourly (night)
- **Quick actions**: +250ml, +500ml water logging
- **Deep link**: Taps open Hydration view in app
- **Data sync**: Real-time via App Group

### Medication Widget
- **Refresh interval**: Every 5 minutes (day), 30 min (night)
- **Quick actions**: Mark medication as taken
- **Deep link**: Taps open Medications view in app
- **Status**: Shows pending, taken, missed, overdue

## Troubleshooting

### Widget Shows "Unable to Load"
- **Check App Group**: Ensure both app and widget have `group.com.swasthicare.shared` enabled
- **Clean build**: Product → Clean Build Folder (Cmd+Shift+K), then rebuild

### Widget Not Updating
- Try force-touching widget and select "Reload Widget"
- Check that WidgetService is being called in ViewModels
- Verify App Group UserDefaults are accessible

### Quick Actions Not Working (iOS 17+)
- Ensure device is running iOS 17 or later
- Check App Intents are properly defined
- Widget must be added to home screen (not in widget gallery)

### Build Warnings
- **CFBundleVersion warning**: Minor warning, doesn't affect functionality
- Can be fixed by ensuring widget and app have same version number

## Manual Testing Checklist

- [ ] Hydration widget small size displays correctly
- [ ] Hydration widget medium size displays correctly
- [ ] Water logging updates widget data
- [ ] +250ml quick action works (iOS 17+)
- [ ] +500ml quick action works (iOS 17+)
- [ ] Tapping widget opens app to Hydration view
- [ ] Medication widget small size displays correctly
- [ ] Medication widget medium size displays correctly
- [ ] Adding medication updates widget
- [ ] Mark as taken quick action works (iOS 17+)
- [ ] Tapping widget opens app to Medications view
- [ ] Widget updates when app is backgrounded
- [ ] Widget persists after device restart

## Version Notes

- **iOS 16**: Basic widgets work, no quick actions
- **iOS 17+**: Full functionality with quick action buttons
- **Minimum iOS**: 16.0 (per project settings)

## Next Steps

1. Test on physical device for best experience
2. Verify quick actions on iOS 17+ device
3. Test widget updates across multiple days
4. Consider adding widget configuration options (future enhancement)

Enjoy your new SwasthiCare widgets! 🎉
