package com.swastricare.health.ui.screens.runactivity.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.swastricare.health.data.models.WorkoutTemplate
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.SecondaryColor

/**
 * Clean Material 3 template card - no borders, no glass.
 *
 * @param template The workout template to display
 * @param isSelected Whether this template is currently selected
 * @param onClick Callback when card is tapped
 */
@Composable
fun TemplateCard(
    template: WorkoutTemplate,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .width(140.dp)
            .clickable { onClick() },
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = when {
                isSelected -> SecondaryColor.copy(alpha = 0.2f)
                else -> AppColors.surfaceVariant
            }
        ),
        elevation = CardDefaults.cardElevation(
            defaultElevation = 0.dp
        )
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(
                text = template.name,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                color = if (isSelected) AppColors.onSurface else AppColors.onSurface.copy(alpha = 0.8f),
                maxLines = 1
            )
            Text(
                text = template.formattedTarget,
                style = MaterialTheme.typography.labelSmall,
                color = AppColors.onSurfaceVariant,
                maxLines = 1
            )
        }
    }
}
