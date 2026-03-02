package com.swasthicare.mobile.data.services

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.os.Looper
import androidx.core.content.ContextCompat
import com.swasthicare.mobile.data.models.ActivitySplit
import com.swasthicare.mobile.data.models.RouteCoordinate
import com.google.android.gms.location.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlin.math.*

/**
 * Location Tracking Service for workout GPS tracking.
 * Uses FusedLocationProviderClient for efficient GPS updates.
 * Calculates distance, pace, and splits in real-time.
 */
class LocationTrackingService(private val context: Context) {

    companion object {
        private const val UPDATE_INTERVAL_MS = 5000L // 5 seconds
        private const val FASTEST_INTERVAL_MS = 3000L
        private const val EARTH_RADIUS_METERS = 6371000.0
        private const val CALORIE_FACTOR_RUNNING = 0.063 // kcal per meter per kg (approx)
        private const val CALORIE_FACTOR_WALKING = 0.035
        private const val CALORIE_FACTOR_CYCLING = 0.025
        private const val DEFAULT_WEIGHT_KG = 70.0
    }

    private var fusedLocationClient: FusedLocationProviderClient? = null
    private var locationCallback: LocationCallback? = null

    private val _routeCoordinates = MutableStateFlow<List<RouteCoordinate>>(emptyList())
    val routeCoordinates: StateFlow<List<RouteCoordinate>> = _routeCoordinates.asStateFlow()

    private val _totalDistanceMeters = MutableStateFlow(0.0)
    val totalDistanceMeters: StateFlow<Double> = _totalDistanceMeters.asStateFlow()

    private val _currentPaceSecondsPerKm = MutableStateFlow(0L)
    val currentPaceSecondsPerKm: StateFlow<Long> = _currentPaceSecondsPerKm.asStateFlow()

    private val _avgPaceSecondsPerKm = MutableStateFlow(0L)
    val avgPaceSecondsPerKm: StateFlow<Long> = _avgPaceSecondsPerKm.asStateFlow()

    private val _splits = MutableStateFlow<List<ActivitySplit>>(emptyList())
    val splits: StateFlow<List<ActivitySplit>> = _splits.asStateFlow()

    private val _caloriesBurned = MutableStateFlow(0)
    val caloriesBurned: StateFlow<Int> = _caloriesBurned.asStateFlow()

    private var lastLocation: Location? = null
    private var startTimeMs: Long = 0
    private var lastSplitDistanceMeters: Double = 0.0
    private var lastSplitTimeMs: Long = 0
    private var currentKm: Int = 0
    private var isPaused = false
    private var activityType: String = "running"

    fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    @SuppressLint("MissingPermission")
    fun startTracking(activityTypeValue: String = "running") {
        if (!hasLocationPermission()) return

        activityType = activityTypeValue
        isPaused = false
        startTimeMs = System.currentTimeMillis()
        lastSplitTimeMs = startTimeMs
        lastSplitDistanceMeters = 0.0
        currentKm = 0
        _routeCoordinates.value = emptyList()
        _totalDistanceMeters.value = 0.0
        _currentPaceSecondsPerKm.value = 0
        _avgPaceSecondsPerKm.value = 0
        _splits.value = emptyList()
        _caloriesBurned.value = 0
        lastLocation = null

        fusedLocationClient = LocationServices.getFusedLocationProviderClient(context)

        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            UPDATE_INTERVAL_MS
        ).apply {
            setMinUpdateIntervalMillis(FASTEST_INTERVAL_MS)
            setWaitForAccurateLocation(true)
        }.build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                if (isPaused) return
                result.lastLocation?.let { processLocation(it) }
            }
        }

        fusedLocationClient?.requestLocationUpdates(
            locationRequest,
            locationCallback!!,
            Looper.getMainLooper()
        )
    }

    fun pauseTracking() {
        isPaused = true
    }

    fun resumeTracking() {
        lastLocation = null
        isPaused = false
    }

    fun stopTracking() {
        locationCallback?.let { callback ->
            fusedLocationClient?.removeLocationUpdates(callback)
        }
        locationCallback = null
        fusedLocationClient = null
    }

    fun getRoute(): List<RouteCoordinate> = _routeCoordinates.value
    fun getSplits(): List<ActivitySplit> = _splits.value

    // ------------------------------------
    // Private
    // ------------------------------------

    private fun processLocation(location: Location) {
        val coord = RouteCoordinate(
            latitude = location.latitude,
            longitude = location.longitude,
            altitude = location.altitude,
            timestamp = System.currentTimeMillis()
        )
        _routeCoordinates.value = _routeCoordinates.value + coord

        // Calculate distance from last point
        lastLocation?.let { prev ->
            val distance = haversineDistance(
                prev.latitude, prev.longitude,
                location.latitude, location.longitude
            )
            // Filter out GPS jitter (ignore movements < 2m or > 100m)
            if (distance in 2.0..100.0) {
                _totalDistanceMeters.value += distance
                updateCalories()
                updatePace(location)
                checkSplit()
            }
        }

        lastLocation = location
    }

    private fun updatePace(location: Location) {
        val elapsedMs = System.currentTimeMillis() - startTimeMs
        val elapsedSeconds = elapsedMs / 1000.0
        val distanceKm = _totalDistanceMeters.value / 1000.0

        if (distanceKm > 0.01) {
            // Average pace
            val avgPace = (elapsedSeconds / distanceKm).toLong()
            _avgPaceSecondsPerKm.value = avgPace

            // Current pace (rolling average over last ~200m)
            val route = _routeCoordinates.value
            if (route.size >= 3) {
                val recentCount = minOf(route.size, 5)
                val recentRoute = route.takeLast(recentCount)
                var recentDistance = 0.0
                for (i in 1 until recentRoute.size) {
                    recentDistance += haversineDistance(
                        recentRoute[i - 1].latitude, recentRoute[i - 1].longitude,
                        recentRoute[i].latitude, recentRoute[i].longitude
                    )
                }
                val recentTimeMs = recentRoute.last().timestamp - recentRoute.first().timestamp
                val recentTimeSec = recentTimeMs / 1000.0
                val recentDistKm = recentDistance / 1000.0
                if (recentDistKm > 0.005) {
                    _currentPaceSecondsPerKm.value = (recentTimeSec / recentDistKm).toLong()
                }
            }
        }
    }

    private fun updateCalories() {
        val factor = when (activityType) {
            "walking" -> CALORIE_FACTOR_WALKING
            "cycling" -> CALORIE_FACTOR_CYCLING
            "hiking" -> CALORIE_FACTOR_RUNNING * 1.1
            else -> CALORIE_FACTOR_RUNNING
        }
        _caloriesBurned.value = (_totalDistanceMeters.value * factor * DEFAULT_WEIGHT_KG / 1000).toInt()
    }

    private fun checkSplit() {
        val totalKm = (_totalDistanceMeters.value / 1000.0).toInt()
        if (totalKm > currentKm) {
            val now = System.currentTimeMillis()
            val splitTimeMs = now - lastSplitTimeMs
            val splitTimeSec = splitTimeMs / 1000
            val splitPace = splitTimeSec // 1 km split, so pace = time in seconds

            val split = ActivitySplit(
                kilometer = totalKm,
                timeSeconds = splitTimeSec,
                paceSecondsPerKm = splitPace,
                elevationGain = 0.0
            )
            _splits.value = _splits.value + split

            currentKm = totalKm
            lastSplitTimeMs = now
            lastSplitDistanceMeters = _totalDistanceMeters.value
        }
    }

    /**
     * Calculate the great-circle distance between two points using the Haversine formula.
     */
    private fun haversineDistance(
        lat1: Double, lon1: Double,
        lat2: Double, lon2: Double
    ): Double {
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = sin(dLat / 2).pow(2) +
                cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) *
                sin(dLon / 2).pow(2)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return EARTH_RADIUS_METERS * c
    }
}
