package com.swasthicare.mobile.data.repository

import com.swasthicare.mobile.data.model.HealthProfile
import com.swasthicare.mobile.data.model.Gender

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
