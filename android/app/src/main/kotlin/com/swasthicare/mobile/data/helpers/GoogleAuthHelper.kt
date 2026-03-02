package com.swasthicare.mobile.data.helpers

import android.content.Context
import android.util.Log
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import java.security.MessageDigest
import java.util.UUID

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
 *       - Package name: com.swasthicare.mobile
 *       - SHA-1 fingerprint: from your signing key (debug or release)
 *         Debug: keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
 */
class GoogleAuthHelper(
    private val context: Context,
    private val webClientId: String
) {
    companion object {
        private const val TAG = "GoogleAuthHelper"
    }

    private val credentialManager = CredentialManager.create(context)

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
     * @throws GoogleSignInNotConfiguredException if webClientId is blank
     * @throws GoogleSignInCancelledException if user cancelled
     * @throws NoGoogleAccountException if no Google accounts found
     * @throws GoogleSignInException for other errors
     */
    suspend fun signIn(): String {
        if (!isConfigured) {
            throw GoogleSignInNotConfiguredException(
                "Google Sign-In is not configured. Set GOOGLE_WEB_CLIENT_ID in gradle.properties."
            )
        }

        val nonce = generateNonce()
        val hashedNonce = hashNonce(nonce)

        val googleIdOption = GetGoogleIdOption.Builder()
            .setFilterByAuthorizedAccounts(false)
            .setServerClientId(webClientId)
            .setNonce(hashedNonce)
            .build()

        val request = GetCredentialRequest.Builder()
            .addCredentialOption(googleIdOption)
            .build()

        return try {
            val result = credentialManager.getCredential(
                request = request,
                context = context
            )

            val credential = GoogleIdTokenCredential.createFrom(result.credential.data)
            Log.d(TAG, "Google Sign-In succeeded")
            credential.idToken
        } catch (e: GetCredentialCancellationException) {
            Log.d(TAG, "Google Sign-In cancelled by user")
            throw GoogleSignInCancelledException("Sign-in was cancelled")
        } catch (e: NoCredentialException) {
            Log.w(TAG, "No Google accounts found: ${e.message}")
            throw NoGoogleAccountException("No Google accounts found on this device")
        } catch (e: GetCredentialException) {
            Log.e(TAG, "Google Sign-In failed: ${e.message}")
            throw GoogleSignInException("Google Sign-In failed: ${e.message}")
        }
    }

    private fun generateNonce(): String {
        return UUID.randomUUID().toString()
    }

    private fun hashNonce(nonce: String): String {
        val bytes = nonce.toByteArray()
        val md = MessageDigest.getInstance("SHA-256")
        val digest = md.digest(bytes)
        return digest.fold("") { str, it -> str + "%02x".format(it) }
    }
}

/**
 * Google Sign-In specific exception types for granular error handling.
 */
class GoogleSignInNotConfiguredException(message: String) : Exception(message)
class GoogleSignInCancelledException(message: String) : Exception(message)
class NoGoogleAccountException(message: String) : Exception(message)
class GoogleSignInException(message: String) : Exception(message)
