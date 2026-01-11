package com.swasthicare.mobile.ui.screens.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDateTime

data class HomeState(
    val userName: String = "Alex Johnson",
    val greeting: String = "Good Morning,",
    val stepCount: Int = 0,
    val calories: Int = 0,
    val activeMinutes: Int = 0,
    val heartRate: Int = 0,
    val sleepHours: String = "--",
    val distance: Double = 0.0,
    val hydrationCurrent: Int = 0,
    val hydrationGoal: Int = 2500,
    val medicationsTaken: Int = 0,
    val medicationsTotal: Int = 4,
    val isLoading: Boolean = true
)

class HomeViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(HomeState())
    val uiState: StateFlow<HomeState> = _uiState.asStateFlow()

    init {
        loadData()
    }

    private fun loadData() {
        viewModelScope.launch {
            // Simulate network delay
            delay(1500)
            
            val hour = LocalDateTime.now().hour
            val greeting = when (hour) {
                in 5..11 -> "Good Morning,"
                in 12..16 -> "Good Afternoon,"
                else -> "Good Evening,"
            }

            _uiState.value = HomeState(
                userName = "Alex Johnson",
                greeting = greeting,
                stepCount = 8432,
                calories = 450,
                activeMinutes = 45,
                heartRate = 72,
                sleepHours = "7h 30m",
                distance = 5.2,
                hydrationCurrent = 1250,
                hydrationGoal = 2500,
                medicationsTaken = 2,
                medicationsTotal = 4,
                isLoading = false
            )
        }
    }
    
    fun incrementHydration() {
        val current = _uiState.value
        if (current.hydrationCurrent < current.hydrationGoal) {
            _uiState.value = current.copy(hydrationCurrent = current.hydrationCurrent + 250)
        }
    }
}
