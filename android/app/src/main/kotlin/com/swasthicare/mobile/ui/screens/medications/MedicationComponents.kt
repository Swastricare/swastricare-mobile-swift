package com.swasthicare.mobile.ui.screens.medications

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
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.data.models.AdherenceStatus
import com.swasthicare.mobile.data.models.MedicationDose
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.theme.*
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

// ─────────────────────────────────────
// MARK: - PillBottleProgress
// ─────────────────────────────────────

@Composable
fun PillBottleProgress(
    adherencePercentage: Float,
    takenCount: Int,
    totalCount: Int,
    modifier: Modifier = Modifier
) {
    val animatedFill by animateFloatAsState(
        targetValue = adherencePercentage.coerceIn(0f, 1f),
        animationSpec = tween(durationMillis = 800, easing = FastOutSlowInEasing),
        label = "pillFill"
    )

    val fillColor by animateColorAsState(
        targetValue = when {
            adherencePercentage >= 0.8f -> Color(0xFF34C759)   // green
            adherencePercentage >= 0.5f -> Color(0xFFFF9500)   // orange
            else -> Color(0xFFFF3B30)                           // red
        },
        animationSpec = tween(600),
        label = "fillColor"
    )

    Box(
        modifier = modifier
            .height(160.dp)
            .fillMaxWidth(0.45f),
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val w = size.width
            val h = size.height
            val bottleColor = Color.White.copy(alpha = 0.15f)
            val strokeColor = Color.White.copy(alpha = 0.5f)
            val strokeWidth = 3.dp.toPx()
            val cr = 12.dp.toPx()

            // Bottle neck
            val neckLeft = w * 0.33f
            val neckRight = w * 0.67f
            val neckTop = h * 0.05f
            val neckBottom = h * 0.20f

            // Bottle body
            val bodyLeft = w * 0.10f
            val bodyRight = w * 0.90f
            val bodyTop = neckBottom
            val bodyBottom = h * 0.92f

            // Clip fill to bottle body shape
            val bodyPath = Path().apply {
                addRoundRect(
                    androidx.compose.ui.geometry.RoundRect(
                        left = bodyLeft, top = bodyTop,
                        right = bodyRight, bottom = bodyBottom,
                        cornerRadius = CornerRadius(cr, cr)
                    )
                )
            }

            // Draw fill liquid
            val fillTop = bodyBottom - (bodyBottom - bodyTop) * animatedFill
            clipPath(bodyPath) {
                drawRect(
                    brush = Brush.verticalGradient(
                        colors = listOf(
                            fillColor.copy(alpha = 0.9f),
                            fillColor.copy(alpha = 0.6f)
                        ),
                        startY = fillTop,
                        endY = bodyBottom
                    ),
                    topLeft = Offset(bodyLeft, fillTop),
                    size = Size(bodyRight - bodyLeft, bodyBottom - fillTop)
                )
            }

            // Draw bottle outline
            drawRoundRect(
                color = bottleColor,
                topLeft = Offset(bodyLeft, bodyTop),
                size = Size(bodyRight - bodyLeft, bodyBottom - bodyTop),
                cornerRadius = CornerRadius(cr, cr),
                style = Fill
            )
            drawRoundRect(
                color = strokeColor,
                topLeft = Offset(bodyLeft, bodyTop),
                size = Size(bodyRight - bodyLeft, bodyBottom - bodyTop),
                cornerRadius = CornerRadius(cr, cr),
                style = Stroke(width = strokeWidth)
            )

            // Neck
            drawRect(
                color = bottleColor,
                topLeft = Offset(neckLeft, neckTop),
                size = Size(neckRight - neckLeft, neckBottom - neckTop)
            )
            drawRect(
                color = strokeColor,
                topLeft = Offset(neckLeft, neckTop),
                size = Size(neckRight - neckLeft, neckBottom - neckTop),
                style = Stroke(width = strokeWidth)
            )
            // Cap
            drawRoundRect(
                color = strokeColor,
                topLeft = Offset(neckLeft - 4.dp.toPx(), 0f),
                size = Size(neckRight - neckLeft + 8.dp.toPx(), neckTop + 8.dp.toPx()),
                cornerRadius = CornerRadius(6.dp.toPx(), 6.dp.toPx()),
                style = Stroke(width = strokeWidth)
            )
        }

        // Pill count label centered in bottle body
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(top = 28.dp)
        ) {
            Text(
                text = "$takenCount",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            Text(
                text = "/$totalCount",
                style = MaterialTheme.typography.bodySmall,
                color = Color.White.copy(alpha = 0.8f)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - DateStrip
// ─────────────────────────────────────

@Composable
fun DateStrip(
    selectedDate: LocalDate,
    onDateSelected: (LocalDate) -> Unit,
    modifier: Modifier = Modifier
) {
    val today = LocalDate.now()
    val dates = (-3..3).map { today.plusDays(it.toLong()) }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        dates.forEach { date ->
            val isSelected = date == selectedDate
            val isToday = date == today
            Box(
                modifier = Modifier
                    .weight(1f)
                    .aspectRatio(0.65f)
                    .clip(RoundedCornerShape(14.dp))
                    .background(
                        if (isSelected) PrimaryColor
                        else Color.White.copy(alpha = 0.1f)
                    )
                    .clickable { onDateSelected(date) },
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = date.dayOfWeek.getDisplayName(TextStyle.SHORT, Locale.getDefault())
                            .take(3).uppercase(),
                        style = MaterialTheme.typography.labelSmall,
                        color = if (isSelected) Color.White else Color.White.copy(alpha = 0.6f),
                        fontSize = 9.sp
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = date.dayOfMonth.toString(),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = if (isSelected || isToday) FontWeight.Bold else FontWeight.Normal,
                        color = if (isSelected) Color.White else Color.White.copy(alpha = 0.9f)
                    )
                    if (isToday && !isSelected) {
                        Spacer(modifier = Modifier.height(3.dp))
                        Box(
                            modifier = Modifier
                                .size(4.dp)
                                .background(PrimaryColor, CircleShape)
                        )
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - StatPillsRow
// ─────────────────────────────────────

@Composable
fun StatPillsRow(
    taken: Int,
    remaining: Int,
    adherenceRate: Float,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        StatPill(label = "Taken", value = "$taken", color = Color(0xFF34C759))
        StatPill(label = "Remaining", value = "$remaining", color = Color(0xFFFF9500))
        StatPill(
            label = "Adherence",
            value = "${(adherenceRate * 100).toInt()}%",
            color = PrimaryColor
        )
    }
}

@Composable
private fun StatPill(label: String, value: String, color: Color) {
    Box(
        modifier = Modifier
            .glass(cornerRadius = 14.dp)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = value,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = color
            )
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - TimelineGroup
// ─────────────────────────────────────

@Composable
fun TimelineGroup(
    label: String,
    doses: List<MedicationDose>,
    onMarkTaken: (MedicationDose) -> Unit,
    onMarkSkipped: (MedicationDose) -> Unit,
    onDoseClick: (MedicationDose) -> Unit,
    modifier: Modifier = Modifier
) {
    if (doses.isEmpty()) return

    Column(modifier = modifier) {
        // Time period header
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
            )
            Spacer(modifier = Modifier.width(10.dp))
            HorizontalDivider(
                modifier = Modifier.weight(1f),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f)
            )
        }

        doses.forEach { dose ->
            MedicationCard(
                dose = dose,
                onMarkTaken = { onMarkTaken(dose) },
                onMarkSkipped = { onMarkSkipped(dose) },
                onClick = { onDoseClick(dose) },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 4.dp)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - MedicationCard
// ─────────────────────────────────────

@Composable
fun MedicationCard(
    dose: MedicationDose,
    onMarkTaken: () -> Unit,
    onMarkSkipped: () -> Unit,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val timeFormatter = DateTimeFormatter.ofPattern("h:mm a")

    Box(
        modifier = modifier
            .glass(cornerRadius = 16.dp)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onClick() }
            .padding(12.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Type emoji + time
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.width(44.dp)
            ) {
                Text(
                    text = dose.medicationType.emoji,
                    style = MaterialTheme.typography.headlineSmall
                )
                Text(
                    text = dose.scheduledTime.format(timeFormatter),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                    maxLines = 1
                )
            }

            // Name + dosage
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = dose.medicationName,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                if (dose.dosage.isNotBlank()) {
                    Text(
                        text = dose.dosage,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                    )
                }
                Spacer(modifier = Modifier.height(4.dp))
                StatusBadge(status = dose.status, isOverdue = dose.isOverdue)
            }

            // Action buttons (only for actionable statuses)
            if (dose.status == AdherenceStatus.PENDING) {
                Column(
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                    horizontalAlignment = Alignment.End
                ) {
                    SmallActionButton(
                        text = "Take",
                        color = Color(0xFF34C759),
                        onClick = onMarkTaken
                    )
                    SmallActionButton(
                        text = "Skip",
                        color = Color(0xFF8E8E93),
                        onClick = onMarkSkipped
                    )
                }
            }
        }
    }
}

@Composable
private fun SmallActionButton(text: String, color: Color, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(color.copy(alpha = 0.15f))
            .border(1.dp, color.copy(alpha = 0.4f), RoundedCornerShape(8.dp))
            .clickable { onClick() }
            .padding(horizontal = 12.dp, vertical = 5.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            color = color
        )
    }
}

// ─────────────────────────────────────
// MARK: - StatusBadge
// ─────────────────────────────────────

@Composable
fun StatusBadge(status: AdherenceStatus, isOverdue: Boolean = false, modifier: Modifier = Modifier) {
    val (label, color) = when {
        isOverdue && status == AdherenceStatus.PENDING -> "Overdue" to Color(0xFFFF3B30)
        status == AdherenceStatus.PENDING -> "Pending" to Color(0xFFFF9500)
        status == AdherenceStatus.TAKEN -> "Taken" to Color(0xFF34C759)
        status == AdherenceStatus.SKIPPED -> "Skipped" to Color(0xFF8E8E93)
        status == AdherenceStatus.MISSED -> "Missed" to Color(0xFFFF3B30)
        status == AdherenceStatus.LATE -> "Late" to Color(0xFFFF9500)
        status == AdherenceStatus.EARLY -> "Early" to PrimaryColor
        else -> "Unknown" to Color(0xFF8E8E93)
    }

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(6.dp))
            .background(color.copy(alpha = 0.15f))
            .padding(horizontal = 8.dp, vertical = 3.dp)
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = color,
            fontWeight = FontWeight.Medium
        )
    }
}

