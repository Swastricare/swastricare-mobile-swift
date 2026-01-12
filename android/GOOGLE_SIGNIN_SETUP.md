# Google Sign-In Setup for Android (Supabase)

This guide explains how to configure Google Sign-In for your SwasthiCare Android app using Supabase OAuth.

## Overview

The app uses:
- **Supabase GoTrue** for authentication
- **Google Credential Manager API** for native Google Sign-In
- **Supabase Google OAuth Provider** to exchange tokens

## Setup Steps

### 1. Enable Google Provider in Supabase

1. Go to [Supabase Dashboard](https://supabase.com/dashboard/project/jlumbeyukpnuicyxzvre/auth/providers)
2. Navigate to: **Authentication** → **Providers** → **Google**
3. Click **Enable**

### 2. Create Google Cloud OAuth Client

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select or create a project
3. Navigate to: **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth Client ID**

#### Create Web Application Client (Required for Supabase)

1. Select **Application type**: **Web application**
2. Name: `SwasthiCare Web Client`
3. Add **Authorized redirect URIs**:
   ```
   https://jlumbeyukpnuicyxzvre.supabase.co/auth/v1/callback
   ```
4. Click **Create**
5. **Copy the Client ID and Client Secret**
6. Paste these in Supabase Dashboard → Google Provider settings
7. **Save** in Supabase

#### Create Android OAuth Client (Required for Native Sign-In)

1. Click **Create Credentials** → **OAuth Client ID** again
2. Select **Application type**: **Android**
3. Name: `SwasthiCare Android`
4. **Package name**: `com.swasthicare.mobile`
5. **Get SHA-1 Certificate Fingerprint**:

   **Debug SHA-1** (for testing):
   ```bash
   cd android
   ./gradlew signingReport
   ```
   Copy the SHA-1 from the `debug` variant

   **Release SHA-1** (for production):
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```

6. Paste the SHA-1 fingerprint
7. Click **Create**

### 3. Update Android App Configuration

1. Open `android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt`
2. Replace the placeholder with your **Web Client ID** (not Android client ID):
   ```kotlin
   webClientId = "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com"
   ```

**Important**: Use the **Web Application Client ID**, not the Android Client ID. This is required for the token exchange with Supabase.

### 4. Verify AndroidManifest.xml

The OAuth callback is already configured:
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="swastricareapp"
        android:host="auth-callback" />
</intent-filter>
```

### 5. Test the Integration

1. Build and run the app
2. Click **Continue with Google** button
3. Select a Google account
4. Grant permissions
5. Should redirect back to app and sign in successfully

## Architecture

### Flow Diagram

```
User Taps Button
    ↓
AuthViewModel.signInWithGoogle()
    ↓
GoogleAuthHelper.signIn()
    ↓
Credential Manager → Shows Google Account Picker
    ↓
Returns Google ID Token
    ↓
SupabaseAuthRepository.signInWithGoogle(idToken)
    ↓
Supabase Auth.signInWith(Google) { idToken = token }
    ↓
Supabase validates token with Google
    ↓
Returns Supabase Session
    ↓
User is logged in
```

### Key Components

1. **GoogleAuthHelper.kt**
   - Uses Android Credential Manager API
   - Generates nonce for security
   - Returns Google ID token

2. **SupabaseAuthRepository.kt**
   - Accepts Google ID token
   - Calls Supabase Google OAuth provider
   - Maps user data to AppUser model

3. **AuthViewModel.kt**
   - Coordinates the flow
   - Handles loading states
   - Manages error messages

## Troubleshooting

### Error: "Google Sign-In failed"
- Verify Web Client ID is correct in `AppContainer.kt`
- Check SHA-1 fingerprint matches in Google Cloud Console
- Ensure package name is `com.swasthicare.mobile`

### Error: "Invalid redirect URI"
- Verify Supabase redirect URI in Google Cloud Console
- Format: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`

### Error: "API not enabled"
- Enable Google+ API in Google Cloud Console
- Navigate to: **APIs & Services** → **Library** → Search "Google+ API"

### Account picker doesn't show
- Clear app data and try again
- Verify Google Play Services is updated on device
- Check internet connection

## Dependencies Already Installed

```kotlin
// Google Sign-In
implementation("com.google.android.gms:play-services-auth:21.2.0")
implementation("androidx.credentials:credentials:1.2.2")
implementation("androidx.credentials:credentials-play-services-auth:1.2.2")
implementation("com.google.android.libraries.identity.googleid:googleid:1.1.0")

// Supabase with Google OAuth
implementation("io.github.jan-tennert.supabase:gotrue-kt:2.6.0")
```

## Security Notes

1. **Never commit credentials** to version control
2. Use different OAuth clients for debug/release builds
3. Implement token refresh logic for long sessions
4. Consider adding ProGuard rules for release builds

## References

- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [Android Credential Manager](https://developer.android.com/training/sign-in/credential-manager)
- [Google Sign-In Android](https://developers.google.com/identity/sign-in/android/start)
