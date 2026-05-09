package com.swastricare.health.ui.screens.medications

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForwardIos
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.swastricare.health.data.models.AdherenceStatus
import com.swastricare.health.data.models.MedicationType
import com.swastricare.health.data.models.MedicationWithDoses
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.theme.AITeal
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.format.DateTimeFormatter

// ─────────────────────────────────────
// MARK: - Filter Enum
// ─────────────────────────────────────

private enum class MedFilter(val label: String) {
    ALL("All"),
    ACTIVE("Active"),
    COMPLETED("Completed"),
    DISCONTINUED("Discontinued")
}

// ─────────────────────────────────────
// MARK: - Type → Icon Colors
// ─────────────────────────────────────

private val typeColors: Map<MedicationType, Pair<Color, Color>> = mapOf(
    MedicationType.PILL       to (Color(0xFFE3F2FD) to Color(0xFF5BA4CF)),
    MedicationType.LIQUID     to (Color(0xFFE8F9F3) to Color(0xFF22C5A6)),
    MedicationType.INJECTION  to (Color(0xFFFDE8F4) to Color(0xFFCF5BA4)),
    MedicationType.INHALER    to (Color(0xFFEFE8FE) to Color(0xFF8B5BCF)),
    MedicationType.DROPS      to (Color(0xFFE3F5FD) to Color(0xFF42A5DC)),
    MedicationType.CREAM      to (Color(0xFFFEF3E8) to Color(0xFFCF8B5B)),
    MedicationType.OTHER      to (Color(0xFFF5F5F5) to Color(0xFF888888))
)

// Cycling fallback palette for medications beyond 7
private val fallbackPalette = listOf(
    Color(0xFFE3F2FD) to Color(0xFF5BA4CF),
    Color(0xFFFFF3E0) to Color(0xFFFFB74D),
    Color(0xFFE8F5E9) to Color(0xFF66BB6A),
    Color(0xFFFCE4EC) to Color(0xFFEC407A),
    Color(0xFFEDE7F6) to Color(0xFF7E57C2),
    Color(0xFFE0F7FA) to Color(0xFF26C6DA),
    Color(0xFFFFF9C4) to Color(0xFFFFCA28)
)

private fun iconColors(mwd: MedicationWithDoses, index: Int): Pair<Color, Color> =
    typeColors[mwd.type] ?: fallbackPalette[index % fallbackPalette.size]

// ─────────────────────────────────────
// MARK: - Badge helpers
// ─────────────────────────────────────

private data class BadgeInfo(val label: String, val bg: Color, val text: Color)

private fun MedicationWithDoses.badge(): BadgeInfo {
    val endDatePassed = medication.endDate != null && !medication.isOngoing &&
        runCatching { LocalDate.parse(medication.endDate!!.take(10)).isBefore(LocalDate.now()) }.getOrDefault(false)

    return when (medication.status) {
        "discontinued" -> BadgeInfo("Discontinued", Color(0xFFF0F0F0), Color(0xFF888888))
        "completed"    -> BadgeInfo("Completed",    Color(0xFFF0F0F0), Color(0xFF888888))
        "paused"       -> BadgeInfo("Paused",        Color(0xFFFFF3E0), Color(0xFFFF9500))
        else -> when {
            endDatePassed -> BadgeInfo("Completed", Color(0xFFF0F0F0), Color(0xFF888888))
            todayDoses.isNotEmpty() &&
                todayDoses.all { it.status == AdherenceStatus.PENDING && it.scheduledTime.isAfter(LocalDateTime.now()) } ->
                BadgeInfo("Upcoming", Color(0xFFFFF3E0), Color(0xFFFF9500))
            else -> BadgeInfo("Active", Color(0xFFE8F9F3), AITeal)
        }
    }
}

// ─────────────────────────────────────
// MARK: - Schedule line helper
// ─────────────────────────────────────

private fun MedicationWithDoses.scheduleLine(): String {
    val schedules = schedules
    if (schedules.isEmpty()) return "As needed"
    val formatter = DateTimeFormatter.ofPattern("hh:mm a")
    val firstTime = runCatching {
        val t = schedules.first().timeOfDay.take(5)
        LocalTime.parse(t, DateTimeFormatter.ofPattern("HH:mm")).format(formatter)
    }.getOrDefault(schedules.first().timeOfDay.take(5))

    return if (schedules.size == 1) "Every day · $firstTime"
    else "${schedules.size} times a day · $firstTime"
}

