package com.swastricare.health.ui.screens.medications

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.data.models.AdherenceStatus
import com.swastricare.health.data.models.MedicationDose
import com.swastricare.health.data.models.MedicationType
import com.swastricare.health.ui.screens.home.WaterWave
import com.swastricare.health.ui.screens.home.lightBorder
import com.swastricare.health.ui.theme.AppColors
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale
import kotlin.math.min

// ─────────────────────────────────────
// MARK: - Brand Colors
// ─────────────────────────────────────

val MedBrandBlue = Color(0xFF2E3192)   // iOS Color(hex: "2E3192")
val MedTealGreen = Color(0xFF11998E)   // iOS Color(hex: "11998e")

// ─────────────────────────────────────
// MARK: - MedicationType Icon
// ─────────────────────────────────────

fun MedicationType.toIcon(): ImageVector = when (this) {
    MedicationType.PILL -> Icons.Default.Medication
    MedicationType.LIQUID -> Icons.Default.LocalDrink
    MedicationType.INJECTION -> Icons.Default.Vaccines
    MedicationType.INHALER -> Icons.Default.Air
    MedicationType.DROPS -> Icons.Default.WaterDrop
    MedicationType.CREAM -> Icons.Default.Spa
    MedicationType.OTHER -> Icons.Default.MedicalServices
}

// ─────────────────────────────────────
// MARK: - AdherenceStatus Helpers
// ─────────────────────────────────────

fun AdherenceStatus.toIcon(): ImageVector = when (this) {
    AdherenceStatus.TAKEN -> Icons.Default.CheckCircle
    AdherenceStatus.PENDING -> Icons.Default.Schedule
    AdherenceStatus.MISSED -> Icons.Default.Cancel
    AdherenceStatus.SKIPPED -> Icons.Default.RemoveCircleOutline
    AdherenceStatus.LATE -> Icons.Default.AccessTime
    AdherenceStatus.EARLY -> Icons.Default.SkipPrevious
}

fun AdherenceStatus.displayName(): String = when (this) {
    AdherenceStatus.TAKEN -> "Taken"
    AdherenceStatus.PENDING -> "Pending"
    AdherenceStatus.MISSED -> "Missed"
    AdherenceStatus.SKIPPED -> "Skipped"
    AdherenceStatus.LATE -> "Late"
    AdherenceStatus.EARLY -> "Early"
}

fun AdherenceStatus.statusColor(): Color = when (this) {
    AdherenceStatus.TAKEN -> Color(0xFF34C759)
    AdherenceStatus.LATE -> Color(0xFFFF9500)
    AdherenceStatus.EARLY -> Color(0xFF007AFF)
    AdherenceStatus.MISSED -> Color(0xFFFF3B30)
    AdherenceStatus.SKIPPED -> Color(0xFF8E8E93)
    AdherenceStatus.PENDING -> Color(0xFF8E8E93)
}

// ─────────────────────────────────────
// MARK: - CalendarStrip
// ─────────────────────────────────────

/**
 * Horizontal scrollable 7-day calendar strip starting from today.
 * Matches iOS: day abbreviation + day number in circle.
 */
@Composable
fun CalendarStrip(
    selectedDate: LocalDate,
    onDateSelected: (LocalDate) -> Unit,
    modifier: Modifier = Modifier
) {
    val today = LocalDate.now()
    val dates = (0..6).map { today.plusDays(it.toLong()) }

    androidx.compose.foundation.lazy.LazyRow(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = PaddingValues(horizontal = 20.dp)
    ) {
        items(dates.size) { index ->
            val date = dates[index]
            val isToday = date == today
            val isSelected = date == selectedDate

            CalendarDay(
                date = date,
                isToday = isToday,
                isSelected = isSelected,
                onClick = { onDateSelected(date) }
            )
        }
    }
}

