package com.swasthicare.mobile.data.helpers

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import java.security.MessageDigest
import java.util.UUID

/**
 * Google Authentication Helper
 * Manages Google Sign-In flow using Credential Manager API
 * Integrates with Supabase OAuth
 */
class GoogleAuthHelper(
    private val context: Context,
    private val webClientId: String
) {
    private val credentialManager = CredentialManager.create(context)
    
    /**
     * Initiate Google Sign-In flow
     * Returns Google ID token to be used with Supabase
     */
    suspend fun signIn(): String {
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
            credential.idToken
        } catch (e: GetCredentialException) {
            throw Exception("Google Sign-In failed: ${e.message}")
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
