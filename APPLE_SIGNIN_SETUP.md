# Apple Sign-In Setup Complete ✅

## Configuration Summary

### Apple Developer Portal
- **App ID:** `com.swastricare.health`
- **Services ID:** `com.swastricare.health.auth`
- **Team ID:** `9TF7Y389MX`
- **Key ID:** `KA4VY3F24J`
- **Redirect URL:** `https://jlumbeyukpnuicyxzvre.supabase.co/auth/v1/callback`

### Supabase Configuration
- **Provider:** Apple (Enabled ✅)
- **Client ID:** `com.swastricare.health.auth`
- **Secret Key:** Configured with Key ID, Team ID, and Private Key

### iOS App Implementation
- **AuthService:** Added `signInWithApple()` method
- **AuthViewModel:** Added `signInWithApple()` method
- **LoginView:** Added "Continue with Apple" button
- **Entitlements:** Sign in with Apple capability enabled

## How to Test

### Testing on Simulator (Limited)
1. Open Xcode
2. Select any iOS Simulator (iOS 13+)
3. Build and run the app
4. Tap "Continue with Apple"
5. Note: Simulator has limited Apple ID support

### Testing on Physical Device (Recommended)
1. Connect your iPhone/iPad
2. Select your device in Xcode
3. Build and run the app
4. Tap "Continue with Apple"
5. Sign in with your Apple ID
6. Choose email sharing options
7. Complete authentication

### What Happens During Sign-In

1. **User taps "Continue with Apple"**
   - App triggers OAuth flow
   - Redirects to Apple Sign-In page

2. **User authenticates with Apple ID**
   - Face ID / Touch ID / Password
   - Choose to share or hide email

3. **Apple redirects back to Supabase**
   - Supabase validates the token
   - Creates/updates user in database

4. **User is signed in**
   - Returns to app authenticated
   - Profile data synced from Apple

## Expected User Data

When user signs in with Apple, you'll receive:
- **User ID:** Unique Apple user identifier
- **Email:** Real or relay email (user's choice)
- **Full Name:** If user chooses to share (first time only)
- **Avatar:** Not provided by Apple

## Troubleshooting

### "Invalid Client" Error
- Check Services ID matches: `com.swastricare.health.auth`
- Verify redirect URL in Apple Developer matches Supabase

### "Invalid Secret" Error
- Regenerate .p8 key in Apple Developer
- Update secret in Supabase with correct format

### Button Does Nothing
- Check Xcode console for errors
- Verify internet connection
- Check Supabase project is running

### App Crashes on Sign-In
- Verify entitlements file includes Sign in with Apple capability
- Check bundle ID matches: `com.swastricare.health`

## Production Checklist

Before releasing to App Store:

- [ ] Update aps-environment to "production" in entitlements
- [ ] Test with multiple Apple IDs
- [ ] Test "Hide My Email" feature
- [ ] Verify user profile creation
- [ ] Test sign-out and re-sign-in
- [ ] Regenerate Apple key if > 6 months old
- [ ] Update privacy policy for Apple Sign-In

## Notes

- Apple keys expire every 6 months - mark calendar to regenerate
- First-time sign-in provides full name, subsequent sign-ins don't
- Users can manage app access at: appleid.apple.com
- "Hide My Email" creates relay addresses like: abc123@privaterelay.appleid.com
