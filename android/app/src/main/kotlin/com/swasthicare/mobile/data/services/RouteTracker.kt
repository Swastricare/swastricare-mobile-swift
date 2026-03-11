package com.swasthicare.mobile.data.services

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.location.Location
import android.os.BatteryManager
import android.os.Looper
import com.google.android.gms.location.*
import com.swasthicare.mobile.data.model.RoutePoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * GPS route tracking service using FusedLocationProviderClient.
 *
 * Collects GPS coordinates at regular intervals during an active workout,
 * exposes a live route via StateFlow, and computes total distance.
 *
 * Applies accuracy filtering, Kalman smoothing, teleportation guards,
 * and stationary jitter rejection for clean route data.
 */
// ─────────────────────────────────────
// MARK: - Battery-Aware GPS Mode
// ─────────────────────────────────────

enum class GpsMode(val label: String) {
    HIGH_ACCURACY("High Accuracy"),
    BALANCED("Balanced"),
    LOW_POWER("Low Power")
}

// ─────────────────────────────────────
// MARK: - Kalman Filter for GPS
// ─────────────────────────────────────

/**
 * Lightweight 1D Kalman filter applied independently to latitude and longitude.
 * Smooths GPS noise while remaining responsive to real movement.
 */
class GpsKalmanFilter(
    private var processNoise: Double = 0.00001,  // Q: how much we expect position to change
    private var measurementNoise: Double = 3.0    // R: GPS measurement noise in degrees (~3m)
) {
    private var estimate: Double = 0.0
    private var errorCovariance: Double = 1.0
    private var initialized = false

    fun update(measurement: Double, accuracy: Float): Double {
        // Scale measurement noise by reported GPS accuracy
        val scaledMeasurementNoise = measurementNoise * (accuracy / 5.0).coerceAtLeast(1.0)

        if (!initialized) {
            estimate = measurement
            errorCovariance = scaledMeasurementNoise
            initialized = true
            return estimate
        }

        // Prediction step
        errorCovariance += processNoise

        // Update step
        val kalmanGain = errorCovariance / (errorCovariance + scaledMeasurementNoise)
        estimate += kalmanGain * (measurement - estimate)
        errorCovariance *= (1.0 - kalmanGain)

        return estimate
    }

    fun reset() {
        estimate = 0.0
        errorCovariance = 1.0
        initialized = false
    }
}

class RouteTracker(private val context: Context) {

    // ─────────────────────────────────────
    // MARK: - GPS Fix Quality
    // ─────────────────────────────────────

    enum class GpsStatus {
        OFF,        // Not tracking / no permission
        SEARCHING,  // Waiting for first fix
        POOR,       // Accuracy > 25m
        FAIR,       // Accuracy 15-25m
        GOOD        // Accuracy <= 15m
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

    private val _currentSpeed = MutableStateFlow(0f) // m/s (smoothed)
    val currentSpeed: StateFlow<Float> = _currentSpeed.asStateFlow()

    private val _currentLocation = MutableStateFlow<Pair<Double, Double>?>(null)
    val currentLocation: StateFlow<Pair<Double, Double>?> = _currentLocation.asStateFlow()

    private val _isAutopaused = MutableStateFlow(false)
    val isAutopaused: StateFlow<Boolean> = _isAutopaused.asStateFlow()

    private var isTracking = false
    private var isPaused = false

    private val _gpsMode = MutableStateFlow(GpsMode.HIGH_ACCURACY)
    val gpsMode: StateFlow<GpsMode> = _gpsMode.asStateFlow()

    private var batteryCheckJob: Job? = null
    private var autopauseJob: Job? = null

    // Kalman filters for lat/lng smoothing
    private val latKalman = GpsKalmanFilter()
    private val lngKalman = GpsKalmanFilter()

    // Speed smoothing buffer (rolling average of last 5 samples)
    private val speedBuffer = ArrayDeque<Float>(5)
    private val SPEED_BUFFER_SIZE = 5

    // Auto-pause: track consecutive stationary readings
    private var stationaryCount = 0
    private val STATIONARY_THRESHOLD = 3  // ~9s at 3s intervals to trigger auto-pause
    private val STATIONARY_SPEED = 0.5f   // m/s — reported speed below this is "not moving"
    private val STATIONARY_DISTANCE = 5.0 // meters — actual movement below this is "not moving"

    // Accuracy & teleportation thresholds
    private val MAX_ACCURACY_METERS = 25f           // reject points with worse accuracy
    private val MAX_DISTANCE_PER_UPDATE_METERS = 80.0 // ~96 km/h max, prevents teleportation
    private val MIN_DISTANCE_METERS = 2.0           // ignore sub-2m jitter

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
        val accuracy = location.accuracy

        // Always update raw current location (for map centering before route is built)
        _currentLocation.value = Pair(location.latitude, location.longitude)

        // Update GPS quality with finer tiers
        _gpsStatus.value = when {
            accuracy <= 15f -> GpsStatus.GOOD
            accuracy <= 25f -> GpsStatus.FAIR
            else -> GpsStatus.POOR
        }

        // Reject points with poor accuracy — they produce jagged routes
        if (accuracy > MAX_ACCURACY_METERS) return

        // Apply Kalman filter to smooth lat/lng
        val smoothedLat = latKalman.update(location.latitude, accuracy)
        val smoothedLng = lngKalman.update(location.longitude, accuracy)

