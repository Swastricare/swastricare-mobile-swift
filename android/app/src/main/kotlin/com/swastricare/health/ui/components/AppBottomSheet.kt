package com.swastricare.health.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.swastricare.health.ui.theme.AITeal
import com.swastricare.health.ui.theme.AppColors

/**
 * App-wide floating bottom sheet — matches the activity-screen permission rationale:
 *   - Built on Dialog so it floats with side + bottom margins
 *   - All four corners rounded at 28dp
 *   - AppColors.surface background
 *   - Pinned to the bottom edge with navigation-bar inset
 *
 * Use this everywhere a screen needs a modal sheet so the look stays consistent.
 */
@Composable
fun AppBottomSheet(
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    sideMargin: Dp = 16.dp,
    bottomMargin: Dp = 12.dp,
    horizontalPadding: Dp = 24.dp,
    verticalPadding: Dp = 28.dp,
    horizontalAlignment: Alignment.Horizontal = Alignment.CenterHorizontally,
    spacing: Dp = 16.dp,
    content: @Composable ColumnScope.() -> Unit
) {
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(start = sideMargin, end = sideMargin, bottom = bottomMargin),
            contentAlignment = Alignment.BottomCenter
        ) {
            Column(
                modifier = modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(28.dp))
                    .background(AppColors.surface)
                    .padding(horizontal = horizontalPadding, vertical = verticalPadding),
                horizontalAlignment = horizontalAlignment,
                verticalArrangement = Arrangement.spacedBy(spacing)
            ) {
                content()
                Spacer(Modifier.navigationBarsPadding())
            }
        }
    }
}

/**
 * The icon header used in permission sheets — a rounded square tinted with the
 * app accent, with an icon centered inside it. Defaults match the activity-screen
 * permission rationale.
 */
@Composable
fun AppSheetIconHeader(
    icon: ImageVector,
    tint: Color = AITeal,
    backgroundAlpha: Float = 0.15f,
    size: Dp = 80.dp,
    iconSize: Dp = 40.dp,
    cornerRadius: Dp = 20.dp
) {
    Box(
        modifier = Modifier
            .size(size)
            .background(
                color = tint.copy(alpha = backgroundAlpha),
                shape = RoundedCornerShape(cornerRadius)
            ),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(iconSize)
        )
    }
}

/**
 * Centered title typically placed below [AppSheetIconHeader].
 */
@Composable
fun AppSheetTitle(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.headlineSmall,
        fontWeight = FontWeight.Bold,
        color = AppColors.onSurface,
        textAlign = TextAlign.Center
    )
}

/**
 * Centered supporting paragraph typically placed below [AppSheetTitle].
 */
@Composable
fun AppSheetDescription(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.bodyMedium,
        color = AppColors.onSurfaceVariant,
        textAlign = TextAlign.Center,
        lineHeight = MaterialTheme.typography.bodyMedium.lineHeight * 1.5f
    )
}