@Composable
private fun CalendarDay(
    date: LocalDate,
    isToday: Boolean,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    val dayAbbr = date.dayOfWeek
        .getDisplayName(TextStyle.SHORT, Locale.getDefault())
        .take(3)

    val bgColor = when {
        isSelected -> Color.Transparent
        isToday -> MedBrandBlue.copy(alpha = 0.1f)
        else -> Color.Transparent
    }

    Box(
        modifier = Modifier
            .width(56.dp)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onClick() }
            .background(bgColor, RoundedCornerShape(12.dp))
            .padding(vertical = 10.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(
                text = dayAbbr,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = if (isSelected) Color.White else AppColors.onSurface.copy(alpha = 0.5f)
            )
            // Number inside circle when selected
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .background(
                        color = if (isSelected) MedBrandBlue else Color.Transparent,
                        shape = CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = date.dayOfMonth.toString(),
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = if (isSelected) Color.White else AppColors.onSurface
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - PillBottleView (matches iOS exactly)
// ─────────────────────────────────────

/**
 * Animated pill bottle with water fill — exact iOS PillBottleView match.
 * Width: 80dp, Height: 130dp
 * Fill color: teal (#11998E)
 * Shows percentage inside body.
 */
@Composable
fun PillBottleView(
    progress: Float,                // 0..1
    modifier: Modifier = Modifier,
    bottleWidth: Int = 80,          // dp
    bottleHeight: Int = 130         // dp
) {
    val teal = MedTealGreen
    val safeProgress = progress.coerceIn(0f, 1f)

    val animatedFill by animateFloatAsState(
        targetValue = safeProgress,
        animationSpec = tween(durationMillis = 800, delayMillis = 200, easing = FastOutSlowInEasing),
        label = "bottleFill"
    )

    // Body starts at 16% from top (cap 10% + neck 6%)
    val bodyTopFraction = 0.16f
    val bodyBottomRadius = 10.dp

    Box(
        modifier = modifier.size(bottleWidth.dp, bottleHeight.dp)
    ) {
        // ── Bottle outline (Canvas) ──
        Canvas(modifier = Modifier.fillMaxSize()) {
            val w = size.width
            val h = size.height
            val stroke = Stroke(width = 2.dp.toPx(), cap = StrokeCap.Round)
            val outlineColor = teal.copy(alpha = 0.3f)

            val capH = h * 0.10f
            val neckH = h * 0.06f
            val bodyTop = capH + neckH
            val capInset = w * 0.15f
            val neckInset = w * 0.10f
            val bodyR = CornerRadius(min(w * 0.08f, 10.dp.toPx()))
            val capR = min(w * 0.06f, 6.dp.toPx())

            // Cap
            val capPath = Path().apply {
                addRoundRect(
                    RoundRect(
                        left = capInset, top = 0f,
                        right = w - capInset, bottom = capH,
                        topLeftCornerRadius = CornerRadius(capR),
                        topRightCornerRadius = CornerRadius(capR)
                    )
                )
            }
            drawPath(capPath, outlineColor, style = stroke)

            // Neck (simple rect, no fill)
            drawRect(
                color = outlineColor,
                topLeft = Offset(neckInset, capH),
                size = Size(w - 2 * neckInset, neckH),
                style = stroke
            )

            // Body
            val bodyPath = Path().apply {
                addRoundRect(
                    RoundRect(
                        left = 0f, top = bodyTop,
                        right = w, bottom = h,
                        bottomLeftCornerRadius = bodyR,
                        bottomRightCornerRadius = bodyR
                    )
                )
            }
            drawPath(bodyPath, outlineColor, style = stroke)
        }

        // ── Water fill (clipped to body only) ──
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(1f - bodyTopFraction)
                .align(Alignment.BottomCenter)
                .clip(RoundedCornerShape(bottomStart = bodyBottomRadius, bottomEnd = bodyBottomRadius))
        ) {
            WaterWave(
                progress = animatedFill,
                color = teal.copy(alpha = 0.25f),
                modifier = Modifier.fillMaxSize()
            )
            WaterWave(
                progress = animatedFill,
                color = teal.copy(alpha = 0.4f),
                modifier = Modifier
                    .fillMaxSize()
                    .padding(top = 3.dp)
            )
        }

        // ── Percentage label ──
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.padding(top = (bottleHeight * bodyTopFraction).dp)
            ) {
                Text(
                    text = "${(animatedFill * 100).toInt()}%",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onSurface
                )
                if (animatedFill >= 1f) {
                    Icon(
                        Icons.Default.CheckCircle,
                        contentDescription = null,
                        tint = Color(0xFF34C759),
                        modifier = Modifier.size(14.dp)
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Medication Stat Pill
// ─────────────────────────────────────

/**
 * Icon + value + label pill. Matches iOS medicationStatPill.
 */
@Composable
fun MedicationStatPill(
    icon: ImageVector,
    iconColor: Color,
    value: String,
    label: String,
    modifier: Modifier = Modifier
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(iconColor.copy(alpha = 0.08f))
            .padding(vertical = 10.dp, horizontal = 8.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = iconColor,
            modifier = Modifier.size(14.dp)
        )
        Text(
            text = value,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface
        )
        Text(
            text = label,
            fontSize = 11.sp,
            color = AppColors.onSurface.copy(alpha = 0.5f),
            maxLines = 1
        )
    }
}

// ─────────────────────────────────────
// MARK: - Timeline Medication Card
// ─────────────────────────────────────

/**
 * Matches iOS TimelineMedicationCard exactly:
 * [icon box][name + dosage · status][quick-take checkmark]
 */
@Composable
fun TimelineMedicationCard(
    dose: MedicationDose,
    onTaken: () -> Unit,
    onTap: () -> Unit,
    modifier: Modifier = Modifier
) {
    val isDark = isSystemInDarkTheme()
    val cardBg = if (isDark) Color(0xFF2C2C2E) else Color(0xFFF2F2F7)

    val statusText = if (dose.status == AdherenceStatus.PENDING && dose.isOverdue) "Overdue" else dose.status.displayName()
    val statusColor = if (dose.status == AdherenceStatus.PENDING && dose.isOverdue)
        Color(0xFFFF3B30) else dose.status.statusColor()

    Box(
        modifier = modifier
            .lightBorder(14.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(cardBg)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onTap() }
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Medication type icon box (40×40)
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(MedBrandBlue.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = dose.medicationType.toIcon(),
                    contentDescription = null,
                    tint = MedBrandBlue,
                    modifier = Modifier.size(18.dp)
                )
            }

            // Name + dosage · status
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(3.dp)
            ) {
                Text(
                    text = dose.medicationName,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onSurface,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    if (dose.dosage.isNotBlank()) {
                        Text(
                            text = dose.dosage,
                            fontSize = 12.sp,
                            color = AppColors.onSurface.copy(alpha = 0.5f)
                        )
                        Text(
                            text = "·",
                            fontSize = 12.sp,
                            color = AppColors.onSurface.copy(alpha = 0.5f)
                        )
                    }
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(3.dp)
                    ) {
                        Icon(
                            imageVector = dose.status.toIcon(),
                            contentDescription = null,
                            tint = statusColor,
                            modifier = Modifier.size(10.dp)
                        )
                        Text(
                            text = statusText,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            color = statusColor
                        )
                    }
                }
            }

            // Action icon on right
            if (dose.status == AdherenceStatus.PENDING) {
                IconButton(
                    onClick = onTaken,
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.CheckCircle,
                        contentDescription = "Take",
                        tint = MedTealGreen,
                        modifier = Modifier.size(28.dp)
                    )
                }
            } else if (dose.status == AdherenceStatus.TAKEN ||
                       dose.status == AdherenceStatus.LATE ||
                       dose.status == AdherenceStatus.EARLY) {
                Icon(
                    imageVector = Icons.Default.CheckCircle,
                    contentDescription = null,
                    tint = Color(0xFF34C759).copy(alpha = 0.6f),
                    modifier = Modifier.size(24.dp)
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - DoseCard (Detail screen)
// ─────────────────────────────────────

/**
 * Matches iOS DoseCard: time + status + take/skip or taken-at label.
 */
@Composable
fun DoseCard(
    dose: MedicationDose,
    onMarkTaken: () -> Unit,
    onMarkSkipped: () -> Unit,
    modifier: Modifier = Modifier
) {
    val timeFormatter = java.time.format.DateTimeFormatter.ofPattern("h:mm a")

    Box(
        modifier = modifier
            .fillMaxWidth()
            .lightBorder(14.dp)
            .clip(RoundedCornerShape(14.dp))
            .let {
                val isDark = isSystemInDarkTheme()
                if (isDark) it.background(Color(0xFF2C2C2E))
                else it.background(Color(0xFFF2F2F7))
            }
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 18.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    text = dose.scheduledTime.format(timeFormatter),
                    fontSize = 18.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onSurface
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Icon(
                        imageVector = dose.status.toIcon(),
                        contentDescription = null,
                        tint = dose.status.statusColor(),
                        modifier = Modifier.size(12.dp)
                    )
                    Text(
                        text = if (dose.isOverdue && dose.status == AdherenceStatus.PENDING)
                            "Overdue" else dose.status.displayName(),
                        fontSize = 13.sp,
                        color = if (dose.isOverdue && dose.status == AdherenceStatus.PENDING)
                            Color(0xFFFF3B30) else dose.status.statusColor()
                    )
                }
            }

            if (dose.status == AdherenceStatus.PENDING) {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    IconButton(onClick = onMarkTaken, modifier = Modifier.size(36.dp)) {
                        Icon(Icons.Default.CheckCircle, null, tint = Color(0xFF34C759), modifier = Modifier.size(28.dp))
                    }
                    IconButton(onClick = onMarkSkipped, modifier = Modifier.size(36.dp)) {
                        Icon(Icons.Default.Cancel, null, tint = Color(0xFFFF9500), modifier = Modifier.size(28.dp))
                    }
                }
            } else if (dose.takenAt != null) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Icon(Icons.Default.CheckCircle, null, tint = Color(0xFF34C759), modifier = Modifier.size(12.dp))
                    Text(
                        text = "at ${dose.takenAt.format(timeFormatter)}",
                        fontSize = 13.sp,
                        color = AppColors.onSurface.copy(alpha = 0.5f)
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - DetailRow
// ─────────────────────────────────────

/**
 * Label + value row with icon. Matches iOS DetailRow.
 */
@Composable
fun DetailRow(
    label: String,
    value: String,
    icon: ImageVector,
    modifier: Modifier = Modifier
) {
    val isDark = isSystemInDarkTheme()
    val cardBg = if (isDark) Color(0xFF2C2C2E) else Color(0xFFF2F2F7)

    Row(
        modifier = modifier
            .fillMaxWidth()
            .lightBorder(14.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(cardBg)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.weight(1f)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = AppColors.onSurface.copy(alpha = 0.5f),
                modifier = Modifier.size(14.dp)
            )
            Text(
                text = label,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.onSurface.copy(alpha = 0.5f)
            )
        }
        Text(
            text = value,
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            color = AppColors.onSurface
        )
    }
}

// ─────────────────────────────────────
// MARK: - MedicationStatCard
// ─────────────────────────────────────

/**
 * Big number + title. Matches iOS MedicationStatCard.
 */
@Composable
fun MedicationStatCard(
    title: String,
    value: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            text = value,
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = color
        )
        Text(
            text = title,
            fontSize = 13.sp,
            color = AppColors.onSurface.copy(alpha = 0.5f)
        )
    }
}

// ─────────────────────────────────────
// MARK: - TypeCard (AddMedication)
// ─────────────────────────────────────

/**
 * Medication type selection card. Matches iOS TypeCard.
 * Selected: white icon/text on #2E3192 background.
 * Unselected: blue icon/text on subtle gray.
 */
@Composable
fun MedicationTypeCard(
    type: MedicationType,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(
                if (isSelected) MedBrandBlue
                else AppColors.onSurface.copy(alpha = 0.05f)
            )
            .border(
                width = 1.dp,
                color = if (isSelected) Color.Transparent
                        else AppColors.onSurface.copy(alpha = 0.1f),
                shape = RoundedCornerShape(14.dp)
            )
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onClick() }
            .padding(vertical = 20.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Icon(
                imageVector = type.toIcon(),
                contentDescription = null,
                tint = if (isSelected) Color.White else MedBrandBlue,
                modifier = Modifier.size(28.dp)
            )
            Text(
                text = type.displayName,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = if (isSelected) Color.White else AppColors.onSurface
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - ScheduleTemplateCard (AddMedication)
// ─────────────────────────────────────

/**
 * Schedule option with name, description, and selection checkmark.
 * Matches iOS ScheduleTemplateCard.
 */
@Composable
fun ScheduleTemplateCard(
    title: String,
    description: String,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val isDark = isSystemInDarkTheme()
    val cardBg = if (isDark) Color(0xFF2C2C2E) else Color(0xFFF2F2F7)

    Box(
        modifier = modifier
            .fillMaxWidth()
            .lightBorder(14.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(cardBg)
            .border(
                width = if (isSelected) 2.dp else 0.dp,
                color = if (isSelected) MedBrandBlue else Color.Transparent,
                shape = RoundedCornerShape(14.dp)
            )
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onClick() }
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 18.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = title,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onSurface
                )
                Text(
                    text = description,
                    fontSize = 13.sp,
                    color = AppColors.onSurface.copy(alpha = 0.5f)
                )
            }
            if (isSelected) {
                Icon(
                    imageVector = Icons.Default.CheckCircle,
                    contentDescription = null,
                    tint = MedBrandBlue,
                    modifier = Modifier.size(24.dp)
                )
            }
        }
    }
}