        val newPoint = RoutePoint(
            latitude = smoothedLat,
            longitude = smoothedLng,
            altitude = if (location.hasAltitude()) location.altitude else 0.0,
            speed = 0f, // will be set below
            timestamp = location.time
        )

        // Calculate actual distance from last accepted point
        val current = _routePoints.value
        val actualDistance = if (current.isNotEmpty()) {
            distanceBetween(current.last(), newPoint)
        } else 0.0

        // Compute speed from actual distance (more reliable than location.speed)
        val timeDelta = if (current.isNotEmpty()) {
            (location.time - current.last().timestamp).coerceAtLeast(1L) / 1000.0
        } else 1.0
        val computedSpeed = (actualDistance / timeDelta).toFloat()

        // Also consider GPS-reported speed, but prefer computed
        val rawGpsSpeed = if (location.hasSpeed()) location.speed else 0f
        // Use the lower of computed vs GPS speed to be conservative about movement
        val effectiveSpeed = minOf(computedSpeed, rawGpsSpeed.takeIf { it > 0f } ?: computedSpeed)

        // Smooth speed with rolling average
        if (speedBuffer.size >= SPEED_BUFFER_SIZE) speedBuffer.removeFirst()
        speedBuffer.addLast(effectiveSpeed)
        val smoothedSpeed = speedBuffer.average().toFloat()
        _currentSpeed.value = smoothedSpeed

        // Auto-pause: use BOTH speed AND actual distance to detect stationary state
        // GPS can report false speed while sitting still due to signal noise
        val isStationary = smoothedSpeed < STATIONARY_SPEED && actualDistance < STATIONARY_DISTANCE

        if (isStationary) {
            stationaryCount++
            if (stationaryCount >= STATIONARY_THRESHOLD && !_isAutopaused.value) {
                _isAutopaused.value = true
            }
            // While autopaused, don't add route points (prevents GPS drift cluster)
            if (_isAutopaused.value) return
        } else {
            if (_isAutopaused.value) {
                _isAutopaused.value = false
            }
            stationaryCount = 0
        }

        // Update the point with smoothed speed
        val finalPoint = newPoint.copy(speed = smoothedSpeed)

        if (current.isNotEmpty()) {
            // Teleportation guard: reject impossibly large jumps
            if (actualDistance > MAX_DISTANCE_PER_UPDATE_METERS) return

            // Jitter filter: ignore sub-threshold movement
            if (actualDistance < MIN_DISTANCE_METERS) return

            _totalDistanceMeters.value += actualDistance
        }

        _routePoints.value = current + finalPoint
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
        _isAutopaused.value = false
        stationaryCount = 0
        speedBuffer.clear()
        latKalman.reset()
        lngKalman.reset()

        updateGpsMode()

        fusedClient.requestLocationUpdates(
            buildLocationRequest(_gpsMode.value),
            locationCallback,
            Looper.getMainLooper()
        )

        // Check battery every 60s
        batteryCheckJob = CoroutineScope(Dispatchers.Main).launch {
            while (isTracking) {
                delay(60_000)
                updateGpsMode()
            }
        }
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
        _gpsMode.value = GpsMode.HIGH_ACCURACY
        _isAutopaused.value = false
        fusedClient.removeLocationUpdates(locationCallback)
        batteryCheckJob?.cancel()
        autopauseJob?.cancel()
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
        _currentLocation.value = null
        _gpsStatus.value = GpsStatus.OFF
        _isAutopaused.value = false
        stationaryCount = 0
        speedBuffer.clear()
        latKalman.reset()
        lngKalman.reset()
    }

    // ─────────────────────────────────────
    // MARK: - Battery-Aware GPS
    // ─────────────────────────────────────

    private fun getBatteryPercent(): Int {
        val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        return batteryManager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            ?.takeIf { it in 0..100 } ?: 100
    }

    private fun updateGpsMode() {
        val battery = getBatteryPercent()
        val newMode = when {
            battery > 20 -> GpsMode.HIGH_ACCURACY
            battery > 10 -> GpsMode.BALANCED
            else -> GpsMode.LOW_POWER
        }
        if (newMode != _gpsMode.value) {
            _gpsMode.value = newMode
            applyGpsMode(newMode)
        }
    }

    @SuppressLint("MissingPermission")
    private fun applyGpsMode(mode: GpsMode) {
        if (!isTracking) return
        fusedClient.removeLocationUpdates(locationCallback)
        fusedClient.requestLocationUpdates(
            buildLocationRequest(mode),
            locationCallback,
            Looper.getMainLooper()
        )
    }

    private fun buildLocationRequest(mode: GpsMode): LocationRequest {
        return when (mode) {
            GpsMode.HIGH_ACCURACY -> LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 3_000L)
                .setMinUpdateIntervalMillis(2_000L)
                .setMinUpdateDistanceMeters(2f)
                .setWaitForAccurateLocation(true)
            GpsMode.BALANCED -> LocationRequest.Builder(Priority.PRIORITY_BALANCED_POWER_ACCURACY, 5_000L)
                .setMinUpdateIntervalMillis(3_000L)
                .setMinUpdateDistanceMeters(5f)
                .setWaitForAccurateLocation(false)
            GpsMode.LOW_POWER -> LocationRequest.Builder(Priority.PRIORITY_LOW_POWER, 10_000L)
                .setMinUpdateIntervalMillis(5_000L)
                .setMinUpdateDistanceMeters(10f)
                .setWaitForAccurateLocation(false)
        }.build()
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
