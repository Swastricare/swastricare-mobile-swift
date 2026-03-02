package com.swasthicare.mobile.data.model

import kotlinx.serialization.Serializable

@Serializable
data class RoutePoint(
    val latitude: Double,
    val longitude: Double,
    val altitude: Double = 0.0,
    val speed: Float = 0f,
    val timestamp: Long = System.currentTimeMillis()
)
