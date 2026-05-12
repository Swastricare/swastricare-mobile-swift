package com.swastricare.health.ui.screens.family.member

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Snackbar
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import com.swastricare.health.data.repository.NudgePreset
import com.swastricare.health.ui.theme.AITeal
import kotlinx.coroutines.delay

private val ScreenBg = Color.White
private val OnSurface = Color(0xFF111827)
private val SubtitleColor = Color(0xFF6B7280)
private val ChipBorder = Color(0xFFE5E7EB)

private const val AUTO_DISMISS_MS = 1200L

private data class PresetChip(
    val emoji: String,
    val label: String,
    val preset: NudgePreset,
)

private val PRESETS = listOf(
    PresetChip("💊", "Take medication", NudgePreset.MEDICATION),
    PresetChip("💧", "Drink water", NudgePreset.HYDRATION),
    PresetChip("🩺", "Log vitals", NudgePreset.VITALS),
    PresetChip("📅", "Appointment", NudgePreset.APPOINTMENT),
    PresetChip("❤️", "Just checking in", NudgePreset.CHECKIN),
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FamilyNudgeScreen(
    viewModel: FamilyNudgeViewModel,
    navController: NavController,
) {
    val state by viewModel.state.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(state.event) {
        val event = state.event ?: return@LaunchedEffect
        val message = when (event) {
            is NudgeUiEvent.Success -> if (event.deliveredViaPush) {
                "Nudge sent — push delivered"
            } else {
                "Nudge sent — saved (recipient offline)"
            }
            is NudgeUiEvent.Failure -> event.message
        }
        viewModel.clearEvent()
        snackbarHostState.showSnackbar(message)
        if (event is NudgeUiEvent.Success) {
            delay(AUTO_DISMISS_MS)
            navController.popBackStack()
        }
    }

    Scaffold(
        containerColor = ScreenBg,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = if (state.memberName.isNotBlank()) {
                            "Nudge ${state.memberName}"
                        } else {
                            "Send a nudge"
                        },
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = OnSurface,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = OnSurface,
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = ScreenBg),
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) { data ->
            Snackbar(
                snackbarData = data,
                containerColor = OnSurface,
                contentColor = Color.White,
                shape = RoundedCornerShape(10.dp),
            )
        } },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(ScreenBg)
                .padding(padding),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 16.dp),
            ) {
                Text(
                    text = "Tap a preset to send instantly, or write a custom message.",
                    fontSize = 14.sp,
                    color = SubtitleColor,
                )

                Spacer(Modifier.height(20.dp))

                Text(
                    text = "Quick nudges",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    color = SubtitleColor,
                )

                Spacer(Modifier.height(10.dp))

                val chipsEnabled = !state.isSending && state.recipientUserId != null
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(PRESETS) { chip ->
                        NudgePresetChip(
                            emoji = chip.emoji,
                            label = chip.label,
                            enabled = chipsEnabled,
                            onClick = { viewModel.sendPreset(chip.preset) },
                        )
                    }
                }

                Spacer(Modifier.height(24.dp))

                Text(
                    text = "Custom message",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    color = SubtitleColor,
                )

                Spacer(Modifier.height(8.dp))

                OutlinedTextField(
                    value = state.customMessage,
                    onValueChange = { viewModel.setCustomMessage(it) },
                    modifier = Modifier.fillMaxWidth(),
                    placeholder = { Text("Type a message (max 200 chars)") },
                    minLines = 4,
                    maxLines = 6,
                    enabled = !state.isSending,
                    shape = RoundedCornerShape(12.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = AITeal,
                        cursorColor = AITeal,
                    ),
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                ) {
                    Text(
                        text = "${state.customMessage.length}/200",
                        fontSize = 11.sp,
                        color = SubtitleColor,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }

                Spacer(Modifier.height(16.dp))

                val sendEnabled = !state.isSending &&
                    state.recipientUserId != null &&
                    state.customMessage.trim().isNotEmpty()
                Button(
                    onClick = { viewModel.sendCustom() },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(52.dp),
                    enabled = sendEnabled,
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = AITeal,
                        contentColor = Color.White,
                        disabledContainerColor = AITeal.copy(alpha = 0.4f),
                        disabledContentColor = Color.White.copy(alpha = 0.8f),
                    ),
                ) {
                    Text(
                        text = if (state.isSending) "Sending…" else "Send custom",
                        fontWeight = FontWeight.SemiBold,
                    )
                }

                if (state.recipientUserId == null && !state.isSending) {
                    Spacer(Modifier.height(12.dp))
                    Text(
                        text = "Resolving member…",
                        fontSize = 12.sp,
                        color = SubtitleColor,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun NudgePresetChip(
    emoji: String,
    label: String,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    AssistChip(
        onClick = onClick,
        enabled = enabled,
        label = {
            Text(
                text = "$emoji  $label",
                fontSize = 13.sp,
                color = if (enabled) OnSurface else SubtitleColor,
            )
        },
        shape = RoundedCornerShape(20.dp),
        border = AssistChipDefaults.assistChipBorder(
            enabled = enabled,
            borderColor = AITeal,
            disabledBorderColor = ChipBorder,
            borderWidth = 1.dp,
        ),
        colors = AssistChipDefaults.assistChipColors(
            containerColor = Color.White,
            disabledContainerColor = Color.White,
        ),
    )
}
