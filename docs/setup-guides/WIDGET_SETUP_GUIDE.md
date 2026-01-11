# SwasthiCare Widget Setup Guide

This guide explains how to configure the Widget Extension in Xcode.

## Quick Setup Steps

### 1. Add Widget Extension Target in Xcode

1. Open `swastricare-mobile-swift.xcodeproj` in Xcode
2. Go to **File > New > Target**
3. Select **Widget Extension** under iOS
4. Configure:
   - Product Name: `SwasthiCareWidgets`
   - Bundle Identifier: `com.swasthicare.app.SwasthiCareWidgets` (or your app bundle ID + `.SwasthiCareWidgets`)
   - Language: Swift
   - **Uncheck** "Include Configuration App Intent" (we've already created intents)
   - **Uncheck** "Include Live Activity"
5. Click **Finish**
6. When prompted to activate the scheme, click **Cancel**

### 2. Replace Generated Files

Xcode creates template files. **Delete them** and use the files from `SwasthiCareWidgets/` folder:

1. In Xcode, select the new `SwasthiCareWidgets` group
2. Delete all auto-generated `.swift` files (keep `Info.plist`)
3. Right-click on `SwasthiCareWidgets` folder > **Add Files to "swastricare-mobile-swift"**
4. Select all files from the `SwasthiCareWidgets/` folder:
   - `SwasthiCareWidgets.swift`
   - `Shared/WidgetDataManager.swift`
   - `Shared/WidgetIntents.swift`
   - `HydrationWidget/HydrationWidgetEntry.swift`
   - `HydrationWidget/HydrationWidgetProvider.swift`
   - `HydrationWidget/HydrationWidgetView.swift`
   - `MedicationWidget/MedicationWidgetEntry.swift`
   - `MedicationWidget/MedicationWidgetProvider.swift`
   - `MedicationWidget/MedicationWidgetView.swift`
5. Make sure **"SwasthiCareWidgets"** target is checked
6. Click **Add**

### 3. Configure App Groups

#### Main App Target:
1. Select the main app target (`swastricare-mobile-swift`)
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Search for **"App Groups"** and add it
5. Click **+** and add: `group.com.swasthicare.shared`

#### Widget Extension Target:
1. Select the `SwasthiCareWidgets` target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **"App Groups"**
5. Select the same group: `group.com.swasthicare.shared`

### 4. Add Entitlements (if needed)

The entitlements files should already be configured, but verify:

**Main App (`swastricare-mobile-swift.entitlements`)** should include:
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.swasthicare.shared</string>
</array>
```

**Widget (`SwasthiCareWidgets.entitlements`)** should include the same.

### 5. Add URL Scheme for Deep Links

1. Select main app target
2. Go to **Info** tab
3. Expand **URL Types**
4. Click **+** to add a new URL Type:
   - Identifier: `swasthicare`
   - URL Schemes: `swasthicare`
   - Role: Editor

### 6. Build and Run

1. Select the main app scheme
2. Build and run on a device/simulator
3. Go to home screen, long press to add widget
4. Find "SwasthiCare" widgets (Hydration & Medication)

## Widget Features

### Hydration Widget
- **Small**: Shows progress ring with percentage and intake amount
- **Medium**: Progress ring + stats + quick add buttons (+250ml, +500ml)

### Medication Widget
- **Small**: Shows next/overdue medication with status
- **Medium**: Shows medication list with progress and quick "mark as taken" buttons

## Troubleshooting

### Widget Shows "Unable to Load"
- Ensure App Groups are configured correctly on both targets
- Check that bundle identifier matches your app's bundle ID pattern
- Clean build folder (Cmd+Shift+K) and rebuild

### Quick Actions Not Working
- Verify iOS 16+ is targeted
- Check App Intent implementations
- Ensure widget and main app share the same App Group

### Data Not Syncing
- Confirm `WidgetService.swift` is added to main app target
- Check that `group.com.swasthicare.shared` matches in both entitlements
- Call `WidgetService.shared.refreshAllWidgets()` after data changes

## Files Structure

```
SwasthiCareWidgets/
├── SwasthiCareWidgets.swift          # Widget bundle & definitions
├── SwasthiCareWidgets.entitlements   # App Group entitlement
├── Info.plist                        # Extension info
├── Assets.xcassets/                  # Widget assets
├── Shared/
│   ├── WidgetDataManager.swift       # App Group data sharing
│   └── WidgetIntents.swift           # Quick action intents
├── HydrationWidget/
│   ├── HydrationWidgetEntry.swift    # Timeline entry
│   ├── HydrationWidgetProvider.swift # Timeline provider
│   └── HydrationWidgetView.swift     # Widget UI
└── MedicationWidget/
    ├── MedicationWidgetEntry.swift   # Timeline entry
    ├── MedicationWidgetProvider.swift# Timeline provider
    └── MedicationWidgetView.swift    # Widget UI
```

## Notes

- Widgets refresh every 15 minutes (hydration) or 5 minutes (medication) during active hours
- Quick actions work on iOS 16+ via App Intents
- Widget taps open the app to the respective view via URL scheme
- Data is synced via App Group UserDefaults
