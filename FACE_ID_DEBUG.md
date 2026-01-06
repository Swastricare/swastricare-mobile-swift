# Face ID Debugging on Physical Device

## If Stuck on "Authenticating..."

### Check in Xcode Console for these logs:

```
🔐 LockScreenView: Appearing, will trigger auth immediately
🔐 BiometricAuth: Starting authentication...
🔐 BiometricAuth: Can use biometrics: true/false
🔐 BiometricAuth: Biometrics available - type: 2 (Face ID) or 1 (Touch ID)
🔐 BiometricAuth: Requesting biometric authentication...
```

### Common Issues:

1. **Permission Prompt Not Showing**
   - First time Face ID is used, iOS should show permission dialog
   - Check: Settings > Privacy & Security > Face ID
   - App should be listed there

2. **Face ID Prompt Not Appearing**
   - The system Face ID dialog should pop up automatically
   - If not, check console for error codes

3. **Stuck on Authenticating**
   - Check console for "LAError - code: X"
   - Common codes:
     - -1: User cancelled
     - -2: User fallback
     - -3: System cancelled
     - -6: Biometry not available
     - -7: Biometry not enrolled
     - -8: Biometry lockout

### Quick Fixes:

**Option 1: Cancel and Retry**
- If you see the lock screen but nothing happens
- Look for any error message displayed
- Tap the button again to retry

**Option 2: Force Quit App**
- Swipe up from bottom
- Swipe app away
- Reopen app

**Option 3: Check Face ID Settings**
- Go to Settings > Face ID & Passcode
- Make sure Face ID is enabled
- Try adding Face ID again if needed

### What Should Happen:

1. Open app → Lock screen appears
2. After 0.1 seconds → Face ID prompt shows automatically
3. Look at Face ID → Authenticates
4. App unlocks → Shows main content

### If Still Stuck:

Send me the console output (the lines with 🔐 emoji) so I can see exactly where it's hanging.
