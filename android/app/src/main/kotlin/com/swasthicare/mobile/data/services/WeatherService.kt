package com.swasthicare.mobile.data.services

import android.Manifest
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.location.Location
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.URL
import kotlin.coroutines.resume

// -----------------------------------------------
// MARK: - Weather Data Model
// -----------------------------------------------

data class WeatherData(
    val temperatureCelsius: Double,
    val description: String,
    val city: String
)

// -----------------------------------------------
// MARK: - OpenWeatherMap API Response
// -----------------------------------------------

@Serializable
private data class OwmResponse(
    val main: OwmMain,
    val weather: List<OwmWeather> = emptyList(),
    val name: String = ""
)

@Serializable
private data class OwmMain(
    val temp: Double = 0.0
)

@Serializable
private data class OwmWeather(
    val description: String = ""
)

// -----------------------------------------------
// MARK: - WeatherService
// -----------------------------------------------

class WeatherService(
    private val context: Context,
    private val prefs: SharedPreferences
) {
    companion object {
        // TODO: Replace with your real OpenWeatherMap API key
        private const val API_KEY = "YOUR_OPENWEATHERMAP_API_KEY"
        private const val CACHE_KEY = "weather_cache"
        private const val CACHE_TIMESTAMP_KEY = "weather_cache_timestamp"
        private const val CACHE_TTL_MS = 60 * 60 * 1000L // 1 hour

        /** Temperature threshold above which hydration goal is increased */
        const val HOT_WEATHER_THRESHOLD = 30.0

        /** Multiplier applied to hydration goal in hot weather */
        const val HOT_WEATHER_MULTIPLIER = 1.20
    }

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    /**
     * Fetch current weather data.
     * Uses cached data if available and fresh (< 1 hour).
     * Returns null if location permission denied or API fails.
     */
    suspend fun getCurrentWeather(): WeatherData? {
        // Check cache first
        getCachedWeather()?.let { return it }

        // Check location permission
        if (ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return null
        }

        // Get location
        val location = getLastLocation() ?: return null

        // Fetch weather from API
        return fetchWeatherFromApi(location.latitude, location.longitude)
    }

    /**
     * Calculate the weather adjustment factor for hydration goal.
     * Returns 1.0 if weather data is unavailable or temp <= 30C.
     * Returns HOT_WEATHER_MULTIPLIER (1.20) if temp > 30C.
     */
    suspend fun getHydrationAdjustmentFactor(): Double {
        val weather = getCurrentWeather() ?: return 1.0
        return if (weather.temperatureCelsius > HOT_WEATHER_THRESHOLD) {
            HOT_WEATHER_MULTIPLIER
        } else {
            1.0
        }
    }

    // -----------------------------------------------
    // MARK: - Private Helpers
    // -----------------------------------------------

    private fun getCachedWeather(): WeatherData? {
        val timestamp = prefs.getLong(CACHE_TIMESTAMP_KEY, 0L)
        if (System.currentTimeMillis() - timestamp > CACHE_TTL_MS) return null

        val cached = prefs.getString(CACHE_KEY, null) ?: return null
        return try {
            val parts = cached.split("|")
            if (parts.size >= 3) {
                WeatherData(
                    temperatureCelsius = parts[0].toDouble(),
                    description = parts[1],
                    city = parts[2]
                )
            } else null
        } catch (_: Exception) {
            null
        }
    }

    private fun cacheWeather(data: WeatherData) {
        prefs.edit()
            .putString(CACHE_KEY, "${data.temperatureCelsius}|${data.description}|${data.city}")
            .putLong(CACHE_TIMESTAMP_KEY, System.currentTimeMillis())
            .apply()
    }

    @Suppress("MissingPermission")
    private suspend fun getLastLocation(): Location? =
        suspendCancellableCoroutine { cont ->
            try {
                val fusedClient = LocationServices.getFusedLocationProviderClient(context)
                val cancellationToken = CancellationTokenSource()

                fusedClient.getCurrentLocation(
                    Priority.PRIORITY_BALANCED_POWER_ACCURACY,
                    cancellationToken.token
                ).addOnSuccessListener { location ->
                    cont.resume(location)
                }.addOnFailureListener {
                    cont.resume(null)
                }

                cont.invokeOnCancellation {
                    cancellationToken.cancel()
                }
            } catch (e: Exception) {
                cont.resume(null)
            }
        }

    private suspend fun fetchWeatherFromApi(lat: Double, lon: Double): WeatherData? =
        withContext(Dispatchers.IO) {
            try {
                val urlStr = "https://api.openweathermap.org/data/2.5/weather" +
                        "?lat=$lat&lon=$lon&appid=$API_KEY&units=metric"
                val url = URL(urlStr)
                val connection = url.openConnection() as HttpURLConnection
                connection.connectTimeout = 10_000
                connection.readTimeout = 10_000
                connection.requestMethod = "GET"

                val responseCode = connection.responseCode
                if (responseCode != 200) return@withContext null

                val responseBody = connection.inputStream.bufferedReader().readText()
                connection.disconnect()

                val response = json.decodeFromString<OwmResponse>(responseBody)
                val weatherData = WeatherData(
                    temperatureCelsius = response.main.temp,
                    description = response.weather.firstOrNull()?.description ?: "",
                    city = response.name
                )

                cacheWeather(weatherData)
                weatherData
            } catch (e: Exception) {
                null
            }
        }
}
