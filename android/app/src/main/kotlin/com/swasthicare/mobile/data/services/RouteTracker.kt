package com.swasthicare.mobile.data.services

import android.annotation.SuppressLint
import android.content.Context
import android.location.Location
import android.os.Looper
import com.google.android.gms.location.*
import com.swasthicare.mobile.data.model.RoutePoint
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * GPS route tracking service using FusedLocationProviderClient.
 *
 * Collects GPS coordinates at regular intervals during an active workout,
 * exposes a live route via StateFlow, and computes total distance.
 */
class RouteTracker(context: Context) {

    // ─────────────────────────────────────
    // MARK: - GPS Fix Quality
    // ─────────────────────────────────────

    enum class GpsStatus {
        OFF,        // Not tracking / no permission
        SEARCHING,  // Waiting for first fix
        POOR,       // Accuracy > 30m
        GOOD        // Accuracy <= 30m
    }

    // ─────────────────────────────────────
    // MARK: - State
    // ─────────────────────────────────────

    private val fusedClient: FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(context)

    private val _routePoints = MutableStateFlow<List<RoutePoint>>(emptyList())
    val routePoints: StateFlow<List<RoutePoint>> = _routePoints.asStateFlow()

    private val _totalDistanceMeters = MutableStateFlow(0.0)
    val totalDistanceMeters: StateFlow<Double> = _totalDistanceMeters.asStateFlow()

    private val _gpsStatus = MutableStateFlow(GpsStatus.OFF)
    val gpsStatus: StateFlow<GpsStatus> = _gpsStatus.asStateFlow()

    private val _currentSpeed = MutableStateFlow(0f) // m/s
    val currentSpeed: StateFlow<Float> = _currentSpeed.asStateFlow()

    private var isTracking = false
    private var isPaused = false

    // ─────────────────────────────────────
    // MARK: - Location Request Config
    // ─────────────────────────────────────

    private val locationRequest = LocationRequest.Builder(
        Priority.PRIORITY_HIGH_ACCURACY,
        3_000L // 3-second interval
    ).apply {
        setMinUpdateIntervalMillis(2_000L)
        setMinUpdateDistanceMeters(2f) // At least 2m moved
        setWaitForAccurateLocation(false)
    }.build()

    // ─────────────────────────────────────
    // MARK: - Location Callback
    // ─────────────────────────────────────

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            if (isPaused) return

            for (location in result.locations) {
                processLocation(location)
            }
        }
    }

    private fun processLocation(location: Location) {
        // Update GPS quality
        val accuracy = location.accuracy
        _gpsStatus.value = when {
            accuracy <= 30f -> GpsStatus.GOOD
            else -> GpsStatus.POOR
        }

        // Update current speed
        _currentSpeed.value = if (location.hasSpeed()) location.speed else 0f

        val newPoint = RoutePoint(
            latitude = location.latitude,
            longitude = location.longitude,
            altitude = if (location.hasAltitude()) location.altitude else 0.0,
            speed = if (location.hasSpeed()) location.speed else 0f,
            timestamp = location.time
        )

        val current = _routePoints.value
        val updated = current + newPoint
        _routePoints.value = updated

        // Recalculate distance from last point
        if (current.isNotEmpty()) {
            val prev = current.last()
            val dist = distanceBetween(prev, newPoint)
            // Filter out GPS jitter: only add distance if > 1m
            if (dist > 1.0) {
                _totalDistanceMeters.value += dist
            }
        }
    }

    // ─────────────────────────────────────
    // MARK: - Public Controls
    // ─────────────────────────────────────

    /**
     * Start collecting GPS locations. Requires location permission to be granted.
     */
    @SuppressLint("MissingPermission")
    fun startTracking() {
        if (isTracking) return
        isTracking = true
        isPaused = false
        _gpsStatus.value = GpsStatus.SEARCHING
        _routePoints.value = emptyList()
        _totalDistanceMeters.value = 0.0

        fusedClient.requestLocationUpdates(
            locationRequest,
            locationCallback,
            Looper.getMainLooper()
        )
    }

    /**
     * Pause GPS collection (e.g. workout paused). Keeps accumulated data.
     */
    fun pauseTracking() {
        isPaused = true
    }

    /**
     * Resume GPS collection after a pause.
     */
    @SuppressLint("MissingPermission")
    fun resumeTracking() {
        if (!isTracking) {
            startTracking()
            return
        }
        isPaused = false
    }

    /**
     * Stop tracking entirely and clean up the location callback.
     */
    fun stopTracking() {
        isTracking = false
        isPaused = false
        _gpsStatus.value = GpsStatus.OFF
        fusedClient.removeLocationUpdates(locationCallback)
    }

    /**
     * Return current route snapshot (useful when saving workout).
     */
    fun getRouteSnapshot(): List<RoutePoint> = _routePoints.value

    /**
     * Return total distance in kilometers.
     */
    fun getTotalDistanceKm(): Double = _totalDistanceMeters.value / 1000.0

    /**
     * Clear all route data.
     */
    fun reset() {
        _routePoints.value = emptyList()
        _totalDistanceMeters.value = 0.0
        _currentSpeed.value = 0f
        _gpsStatus.value = GpsStatus.OFF
    }

    // ─────────────────────────────────────
    // MARK: - Distance Calculation
    // ─────────────────────────────────────

    companion object {
        /**
         * Uses Android's Location.distanceBetween() for accurate Haversine distance.
         */
        fun distanceBetween(a: RoutePoint, b: RoutePoint): Double {
            val results = FloatArray(1)
            Location.distanceBetween(
                a.latitude, a.longitude,
                b.latitude, b.longitude,
                results
            )
            return results[0].toDouble()
        }

        /**
         * Calculate total distance for a list of route points.
         */
        fun totalDistance(points: List<RoutePoint>): Double {
            if (points.size < 2) return 0.0
            var total = 0.0
            for (i in 1 until points.size) {
                total += distanceBetween(points[i - 1], points[i])
            }
            return total
        }
    }
}
