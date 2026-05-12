package com.swastricare.health.ui.screens.family.member

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavController
import com.swastricare.health.ui.theme.AITeal

/**
 * AI chat screen scoped to a specific family member. Uses its own VM so it can
 * stay decoupled from the personal AIScreen (camera/food/personalities/history).
 *
 * Health context for the prompt is built by [FamilyMemberContextBuilder] via
 * `AIService.sendChatMessageForMember`. RLS on the underlying tables enforces
 * that the caller only sees what `has_family_access` permits.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FamilyMemberAIScreen(
    healthProfileId: String,
    navController: NavController,
    viewModel: FamilyMemberAIViewModel = hiltViewModel(),
) {
    LaunchedEffect(healthProfileId) {
        viewModel.init(healthProfileId)
    }

    val state by viewModel.state.collectAsState()
    val listState = rememberLazyListState()

    // Auto-scroll to newest message.
    LaunchedEffect(state.messages.size, state.isLoading) {
        if (state.messages.isNotEmpty()) {
            listState.animateScrollToItem(state.messages.size - 1)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White)
            .windowInsetsPadding(WindowInsets.systemBars)
            .imePadding(),
    ) {
        // Top bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = { navController.popBackStack() }) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = Color(0xFF111827),
                )
            }
            Column(modifier = Modifier.padding(start = 4.dp)) {
                Text(
                    text = "Ask about ${state.memberName ?: "this member"}",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(0xFF111827),
                )
                Text(
                    text = "AI-assisted summary for caregivers",
                    fontSize = 12.sp,
                    color = Color(0xFF6B7280),
                )
            }
        }

        // Messages
        if (state.messages.isEmpty()) {
            Box(modifier = Modifier.weight(1f)) {
                EmptyHint(memberName = state.memberName)
            }
        } else {
            LazyColumn(
                state = listState,
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
                contentPadding = PaddingValues(vertical = 12.dp),
            ) {
                items(state.messages, key = { it.id }) { msg ->
                    ChatBubble(content = msg.content, isUser = msg.isUser, isLoading = msg.isLoading)
                }
            }
        }

        // Suggestion chips
        if (state.messages.isEmpty()) {
            val chips = listOf(
                "How is their sleep?",
                "Are they hydrated enough?",
                "How's their medication adherence today?",
            )
            LazyRow(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(horizontal = 4.dp),
            ) {
                items(chips) { chip ->
                    SuggestionChip(text = chip) {
                        viewModel.onInputChanged(chip)
                    }
                }
            }
        }

        // Input bar
        InputBar(
            text = state.inputText,
            onTextChange = viewModel::onInputChanged,
            onSend = viewModel::sendMessage,
            isSending = state.isLoading,
        )
    }
}

@Composable
private fun EmptyHint(memberName: String?) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp)
            .padding(top = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .size(64.dp)
                .clip(CircleShape)
                .background(AITeal.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center,
        ) {
            Text(text = "AI", color = AITeal, fontWeight = FontWeight.Bold, fontSize = 20.sp)
        }
        Spacer(Modifier.height(12.dp))
        Text(
            text = "Ask anything about ${memberName ?: "this family member"}",
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color(0xFF111827),
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = "Today's vitals, hydration, sleep and medication adherence are shared with the AI for context. Replies are general guidance, not medical advice.",
            fontSize = 13.sp,
            color = Color(0xFF6B7280),
        )
    }
}

@Composable
private fun SuggestionChip(text: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(AITeal.copy(alpha = 0.08f))
            .border(1.dp, AITeal.copy(alpha = 0.3f), RoundedCornerShape(20.dp))
            .clickable { onClick() }
            .padding(horizontal = 14.dp, vertical = 8.dp),
    ) {
        Text(text = text, color = AITeal, fontSize = 13.sp, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun ChatBubble(content: String, isUser: Boolean, isLoading: Boolean) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start,
    ) {
        val bubbleColor = if (isUser) AITeal else Color(0xFFF3F4F6)
        val textColor = if (isUser) Color.White else Color(0xFF111827)
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(16.dp))
                .background(bubbleColor)
                .padding(horizontal = 14.dp, vertical = 10.dp),
        ) {
            if (isLoading) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(14.dp),
                        strokeWidth = 2.dp,
                        color = AITeal,
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(text = "Thinking…", color = Color(0xFF6B7280), fontSize = 13.sp)
                }
            } else {
                Text(text = content, color = textColor, fontSize = 14.sp)
            }
        }
    }
}

@Composable
private fun InputBar(
    text: String,
    onTextChange: (String) -> Unit,
    onSend: () -> Unit,
    isSending: Boolean,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .weight(1f)
                .heightIn(min = 44.dp)
                .clip(RoundedCornerShape(22.dp))
                .background(Color(0xFFF3F4F6))
                .border(1.dp, Color(0xFFE5E7EB), RoundedCornerShape(22.dp))
                .padding(horizontal = 16.dp, vertical = 10.dp),
            contentAlignment = Alignment.CenterStart,
        ) {
            if (text.isEmpty()) {
                Text(
                    text = "Ask about their day...",
                    color = Color(0xFF9CA3AF),
                    fontSize = 14.sp,
                )
            }
            BasicTextField(
                value = text,
                onValueChange = onTextChange,
                singleLine = false,
                cursorBrush = SolidColor(AITeal),
                textStyle = LocalTextStyle.current.copy(
                    color = Color(0xFF111827),
                    fontSize = 14.sp,
                ),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = { onSend() }),
                modifier = Modifier.fillMaxWidth(),
            )
        }
        Spacer(Modifier.width(8.dp))
        val canSend = !isSending && text.isNotBlank()
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(if (canSend) AITeal else AITeal.copy(alpha = 0.4f))
                .clickable(enabled = canSend) { onSend() },
            contentAlignment = Alignment.Center,
        ) {
            if (isSending) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    strokeWidth = 2.dp,
                    color = Color.White,
                )
            } else {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.Send,
                    contentDescription = "Send",
                    tint = Color.White,
                    modifier = Modifier.size(20.dp),
                )
            }
        }
    }
}
