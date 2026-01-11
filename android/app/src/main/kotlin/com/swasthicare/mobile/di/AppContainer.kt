package com.swasthicare.mobile.di

import com.swasthicare.mobile.data.repository.AuthRepository
import com.swasthicare.mobile.data.repository.MockAuthRepository
import com.swasthicare.mobile.data.repository.ProfileRepository
import com.swasthicare.mobile.data.repository.MockProfileRepository
import com.swasthicare.mobile.data.repository.VaultRepository
import com.swasthicare.mobile.data.repository.MockVaultRepository

// Simple Service Locator / Dependency Container
object AppContainer {
    val authRepository: AuthRepository by lazy { MockAuthRepository() }
    val profileRepository: ProfileRepository by lazy { MockProfileRepository() }
    val vaultRepository: VaultRepository by lazy { MockVaultRepository() }
}
