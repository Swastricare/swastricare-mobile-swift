package com.swasthicare.mobile.data.model

import kotlinx.serialization.Serializable

@Serializable
data class WorkoutDetail(
    val id: String,
    val type: String, // "run", "walk", "cycle", "hike"
    val startTime: String, // ISO datetime
    val endTime: String,
    val durationSeconds: Long,
    val distanceMeters: Double,
    val calories: Int,
    val elevationGain: Double = 0.0,
    val avgPace: Double = 0.0, // seconds per km
    val avgSpeed: Double = 0.0, // km/h
    val maxSpeed: Double = 0.0,
    val routePoints: List<RoutePoint> = emptyList(),
    val splits: List<SplitData> = emptyList(),
    val heartRateData: List<HeartRatePoint> = emptyList()
)

@Serializable
data class SplitData(
    val kilometer: Int,
    val timeSeconds: Long,
    val paceSecondsPerKm: Long,
    val cumulativeSeconds: Long
)

@Serializable
data class HeartRatePoint(
    val timestamp: Long,
    val bpm: Int
)
