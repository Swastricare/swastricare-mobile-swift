package com.swastricare.health.ui.screens.notifications

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.content.SharedPreferences
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.hilt.navigation.compose.hiltViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.screens.home.lightBorder
import com.swastricare.health.ui.theme.AppColors
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import com.swastricare.health.ui.components.TrackScreen

// ─────────────────────────────────────
// MARK: - Data Models
// ─────────────────────────────────────

@Serializable
data class NotificationRecord(
    val id: String,
    val title: String,
    val body: String,
    val category: NotificationCategory,
    val timestamp: String, // ISO datetime
    val isRead: Boolean = false
) {
    val formattedTime: String get() {
        val timePart = timestamp.substringAfter("T").take(5)
        val parts = timePart.split(":")
        if (parts.size < 2) return timePart
        val hour = parts[0].toIntOrNull() ?: return timePart
        val minute = parts[1]
        val amPm = if (hour < 12) "AM" else "PM"
        val hour12 = when {
            hour == 0 -> 12
            hour > 12 -> hour - 12
            else -> hour
        }
        return "$hour12:$minute $amPm"
    }

    val dateKey: String get() = timestamp.take(10)
}

@Serializable
enum class NotificationCategory(val displayName: String, val icon: String, val colorHex: Long) {
    HYDRATION("Hydration", "💧", 0xFF00BCD4),
    MEDICATION("Medication", "💊", 0xFF4CAF50),
    DIET("Diet", "🥗", 0xFFFF9800),
    CYCLE("Cycle", "🌸", 0xFFE91E63),
    APPOINTMENT("Appointment", "🏥", 0xFF9C27B0),
    ACTIVITY("Activity", "🏃", 0xFF2196F3),
    AI_NUDGE("AI Coach", "🤖", 0xFF00BCD4),
    GENERAL("General", "🔔", 0xFF607D8B);
}

// ─────────────────────────────────────
// MARK: - ViewModel
// ─────────────────────────────────────

data class NotificationHistoryState(
    val records: List<NotificationRecord> = emptyList(),
    val isLoading: Boolean = true,
    val isRefreshing: Boolean = false
) {
    val groupedByDate: Map<String, List<NotificationRecord>>
        get() = records.groupBy { it.dateKey }
            .toSortedMap(compareByDescending { it })

    val isEmpty: Boolean get() = records.isEmpty() && !isLoading
}

@HiltViewModel
class NotificationHistoryViewModel @Inject constructor(
    private val prefs: SharedPreferences
) : ViewModel() {
    private val _uiState = MutableStateFlow(NotificationHistoryState())
    val uiState: StateFlow<NotificationHistoryState> = _uiState.asStateFlow()

    init {
        loadHistory()
    }

    fun loadHistory() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            val records = loadFromPrefs()
            _uiState.value = _uiState.value.copy(records = records, isLoading = false)
        }
    }

    fun refresh() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isRefreshing = true)
            delay(500)
            val records = loadFromPrefs()
            _uiState.value = _uiState.value.copy(records = records, isRefreshing = false)
        }
    }

    fun clearHistory() {
        viewModelScope.launch {
            prefs.edit().remove("notification_history").apply()
            _uiState.value = _uiState.value.copy(records = emptyList())
        }
    }

    private fun loadFromPrefs(): List<NotificationRecord> {
        val json = prefs.getString("notification_history", null) ?: return emptyList()
        return try {
            kotlinx.serialization.json.Json.decodeFromString<List<NotificationRecord>>(json)
                .filter {
                    // Only show last 7 days
                    val dateStr = it.timestamp.take(10)
                    val date = LocalDate.parse(dateStr)
                    date.isAfter(LocalDate.now().minusDays(8))
                }
                .sortedByDescending { it.timestamp }
        } catch (_: Exception) {
            emptyList()
        }
    }

    companion object {
        /** Called by NotificationService to persist a new notification record */
        fun saveNotification(
            prefs: android.content.SharedPreferences,
            title: String,
            body: String,
            category: NotificationCategory
        ) {
            val existing = try {
                val json = prefs.getString("notification_history", null) ?: "[]"
                kotlinx.serialization.json.Json.decodeFromString<List<NotificationRecord>>(json)
            } catch (_: Exception) {
                emptyList()
            }

            val record = NotificationRecord(
                id = java.util.UUID.randomUUID().toString(),
                title = title,
                body = body,
                category = category,
                timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss"))
            )

            val updated = (listOf(record) + existing).take(200) // Keep max 200 records
            val historyJson = kotlinx.serialization.json.buildJsonArray {
                updated.forEach { r ->
                    add(kotlinx.serialization.json.Json.encodeToJsonElement(NotificationRecord.serializer(), r))
                }
            }.toString()
            prefs.edit().putString("notification_history", historyJson).apply()
        }
    }
}