// ─────────────────────────────────────
// MARK: - AllMedicationsScreen
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class, androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
fun AllMedicationsScreen(
    onBack: () -> Unit,
    onNavigateToDetail: (String) -> Unit,
    onNavigateToAddMedication: () -> Unit
) {
    TrackScreen("AllMedications")
    val vm: MedicationsViewModel = hiltViewModel()
    val uiState by vm.uiState.collectAsState()

    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) vm.loadMedications()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    var filter by remember { mutableStateOf(MedFilter.ALL) }
    var searchQuery by remember { mutableStateOf("") }
    var searchActive by remember { mutableStateOf(false) }

    val filtered = remember(uiState.medicationsWithDoses, filter, searchQuery) {
        uiState.medicationsWithDoses.filter { mwd ->
            val endDatePassed = mwd.medication.endDate != null && !mwd.medication.isOngoing &&
                runCatching { LocalDate.parse(mwd.medication.endDate!!.take(10)).isBefore(LocalDate.now()) }.getOrDefault(false)
            val matchesFilter = when (filter) {
                MedFilter.ALL          -> true
                MedFilter.ACTIVE       -> mwd.medication.status in listOf("active", "paused") && !endDatePassed
                MedFilter.COMPLETED    -> mwd.medication.status == "completed" || endDatePassed
                MedFilter.DISCONTINUED -> mwd.medication.status == "discontinued"
            }
            val matchesSearch = searchQuery.isBlank() ||
                mwd.medication.name.contains(searchQuery, ignoreCase = true) ||
                mwd.medication.dosage?.contains(searchQuery, ignoreCase = true) == true ||
                mwd.medication.notes?.contains(searchQuery, ignoreCase = true) == true
            matchesFilter && matchesSearch
        }
    }

    Scaffold(
        containerColor = Color.White,
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = onNavigateToAddMedication,
                containerColor = AITeal,
                contentColor = Color.White,
                icon = { Icon(Icons.Default.Add, null, modifier = Modifier.size(20.dp)) },
                text = {
                    Text(
                        "Add Medication",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                },
                modifier = Modifier.navigationBarsPadding()
            )
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = innerPadding.calculateTopPadding()),
            contentPadding = PaddingValues(bottom = 120.dp)
        ) {
            // ── Hero Header ──
            item {
                AllMedHeroHeader(
                    onBack = onBack,
                    searchActive = searchActive,
                    searchQuery = searchQuery,
                    onSearchToggle = {
                        searchActive = !searchActive
                        if (!searchActive) searchQuery = ""
                    },
                    onSearchQueryChange = { searchQuery = it }
                )
            }

            // ── Tab Bar (sticky) ──
            stickyHeader {
                AllMedTabBar(selected = filter, onSelect = { filter = it })
            }

            // ── Skeleton Loading ──
            if (uiState.isLoading && uiState.medicationsWithDoses.isEmpty()) {
                items(6) {
                    AllMedRowSkeleton()
                }
            }

            // ── Empty State ──
            else if (filtered.isEmpty() && !uiState.isLoading) {
                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 48.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(
                            Icons.Default.Medication,
                            contentDescription = null,
                            tint = Color(0xFFCCCCCC),
                            modifier = Modifier.size(48.dp)
                        )
                        Text(
                            if (searchQuery.isNotBlank()) "No results for \"$searchQuery\""
                            else "No ${filter.label.lowercase()} medications",
                            fontSize = 15.sp,
                            color = Color(0xFF888888),
                            textAlign = TextAlign.Center
                        )
                    }
                }
            } else {
                itemsIndexed(
                    items = filtered,
                    key = { _, mwd -> mwd.medication.id }
                ) { index, mwd ->
                    AllMedRow(
                        mwd = mwd,
                        index = index,
                        onClick = { onNavigateToDetail(mwd.medication.id) }
                    )
                }
            }


            // ── Stay Consistent Banner ──
            item { StayConsistentBanner() }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Hero Header
// ─────────────────────────────────────

@Composable
private fun AllMedHeroHeader(
    onBack: () -> Unit,
    searchActive: Boolean,
    searchQuery: String,
    onSearchToggle: () -> Unit,
    onSearchQueryChange: (String) -> Unit
) {
    val tips = listOf(
        Triple(Icons.Default.Schedule,       Color(0xFF22C5A6), "Take at the same time each day for best results."),
        Triple(Icons.Default.WaterDrop,      Color(0xFF5BA4CF), "Always take pills with a full glass of water."),
        Triple(Icons.Default.Notifications,  Color(0xFF8B5BCF), "Enable reminders so you never miss a dose."),
        Triple(Icons.Default.FavoriteBorder, Color(0xFFEC407A), "Consistency is the key to effective treatment."),
        Triple(Icons.Default.CheckCircle,    Color(0xFF66BB6A), "Mark doses taken right after you take them.")
    )
    val tipIndex = remember { (System.currentTimeMillis() / 60000 % tips.size).toInt() }
    val (tipIcon, tipColor, tipText) = tips[tipIndex]

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White)
    ) {
        // ── Top bar ──
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(horizontal = 4.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = if (searchActive) onSearchToggle else onBack) {
                Icon(
                    if (searchActive) Icons.Default.Close else Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = null,
                    tint = Color(0xFF1A1A2E)
                )
            }
            if (searchActive) {
                TextField(
                    value = searchQuery,
                    onValueChange = onSearchQueryChange,
                    placeholder = { Text("Search medications…", fontSize = 15.sp, color = Color(0xFFAAAAAA)) },
                    singleLine = true,
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = Color.Transparent,
                        unfocusedContainerColor = Color.Transparent,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent,
                        cursorColor = AITeal
                    ),
                    modifier = Modifier.weight(1f)
                )
            } else {
                Column(modifier = Modifier.weight(1f)) {
                    Text("All Medications", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Color(0xFF1A1A2E))
                    Text("Manage your medications 💊", fontSize = 13.sp, color = Color(0xFF666666))
                }
                IconButton(onClick = onSearchToggle) {
                    Icon(Icons.Default.Search, contentDescription = "Search", tint = Color(0xFF1A1A2E))
                }
            }
        }

        if (!searchActive) {
            Spacer(Modifier.height(4.dp))

            // ── Tip of the moment card ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(tipColor.copy(alpha = 0.10f))
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(tipColor.copy(alpha = 0.18f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(tipIcon, null, tint = tipColor, modifier = Modifier.size(20.dp))
                }
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text("Tip", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = tipColor)
                    Text(tipText, fontSize = 13.sp, color = Color(0xFF3C3C43), lineHeight = 18.sp)
                }
            }

            Spacer(Modifier.height(8.dp))
        }
    }
}


