package com.swastricare.health.data.helpers

import android.content.Context
import android.util.Log
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential

/**
 * Google Authentication Helper
 * Manages Google Sign-In flow using Credential Manager API
 * Integrates with Supabase OAuth
 *
 * SETUP INSTRUCTIONS:
 * -------------------
 * 1. Go to Google Cloud Console: https://console.cloud.google.com/
 * 2. Create a project (or select existing one)
 * 3. Enable "Google Identity" API
 * 4. Go to Credentials -> Create Credentials -> OAuth 2.0 Client ID
 * 5. Create a "Web application" client (NOT Android) -- Supabase needs the Web Client ID
 * 6. Copy the Web Client ID (ends in .apps.googleusercontent.com)
 * 7. Add to your gradle.properties (project root or ~/.gradle/gradle.properties):
 *       GOOGLE_WEB_CLIENT_ID=your-id-here.apps.googleusercontent.com
 * 8. Also configure in Supabase Dashboard -> Auth -> Providers -> Google:
 *       - Enable Google provider
 *       - Paste the Web Client ID as "Client ID"
 *       - Paste the Web Client Secret as "Client Secret"
 * 9. In Google Cloud Console, also create an "Android" OAuth client:
 *       - Package name: com.swastricare.health
 *       - SHA-1 fingerprint: from your signing key (debug or release)
 *         Debug: keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
 */
class GoogleAuthHelper(
    private val applicationContext: Context,
    private val webClientId: String
) {
    companion object {
        private const val TAG = "GoogleAuthHelper"
    }

    /**
     * Whether Google Sign-In is configured (non-empty client ID).
     */
    val isConfigured: Boolean
        get() = webClientId.isNotBlank() &&
                webClientId != "YOUR_GOOGLE_WEB_CLIENT_ID.apps.googleusercontent.com"

    /**
     * Initiate Google Sign-In flow.
     * Returns Google ID token to be used with Supabase.
     *
     * Step 1: Try GetGoogleIdOption (One Tap — fast, works if app is already authorized).
     * Step 2: If NoCredentialException, fall back to GetSignInWithGoogleOption (full account
     *         picker — works for first-time sign-in or when the Android OAuth client
     *         SHA-1/package name isn't pre-authorized in Google Cloud Console).
     *
     * @param activityContext MUST be an Activity context (not Application) for Credential Manager UI
     * @throws GoogleSignInNotConfiguredException if webClientId is blank
     * @throws GoogleSignInCancelledException if user cancelled
     * @throws NoGoogleAccountException if no Google accounts found on device
     * @throws GoogleSignInException for other errors
     */
    suspend fun signIn(activityContext: Context): String {
        if (!isConfigured) {
            throw GoogleSignInNotConfiguredException(
                "Google Sign-In is not configured. Set GOOGLE_WEB_CLIENT_ID in gradle.properties."
            )
        }

        val credentialManager = CredentialManager.create(activityContext)

        // Step 1: One Tap (preferred — silent/quick if already authorized).
        // Don't set a nonce — Supabase's signInWith(IDToken) generates its own nonce.
        val oneTapRequest = GetCredentialRequest.Builder()
            .addCredentialOption(
                GetGoogleIdOption.Builder()
                    .setFilterByAuthorizedAccounts(false)
                    .setServerClientId(webClientId)
                    .build()
            )
            .build()

        return try {
            val result = credentialManager.getCredential(
                request = oneTapRequest,
                context = activityContext
            )
            Log.d(TAG, "Google Sign-In succeeded via One Tap")
            GoogleIdTokenCredential.createFrom(result.credential.data).idToken
        } catch (e: GetCredentialCancellationException) {
            Log.d(TAG, "Google Sign-In cancelled by user")
            throw GoogleSignInCancelledException("Sign-in was cancelled")
        } catch (e: NoCredentialException) {
            // One Tap found no eligible credentials — fall back to full account picker.
            // This commonly happens on first install or when the Android OAuth client
            // SHA-1/package name isn't pre-authorized in Google Cloud Console.
            Log.w(TAG, "One Tap found no credentials, falling back to Sign in with Google: ${e.message}")
            signInWithGooglePicker(activityContext, credentialManager)
        } catch (e: GetCredentialException) {
            Log.e(TAG, "Google Sign-In failed: ${e.message}")
            throw GoogleSignInException("Google Sign-In failed: ${e.message}")
        }
    }

    /**
     * Fallback: full "Sign in with Google" bottom-sheet account picker.
     * Works even without a pre-authorized session.
     */
    private suspend fun signInWithGooglePicker(
        activityContext: Context,
        credentialManager: CredentialManager
    ): String {
        val request = GetCredentialRequest.Builder()
            .addCredentialOption(GetSignInWithGoogleOption.Builder(webClientId).build())
            .build()

        return try {
            val result = credentialManager.getCredential(
                request = request,
                context = activityContext
            )
            Log.d(TAG, "Google Sign-In succeeded via account picker")
            GoogleIdTokenCredential.createFrom(result.credential.data).idToken
        } catch (e: GetCredentialCancellationException) {
            Log.d(TAG, "Google Sign-In cancelled by user")
            throw GoogleSignInCancelledException("Sign-in was cancelled")
        } catch (e: NoCredentialException) {
            Log.w(TAG, "No Google accounts on device: ${e.message}")
            throw NoGoogleAccountException(
                "No Google account found. Please add a Google account in your device Settings."
            )
        } catch (e: GetCredentialException) {
            Log.e(TAG, "Google Sign-In (picker) failed: ${e.message}")
            throw GoogleSignInException("Google Sign-In failed: ${e.message}")
        }
    }
}

/**
 * Google Sign-In specific exception types for granular error handling.
 */
class GoogleSignInNotConfiguredException(message: String) : Exception(message)
class GoogleSignInCancelledException(message: String) : Exception(message)
class NoGoogleAccountException(message: String) : Exception(message)
class GoogleSignInException(message: String) : Exception(message)