// ─────────────────────────────────────
// MARK: - Screen
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationHistoryScreen(
    onNavigateBack: () -> Unit
) {
    TrackScreen("NotificationHistory")
    val vm: NotificationHistoryViewModel = hiltViewModel()
    val uiState by vm.uiState.collectAsState()
    var showClearDialog by remember { mutableStateOf(false) }

    Box(modifier = Modifier.fillMaxSize().background(AppColors.background)) {

        Column(modifier = Modifier.fillMaxSize()) {
            // ── Top Bar ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onNavigateBack) {
                    Icon(Icons.Default.ArrowBack, "Back", tint = AppColors.onSurface)
                }
                Text(
                    "Notifications",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f).padding(start = 4.dp)
                )
                if (uiState.records.isNotEmpty()) {
                    IconButton(onClick = { showClearDialog = true }) {
                        Icon(
                            Icons.Default.DeleteOutline, "Clear",
                            tint = AppColors.onSurface.copy(alpha = 0.5f)
                        )
                    }
                }
            }

            // ── Content ──
            when {
                uiState.isLoading -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(color = AppColors.primary)
                    }
                }
                uiState.isEmpty -> {
                    EmptyNotificationsView()
                }
                else -> {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        uiState.groupedByDate.forEach { (dateKey, records) ->
                            item(key = "header_$dateKey") {
                                DateHeader(dateKey = dateKey)
                            }
                            itemsIndexed(
                                items = records,
                                key = { _, record -> record.id }
                            ) { index, record ->
                                AnimatedVisibility(
                                    visible = true,
                                    enter = fadeIn(initialAlpha = 0.3f)
                                ) {
                                    NotificationCard(record = record)
                                }
                            }
                        }
                        item { Spacer(Modifier.height(100.dp)) }
                    }
                }
            }
        }
    }

    // Clear confirmation dialog
    if (showClearDialog) {
        AlertDialog(
            onDismissRequest = { showClearDialog = false },
            icon = { Icon(Icons.Default.DeleteOutline, null, tint = AppColors.error) },
            title = { Text("Clear Notification History") },
            text = { Text("This will remove all notification records from the past 7 days.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        vm.clearHistory()
                        showClearDialog = false
                    },
                    colors = ButtonDefaults.textButtonColors(contentColor = AppColors.error)
                ) { Text("Clear All") }
            },
            dismissButton = {
                TextButton(onClick = { showClearDialog = false }) { Text("Cancel") }
            }
        )
    }
}

// ─────────────────────────────────────
// MARK: - Components
// ─────────────────────────────────────

@Composable
private fun DateHeader(dateKey: String) {
    val date = try { LocalDate.parse(dateKey) } catch (_: Exception) { null }
    val label = when {
        date == null -> dateKey
        date == LocalDate.now() -> "Today"
        date == LocalDate.now().minusDays(1) -> "Yesterday"
        else -> date.format(DateTimeFormatter.ofPattern("EEEE, MMM d"))
    }

    Text(
        text = label,
        fontSize = 14.sp,
        fontWeight = FontWeight.SemiBold,
        color = AppColors.onSurface.copy(alpha = 0.5f),
        modifier = Modifier.padding(top = 4.dp)
    )
}

@Composable
private fun NotificationCard(record: NotificationRecord) {
    val sectionBg = if (isSystemInDarkTheme()) Color(0xFF1C1C1E) else AppColors.surface
    val categoryColor = Color(record.category.colorHex)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .lightBorder(14.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(sectionBg)
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top
    ) {
        // Category icon badge
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(categoryColor.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) {
            Text(record.category.icon, fontSize = 20.sp)
        }

        // Content
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    record.title,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
                Text(
                    record.formattedTime,
                    fontSize = 12.sp,
                    color = AppColors.onSurface.copy(alpha = 0.4f)
                )
            }
            Text(
                record.body,
                fontSize = 13.sp,
                color = AppColors.onSurface.copy(alpha = 0.6f),
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
private fun EmptyNotificationsView() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text("🔔", fontSize = 56.sp)
            Text(
                "No Notifications",
                fontSize = 20.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface.copy(alpha = 0.6f)
            )
            Text(
                "Your notification history from the\npast 7 days will appear here",
                fontSize = 14.sp,
                color = AppColors.onSurface.copy(alpha = 0.4f),
                textAlign = TextAlign.Center
            )
        }
    }
}
