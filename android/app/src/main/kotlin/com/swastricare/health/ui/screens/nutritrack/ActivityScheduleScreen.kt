package com.swastricare.health.ui.screens.nutritrack

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val TealAccent = Color(0xFF2A7D7B)
private val BackgroundColor = Color(0xFFF5F5F7)

private data class MealItem(
    val time: String,
    val emoji: String,
    val iconColor: Color,
    val name: String,
    val kcal: Int,
    val isCompleted: Boolean
)

private val mealItems = listOf(
    MealItem("6:30 AM", "\uD83E\uDD64", Color(0xFF4CAF50), "Morning Drink", 50, true),
    MealItem("6:30 AM", "\uD83C\uDF73", Color(0xFF42A5F5), "Breakfast", 244, true),
    MealItem("6:30 AM", "\uD83C\uDF6A", Color(0xFFFF9800), "Morning Snack", 144, false),
    MealItem("1:30 PM", "\uD83C\uDF7D\uFE0F", Color(0xFF42A5F5), "Lunch", 320, true),
    MealItem("7:30 PM", "\uD83C\uDF6A", Color(0xFFFF9800), "Evening Snack", 300, false),
    MealItem("7:30 PM", "\uD83C\uDF7D\uFE0F", Color(0xFF42A5F5), "Dinner Snack", 78, false),
    MealItem("9:45 PM", "\uD83E\uDD57", Color(0xFF4CAF50), "Dinner", 213, true),
    MealItem("9:45 PM", "\uD83E\uDD64", Color(0xFFFFCA28), "Night Drink", 70, false)
)

private data class DayInfo(
    val dayLetter: String,
    val date: Int,
    val isToday: Boolean
)

private val weekDays = listOf(
    DayInfo("S", 9, false),
    DayInfo("M", 10, false),
    DayInfo("T", 11, false),
    DayInfo("W", 12, true),
    DayInfo("T", 13, false),
    DayInfo("F", 14, false),
    DayInfo("S", 15, false)
)

@Composable
fun ActivityScheduleScreen(
    onNavigateBack: () -> Unit = {},
    onNavigateToAddBreakfast: () -> Unit = {}
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(BackgroundColor)
    ) {
        Spacer(modifier = Modifier.height(48.dp))

        // Top Bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onNavigateBack) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = Color.Black
                )
            }
            Text(
                text = "Activity",
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f),
                textAlign = TextAlign.Center
            )
            IconButton(onClick = { }) {
                Icon(
                    imageVector = Icons.Filled.DateRange,
                    contentDescription = "Calendar",
                    tint = Color.Black
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Week Calendar Strip
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = Color.White),
            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 16.dp),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                weekDays.forEach { day ->
                    DayColumn(day = day)
                }
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // Timeline List
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
        ) {
            var lastTime = ""
            mealItems.forEachIndexed { index, item ->
                val showTime = item.time != lastTime
                lastTime = item.time
                val isLast = index == mealItems.size - 1

                TimelineRow(
                    item = item,
                    showTime = showTime,
                    showConnector = !isLast,
                    onClick = if (item.name == "Breakfast") onNavigateToAddBreakfast else null
                )
            }

            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}

@Composable
private fun DayColumn(day: DayInfo) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = day.dayLetter,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            color = if (day.isToday) TealAccent else Color.Gray
        )
        Spacer(modifier = Modifier.height(8.dp))
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .then(
                    if (day.isToday) Modifier.background(TealAccent)
                    else Modifier
                ),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "${day.date}",
                fontSize = 15.sp,
                fontWeight = if (day.isToday) FontWeight.Bold else FontWeight.Normal,
                color = if (day.isToday) Color.White else Color(0xFF555555)
            )
        }
    }
}

@Composable
private fun TimelineRow(
    item: MealItem,
    showTime: Boolean,
    showConnector: Boolean,
    onClick: (() -> Unit)?
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable { onClick() } else Modifier)
            .padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Time column
        Box(modifier = Modifier.width(64.dp)) {
            if (showTime) {
                Text(
                    text = item.time,
                    fontSize = 12.sp,
                    color = Color.Gray,
                    fontWeight = FontWeight.Medium
                )
            }
        }

        // Icon with connector line
        Box(
            modifier = Modifier
                .size(44.dp)
                .then(
                    if (showConnector) {
                        Modifier.drawBehind {
                            drawLine(
                                color = Color(0xFFE0E0E0),
                                start = Offset(size.width / 2, size.height),
                                end = Offset(size.width / 2, size.height + 12.dp.toPx()),
                                strokeWidth = 1.5f
                            )
                        }
                    } else Modifier
                ),
            contentAlignment = Alignment.Center
        ) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(item.iconColor.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center
            ) {
                Text(text = item.emoji, fontSize = 20.sp)
            }
        }

        Spacer(modifier = Modifier.width(12.dp))

        // Meal info
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = item.name,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.Black
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = "${item.kcal} kcal",
                fontSize = 13.sp,
                color = Color.Gray
            )
        }

        // Status indicator
        if (item.isCompleted) {
            Box(
                modifier = Modifier
                    .size(28.dp)
                    .clip(CircleShape)
                    .background(TealAccent),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Filled.Check,
                    contentDescription = "Done",
                    tint = Color.White,
                    modifier = Modifier.size(16.dp)
                )
            }
        } else {
            Box(
                modifier = Modifier
                    .size(28.dp)
                    .clip(CircleShape)
                    .background(Color.Transparent)
                    .drawBehind {
                        drawCircle(
                            color = Color(0xFFD0D0D0),
                            style = androidx.compose.ui.graphics.drawscope.Stroke(width = 2f)
                        )
                    }
            )
        }
    }
}
