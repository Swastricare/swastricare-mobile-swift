package com.swastricare.health.ui.screens.ai

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Article
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.MedicalServices
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.TipsAndUpdates
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.ui.theme.AITeal
import com.swastricare.health.ui.theme.AppColors

// ─────────────────────────────────────
// AI mascot illustration loader (assets/icons/ai illustration.png)
// ─────────────────────────────────────

@Composable
fun AIIllustration(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val bitmap = remember {
        runCatching {
            context.assets.open("icons/ai illustration.png").use {
                BitmapFactory.decodeStream(it)
            }
        }.getOrNull()
    }
    if (bitmap != null) {
        Image(
            bitmap = bitmap.asImageBitmap(),
            contentDescription = "Swastri AI mascot",
            contentScale = ContentScale.Fit,
            modifier = modifier
        )
    } else {
        Box(
            modifier = modifier
                .clip(CircleShape)
                .background(AITeal.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Filled.AutoAwesome,
                contentDescription = null,
                tint = AITeal,
                modifier = Modifier.size(48.dp)
            )
        }
    }
}

@Composable
fun AIAvatar(size: Dp = 32.dp, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .size(size)
            .clip(CircleShape)
            .background(AITeal.copy(alpha = 0.12f)),
        contentAlignment = Alignment.Center
    ) {
        AIIllustration(modifier = Modifier.size(size))
    }
}

// ─────────────────────────────────────
// Top header — avatar + title + subtitle, with leading/trailing actions
// ─────────────────────────────────────

@Composable
fun AIHeader(
    onMenuClick: () -> Unit,
    onClearChat: () -> Unit,
    onDeleteChat: () -> Unit
) {
    var showOverflow by androidx.compose.runtime.remember { mutableStateOf(false) }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = onMenuClick) {
            Icon(
                Icons.Default.Menu,
                contentDescription = "Open chat history",
                tint = AppColors.onBackground
            )
        }
        AIAvatar(size = 36.dp)
        Spacer(modifier = Modifier.size(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "Swastri AI",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    fontFamily = Poppins,
                    color = AppColors.onBackground
                )
                Spacer(modifier = Modifier.size(4.dp))
                Icon(
                    Icons.Filled.Verified,
                    contentDescription = null,
                    tint = AITeal,
                    modifier = Modifier.size(14.dp)
                )
            }
            Text(
                text = "Your personal health assistant",
                fontSize = 11.sp,
                fontFamily = Poppins,
                color = AppColors.onSurfaceVariant
            )
        }
        Box {
            IconButton(onClick = { showOverflow = true }) {
                Icon(
                    Icons.Default.MoreVert,
                    contentDescription = "More options",
                    tint = AppColors.onBackground
                )
            }
            DropdownMenu(
                expanded = showOverflow,
                onDismissRequest = { showOverflow = false }
            ) {
                DropdownMenuItem(
                    text = { Text("Clear chat") },
                    leadingIcon = {
                        Icon(
                            Icons.Default.Refresh,
                            contentDescription = null,
                            modifier = Modifier.size(18.dp)
                        )
                    },
                    onClick = {
                        showOverflow = false
                        onClearChat()
                    }
                )
                DropdownMenuItem(
                    text = { Text("Delete chat") },
                    leadingIcon = {
                        Icon(
                            Icons.Default.Delete,
                            contentDescription = null,
                            tint = AppColors.error,
                            modifier = Modifier.size(18.dp)
                        )
                    },
                    onClick = {
                        showOverflow = false
                        onDeleteChat()
                    }
                )
            }
        }
    }
}

// ─────────────────────────────────────
// Empty-state intro: large illustration + greeting + 2×2 quick-action grid
// ─────────────────────────────────────

data class IntroQuickAction(
    val title: String,
    val icon: ImageVector,
    val prompt: String
)

private val DefaultIntroActions = listOf(
    IntroQuickAction(
        title = "Explain my lab report",
        icon = Icons.Outlined.Description,
        prompt = "Can you help me understand my recent lab report?"
    ),
    IntroQuickAction(
        title = "Medication information",
        icon = Icons.Filled.MedicalServices,
        prompt = "Tell me about my medications and how to take them safely."
    ),
    IntroQuickAction(
        title = "Check my symptoms",
        icon = Icons.Filled.MonitorHeart,
        prompt = "I'd like to check some symptoms I'm experiencing."
    ),
    IntroQuickAction(
        title = "Health tips & guidance",
        icon = Icons.Filled.TipsAndUpdates,
        prompt = "Share personalized health tips based on my profile."
    )
)

@Composable
fun AIEmptyIntro(
    onPromptClick: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(modifier = Modifier.height(24.dp))
        AIIllustration(modifier = Modifier.size(180.dp))
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "Hi! I'm Swastri AI",
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = Poppins,
            color = AppColors.onBackground
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "Ask me anything about your health, reports, medications, symptoms and more.",
            fontSize = 13.sp,
            fontFamily = Poppins,
            color = AppColors.onSurfaceVariant,
            textAlign = TextAlign.Center,
            lineHeight = 19.sp
        )
        Spacer(modifier = Modifier.height(36.dp))
        IntroQuickActionGrid(
            actions = DefaultIntroActions,
            onAction = { onPromptClick(it.prompt) }
        )
        Spacer(modifier = Modifier.height(24.dp))
    }
}

@Composable
private fun IntroQuickActionGrid(
    actions: List<IntroQuickAction>,
    onAction: (IntroQuickAction) -> Unit
) {
    val haptic = LocalHapticFeedback.current
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        actions.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                row.forEach { action ->
                    IntroQuickActionCard(
                        action = action,
                        modifier = Modifier.weight(1f),
                        onClick = {
                            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            onAction(action)
                        }
                    )
                }
                if (row.size == 1) {
                    Spacer(modifier = Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun IntroQuickActionCard(
    action: IntroQuickAction,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White)
            .border(
                width = 1.dp,
                color = Color(0xFFE5E8EB),
                shape = RoundedCornerShape(14.dp)
            )
            .clickable { onClick() }
            .padding(horizontal = 12.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(
            imageVector = action.icon,
            contentDescription = null,
            tint = AITeal,
            modifier = Modifier.size(20.dp)
        )
        Text(
            text = action.title,
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            fontFamily = Poppins,
            color = AppColors.onBackground,
            lineHeight = 16.sp
        )
    }
}

// ─────────────────────────────────────
// Date separator (e.g. "Today")
// ─────────────────────────────────────

@Composable
fun ChatDateSeparator(label: String, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label,
            fontSize = 12.sp,
            fontFamily = Poppins,
            color = AppColors.onSurfaceVariant
        )
    }
}
