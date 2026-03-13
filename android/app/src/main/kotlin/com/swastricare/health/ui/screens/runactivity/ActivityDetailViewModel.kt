package com.swastricare.health.ui.screens.runactivity

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.model.RoutePoint
import com.swastricare.health.data.model.SplitData
import com.swastricare.health.data.model.WorkoutDetail
import com.swastricare.health.data.repository.SupabaseAuthRepository
import com.swastricare.health.domain.model.WorkoutSession
import com.swastricare.health.domain.repository.ProfileRepository
import com.swastricare.health.domain.repository.RunActivityRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.format.DateTimeFormatter
import javax.inject.Inject

data class ActivityDetailUiState(
    val workout: WorkoutDetail? = null,
    val isLoading: Boolean = true
)

@HiltViewModel
class ActivityDetailViewModel @Inject constructor(
    private val runActivityRepository: RunActivityRepository,
    private val profileRepository: ProfileRepository,
    private val authRepository: SupabaseAuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(ActivityDetailUiState())
    val uiState: StateFlow<ActivityDetailUiState> = _uiState.asStateFlow()

    fun loadActivity(workoutId: String) {
        viewModelScope.launch {
            _uiState.value = ActivityDetailUiState(isLoading = true)

            // Try local storage first
            val local = runActivityRepository.loadLocalActivities()
                .find { it.id == workoutId }
                ?.toWorkoutDetail()
            if (local != null) {
                _uiState.value = ActivityDetailUiState(workout = local, isLoading = false)
                return@launch
            }

            // Try cloud
            try {
                val userId = authRepository.currentUser?.id ?: ""
                val profileId = profileRepository.getHealthProfile(userId).getOrNull()?.id
                if (profileId != null) {
                    val cloudResult = runActivityRepository.fetchActivitiesFromCloud(profileId)
                    val cloudWorkout = cloudResult.getOrNull()
                        ?.find { it.id == workoutId }
                        ?.toWorkoutDetail()
                    _uiState.value = ActivityDetailUiState(workout = cloudWorkout, isLoading = false)
                } else {
                    _uiState.value = ActivityDetailUiState(workout = null, isLoading = false)
                }
            } catch (_: Exception) {
                _uiState.value = ActivityDetailUiState(workout = null, isLoading = false)
            }
        }
    }

    private fun WorkoutSession.toWorkoutDetail(): WorkoutDetail {
        val formatter = DateTimeFormatter.ISO_LOCAL_DATE_TIME
        return WorkoutDetail(
            id = id,
            type = activityType.dbValue,
            startTime = startTime?.format(formatter) ?: "",
            endTime = endTime?.format(formatter) ?: "",
            durationSeconds = durationSeconds,
            distanceMeters = distanceMeters,
            calories = caloriesBurned,
            elevationGain = routePoints.zipWithNext { a, b ->
                val diff = b.altitude - a.altitude
                if (diff > 0) diff else 0.0
            }.sum(),
            avgPace = avgPaceSecondsPerKm.toDouble(),
            avgSpeed = if (durationSeconds > 0) (distanceMeters / 1000.0) / (durationSeconds / 3600.0) else 0.0,
            maxSpeed = 0.0,
            routePoints = routePoints.map { point ->
                RoutePoint(
                    latitude = point.latitude,
                    longitude = point.longitude,
                    altitude = point.altitude,
                    speed = 0f,
                    timestamp = point.timestamp
                )
            },
            splits = splits.map { split ->
                SplitData(
                    kilometer = split.kilometer,
                    timeSeconds = split.timeSeconds,
                    paceSecondsPerKm = split.paceSecondsPerKm,
                    cumulativeSeconds = split.timeSeconds * split.kilometer
                )
            }
        )
    }
}
