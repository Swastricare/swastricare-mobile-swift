package com.swasthicare.mobile.data.repository

import com.swasthicare.mobile.data.model.HealthProfile
import com.swasthicare.mobile.data.model.Gender
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from

interface ProfileRepository {
    suspend fun getHealthProfile(userId: String): HealthProfile?
    suspend fun createHealthProfile(profile: HealthProfile): HealthProfile
    suspend fun updateHealthProfile(profile: HealthProfile): HealthProfile
}

class MockProfileRepository : ProfileRepository {
    override suspend fun getHealthProfile(userId: String): HealthProfile? {
        return HealthProfile(
            userId = userId,
            fullName = "Alex Johnson",
            gender = Gender.Male,
            dateOfBirth = "1995-05-15",
            heightCm = 175.0,
            weightKg = 70.0,
            bloodType = "O+"
        )
    }

    override suspend fun createHealthProfile(profile: HealthProfile): HealthProfile = profile

    override suspend fun updateHealthProfile(profile: HealthProfile): HealthProfile = profile
}

class SupabaseProfileRepository(
    private val client: SupabaseClient
) : ProfileRepository {

    override suspend fun getHealthProfile(userId: String): HealthProfile? {
        return try {
            client.from("health_profiles").select {
                filter { eq("user_id", userId) }
                limit(1)
            }.decodeSingleOrNull<HealthProfile>()
        } catch (e: Exception) {
            null
        }
    }

    override suspend fun createHealthProfile(profile: HealthProfile): HealthProfile {
        client.from("health_profiles").insert(profile)
        return profile
    }

    override suspend fun updateHealthProfile(profile: HealthProfile): HealthProfile {
        client.from("health_profiles").update(profile) {
            filter { eq("user_id", profile.userId) }
        }
        return profile
    }
}