// ─────────────────────────────────────
// MARK: - AdherenceBarChart (7-day)
// ─────────────────────────────────────

@Composable
fun AdherenceBarChart(
    weekDays: List<Pair<String, Float>>,  // (day label, adherence 0..1)
    modifier: Modifier = Modifier
) {
    val isDark = isSystemInDarkTheme()
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.Bottom
    ) {
        weekDays.forEach { (day, rate) ->
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.weight(1f)
            ) {
                val barColor = when {
                    rate >= 0.8f -> Color(0xFF34C759)
                    rate >= 0.5f -> Color(0xFFFF9500)
                    rate > 0f -> Color(0xFFFF3B30)
                    else -> Color.White.copy(alpha = 0.1f)
                }
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(60.dp),
                    contentAlignment = Alignment.BottomCenter
                ) {
                    val animatedHeight by animateFloatAsState(
                        targetValue = rate.coerceIn(0f, 1f),
                        animationSpec = tween(600, easing = FastOutSlowInEasing),
                        label = "bar_$day"
                    )
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .fillMaxHeight(animatedHeight.coerceAtLeast(0.04f))
                            .clip(RoundedCornerShape(topStart = 4.dp, topEnd = 4.dp))
                            .background(barColor)
                    )
                }
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = day,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                    fontSize = 10.sp
                )
            }
        }
    }
}