// ─────────────────────────────────────
// MARK: - Tab Bar
// ─────────────────────────────────────

@Composable
private fun AllMedTabBar(selected: MedFilter, onSelect: (MedFilter) -> Unit) {
    Surface(color = Color.White, shadowElevation = 1.dp) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(0.dp)
        ) {
            MedFilter.entries.forEach { tab ->
                val isSelected = tab == selected
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null
                        ) { onSelect(tab) }
                        .padding(vertical = 12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        tab.label,
                        fontSize = 13.sp,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                        color = if (isSelected) AITeal else Color(0xFF888888),
                        maxLines = 1
                    )
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(0.6f)
                            .height(2.dp)
                            .clip(RoundedCornerShape(1.dp))
                            .background(if (isSelected) AITeal else Color.Transparent)
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Medication Row
// ─────────────────────────────────────

@Composable
private fun AllMedRow(
    mwd: MedicationWithDoses,
    index: Int,
    onClick: () -> Unit
) {
    val (bgColor, iconColor) = iconColors(mwd, index)
    val badge = mwd.badge()
    val schedLine = mwd.scheduleLine()
    val dosageText = buildString {
        mwd.medication.dosage?.let { append(it) }
        mwd.medication.dosageUnit?.let { if (isNotEmpty()) append(" "); append(it) }
        if (isNotEmpty()) append(" · ")
        append(mwd.type.displayName)
    }

    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null
                ) { onClick() }
                .padding(horizontal = 20.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Type icon circle
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(bgColor),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = mwd.type.toIcon(),
                    contentDescription = null,
                    tint = iconColor,
                    modifier = Modifier.size(24.dp)
                )
            }

            // Name + dosage + schedule
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    mwd.medication.name,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(0xFF1A1A2E),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                if (dosageText.isNotBlank()) {
                    Text(
                        dosageText,
                        fontSize = 12.sp,
                        color = Color(0xFF888888),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Icon(
                        Icons.Default.CalendarToday,
                        contentDescription = null,
                        tint = Color(0xFFAAAAAA),
                        modifier = Modifier.size(11.dp)
                    )
                    Text(
                        schedLine,
                        fontSize = 12.sp,
                        color = Color(0xFFAAAAAA),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }

            // Status badge
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(20.dp))
                    .background(badge.bg)
                    .padding(horizontal = 10.dp, vertical = 4.dp)
            ) {
                Text(
                    badge.label,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = badge.text
                )
            }

            // Chevron
            Icon(
                Icons.AutoMirrored.Filled.ArrowForwardIos,
                contentDescription = null,
                tint = Color(0xFFCCCCCC),
                modifier = Modifier.size(14.dp)
            )
        }

        HorizontalDivider(
            color = Color(0xFFF5F5F5),
            modifier = Modifier.padding(start = 82.dp)
        )
    }
}

// ─────────────────────────────────────
// MARK: - Stay Consistent Banner
// ─────────────────────────────────────

@Composable
private fun StayConsistentBanner() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color(0xFFF0FBF8))
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(AITeal.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Default.CheckCircle,
                contentDescription = null,
                tint = AITeal,
                modifier = Modifier.size(20.dp)
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                "Stay consistent",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color(0xFF1A1A2E)
            )
            Text(
                "Taking your medications on time helps you stay healthy",
                fontSize = 12.sp,
                color = Color(0xFF888888),
                lineHeight = 16.sp
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Skeleton Row
// ─────────────────────────────────────

@Composable
private fun AllMedRowSkeleton() {
    val shimmer = medShimmerBrush()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // Circle icon placeholder
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(CircleShape)
                .background(shimmer)
        )
        // Text lines
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(0.55f)
                    .height(14.dp)
                    .clip(RoundedCornerShape(7.dp))
                    .background(shimmer)
            )
            Box(
                modifier = Modifier
                    .fillMaxWidth(0.38f)
                    .height(11.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(shimmer)
            )
        }
        // Badge placeholder
        Box(
            modifier = Modifier
                .width(56.dp)
                .height(22.dp)
                .clip(RoundedCornerShape(11.dp))
                .background(shimmer)
        )
    }
}
