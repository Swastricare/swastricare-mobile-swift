package com.swasthicare.mobile.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class Gender(val displayName: String) {
    @SerialName("male")
    Male("Male"),
    
    @SerialName("female")
    Female("Female"),
    
    @SerialName("other")
    Other("Other"),
    
    @SerialName("prefer_not_to_say")
    PreferNotToSay("Prefer not to say")
}

@Serializable
data class HealthProfile(
    val id: String? = null,
    
    @SerialName("user_id")
    val userId: String,
    
    @SerialName("full_name")
    val fullName: String,
    
    val gender: Gender,
    
    @SerialName("date_of_birth")
    val dateOfBirth: String, // YYYY-MM-DD
    
    @SerialName("height_cm")
    val heightCm: Double,
    
    @SerialName("weight_kg")
    val weightKg: Double,
    
    @SerialName("blood_type")
    val bloodType: String? = null,
    
    @SerialName("created_at")
    val createdAt: String? = null,
    
    @SerialName("updated_at")
    val updatedAt: String? = null
)
