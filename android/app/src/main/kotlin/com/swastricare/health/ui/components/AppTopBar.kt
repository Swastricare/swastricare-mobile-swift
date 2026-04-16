package com.swastricare.health.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.ui.theme.AppColors

/**
 * The single standard app-wide top bar.
 *
 * Every screen header in the app uses this composable. If the title style
 * ever needs to change (font, size, alignment), change it here — not in
 * each screen.
 *
 * Layout contract:
 *   • Exactly 56.dp tall — no extra vertical breathing room
 *   • Title centered horizontally and vertically
 *   • Back button reserved on the left when [onBack] is non-null; the
 *     trailing area is padded to the same width so the title stays
 *     visually centered with or without actions
 *   • Transparent background — the screen supplies its own background
 *   • No internal window insets — MainScaffold / the detail-route
 *     wrapper already supplies status-bar padding
 */
@Composable
fun AppTopBar(
    title: String,
    modifier: Modifier = Modifier,
    onBack: (() -> Unit)? = null,
    titleColor: Color = AppColors.onSurface,
    iconTint: Color = titleColor,
    actions: @Composable RowScope.() -> Unit = {}
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Leading slot: back button when provided, otherwise empty but
        // reserves a min width so the title is visually centered.
        Box(
            modifier = Modifier.defaultMinSize(minWidth = 48.dp),
            contentAlignment = Alignment.Center
        ) {
            if (onBack != null) {
                IconButton(onClick = onBack) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = iconTint
                    )
                }
            }
        }

        Text(
            text = title,
            modifier = Modifier.weight(1f),
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold,
            color = titleColor,
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )

        // Trailing slot: actions, or an empty min-width spacer that
        // mirrors the leading slot so the title stays centered.
        Row(
            modifier = Modifier.defaultMinSize(minWidth = 48.dp),
            horizontalArrangement = Arrangement.End,
            verticalAlignment = Alignment.CenterVertically,
            content = actions
        )
    }
}
